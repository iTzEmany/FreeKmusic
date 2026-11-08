import 'dart:async';

import '../support/suggestion_gate_fake.dart';

import 'dart:io';
import 'dart:math' show max;

import 'package:audio_service/audio_service.dart' show AudioServiceShuffleMode;
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_radio_parser.dart';
import 'package:codecore/services/radio/radio_station.dart';
import 'package:codecore/services/shuffle_plus/radio_fill.dart';
import 'package:codecore/services/shuffle_plus/radio_gate.dart';
import 'package:codecore/services/shuffle_plus/seed_index.dart';
import 'package:codecore/services/shuffle_plus/seed_resolver.dart';
import 'package:codecore/services/shuffle_plus/similar_queue.dart';
import 'package:codecore/services/shuffle_plus/suggestion_log.dart';
import 'package:codecore/services/shuffle_plus/suggestion_pool.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/fake_backend.dart';
import '../support/fake_stream_preparer.dart';

YtResult _r(String id) => YtResult(
  id: id,
  title: 'T$id',
  channel: 'C$id',
  duration: const Duration(seconds: 200),
  artists: ['Artist $id'],
);

class _FakeTimer implements Timer {
  _FakeTimer(this.delay, this.run);
  final Duration delay;
  final void Function() run;
  @override
  bool isActive = true;
  @override
  int get tick => 0;
  @override
  void cancel() => isActive = false;
}

