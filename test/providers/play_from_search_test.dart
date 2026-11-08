import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_radio_parser.dart';
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

  // The radio: `pageSize` songs per page, ids r<call>_<n>, endless.
  Future<RadioPage> radio(String id, {String? continuation}) async {
    asked.add((id, continuation));
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
    gate: gate,
    inLibrary: (_) => false,
  );

  SimilarQueue sessionFor(
    int seedId,
    String videoId, {
    int block = 3,
    int low = 2,
  }) => SimilarQueue(
    handler: handler,
    fill: fillFor(RadioSeed.online(videoId, 'Seed')),
    seedId: seedId,
    seedVideoId: videoId,
    register: (r, t) async => online.register(r, seedTitle: t, suggested: true),
    onSuggested: (r, t) => suggested.add(r.id),
    onClosed: () {},
    blocked: () => false,
    block: block,
    low: low,
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
    player = PlayerController(
      handler,
      null,
      jamActive: () => jam,
      addToJam: (ids) async => throw StateError('unexpected addToJam'),
      addOnlineToJam: (_) => true,
      libraryIdOf: (r) async => r.id == downloaded ? lib[1].id : null,
      onSuggested: (r, t) => suggested.add('${r.id}/$t'),
      similarFill: (seed) async {
        fills++;
        return fillFor(seed);
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
      player = PlayerController(
        handler,
        null,
        jamActive: () => true,
        addToJam: (ids) async {
          joined.addAll(ids);
          throw StateError('stop here');
        },
        similarFill: (_) async {
          fills++;
          return null;
        },
      );
      await expectLater(player.playFromSearch(track: lib[1]), throwsStateError);
      expect(joined, [lib[1].id]);
      expect(await player.playFromSearch(online: _r('x')), isFalse);
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
    await handler.skipToQueueItem(2); // 1 left, under the threshold of 2
    await pumpEventQueue();
    expect(asked.length, 2);
    expect(asked.last.$2, 'more');
    expect(handler.queueIds.length, 7);
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

  test('another queue ends the refill: no request, no insert', () async {
    expect(await player.playFromSearch(online: _r('x')), isTrue);
    expect(asked.length, 1);
    await handler.skipToQueueItem(2);
    await pumpEventQueue();
    await player.playFromList(lib, 0);
    expect(player.similarTitle.value, isNull);
    now = now.add(const Duration(hours: 1));
    await handler.skipToQueueItem(1);
    await pumpEventQueue();
    expect(asked.length, 1);
    expect(handler.queueIds, [for (final t in lib) t.id]);
  });
}
