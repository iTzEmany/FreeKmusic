import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
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

/// A Jam that only reports a status; the buttons are not looked at here.
class _Jam implements RemoteTransport {
  _Jam(this.status);

  @override
  final RemoteStatus status;
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

void main() {
  late AppDatabase db;
  late FakeBackend backend;
  late OnlineEntries online;
  late FakeStreamPreparer preparer;
  late CodecoreAudioHandler handler;
  late Directory dir;
  late List<int> ids;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    backend = FakeBackend();
    online = OnlineEntries();
    dir = Directory.systemTemp.createTempSync('media_buttons');
    for (final n in ['a', 'b']) {
      await db.into(db.tracks).insert(TracksCompanion.insert(
          path: '/m/$n.mp3', title: n, albumKey: 'k', format: 'mp3',
          sizeBytes: 1, mtimeMs: 1, addedAt: 1, durationMs: const Value(200000)));
    }
    ids = (await db.select(db.tracks).get()).map((t) => t.id).toList();
    preparer = FakeStreamPreparer(TrackRepository(db), dir);
    handler = CodecoreAudioHandler(backend, PlayQueue(), TrackRepository(db),
        onError: (_) {}, online: online, preparer: preparer);
  });
  tearDown(() async {
    await handler.dispose();
    await db.close();
    dir.deleteSync(recursive: true);
  });

  const emptyJam = RemoteStatus();

  test('the headset button pauses what plays and plays what is paused', () async {
    await handler.playQueue(ids, 0);
    await handler.click();
    expect(backend.playing, isFalse);
    await handler.click();
    expect(backend.playing, isTrue);
  });

  test('the headset button pauses a stream that still waits for its file', () async {
    final id = online.register(const YtResult(
        id: 'v1', title: 'Song', channel: 'Chan', duration: Duration(minutes: 3)));
    final gate = preparer.gates['youtube:v1'] = Completer<void>();
    final started = handler.playQueue([id], 0);
    await pumpEventQueue();
    expect(handler.loadingStream, isTrue);
    await handler.click();
    gate.complete();
    await started;
    expect(backend.playing, isFalse, reason: 'the click was a pause, not a play');
  });

  test('next and previous buttons move the queue', () async {
    await handler.playQueue(ids, 0);
    await handler.click(MediaButton.next);
    expect(handler.currentTrack?.title, 'b');
    await handler.click(MediaButton.previous);
    expect(handler.currentTrack?.title, 'a');
  });

  test('the headset button works with a Jam attached and nothing local', () async {
    final calls = <String>[];
    handler.attachRemote(_RecordingJam(calls));
    await handler.click();
    expect(calls, ['play']);
  });

  test('the headset button goes to the Jam, not to the local queue', () async {
    await handler.restore(ids, 0, Duration.zero);
    await handler.play();
    final calls = <String>[];
    handler.attachRemote(_RecordingJam(calls));
    await handler.click();
    expect(calls, ['play']);
    expect(backend.playing, isTrue, reason: 'the local player was not paused');
  });

  test('pause when already paused stays paused', () async {
    await handler.restore(ids, 0, Duration.zero);
    await handler.pause();
    await handler.pause();
    await pumpEventQueue();
    expect(backend.playing, isFalse);
    expect(handler.playbackState.value.playing, isFalse);
  });

  test('pause when stopped stays stopped', () async {
    await handler.playQueue(ids, 0);
    await handler.stop();
    await handler.pause();
    await pumpEventQueue();
    expect(handler.playbackState.value.playing, isFalse);
    expect(handler.playbackState.value.processingState, AudioProcessingState.idle);
  });

  test('a Jam with no track keeps the session alive', () async {
    handler.attachRemote(_Jam(emptyJam));
    final s = handler.playbackState.value;
    expect(s.processingState, AudioProcessingState.ready);
    expect(s.playing, isFalse);
    expect(s.controls, isNotEmpty);
  });

  test('after a Jam that ended empty, the local track keeps the session alive', () async {
    await handler.restore(ids, 1, const Duration(seconds: 7));
    handler.attachRemote(_Jam(emptyJam));
    handler.attachRemote(null);
    final s = handler.playbackState.value;
    expect(s.processingState, AudioProcessingState.ready);
    expect(handler.mediaItem.value?.title, 'b');
  });

  test('after a Jam with nothing local the session ends', () async {
    handler.attachRemote(_Jam(emptyJam));
    handler.attachRemote(null);
    expect(handler.playbackState.value.processingState, AudioProcessingState.idle);
  });

  test('the buttons and the seek bar are published in every state', () async {
    void expectButtons() {
      final s = handler.playbackState.value;
      expect(s.controls, [
        MediaControl.skipToPrevious,
        s.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ]);
      expect(s.systemActions, contains(MediaAction.seek));
    }

    await handler.playQueue(ids, 0);
    expectButtons();
    handler.attachRemote(_Jam(emptyJam));
    handler.attachRemote(null);
    expectButtons();
    await handler.pause();
    await pumpEventQueue();
    expectButtons();
  });

  test('play with nothing loaded plays the saved queue once it is restored', () async {
    await handler.play(); // the headset button woke the process: no queue yet
    await handler.restore(ids, 1, const Duration(seconds: 42));
    expect(handler.currentTrack?.title, 'b');
    expect(backend.playing, isTrue);
    expect(backend.seeks.last, const Duration(seconds: 42));
  });

  test('click with nothing loaded plays the saved queue once it is restored', () async {
    await handler.click();
    await handler.restore(ids, 1, Duration.zero);
    expect(backend.playing, isTrue);
  });

  test('a play that found nothing is forgotten once something else is loaded', () async {
    await handler.play();
    await handler.playQueue(ids, 0);
    await handler.pause();
    await handler.restore(ids, 1, Duration.zero);
    expect(backend.playing, isFalse);
  });

  test('a play that found nothing is forgotten when a Jam comes', () async {
    await handler.play();
    handler.attachRemote(_Jam(emptyJam));
    handler.attachRemote(null);
    await handler.restore(ids, 1, Duration.zero);
    expect(backend.playing, isFalse);
  });

  test('a pause before the restore cancels the play that was waiting', () async {
    await handler.play();
    await handler.pause();
    await handler.restore(ids, 1, const Duration(seconds: 42));
    expect(backend.playing, isFalse);
  });
}

class _RecordingJam extends _Jam {
  _RecordingJam(this.calls, {bool playing = false})
      : super(RemoteStatus(title: 'Jam song', playing: playing));

  final List<String> calls;
  @override
  Future<void> play() async => calls.add('play');
  @override
  Future<void> pause() async => calls.add('pause');
}
