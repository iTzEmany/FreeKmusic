import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/audio/audio_backend.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/audio/remote_transport.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_backend.dart';

class FakeRemote implements RemoteTransport {
  FakeRemote(this._status);

  RemoteStatus _status;
  final _c = StreamController<RemoteStatus>.broadcast();
  final calls = <String>[];

  void set(RemoteStatus s) {
    _status = s;
    _c.add(s);
  }

  @override
  RemoteStatus get status => _status;
  @override
  Stream<RemoteStatus> get changes => _c.stream;
  @override
  Future<void> play() async => calls.add('play');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> next() async => calls.add('next');
  @override
  Future<void> previous() async => calls.add('previous');
  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek ${position.inSeconds}');
}

/// Lets every pending async step run, without waiting on the wall clock.
Future<void> settle() => pumpEventQueue();

void main() {
  late AppDatabase db;
  late FakeBackend backend;
  late CodecoreAudioHandler handler;
  late List<int> ids;

  const playing = RemoteStatus(
    title: 'Jam song',
    artist: 'Band',
    album: 'Alb',
    duration: Duration(minutes: 3),
    position: Duration(seconds: 42),
    playing: true,
    canSkip: true,
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    backend = FakeBackend();
    for (final n in ['a', 'b']) {
      await db
          .into(db.tracks)
          .insert(
            TracksCompanion.insert(
              path: '/m/$n.mp3',
              title: n,
              albumKey: 'k',
              format: 'mp3',
              sizeBytes: 1,
              mtimeMs: 1,
              addedAt: 1,
              durationMs: const Value(100000),
            ),
          );
    }
    ids = (await db.select(db.tracks).get()).map((t) => t.id).toList();
    handler = CodecoreAudioHandler(
      backend,
      PlayQueue(),
      TrackRepository(db),
      onError: (_) {},
    );
  });
  tearDown(() async {
    await handler.dispose();
    await db.close();
  });

  test('the notification shows the Jam while it is attached', () async {
    await handler.playQueue(ids, 0);
    handler.attachRemote(FakeRemote(playing));
    expect(handler.mediaItem.value!.title, 'Jam song');
    expect(handler.mediaItem.value!.artist, 'Band');
    expect(handler.mediaItem.value!.duration, const Duration(minutes: 3));
    final st = handler.playbackState.value;
    expect(st.playing, isTrue);
    expect(st.updatePosition, const Duration(seconds: 42));
    expect(st.controls, [MediaControl.pause, MediaControl.skipToNext]);
  });

  test('a remote without «next» shows no button', () async {
    handler.attachRemote(
      FakeRemote(
        const RemoteStatus(title: 'x', playing: false, canSkip: false),
      ),
    );
    expect(handler.playbackState.value.controls, [MediaControl.play]);
  });

  test('the buttons go to the Jam and never to the local player', () async {
    await handler.playQueue(ids, 0);
    final loadedBefore = backend.loaded.length;
    final remote = FakeRemote(playing);
    handler.attachRemote(remote);

    await handler.pause();
    await handler.play();
    await handler.skipToNext();
    await handler.seek(const Duration(seconds: 90));
    await handler.skipToPrevious();
    await handler.stop();
    expect(remote.calls, [
      'pause',
      'play',
      'next',
      'seek 90',
      'previous',
      'pause',
    ]);
    expect(
      backend.loaded.length,
      loadedBefore,
      reason: 'no local track change',
    );
    expect(backend.seeks, isEmpty);
    expect(
      handler.currentTrack?.title,
      'a',
      reason: 'the local queue is as it was',
    );
  });

  test('updates from the Jam reach the notification', () async {
    final remote = FakeRemote(playing);
    handler.attachRemote(remote);
    remote.set(
      const RemoteStatus(
        title: 'Next one',
        playing: false,
        position: Duration(seconds: 3),
        canSkip: true,
      ),
    );
    await settle();
    expect(handler.mediaItem.value!.title, 'Next one');
    expect(handler.playbackState.value.playing, isFalse);
    expect(handler.playbackState.value.controls.first, MediaControl.play);
  });

  test('an empty Jam queue shows no item but keeps the session', () async {
    handler.attachRemote(FakeRemote(const RemoteStatus()));
    expect(handler.mediaItem.value, isNull);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.ready,
    );
  });

  test('local player events do not overwrite the Jam while attached', () async {
    await handler.playQueue(ids, 0);
    handler.attachRemote(FakeRemote(playing));
    backend.stateC.add(BackendState.paused);
    await settle();
    expect(handler.mediaItem.value!.title, 'Jam song');
    expect(handler.playbackState.value.playing, isTrue);
  });

  test('detaching gives the notification back to the local player', () async {
    await handler.playQueue(ids, 1);
    handler.attachRemote(FakeRemote(playing));
    handler.attachRemote(null);
    expect(handler.mediaItem.value!.title, 'b');
    expect(handler.playbackState.value.controls.first, isNotNull);
    await handler.pause();
    await settle();
    expect(backend.playing, isFalse, reason: 'the local player answers again');
  });

  test('detaching with nothing local clears the notification', () async {
    handler.attachRemote(FakeRemote(playing));
    handler.attachRemote(null);
    expect(handler.mediaItem.value, isNull);
  });
}
