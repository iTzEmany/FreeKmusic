import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/audio/audio_backend.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/audio/remote_transport.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_stream_preparer.dart';

class _Jam implements RemoteTransport {
  @override
  RemoteStatus get status => const RemoteStatus(title: 'Jam song');
  @override
  Stream<RemoteStatus> get changes => const Stream.empty();
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> next() async {}
  @override
  Future<void> previous() async {}
  @override
  Future<void> seek(Duration position) async {}
}

// The park waits are real but short: the handler takes the wait as a parameter.
// Tests that must see it fire use the short one and only look well after it;
// tests that look before it fires use the long one and do not wait at all.
const _park = Duration(milliseconds: 60);
const _long = Duration(minutes: 30);
Future<void> _past() => Future<void>.delayed(_park * 3);

void main() {
  late AppDatabase db;
  late FakeBackend backend;
  late OnlineEntries online;
  late FakeStreamPreparer preparer;
  late Directory dir;
  late List<int> ids;
  late CodecoreAudioHandler handler;

  CodecoreAudioHandler build({bool stopWhenIdle = true, Duration park = _park}) => CodecoreAudioHandler(
      backend, PlayQueue(), TrackRepository(db),
      onError: (_) {},
      online: online,
      preparer: preparer,
      stopServiceWhenIdle: stopWhenIdle,
      idleParkAfter: park);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    backend = FakeBackend();
    online = OnlineEntries();
    dir = Directory.systemTemp.createTempSync('idle_park');
    // 3 h each: long enough to keep a place (resume point).
    for (final n in ['a', 'b']) {
      await db.into(db.tracks).insert(TracksCompanion.insert(
          path: '/m/$n.mp3', title: n, albumKey: 'k', format: 'mp3',
          sizeBytes: 1, mtimeMs: 1, addedAt: 1,
          durationMs: const Value(3 * 60 * 60 * 1000)));
    }
    ids = (await db.select(db.tracks).get()).map((t) => t.id).toList();
    preparer = FakeStreamPreparer(TrackRepository(db), dir);
    handler = build();
  });
  tearDown(() async {
    await handler.dispose();
    await db.close();
    dir.deleteSync(recursive: true);
  });

  AudioProcessingState processing() => handler.playbackState.value.processingState;

  test('paused for long enough, the session goes idle but queue, track and place stay', () async {
    await handler.dispose();
    handler = build(park: _long);
    await handler.restore(ids, 1, Duration.zero);
    expect(processing(), AudioProcessingState.ready, reason: 'not before the wait is over');
    await handler.dispose();
    handler = build();
    await handler.restore(ids, 1, Duration.zero);
    backend.posC.add(const Duration(minutes: 42));
    await pumpEventQueue();
    await _past();
    expect(processing(), AudioProcessingState.idle);
    expect(handler.currentTrack?.title, 'b');
    expect(handler.queueIds, ids);
    expect(handler.currentIndex, 1);
    expect(backend.stopCalls, 0);
    expect((await TrackRepository(db).getById(ids[1]))!.resumePositionMs,
        const Duration(minutes: 42).inMilliseconds);
  });

  test('play after the park goes on from the same place', () async {
    await handler.restore(ids, 1, const Duration(minutes: 5));
    await _past();
    expect(processing(), AudioProcessingState.idle);
    final loads = backend.loaded.length, seeks = backend.seeks.length;
    await handler.play();
    await pumpEventQueue();
    expect(backend.playing, isTrue);
    expect(backend.loaded.length, loads, reason: 'nothing is loaded again');
    expect(backend.seeks.length, seeks, reason: 'no new seek: the place was kept');
    expect(processing(), AudioProcessingState.ready);
    expect(handler.playbackState.value.playing, isTrue);
  });

  test('playing keeps the session; pausing starts the wait again', () async {
    await handler.restore(ids, 0, Duration.zero);
    await handler.play();
    await _past();
    expect(processing(), AudioProcessingState.ready);
    await handler.pause();
    await _past();
    expect(processing(), AudioProcessingState.idle);
  });

  test('a Jam attached never lets it park', () async {
    await handler.restore(ids, 0, Duration.zero);
    handler.attachRemote(_Jam());
    await _past();
    expect(processing(), AudioProcessingState.ready);
    handler.attachRemote(null);
    await _past();
    expect(processing(), AudioProcessingState.idle, reason: 'after the Jam the wait runs again');
  });

  test('a Jam attached and detached before the wait is over does not park', () async {
    await handler.dispose();
    handler = build(park: const Duration(seconds: 1));
    await handler.restore(ids, 0, Duration.zero);
    expect(processing(), AudioProcessingState.ready);
    handler.attachRemote(_Jam());
    handler.attachRemote(null);
    expect(processing(), AudioProcessingState.ready);
  });

  test('a backend event after the park does not wake the session', () async {
    await handler.restore(ids, 0, Duration.zero);
    await _past();
    expect(processing(), AudioProcessingState.idle);
    backend.stateC.add(BackendState.paused);
    await pumpEventQueue();
    expect(processing(), AudioProcessingState.idle);
  });

  test('another track becoming current while parked wakes the session, and it parks again', () async {
    await handler.restore(ids, 0, Duration.zero);
    await _past();
    expect(processing(), AudioProcessingState.idle);
    await handler.removeFromQueue(0);
    await pumpEventQueue();
    expect(handler.currentTrack?.title, 'b');
    expect(processing(), AudioProcessingState.ready);
    await _past();
    expect(processing(), AudioProcessingState.idle);
  });

  test('a stream waiting for its file does not park', () async {
    final id = online.register(const YtResult(
        id: 'v1', title: 'Song', channel: 'Chan', duration: Duration(minutes: 3)));
    final gate = preparer.gates['youtube:v1'] = Completer<void>();
    await handler.restore(ids, 0, Duration.zero);
    final started = handler.playQueue([id], 0);
    await pumpEventQueue();
    expect(handler.loadingStream, isTrue);
    await _past();
    expect(processing(), AudioProcessingState.loading);
    gate.complete();
    await started;
  });

  test('on the desktop it never parks', () async {
    await handler.dispose();
    handler = build(stopWhenIdle: false);
    await handler.restore(ids, 0, Duration.zero);
    await _past();
    expect(processing(), AudioProcessingState.ready);
  });
}