void main() {
  late Directory dir;
  late AppDatabase db;
  late OnlineEntries online;
  late CodecoreAudioHandler handler;
  late PlayerController player;
  late List<Track> lib;
  late SeedIndex seedIndex;
  late DateTime now;
  late RadioGate gate;
  final asked = <(String, String?)>[];
  final suggested = <String>[];
  final timers = <_FakeTimer>[];
  Object? radioError;
  var pageSize = 3;
  var fills = 0;
  var jam = false;
  String? downloaded;
  Set<String> matched = {};
  Completer<void>? holdFill, holdRegister;
  var closed = 0;
  var autoAdvance = false;
  int? failOnCall;
  var registering = 0, maxRegistering = 0;

  // The radio: `pageSize` songs per page, ids r<call>_<n>, endless.
  Future<RadioPage> radio(String id, {String? continuation}) async {
    asked.add((id, continuation));
    if (autoAdvance) now = now.add(const Duration(minutes: 2));
    if (failOnCall == asked.length) throw StateError('page failed');
    final e = radioError;
    if (e != null) throw e;
    final c = asked.length;
    return RadioPage([
      RadioItem(_r(id), RadioKind.song, isSeed: true),
      for (var n = 0; n < pageSize; n++)
        RadioItem(_r('r${c}_$n'), RadioKind.song),
    ], continuation: 'more');
  }

  RadioFill fillFor(RadioSeed seed) => RadioFill(
    seeds: [seed],
    resolver: SeedResolver(
      downloads: DownloadIndex(File(p.join(dir.path, 'd.json'))),
      index: seedIndex,
      searchSongs: (q) async => const [],
    ),
    radioPage: radio,
    log: SuggestionLog(
      file: () async => File(p.join(dir.path, 'l.json')),
      writeDelay: const Duration(days: 1),
    ),
    filter: testGate(),
    gate: gate,
    inLibrary: (_) => false,
  );

  SimilarQueue sessionFor(
    int seedId,
    String videoId, {
    int block = 3,
    int low = 2,
    Duration retryAfter = const Duration(minutes: 1),
    Future<void>? Function()? hold,
  }) => SimilarQueue(
    handler: handler,
    fill: fillFor(RadioSeed.online(videoId, 'Seed')),
    seedId: seedId,
    seedVideoId: videoId,
    register: (r, t) async {
      maxRegistering = max(maxRegistering, ++registering);
      await hold?.call();
      registering--;
      return online.register(r, seedTitle: t, suggested: true);
    },
    onSuggested: (r, t) => suggested.add(r.id),
    onClosed: () => closed++,
    blocked: () => jam,
    block: block,
    low: low,
    retryAfter: retryAfter,
    now: () => now,
    schedule: (d, f) {
      final t = _FakeTimer(d, f);
      timers.add(t);
      return t;
    },
  );

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('play_from_search');
    db = AppDatabase(NativeDatabase.memory());
    online = OnlineEntries();
    final repo = TrackRepository(db);
    handler = CodecoreAudioHandler(
      FakeBackend(),
      PlayQueue(),
      repo,
      onError: (_) {},
      online: online,
      preparer: FakeStreamPreparer(repo, dir),
    );
    for (final n in ['a', 'b']) {
      await db
          .into(db.tracks)
          .insert(
            TracksCompanion.insert(
              path: '/m/$n.mp3',
              title: 'Song $n',
              albumKey: 'k',
              format: 'mp3',
              sizeBytes: 1,
              mtimeMs: 1,
              addedAt: 1,
            ),
          );
    }
    lib = await db.select(db.tracks).get();
    seedIndex = SeedIndex(
      file: () async => File(p.join(dir.path, 's.json')),
      writeDelay: const Duration(days: 1),
    );
    now = DateTime(2026, 11, 8);
    gate = RadioGate(now: () => now);
    asked.clear();
    suggested.clear();
    timers.clear();
    radioError = null;
    pageSize = 3;
    fills = 0;
    jam = false;
    downloaded = null;
    matched = {};
    holdFill = holdRegister = null;
    closed = 0;
    autoAdvance = false;
    failOnCall = null;
    registering = maxRegistering = 0;
    player = PlayerController(
      handler,
      null,
      jamActive: () => jam,
      addToJam: (ids) async => throw StateError('unexpected addToJam'),
      addOnlineToJam: (_) => true,
      libraryIdOf: (r) async {
        // Only the similar songs wait: the pick's own lookup goes through.
        if (r.id.startsWith('r')) await holdRegister?.future;
        return r.id == downloaded ? lib[1].id : null;
      },
      libraryMatchIdOf: (r) async => matched.contains(r.id) ? lib[1].id : null,
      onSuggested: (r, t) => suggested.add('${r.id}/$t'),
      similarFill: (seed) async {
        fills++;
        if (seed.title == 'TA') await holdFill?.future;
        return fillFor(seed);
      },
      similarNow: () => now,
      similarSchedule: (d, f) {
        final t = _FakeTimer(d, f);
        timers.add(t);
        return t;
      },
    );
    await handler.playQueue([lib[0].id], 0);
  });
  tearDown(() async {
    player.dispose();
    await handler.dispose();
    await db.close();
    dir.deleteSync(recursive: true);
  });

  test(
    'online pick: the queue is the song and its similar ones; the old one goes',
    () async {
      expect(await player.playFromSearch(online: _r('x')), isTrue);
      final q = handler.queueIds;
      expect(q.length, 4);
      expect(
        [for (final i in q) online.entryOf(i)?.result.id],
        ['x', 'r1_0', 'r1_1', 'r1_2'],
      );
      expect(handler.currentIndex, 0);
      expect(handler.shuffleEnabled, isFalse);
      expect(asked, [('x', null)]);
      expect(player.similarTitle.value, 'Tx');
      expect(playContextOf(handler)?.kind, PlayContextKind.search);
    },
  );

  test(
    'library pick: id from the seed index, local id for a download, seed title',
    () async {
      await seedIndex.put(SeedIndex.keyOf(lib[0].title, lib[0].artist), 'vidA');
      downloaded = 'r1_1';
      expect(await player.playFromSearch(track: lib[0]), isTrue);
      expect(asked.single.$1, 'vidA');
      final q = handler.queueIds;
      expect(q[0], lib[0].id);
      expect(q[2], lib[1].id); // the downloaded one keeps its library id
      expect(online.entryOf(q[1])?.seedTitle, 'Song a');
      expect(online.entryOf(q[1])?.suggested, isTrue);
      // Only the online ones go to the suggestions log.
      expect(suggested, ['r1_0/Song a', 'r1_2/Song a']);
    },
  );

  test('a radio that fails leaves only the song', () async {
    radioError = const YtException(YtErrorKind.network);
    expect(await player.playFromSearch(online: _r('x')), isFalse);
    expect(handler.queueIds.length, 1);
    expect(player.similarTitle.value, isNull);
  });

  test(
    'in a Jam the pick joins the shared queue and no radio is asked',
    () async {
      jam = true;
      final joined = <int>[];
      final joinedOnline = <String>[];
      player = PlayerController(
        handler,
        null,
        jamActive: () => true,
        addToJam: (ids) async {
          joined.addAll(ids);
          throw StateError('stop here');
        },
        addOnlineToJam: (r) {
          joinedOnline.add(r.id);
          return true;
        },
        similarFill: (_) async {
          fills++;
          return null;
        },
      );
      await expectLater(player.playFromSearch(track: lib[1]), throwsStateError);
      expect(joined, [lib[1].id]);
      expect(await player.playFromSearch(online: _r('x')), isFalse);
      expect(joinedOnline, ['x']);
      expect(fills, 0);
      expect(handler.queueIds, [lib[0].id]);
    },
  );

  test('few songs after the current one: another block is asked', () async {
    final id = online.register(_r('s'));
    await handler.playQueue([id], 0);
    final s = sessionFor(id, 's');
    expect(await s.start(), isTrue);
    expect(handler.queueIds.length, 4);
    now = now.add(const Duration(minutes: 2));
    await handler.skipToQueueItem(1); // exactly `low` left: no request
    await pumpEventQueue();
    expect(asked.length, 1);
    await handler.skipToQueueItem(2); // 1 left, under the threshold of 2
    await pumpEventQueue();
    expect(asked.length, 2);
    expect(asked.last.$2, 'more');
    expect(handler.queueIds.length, 7);
    expect(timers, isEmpty); // a full block leaves nothing to wait for
    s.close();
  });

  test(
    'refill under RadioGate: gap of a minute, pause of 15 after a 429',
    () async {
      final id = online.register(_r('s'));
      await handler.playQueue([id], 0);
      final s = sessionFor(id, 's');
      await s.start();
      await handler.skipToQueueItem(2);
      await pumpEventQueue();
      expect(asked.length, 1); // inside the gap: no request, a wait instead
      expect(timers.single.delay, RadioGate.minGap);
      now = now.add(RadioGate.minGap + const Duration(seconds: 1));
      timers.single.run();
      await pumpEventQueue();
      expect(asked.length, 2);
      expect(handler.queueIds.length, 7);
      // The next one answers 429: nothing more for 15 minutes.
      await handler.skipToQueueItem(5);
      now = now.add(RadioGate.minGap + const Duration(seconds: 1));
      radioError = const YtException(YtErrorKind.rateLimited);
      // The queue change of the jump found the gap closed: its timer fires now.
      timers.last.run();
      await pumpEventQueue();
      expect(asked.length, 3);
      expect(gate.rateLimited, isTrue);
      expect(timers.last.delay, RadioGate.pause);
      radioError = null;
      now = now.add(RadioGate.pause);
      timers.last.run();
      await pumpEventQueue();
      expect(asked.length, 4);
      expect(handler.queueIds.length, 10);
      s.close();
    },
  );

  test(
    'a new queue during a slow lookup: nothing of the old session gets in',
    () async {
      holdRegister = Completer<void>();
      final picked = player.playFromSearch(online: _r('x'));
      await pumpEventQueue(); // the first similar song is being looked up
      await player.playFromList(lib, 0);
      holdRegister!.complete();
      expect(await picked, isNull);
      await pumpEventQueue();
      expect(handler.queueIds, [for (final t in lib) t.id]);
      expect(asked.length, 1);
      expect(player.similarTitle.value, isNull);
    },
  );

  test(
    'a Jam that starts during a lookup: the similar song does not get in',
    () async {
      holdRegister = Completer<void>();
      final picked = player.playFromSearch(online: _r('x'));
      await pumpEventQueue();
      jam = true;
      holdRegister!.complete();
      expect(await picked, isFalse);
      expect(handler.queueIds.length, 1);
    },
  );

  test('a pick overtaken by another is told to nobody (null)', () async {
    holdFill = Completer<void>();
    final a = player.playFromSearch(online: _r('A'));
    await pumpEventQueue();
    expect(await player.playFromSearch(online: _r('B')), isTrue);
    holdFill!.complete();
    expect(await a, isNull);
    expect(player.similarTitle.value, 'TB');
  });

  test(
    'a library song of another source is the library track, not a duplicate',
    () async {
      matched = {'r1_1'};
      await player.playFromSearch(online: _r('x'));
      final q = handler.queueIds;
      expect(q[2], lib[1].id);
      expect(online.idsOf(_r('r1_1')), isEmpty);
      expect(suggested, ['r1_0/Tx', 'r1_2/Tx']);
    },
  );

  test('two videos matching the same library track queue it once', () async {
    matched = {'r1_0', 'r1_1'};
    await player.playFromSearch(online: _r('x'));
    final q = handler.queueIds;
    expect(q.where((i) => i == lib[1].id).length, 1);
    expect(q.length, 3); // x, the library track, r1_2
  });

  test('shuffle on before the pick: the queue plays in order', () async {
    await handler.setShuffleMode(AudioServiceShuffleMode.all);
    await player.playFromSearch(online: _r('x'));
    expect(handler.shuffleEnabled, isFalse);
  });

  test(
    'every other way to start a queue ends the session and its wait',
    () async {
      await player.playFromSearch(
        online: _r('x'),
      ); // 3 < block: a wait is pending
      expect(timers.single.isActive, isTrue);
      player.rebuildUpcoming(); // «Svuota»
      expect(timers.single.isActive, isFalse);
      expect(player.similarTitle.value, isNull);
      await player.playFromSearch(online: _r('y'));
      expect(timers.last.isActive, isTrue);
      await player.playStations([
        const RadioStation(id: 's', name: 'S', streamUrl: 'http://s'),
      ], 0);
      expect(timers.last.isActive, isFalse);
      expect(player.similarTitle.value, isNull);
      player.dispose();
      player.dispose(); // twice is fine
    },
  );

  test(
    'the seed downloaded midway swaps its id: the session lives on',
    () async {
      final id = online.register(_r('s'));
      await handler.playQueue([id], 0);
      final s = sessionFor(id, 's');
      await s.start();
      await handler.skipToQueueItem(1); // the current entry is never swapped
      expect(handler.replaceQueueId(id, lib[1].id), isTrue);
      now = now.add(const Duration(minutes: 2));
      await handler.skipToQueueItem(2);
      await pumpEventQueue();
      expect(s.closed, isFalse);
      expect(asked.length, 2);
      expect(handler.queueIds.length, 7);
      s.close();
    },
  );

  test('with a wait pending a new queue closes at once, once, and cancels the timer', () async {
    final id = online.register(_r('s'));
    await handler.playQueue([id], 0);
    final s = sessionFor(id, 's');
    await s.start();
    await handler.skipToQueueItem(2);
    await pumpEventQueue();
    expect(timers.single.isActive, isTrue); // inside the gap
    await handler.playQueue([lib[0].id], 0);
    await pumpEventQueue();
    expect(s.closed, isTrue);
    expect(timers.single.isActive, isFalse);
    s.close();
    expect(closed, 1);
  });

  test(
    'with a wait pending, queue changes ask nothing and set no second timer',
    () async {
      final id = online.register(_r('s'));
      await handler.playQueue([id], 0);
      final s = sessionFor(id, 's');
      await s.start();
      await handler.skipToQueueItem(2);
      await pumpEventQueue();
      handler.insertAt(handler.queueIds.length, lib[0].id);
      await handler.skipToQueueItem(3);
      await pumpEventQueue();
      expect(asked.length, 1);
      expect(timers.length, 1);
      s.close();
    },
  );

  test('inserts during a refill do not start another one', () async {
    final id = online.register(_r('s'));
    await handler.playQueue([id], 0);
    final gateOpen = Completer<void>();
    final s = sessionFor(id, 's', hold: () => holdRegister?.future);
    await s.start();
    now = now.add(const Duration(minutes: 2));
    holdRegister = gateOpen;
    await handler.skipToQueueItem(2); // starts a refill, stuck at its lookup
    await pumpEventQueue();
    handler.insertAt(handler.queueIds.length, lib[0].id);
    await handler.skipToQueueItem(3);
    await pumpEventQueue();
    gateOpen.complete();
    await pumpEventQueue();
    expect(maxRegistering, 1);
    s.close();
  });

  test(
    'a failure other than a rate limit holds the next request for retryAfter',
    () async {
      final id = online.register(_r('s'));
      await handler.playQueue([id], 0);
      final s = sessionFor(id, 's', retryAfter: const Duration(minutes: 7));
      await s.start();
      now = now.add(const Duration(minutes: 2));
      radioError = StateError('boom');
      await handler.skipToQueueItem(2);
      await pumpEventQueue();
      expect(asked.length, 2);
      expect(timers.single.delay, const Duration(minutes: 7));
      expect(gate.rateLimited, isFalse);
      s.close();
    },
  );

  test('a failure inside the first block holds the refill back', () async {
    final id = online.register(_r('s'));
    await handler.playQueue([id], 0);
    autoAdvance = true;
    failOnCall = 2;
    final s = sessionFor(id, 's', block: 10, low: 20);
    expect(await s.start(), isTrue); // 3 songs, then the second page fails
    await pumpEventQueue();
    expect(asked.length, 2); // low is huge, yet nothing more is asked now
    expect(timers.single.delay, RadioGate.minGap);
    s.close();
  });
}
