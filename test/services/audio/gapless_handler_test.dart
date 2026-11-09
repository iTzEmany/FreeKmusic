import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/audio/audio_backend.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/crossfade_engine.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/stream/stream_preparer.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_stream_preparer.dart';

/// Lets every pending async step run, without waiting on the wall clock.
Future<void> settle() => pumpEventQueue();

void main() {
  late AppDatabase db;
  late TrackRepository repo;
  late FakeBackend backend;
  late PlayQueue queue;
  late CodecoreAudioHandler handler;
  late List<PlaybackFailure> errors;
  late List<int> ids; // a, b, c
  late int extra; // d, not in the first queue

  Future<int> insert(String name,
      {int ms = 100000, double? gain, int? resume, String album = 'k'}) async {
    await db.into(db.tracks).insert(TracksCompanion.insert(
          path: '/m/$name.mp3',
          title: name,
          albumKey: album,
          format: 'mp3',
          sizeBytes: 1,
          mtimeMs: 1,
          addedAt: 1,
          durationMs: Value(ms),
          replayGainDb: Value(gain),
          resumePositionMs: Value(resume),
        ));
    return (await repo.idForPath('/m/$name.mp3'))!;
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = TrackRepository(db);
    backend = FakeBackend();
    queue = PlayQueue(random: Random(5));
    errors = [];
    ids = [await insert('a'), await insert('b', gain: -6), await insert('c')];
    extra = await insert('d');
    handler = CodecoreAudioHandler(backend, queue, repo, onError: errors.add);
  });
  tearDown(() async {
    await handler.dispose();
    await db.close();
  });

  Future<void> startGapless({int at = 0}) async {
    await handler.playQueue(ids, at);
    await handler.setTransition(TransitionMode.gapless);
    await settle();
  }

  test('normal mode never touches the backend window', () async {
    await handler.playQueue(ids, 0);
    handler.insertAt(handler.currentIndex + 1, extra);
    handler.pauseAtTrackEnd = true;
    await settle();
    expect(backend.nextCalls, isEmpty);
  });

  test('gapless prepares the next track as soon as it is chosen', () async {
    await startGapless();
    expect(backend.nextPath, '/m/b.mp3');
    expect(backend.nextOverlap, isFalse);
  });

  test('an automatic join changes track without loading anything', () async {
    await startGapless();
    final loads = backend.loaded.length;
    final seen = <int?>[];
    handler.currentTrackStream.listen((t) => seen.add(t?.id));
    backend.advance();
    await settle();
    expect(handler.currentTrack!.title, 'b');
    expect(handler.currentIndex, 1);
    expect(seen, [ids[1]]);
    expect(backend.loaded.length, loads, reason: 'no new load');
    expect(handler.mediaItem.value!.title, 'b');
    expect(backend.nextPath, '/m/c.mp3', reason: 'the window slid on');
    expect(handler.isPlaying, isTrue);
  });

  test('the play count of the new track starts again from the join', () async {
    await startGapless();
    backend.advance();
    await settle();
    backend.posC.add(const Duration(seconds: 60)); // past half of 100 s
    await settle();
    expect((await repo.getById(ids[1]))!.playCount, 1);
    expect((await repo.getById(ids[0]))!.playCount, 0);
  });

  test('ReplayGain follows the join', () async {
    await handler.setNormalize(true);
    await startGapless();
    expect(backend.nextVolume, closeTo(CodecoreAudioHandler.gainFactor(-6), 1e-9));
    backend.advance();
    await settle();
    expect(backend.volumes.last, closeTo(CodecoreAudioHandler.gainFactor(-6), 1e-9));
    expect(backend.nextVolume, 1.0);
  });

  test('shuffle turned on mid-track changes what follows', () async {
    await startGapless();
    await handler.setShuffleMode(AudioServiceShuffleMode.all);
    await settle();
    final announced = queue.peekNext()!;
    final path = (await repo.getById(announced))!.path;
    expect(backend.nextPath, path);
    backend.advance();
    await settle();
    expect(handler.currentTrack!.id, announced);
  });

  test('removing the next track from the queue prepares the one after', () async {
    await startGapless();
    await handler.removeFromQueue(1);
    await settle();
    expect(backend.nextPath, '/m/c.mp3');
  });

  test('an insert right after the current replaces what was prepared', () async {
    await startGapless();
    handler.insertAt(handler.currentIndex + 1, extra);
    await settle();
    expect(backend.nextPath, '/m/d.mp3');
    backend.advance();
    await settle();
    expect(handler.currentTrack!.title, 'd');
  });

  test('a join the queue no longer expects plays what the queue says', () async {
    await startGapless();
    handler.insertAt(handler.currentIndex + 1, extra);
    backend.advance(); // before the window could be refreshed
    await settle();
    expect(handler.currentTrack!.title, 'd');
    expect(backend.loaded.last, '/m/d.mp3', reason: 'loaded the normal way');
  });

  test('repeat one repeats the same track in the window', () async {
    await startGapless();
    await handler.setRepeatMode(AudioServiceRepeatMode.one);
    await settle();
    expect(backend.nextPath, '/m/a.mp3');
    backend.advance();
    await settle();
    expect(handler.currentTrack!.title, 'a');
    expect(handler.currentIndex, 0);
  });

  test('the end-of-track sleep timer takes the next track away', () async {
    await startGapless();
    handler.pauseAtTrackEnd = true;
    await settle();
    expect(backend.nextPath, isNull);
    backend.stateC.add(BackendState.completed);
    await settle();
    expect(handler.currentTrack!.title, 'b', reason: 'loaded, as in normal mode');
    expect(handler.isPlaying, isFalse);
    expect(handler.pauseAtTrackEnd, isFalse);
  });

  test('the backend joined just as the timer was set: stops at the new track',
      () async {
    await startGapless();
    handler.pauseAtTrackEnd = true;
    final done = handler.pausedAtTrackEnd.first;
    backend.advance(); // before the window edit could take the next track away
    await settle();
    await done;
    expect(handler.currentTrack!.title, 'b');
    expect(backend.playing, isFalse);
    expect(handler.pauseAtTrackEnd, isFalse);
  });

  test('turning the timer off puts the next track back', () async {
    await startGapless();
    handler.pauseAtTrackEnd = true;
    await settle();
    handler.pauseAtTrackEnd = false;
    await settle();
    expect(backend.nextPath, '/m/b.mp3');
  });

  test('nothing follows the last track', () async {
    await startGapless(at: 2);
    expect(backend.nextPath, isNull);
    backend.stateC.add(BackendState.completed);
    await settle();
    expect(handler.currentTrack, isNull);
  });

  test('a next track missing from the library: the join falls back to the normal path', () async {
    await handler.playQueue([ids[0], 9999, ids[2]], 0);
    await handler.setTransition(TransitionMode.gapless);
    await settle();
    expect(backend.nextPath, isNull);
    backend.stateC.add(BackendState.completed);
    await settle();
    expect(errors.single.reason, PlaybackFailureReason.notInLibrary);
    expect(backend.loaded.last, '/m/c.mp3');
  });

  test('a track with a saved place is joined through a normal load', () async {
    final book = await insert('book', ms: 3600000, resume: 1800000);
    await handler.playQueue([ids[0], book], 0);
    await handler.setTransition(TransitionMode.gapless);
    await settle();
    expect(backend.nextPath, isNull);
  });

  test('back to normal mid-track empties the window', () async {
    await startGapless();
    await handler.setTransition(TransitionMode.normal);
    await settle();
    expect(backend.nextPath, isNull);
    backend.stateC.add(BackendState.completed);
    await settle();
    expect(handler.currentTrack!.title, 'b');
    expect(backend.loaded.last, '/m/b.mp3');
  });

  test('a manual skip loads the track and prepares the following one', () async {
    await startGapless();
    await handler.skipToNext();
    await settle();
    expect(backend.loaded.last, '/m/b.mp3');
    expect(backend.nextPath, '/m/c.mp3');
    await handler.skipToPrevious();
    await settle();
    expect(backend.loaded.last, '/m/a.mp3');
    expect(backend.nextPath, '/m/b.mp3');
  });

  test('crossfade asks for an overlap, except inside an album when told so', () async {
    final x = await insert('x', album: 'same');
    final y = await insert('y', album: 'same');
    await handler.playQueue([x, y, ids[0]], 0);
    await handler.setTransition(TransitionMode.crossfade);
    await settle();
    expect(backend.nextOverlap, isTrue);
    await handler.setTransition(TransitionMode.crossfade, plainInAlbum: true);
    await settle();
    expect(backend.nextOverlap, isFalse, reason: 'x and y share an album');
    backend.advance();
    await settle();
    expect(backend.nextOverlap, isTrue, reason: 'y to a: different albums');
  });

  group('with the crossfade engine', () {
    late List<FakeBackend> players;
    late CodecoreAudioHandler fader;
    late _Ticks ticks;

    setUp(() async {
      players = [];
      ticks = _Ticks();
      fader = CodecoreAudioHandler(
        CrossfadeEngine(() {
          final f = FakeBackend();
          players.add(f);
          return f;
        }, ticker: ticks.ticker),
        PlayQueue(),
        repo,
        onError: errors.add,
      );
    });
    tearDown(() => fader.dispose());

    Future<void> aboutToFade() async {
      await fader.playQueue(ids, 0);
      await fader.setTransition(TransitionMode.crossfade, crossfadeSeconds: 6);
      await settle();
      players[0].durC.add(const Duration(seconds: 100));
      players[1].durC.add(const Duration(seconds: 100));
      await settle();
    }

    test('the engine is told the length, and the next track waits on the other player', () async {
      await aboutToFade();
      expect(players, hasLength(2));
      expect(players[1].loaded, ['/m/b.mp3']);
    });

    test('the notification changes halfway through the fade', () async {
      await aboutToFade();
      players[0].posC.add(const Duration(seconds: 94));
      await settle();
      ticks.tick(9);
      await settle();
      expect(fader.currentTrack!.title, 'a');
      ticks.tick(1);
      await settle();
      expect(fader.currentTrack!.title, 'b');
      expect(fader.mediaItem.value!.title, 'b');
      expect(fader.currentIndex, 1);
    });

    test('the new track is counted as played from the join', () async {
      await aboutToFade();
      players[0].posC.add(const Duration(seconds: 94));
      await settle();
      ticks.tick(10);
      await settle();
      players[1].posC.add(const Duration(seconds: 60));
      await settle();
      expect((await repo.getById(ids[1]))!.playCount, 1);
    });

    test('ReplayGain of the entering track is on its own ramp', () async {
      await fader.setNormalize(true);
      await aboutToFade();
      players[0].posC.add(const Duration(seconds: 94));
      await settle();
      ticks.tick(20);
      await settle();
      // b has -6 dB of ReplayGain: its full level is that factor
      expect(players[1].volumes.last,
          closeTo(CodecoreAudioHandler.gainFactor(-6), 1e-9));
    });

    test('with the end-of-track timer there is no fade', () async {
      await aboutToFade();
      fader.pauseAtTrackEnd = true;
      await settle();
      players[0].posC.add(const Duration(seconds: 95));
      await settle();
      expect(ticks.timers, isEmpty);
      expect(players[1].playing, isFalse);
    });

    test('a new volume reaches the track waiting to come in', () async {
      await aboutToFade();
      await fader.setVolume(0.4);
      await settle();
      players[0].posC.add(const Duration(seconds: 94));
      await settle();
      ticks.tick(20);
      await settle();
      expect(players[1].volumes.last, closeTo(0.4, 1e-9));
    });

    test('changing back to normal removes the overlap', () async {
      await aboutToFade();
      await fader.setTransition(TransitionMode.normal);
      await settle();
      players[0].posC.add(const Duration(seconds: 95));
      await settle();
      expect(ticks.timers, isEmpty);
    });
  });

  group('from an address to a cached file (R-80)', () {
    late OnlineEntries online;
    late FakeStreamPreparer prep;
    late Directory dir;
    late CodecoreAudioHandler h;
    late int a, b;
    late FakeBackend fb;
    final addr = Uri.parse('https://rr1.googlevideo.com/v1');

    YtResult res(String id) => YtResult(id: id, title: 'Song $id', channel: 'C', duration: const Duration(minutes: 3));

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('gapless_url');
      fb = FakeBackend();
      online = OnlineEntries();
      prep = FakeStreamPreparer(repo, dir);
      h = CodecoreAudioHandler(fb, queue, repo, onError: errors.add, online: online, preparer: prep);
      a = online.register(res('v1'));
      b = online.register(res('v2'));
      prep.urls['youtube:v1'] = (addr, const {});
    });
    tearDown(() async {
      await h.dispose();
      dir.deleteSync(recursive: true);
    });

    File cacheB() => prep.cached['youtube:v2'] = File('${dir.path}/youtube_v2.m4a')..writeAsStringSync('x');

    Future<void> start() async {
      await h.playQueue([a, b], 0);
      await h.setTransition(TransitionMode.gapless);
      await settle();
    }

    test('A from its address and B in the cache: B is the backend next track and the join plays it', () async {
      final file = cacheB();
      await start();
      expect(fb.loadedUris, hasLength(1));
      expect(fb.nextPath, file.path);
      final loads = fb.loaded.length;
      fb.advance();
      await settle();
      expect(h.currentTrack!.id, b);
      expect(fb.loaded.length, loads);
    });

    test('B with an address only: no next track is set', () async {
      await start();
      expect(fb.nextPath, isNull);
    });

    test('B reaching the cache while A plays is set as next track', () async {
      await start();
      expect(fb.nextPath, isNull);
      final file = cacheB();
      prep.phases.value = {'youtube:v2': StreamPhase.ready};
      await settle();
      expect(fb.nextPath, file.path);
    });

    test('the cached file of B moves (a download): the window follows it', () async {
      final old = cacheB();
      await start();
      expect(fb.nextPath, old.path);
      final moved = prep.cached['youtube:v2'] = File('${dir.path}/moved_v2.m4a')..writeAsStringSync('x');
      prep.phases.value = {'youtube:v2': StreamPhase.ready};
      await settle();
      expect(fb.nextPath, moved.path);
    });

    test('a late file of the track left by a join does not take the plays of the new one', () async {
      final gate = prep.gates['youtube:v1'] = Completer<void>();
      final file = cacheB();
      await repo.upsertStreamRow('youtube:v2', res('v2'), file);
      await start();
      fb.advance();
      await settle();
      expect(h.currentTrack!.id, b);
      gate.complete(); // the file of A arrives now
      await settle();
      await h.play();
      fb.posC.add(const Duration(seconds: 40));
      await settle();
      expect((await repo.streamRow('youtube:v2'))!.playCount, 1);
    });

    test('a downloaded online entry is prepared from the library file, the join loads nothing', () async {
      h.libraryIdOf = (r) async => r.id == 'v2' ? ids.first : null;
      await start();
      expect(fb.nextPath, '/m/a.mp3');
      final loads = fb.loaded.length;
      fb.advance();
      await settle();
      expect(h.currentTrack!.id, ids.first);
      expect(fb.loaded.length, loads);
    });

    test('the next track survives the load of an address-streamed current one', () async {
      final slow = _SlowStart(repo, dir)..urls['youtube:v1'] = (addr, const {});
      h.preparer = slow;
      final started = h.playQueue([a, ids.first], 0);
      await h.setTransition(TransitionMode.gapless);
      await settle();
      slow.gate.complete();
      await started;
      await settle();
      expect(fb.nextPath, '/m/a.mp3');
    });

    test('the next track survives a recovery of the address', () async {
      await h.playQueue([a, ids.first], 0);
      await h.setTransition(TransitionMode.gapless);
      await settle();
      expect(fb.nextPath, '/m/a.mp3');
      prep.restarts['youtube:v1'] = [StreamStart.url(addr, const {})];
      fb.stateC.add(BackendState.error);
      await settle();
      expect(fb.loadedUris, hasLength(2));
      expect(fb.nextPath, '/m/a.mp3');
    });

    test('with the crossfade engine B is prepared from its file on the other player', () async {
      final players = <FakeBackend>[];
      final fader = CodecoreAudioHandler(
        CrossfadeEngine(() {
          final f = FakeBackend();
          players.add(f);
          return f;
        }, ticker: _Ticks().ticker),
        PlayQueue(),
        repo,
        onError: errors.add,
        online: online,
        preparer: prep,
      );
      addTearDown(fader.dispose);
      final file = cacheB();
      await fader.playQueue([a, b], 0);
      await fader.setTransition(TransitionMode.crossfade, crossfadeSeconds: 6);
      await settle();
      players[0].durC.add(const Duration(seconds: 100));
      players[1].durC.add(const Duration(seconds: 100));
      await settle();
      expect(players[0].loadedUris, hasLength(1));
      expect(players[1].loaded, [file.path]);
    });
  });
}

/// `start` waits for [gate]; the current entry shows as downloading, like the real one.
class _SlowStart extends FakeStreamPreparer {
  _SlowStart(super.tracks, super.dir);
  final gate = Completer<void>();

  @override
  Future<StreamStart> start(String key, YtResult r, {bool keep = true}) async {
    await gate.future;
    return super.start(key, r);
  }

  @override
  void setQueue(List<StreamItem> items) {
    super.setQueue(items);
    if (items.isNotEmpty) phases.value = {...phases.value, items.first.key: StreamPhase.downloading};
  }
}

class _FakeTimer implements Timer {
  bool active = true;
  @override
  void cancel() => active = false;
  @override
  bool get isActive => active;
  @override
  int get tick => 0;
}

class _Ticks {
  final timers = <_FakeTimer>[];
  void Function()? _onTick;

  RampTicker get ticker => (p, cb) {
        _onTick = cb;
        final t = _FakeTimer();
        timers.add(t);
        return t;
      };

  void tick([int n = 1]) {
    for (var i = 0; i < n; i++) {
      if (timers.isNotEmpty && timers.last.active) _onTick!();
    }
  }
}

