import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:audio_service/audio_service.dart';
import 'package:codecore/services/audio/audio_backend.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/radio/radio_station.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_backend.dart';

/// Lets every pending async step run, without waiting on the wall clock.
Future<void> settle() => pumpEventQueue();

void main() {
  late AppDatabase db;
  late TrackRepository repo;
  late FakeBackend backend;
  late CodecoreAudioHandler handler;
  late List<PlaybackFailure> errors;
  late List<int> ids;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = TrackRepository(db);
    backend = FakeBackend();
    errors = [];
    for (final n in ['a', 'b', 'c']) {
      await db.into(db.tracks).insert(TracksCompanion.insert(
            path: '/m/$n.mp3',
            title: n,
            albumKey: 'k',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 1,
            durationMs: const Value(100000),
          ));
    }
    ids = (await db.select(db.tracks).get()).map((t) => t.id).toList();
    handler = CodecoreAudioHandler(backend, PlayQueue(), repo,
        onError: errors.add);
  });
  tearDown(() async {
    await handler.dispose();
    await db.close();
  });

  test('playQueue loads and plays the chosen track', () async {
    await handler.playQueue(ids, 1);
    await settle();
    expect(backend.loaded.last, '/m/b.mp3');
    expect(handler.isPlaying, true);
    expect(handler.currentTrack!.title, 'b');
  });

  test('completion advances to the next track', () async {
    await handler.playQueue(ids, 0);
    backend.stateC.add(BackendState.completed);
    await settle();
    expect(backend.loaded.last, '/m/b.mp3');
  });

  test('repeat off at last track goes idle', () async {
    await handler.playQueue(ids, 2);
    backend.stateC.add(BackendState.completed);
    await settle();
    expect(handler.currentTrack, isNull);
    expect(handler.isPlaying, false);
    expect(backend.loaded.where((p) => p == '/m/c.mp3').length, 1);
  });

  test('play on the very end of the last track starts it over', () async {
    await handler.playQueue(ids, 2);
    await settle();
    backend.posC.add(const Duration(milliseconds: 100000));
    backend.stateC.add(BackendState.paused);
    await settle();
    await handler.play();
    await settle();
    expect(backend.seeks.last, Duration.zero);
    expect(handler.currentTrack!.title, 'c');
  });

  test('after «Svuota» the next track comes from the list played, not «nothing»', () async {
    await handler.playQueue(ids, 0);
    await settle();
    handler.addToQueue(ids[2]);
    // The old «Svuota»: everything after the current track removed.
    while (handler.queueIds.length > 1) {
      await handler.removeFromQueue(1);
    }
    expect(handler.hasNext, isFalse);
    final before = handler.rebuildUpcoming();
    expect(before, isNotNull);
    expect(handler.queueIds, ids, reason: 'the list again, the extra gone');
    await handler.skipToNext();
    await settle();
    expect(handler.currentTrack!.title, 'b');
    handler.restoreQueue(before!);
    expect(handler.queueIds, ids, reason: 'another track plays: no undo');
  });

  test('a new context keeps the block right after the new current track (D-488)', () async {
    await handler.playQueue([ids[0], ids[1]], 0);
    await settle();
    handler.addToQueue(ids[2]);
    await handler.playQueue([ids[1], ids[0]], 0);
    await settle();
    expect(handler.queueIds, [ids[1], ids[2], ids[0]]);
    expect(handler.userAhead, 1);
  });

  test('jumping into the block plays the touched entry, not the block head (D-494)', () async {
    for (final n in ['d', 'e', 'f']) {
      await db.into(db.tracks).insert(TracksCompanion.insert(
            path: '/m/$n.mp3',
            title: n,
            albumKey: 'k',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 1,
            durationMs: const Value(100000),
          ));
    }
    final all = (await db.select(db.tracks).get()).map((t) => t.id).toList();
    await handler.playQueue(all.sublist(0, 3), 0);
    await settle();
    handler.addToQueue(all[3]);
    handler.addToQueue(all[4]);
    handler.addToQueue(all[5]);
    expect(handler.queueIds, [all[0], all[3], all[4], all[5], all[1], all[2]]);
    var changes = 0;
    final sub = handler.queueChanges.listen((_) => changes++);
    addTearDown(sub.cancel);
    await handler.skipToQueueItem(2); // the middle one of the block
    expect(changes, greaterThan(0), reason: 'the block moved: lists reread the order');
    await settle();
    expect(handler.currentTrack!.title, 'e');
    expect(backend.loaded.last, '/m/e.mp3');
    expect(handler.queueIds, [all[0], all[4], all[3], all[5], all[1], all[2]]);
    expect(handler.userAhead, 2);
    // Past the block: the touched entry plays and the block follows it.
    await handler.skipToQueueItem(4);
    await settle();
    expect(handler.currentTrack!.title, 'b');
    expect(handler.queueIds.sublist(handler.currentIndex + 1, handler.currentIndex + 3), [all[3], all[5]]);
  });

  test('a shuffled repeat-all lap restarting tells the lists, by skip and by itself', () async {
    await handler.setRepeatMode(AudioServiceRepeatMode.all);
    await handler.setShuffleMode(AudioServiceShuffleMode.all);
    await handler.playQueue(ids, 0);
    await settle();
    var changes = 0;
    final sub = handler.queueChanges.listen((_) => changes++);
    addTearDown(sub.cancel);
    await handler.skipToNext();
    await handler.skipToNext();
    await settle();
    expect(changes, 0, reason: 'mid-lap the order stays');
    await handler.skipToNext(); // last one: a new lap, reshuffled
    await settle();
    expect(changes, 1);
    expect(handler.currentIndex, 0);
    await handler.skipToNext();
    await handler.skipToNext();
    changes = 0;
    backend.stateC.add(BackendState.completed); // the last one ends by itself
    await settle();
    expect(changes, 1);
    expect(handler.currentIndex, 0);
  });

  test('previous between stations moves the block and tells the lists', () async {
    final h = CodecoreAudioHandler(backend, PlayQueue(), repo,
        onError: errors.add, online: OnlineEntries());
    addTearDown(h.dispose);
    await h.playStations([
      const RadioStation(id: 'a', name: 'A', streamUrl: 'http://r.test/a'),
      const RadioStation(id: 'b', name: 'B', streamUrl: 'http://r.test/b'),
    ], 0);
    await settle();
    h.addToQueue(ids[2]);
    var changes = 0;
    final sub = h.queueChanges.listen((_) => changes++);
    addTearDown(sub.cancel);
    await h.skipToPrevious();
    await settle();
    expect(changes, greaterThan(0));
  });

  test('a radio station empties the block (D-496)', () async {
    final h = CodecoreAudioHandler(backend, PlayQueue(), repo,
        onError: errors.add, online: OnlineEntries());
    addTearDown(h.dispose);
    await h.playQueue(ids, 0);
    await settle();
    h.addToQueue(ids[2]);
    expect(h.userAhead, 1);
    await h.playStations(
        [const RadioStation(id: 'a', name: 'A', streamUrl: 'http://r.test/a')], 0);
    await settle();
    expect(h.userAhead, 0);
    expect(h.queueIds.length, 1);
  });

  test('removeTracks drops every occurrence, also from the list «Svuota» uses', () async {
    await handler.playQueue(ids, 0);
    await settle();
    handler.addToQueue(ids[1]);

    await handler.removeTracks({ids[1]});

    expect(handler.queueIds, [ids[0], ids[2]]);
    expect(handler.currentTrack!.title, 'a');
    handler.rebuildUpcoming();
    expect(handler.queueIds, [ids[0], ids[2]], reason: 'b is not rebuilt');
  });

  test('removeTracks of the playing track loads the next one and keeps playing', () async {
    await handler.playQueue(ids, 1);
    await settle();

    await handler.removeTracks({ids[1]});
    await settle();

    expect(handler.queueIds, [ids[0], ids[2]]);
    expect(backend.loaded.last, '/m/c.mp3');
    expect(handler.isPlaying, true);
  });

  test('load error reports and skips to next', () async {
    backend.failing.add('/m/b.mp3');
    await handler.playQueue(ids, 1);
    await settle();
    expect(errors.single.title, 'b');
    expect(errors.single.reason, PlaybackFailureReason.fileMissing);
    expect(backend.loaded.last, '/m/c.mp3');
  });

  test('more than 3 consecutive errors stop playback', () async {
    final extra = <int>[];
    for (var i = 0; i < 5; i++) {
      final id = await db.into(db.tracks).insert(TracksCompanion.insert(
            path: '/x/$i.mp3',
            title: 'x$i',
            albumKey: 'k',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 1,
          ));
      extra.add(id);
      backend.failing.add('/x/$i.mp3');
    }
    await handler.playQueue(extra, 0);
    await settle();
    expect(errors.length, 4);
    expect(handler.currentTrack, isNull);
  });

  test('togglePlayPause follows real backend state', () async {
    await handler.togglePlayPause();
    expect(backend.loaded, isEmpty);
    await handler.playQueue(ids, 0);
    await settle();
    await handler.togglePlayPause();
    await settle();
    expect(handler.isPlaying, false);
    await handler.togglePlayPause();
    await settle();
    expect(handler.isPlaying, true);
  });

  test('play count increments once after half the track', () async {
    await handler.playQueue(ids, 0);
    await settle();
    backend.posC.add(const Duration(seconds: 60));
    backend.posC.add(const Duration(seconds: 61));
    await settle();
    final t = await repo.getById(ids[0]);
    expect(t!.playCount, 1);
    expect(t.lastPlayedAt, isNotNull);
  });

  test('pauseAtTrackEnd loads the next track without playing', () async {
    await handler.playQueue(ids, 0);
    await settle();
    handler.pauseAtTrackEnd = true;
    backend.stateC.add(BackendState.completed);
    await settle();
    expect(handler.currentTrack!.title, 'b');
    expect(handler.isPlaying, false);
    expect(handler.pauseAtTrackEnd, false);
  });

  test('pauseAtTrackEnd pauses even when the backend keeps playing new files',
      () async {
    backend.playingSurvivesLoad = true;
    await handler.playQueue(ids, 0);
    await settle();
    handler.pauseAtTrackEnd = true;
    final done = handler.pausedAtTrackEnd.first;
    backend.stateC.add(BackendState.completed);
    await settle();
    await done;
    expect(handler.currentTrack!.title, 'b');
    expect(backend.playing, false);
    expect(handler.isPlaying, false);
  });

  test('pauseAtTrackEnd on the last track ends playback and says so', () async {
    await handler.playQueue(ids, 2);
    await settle();
    handler.pauseAtTrackEnd = true;
    final done = handler.pausedAtTrackEnd.first;
    backend.stateC.add(BackendState.completed);
    await settle();
    await done;
    expect(handler.currentTrack, isNull);
  });

  test('skipToNext plays the track the queue shows next, order untouched',
      () async {
    final more = <int>[
      for (var i = 0; i < 12; i++)
        await db.into(db.tracks).insert(TracksCompanion.insert(
              path: '/m/x$i.mp3',
              title: 'x$i',
              albumKey: 'k',
              format: 'mp3',
              sizeBytes: 1,
              mtimeMs: 1,
              addedAt: 1,
              durationMs: const Value(100000),
            )),
    ];
    await handler.setShuffleMode(AudioServiceShuffleMode.all);
    await handler.playQueue(more, 2);
    await settle();
    final shown = handler.queueIds;
    for (var i = 1; i <= 3; i++) {
      await handler.skipToNext();
      await settle();
      expect(handler.currentTrack!.id, shown[handler.currentIndex]);
      expect(handler.currentIndex, i);
      expect(handler.queueIds, shown, reason: 'not reshuffled');
    }
  });

  group('speed', () {
    test('goes to the backend and to the published state', () async {
      await handler.playQueue(ids, 0);
      await handler.setSpeed(1.5);
      expect(backend.speed, 1.5);
      expect(handler.speed, 1.5);
      expect(handler.playbackState.value.speed, 1.5);
    });

    test('is kept between 0.5× and 2×', () async {
      await handler.setSpeed(9);
      expect(handler.speed, 2.0);
      await handler.setSpeed(0.1);
      expect(handler.speed, 0.5);
    });

    test('the same value again does not bother the backend', () async {
      await handler.setSpeed(1.25);
      await handler.setSpeed(1.25);
      expect(backend.speedCalls, [1.25]);
    });

    test('survives a track change on a backend that forgets it', () async {
      backend.forgetSpeedOnLoad = true;
      await handler.playQueue(ids, 0);
      await handler.setSpeed(1.5);
      await handler.skipToNext();
      await settle();
      expect(backend.loaded.last, '/m/b.mp3');
      expect(backend.speed, 1.5, reason: 'reapplied after the new load');
    });

    test('1× needs no extra call when nothing was changed', () async {
      await handler.playQueue(ids, 0);
      expect(backend.speedCalls, isEmpty);
    });
  });

  group('«riprendi da qui»', () {
    late int longId, shortId;
    const hour = 60 * 60 * 1000;

    Future<int?> saved(int id) async => (await repo.getById(id))!.resumePositionMs;
    Future<void> at(Duration p) async {
      backend.posC.add(p);
      await settle();
    }

    setUp(() async {
      longId = await db.into(db.tracks).insert(TracksCompanion.insert(
            path: '/m/book.mp3',
            title: 'Book',
            albumKey: 'k',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 1,
            durationMs: const Value(hour),
          ));
      shortId = ids.first;
    });

    test('saves while playing, at most every 15 seconds', () async {
      await handler.playQueue([longId], 0);
      await at(const Duration(seconds: 40));
      expect(await saved(longId), 40000);
      await at(const Duration(seconds: 50)); // only 10 s later
      expect(await saved(longId), 40000);
      await at(const Duration(seconds: 56));
      expect(await saved(longId), 56000);
    });

    test('pausing saves the exact place', () async {
      await handler.playQueue([longId], 0);
      await at(const Duration(minutes: 12, seconds: 3));
      await handler.pause();
      await settle();
      expect(await saved(longId), const Duration(minutes: 12, seconds: 3).inMilliseconds);
    });

    test('next time it starts 5 seconds before the saved point', () async {
      await repo.setResumePosition(longId, 600000);
      await handler.playQueue([longId], 0);
      await settle();
      expect(backend.seeks.last, const Duration(minutes: 9, seconds: 55));
    });

    test('an explicit position (restoring the last session) wins', () async {
      await repo.setResumePosition(longId, 600000);
      await handler.restore([longId], 0, const Duration(minutes: 3));
      await settle();
      expect(backend.seeks.last, const Duration(minutes: 3));
    });

    test('leaving the track for another one keeps its place', () async {
      await handler.playQueue([longId, shortId], 0);
      await at(const Duration(minutes: 20));
      await handler.skipToNext();
      await settle();
      expect(await saved(longId), const Duration(minutes: 20).inMilliseconds);
    });

    test('finishing the track clears the bookmark', () async {
      await repo.setResumePosition(longId, 600000);
      await handler.playQueue([longId, shortId], 0);
      await at(const Duration(minutes: 59, seconds: 50));
      backend.stateC.add(BackendState.completed);
      await settle();
      expect(await saved(longId), isNull);
    });

    test('the last 30 seconds clear it too', () async {
      await handler.playQueue([longId], 0);
      await at(const Duration(minutes: 30));
      expect(await saved(longId), isNotNull);
      await at(const Duration(minutes: 59, seconds: 45));
      await handler.pause();
      await settle();
      expect(await saved(longId), isNull);
    });

    test('short tracks are never bookmarked', () async {
      await handler.playQueue([shortId], 0);
      await at(const Duration(seconds: 60));
      await handler.pause();
      await settle();
      expect(await saved(shortId), isNull);
    });
  });
}
