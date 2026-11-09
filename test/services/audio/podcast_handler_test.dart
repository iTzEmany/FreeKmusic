import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/audio/audio_backend.dart';
import 'package:audio_service/audio_service.dart' show AudioServiceRepeatMode;
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_stream_preparer.dart';

/// Remembers whether the old track was still playing when the address was opened.
class _SpyBackend extends FakeBackend {
  bool? playingAtLoadUri;
  @override
  Future<void> loadUri(Uri uri, {Map<String, String> headers = const {}}) {
    playingAtLoadUri = playing;
    return super.loadUri(uri, headers: headers);
  }
}

/// Lets every pending async step run, without waiting on the wall clock.
Future<void> settle() => pumpEventQueue();

void main() {
  late AppDatabase db;
  late TrackRepository repo;
  late FakeBackend backend;
  late CodecoreAudioHandler handler;
  late List<int> heard;
  late int episodeId, otherEpisodeId, songId;
  const ten = 10 * 60 * 1000; // a 10-minute episode: under the 20-minute rule for music

  Future<int> add(String name, {int kind = 0, int ms = ten}) => db.into(db.tracks).insert(
      TracksCompanion.insert(
        path: '/m/$name.mp3', title: name, albumKey: 'k$kind', format: 'mp3',
        sizeBytes: 1, mtimeMs: 1, addedAt: 1, durationMs: Value(ms), kind: Value(kind)));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = TrackRepository(db);
    backend = FakeBackend();
    heard = [];
    episodeId = await add('ep1', kind: 1);
    otherEpisodeId = await add('ep2', kind: 1);
    songId = await add('song');
    handler = CodecoreAudioHandler(backend, PlayQueue(), repo, onError: (_) {}, onEpisodeHeard: heard.add);
  });
  tearDown(() async {
    await handler.dispose();
    await db.close();
  });

  Future<int?> saved(int id) async => (await repo.getById(id))!.resumePositionMs;
  Future<void> at(Duration p) async {
    backend.posC.add(p);
    await settle();
  }

  test('a short episode is bookmarked while playing (a song of that length would not be)', () async {
    await handler.playQueue([episodeId], 0);
    await at(const Duration(seconds: 5));
    expect(await saved(episodeId), isNull, reason: 'the first 10 seconds are not a place to come back to');
    await at(const Duration(minutes: 3));
    expect(await saved(episodeId), const Duration(minutes: 3).inMilliseconds);

    await handler.playQueue([songId], 0);
    await at(const Duration(minutes: 3));
    expect(await saved(songId), isNull);
  });

  test('an episode takes the length the player measures; a song keeps its own', () async {
    await handler.playQueue([episodeId], 0);
    backend.durC.add(const Duration(minutes: 11));
    await settle();
    expect((await repo.getById(episodeId))!.durationMs, const Duration(minutes: 11).inMilliseconds);

    await handler.playQueue([songId], 0);
    backend.durC.add(const Duration(minutes: 3));
    await settle();
    expect((await repo.getById(songId))!.durationMs, ten);
  });

  test('pausing keeps the exact place, and the next play starts 5 seconds earlier', () async {
    await handler.playQueue([episodeId], 0);
    await at(const Duration(minutes: 4, seconds: 20));
    await handler.pause();
    await settle();
    expect(await saved(episodeId), const Duration(minutes: 4, seconds: 20).inMilliseconds);

    await handler.playQueue([episodeId], 0);
    await settle();
    expect(backend.seeks.last, const Duration(minutes: 4, seconds: 15));
  });

  test('it counts as heard once, past 95 %, and the bookmark is cleared', () async {
    await handler.playQueue([episodeId], 0);
    await at(const Duration(minutes: 9)); // 90 %
    expect(heard, isEmpty);
    await at(const Duration(minutes: 9, seconds: 40)); // 96.7 %
    await at(const Duration(minutes: 9, seconds: 50));
    await handler.pause();
    await settle();
    expect(heard, [episodeId], reason: 'reported once, not at every save');
    expect(await saved(episodeId), isNull);
  });

  test('playing it to the end counts as heard, even if no save came near the end', () async {
    await handler.playQueue([episodeId, songId], 0);
    await at(const Duration(minutes: 2));
    // The last 15-second save was a while ago; then the end arrives.
    backend.posC.add(const Duration(minutes: 9, seconds: 59));
    backend.stateC.add(BackendState.completed);
    await settle();
    expect(heard, [episodeId]);
    expect(await saved(episodeId), isNull);
  });

  test('music never reports anything, however it ends', () async {
    await handler.playQueue([songId], 0);
    await at(const Duration(minutes: 9, seconds: 50));
    backend.stateC.add(BackendState.completed);
    await settle();
    expect(heard, isEmpty);
  });

  test('another episode is reported on its own', () async {
    await handler.playQueue([episodeId, otherEpisodeId], 0);
    await at(const Duration(minutes: 9, seconds: 50));
    await handler.skipToNext();
    await settle();
    await at(const Duration(minutes: 9, seconds: 55));
    await handler.pause();
    await settle();
    expect(heard, [episodeId, otherEpisodeId]);
  });

  test('a callback that throws does not break playback', () async {
    await handler.dispose();
    handler = CodecoreAudioHandler(backend, PlayQueue(), repo,
        onError: (_) {}, onEpisodeHeard: (_) => throw StateError('db closed'));
    await handler.playQueue([episodeId], 0);
    await at(const Duration(minutes: 9, seconds: 50));
    await handler.pause();
    await settle();
    expect(handler.playbackState.value.playing, isFalse);
  });

  group('an episode that is not downloaded (a remote row)', () {
    const url = 'https://feed.example/ep.mp3';
    late int remoteId;
    const hour = 60 * 60 * 1000;

    setUp(() async {
      remoteId = await db.into(db.tracks).insert(TracksCompanion.insert(
          path: url, title: 'Remote', albumKey: 'podcast|1', format: 'mp3', sizeBytes: 0, mtimeMs: 0,
          addedAt: 1, durationMs: const Value(hour), kind: const Value(1)));
    });

    test('plays from its address and keeps the bookmark', () async {
      await handler.playQueue([remoteId], 0);
      await settle();
      expect(backend.loadedUris.single.uri, Uri.parse(url));
      expect(backend.loaded, isEmpty, reason: 'no file to open');
      await at(const Duration(minutes: 7));
      await handler.pause();
      await settle();
      expect(await saved(remoteId), const Duration(minutes: 7).inMilliseconds);
    });

    test('starts again 5 seconds before the bookmark, even after music', () async {
      await (db.update(db.tracks)..where((t) => t.id.equals(remoteId)))
          .write(const TracksCompanion(resumePositionMs: Value(20 * 60 * 1000)));
      await handler.playQueue([songId], 0);
      await settle();
      await handler.playQueue([remoteId], 0);
      await settle();
      expect(backend.seeks.last, const Duration(minutes: 19, seconds: 55));
    });

    test('with no network the track is skipped with a message and nothing crashes', () async {
      final failures = <PlaybackFailure>[];
      await handler.dispose();
      backend.failing.add(url);
      handler = CodecoreAudioHandler(backend, PlayQueue(), repo, onError: failures.add);
      await handler.playQueue([remoteId, songId], 0);
      await settle();
      expect(failures.map((f) => f.reason), contains(PlaybackFailureReason.onlineUnavailable));
    });

    Future<int> remote(String name, {int ms = hour}) => db.into(db.tracks).insert(TracksCompanion.insert(
        path: 'https://feed.example/$name.mp3', title: name, albumKey: 'podcast|1', format: 'mp3', sizeBytes: 0,
        mtimeMs: 0, addedAt: 1, durationMs: Value(ms), kind: const Value(1)));

    Future<List<PlaybackFailure>> fresh({
      FakeBackend? with_,
      void Function(int)? resumed,
      FakeStreamPreparer? preparer,
    }) async {
      final failures = <PlaybackFailure>[];
      await handler.dispose();
      if (with_ != null) backend = with_;
      handler = CodecoreAudioHandler(backend, PlayQueue(), repo,
          onError: failures.add, onEpisodeHeard: heard.add, onEpisodeResumed: resumed, preparer: preparer);
      return failures;
    }

    test('the old track stops before the address is opened', () async {
      final spy = _SpyBackend();
      await fresh(with_: spy);
      await handler.playQueue([songId], 0);
      await settle();
      await handler.play();
      await settle();
      await handler.playQueue([remoteId], 0);
      await settle();
      expect(spy.playingAtLoadUri, isFalse);
    });

    test('a queue of remote episodes goes from one to the next, none prepared as a file', () async {
      final second = await remote('second');
      await handler.playQueue([remoteId, second], 0);
      await settle();
      await handler.skipToNext();
      await settle();
      expect(backend.loadedUris.map((u) => u.uri.toString()), [url, 'https://feed.example/second.mp3']);
      expect(backend.nextCalls.whereType<String>(), isEmpty);
    });

    test('repeat one plays the episode from its address again', () async {
      await handler.playQueue([remoteId], 0);
      await handler.setRepeatMode(AudioServiceRepeatMode.one);
      await settle();
      await at(const Duration(minutes: 59));
      backend.stateC.add(BackendState.completed);
      await settle();
      expect(backend.loadedUris, hasLength(2));
      expect(backend.nextCalls.whereType<String>(), isEmpty);
    });

    test('a stream that ends early (the network went) keeps the place, is not heard and says so', () async {
      final failures = await fresh();
      await handler.playQueue([remoteId, songId], 0);
      await settle();
      await at(const Duration(minutes: 5));
      backend.stateC.add(BackendState.completed);
      await settle();
      expect(failures.map((f) => f.reason), [PlaybackFailureReason.onlineUnavailable]);
      expect(heard, isEmpty);
      expect(await saved(remoteId), const Duration(minutes: 5).inMilliseconds);
    });

    test('a stream that ends at its end is heard and forgets the place', () async {
      final failures = await fresh();
      await handler.playQueue([remoteId], 0);
      await settle();
      await at(const Duration(minutes: 59, seconds: 50));
      backend.stateC.add(BackendState.completed);
      await settle();
      expect(failures, isEmpty);
      expect(heard, [remoteId]);
      expect(await saved(remoteId), isNull);
    });

    test('a player error half way keeps the place and moves on with a message, not stuck', () async {
      final failures = await fresh();
      await handler.playQueue([remoteId, songId], 0);
      await settle();
      await at(const Duration(minutes: 8));
      backend.stateC.add(BackendState.error);
      await settle();
      expect(failures.map((f) => f.reason), [PlaybackFailureReason.onlineUnavailable]);
      expect(await saved(remoteId), const Duration(minutes: 8).inMilliseconds);
      expect(backend.loaded, ['/m/song.mp3']);
    });

    test('a YouTube Music episode (kind 1, stream:) streams through the preparer and starts at its bookmark', () async {
      final dir = Directory.systemTemp.createTempSync('ytm_ep');
      addTearDown(() => dir.deleteSync(recursive: true));
      final preparer = FakeStreamPreparer(repo, dir);
      preparer.urls['youtube:v1'] = (Uri.parse('https://rr1.googlevideo.com/ep'), const {});
      await fresh(preparer: preparer);
      final ytm = await db.into(db.tracks).insert(TracksCompanion.insert(
          path: 'stream:youtube:v1', title: 'Ytm', albumKey: 'podcast|2', format: 'm4a', sizeBytes: 0, mtimeMs: 0,
          addedAt: 1, durationMs: const Value(hour), kind: const Value(1), resumePositionMs: const Value(30 * 60 * 1000)));
      await handler.playQueue([ytm], 0);
      await settle();
      expect(backend.loadedUris.single.uri.host, 'rr1.googlevideo.com');
      expect(backend.seeks.last, const Duration(minutes: 29, seconds: 55));
      await at(const Duration(minutes: 31));
      await handler.pause();
      await settle();
      expect(await saved(ytm), const Duration(minutes: 31).inMilliseconds, reason: 'bookmarked like any episode');
      expect(preparer.queues.last, ['youtube:v1']);
    });

    test('listening again to an episode marked as heard takes the mark away, once, and it can be heard again', () async {
      final resumed = <int>[];
      await fresh(resumed: resumed.add);
      await handler.playQueue([remoteId], 0);
      await settle();
      await at(const Duration(minutes: 2));
      await at(const Duration(minutes: 3));
      await handler.pause();
      await settle();
      expect(resumed, [remoteId], reason: 'on the first bookmark of the session only');
      await handler.play();
      await at(const Duration(minutes: 59, seconds: 40));
      await handler.pause();
      await settle();
      expect(heard, [remoteId]);
      await handler.play();
      await at(const Duration(minutes: 5));
      await handler.pause();
      await settle();
      expect(resumed, [remoteId, remoteId], reason: 'heard again, then resumed again');
    });
  });
}
