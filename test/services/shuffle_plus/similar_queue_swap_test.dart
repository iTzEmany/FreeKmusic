import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/query_match.dart' show MediaKind;
import 'package:codecore/services/online/source_cooldown.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_radio_parser.dart';
import 'package:codecore/services/shuffle_plus/radio_fill.dart';
import 'package:codecore/services/shuffle_plus/radio_gate.dart';
import 'package:codecore/services/shuffle_plus/seed_index.dart';
import 'package:codecore/services/shuffle_plus/suggestion_gate.dart';
import 'package:codecore/services/shuffle_plus/seed_resolver.dart';
import 'package:codecore/services/shuffle_plus/similar_queue.dart';
import 'package:codecore/services/shuffle_plus/suggestion_log.dart';
import 'package:codecore/services/shuffle_plus/suggestion_pool.dart'
    show RadioSeed, suggestionArtistKey;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/fake_backend.dart';
import '../../support/fake_stream_preparer.dart';
import '../../support/suggestion_gate_fake.dart';

YtResult _r(String id) => YtResult(
  id: id,
  title: 'T$id',
  channel: 'C$id',
  duration: const Duration(seconds: 200),
  artists: ['Artist $id'],
);

void main() {
  late Directory dir;
  late AppDatabase db;
  late OnlineEntries online;
  late CodecoreAudioHandler handler;
  late RadioGate gate;
  late SourceCooldown cooldown;
  late SuggestionLog log;
  late DateTime now;
  final registered = <String>[], suggested = <String>[];
  var closed = 0;

  // A radio page: the seed and `n` songs r0..r<n-1>.
  Future<RadioPage> radio(String id, {String? continuation}) async =>
      RadioPage([
        RadioItem(_r(id), RadioKind.song, isSeed: true),
        for (var n = 0; n < 12; n++) RadioItem(_r('r$n'), RadioKind.song),
      ]);

  SimilarQueue session(
    int seedId, {
    Future<YtResult?> Function(YtResult)? swap,
    SuggestionGate? filter,
    Duration swapTimeout = const Duration(seconds: 45),
  }) => SimilarQueue(
    handler: handler,
    fill: RadioFill(
      seeds: [RadioSeed.online('s', 'Seed')],
      resolver: SeedResolver(
        downloads: DownloadIndex(File(p.join(dir.path, 'd.json'))),
        index: SeedIndex(
          file: () async => File(p.join(dir.path, 's.json')),
          writeDelay: const Duration(days: 1),
        ),
        searchSongs: (q) async => const [],
      ),
      radioPage: radio,
      log: log,
      filter: filter ?? testGate(),
      gate: gate,
      inLibrary: (_) => false,
    ),
    seedId: seedId,
    seedVideoId: 's',
    register: (r, t) async {
      registered.add(r.id);
      return online.register(r, seedTitle: t, suggested: true);
    },
    onSuggested: (r, t) => suggested.add(r.id),
    onClosed: () => closed++,
    blocked: () => false,
    swap: swap,
    swapTimeout: swapTimeout,
    cooldown: cooldown,
    now: () => now,
    schedule: (d, f) => Timer(const Duration(days: 1), f),
  );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('similar_swap');
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
    now = DateTime(2026, 11, 8);
    gate = RadioGate(now: () => now);
    cooldown = SourceCooldown(now: () => now);
    log = SuggestionLog(
      file: () async => File(p.join(dir.path, 'l.json')),
      writeDelay: const Duration(days: 1),
    );
    registered.clear();
    suggested.clear();
    closed = 0;
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seed() async {
    final id = online.register(_r('s'));
    await handler.playQueue([id], 0);
    return id;
  }

  test('swap == null: the first block is `block` songs, untouched', () async {
    final s = session(await seed());
    expect(await s.start(), isTrue);
    expect(registered, [
      'r0',
      'r1',
      'r2',
      'r3',
      'r4',
      'r5',
      'r6',
      'r7',
      'r8',
      'r9',
    ]);
    s.close();
  });

  test(
    'swap: first group of 3, the swapped id is registered, queued and logged',
    () async {
      final calls = <String>[];
      final s = session(
        await seed(),
        swap: (r) async {
          calls.add(r.id);
          return _r('k${r.id}');
        },
      );
      expect(await s.start(), isTrue);
      expect(calls, ['r0', 'r1', 'r2']);
      expect(registered, ['kr0', 'kr1', 'kr2']);
      expect(suggested, ['kr0', 'kr1', 'kr2']);
      expect(handler.queueIds.length, 4);
      s.close();
    },
  );

  test('swap null discards the song: the next one is tried', () async {
    final s = session(await seed(), swap: (r) async => r.id == 'r1' ? null : r);
    expect(await s.start(), isTrue);
    expect(registered, ['r0', 'r2', 'r3']);
    s.close();
  });

  test(
    'cap: at most 2 x group size swap calls, then the group ends short',
    () async {
      var calls = 0;
      final s = session(
        await seed(),
        swap: (r) async {
          calls++;
          return calls == 1 ? r : null;
        },
      );
      expect(await s.start(), isTrue);
      expect(calls, 6);
      expect(registered, ['r0']);
      s.close();
    },
  );

  test('swap discarding everything: no song, session closed', () async {
    final s = session(await seed(), swap: (r) async => null);
    expect(await s.start(), isFalse);
    expect(closed, 1);
  });

  test('a 429 from swap: video source and gate paused, no song', () async {
    final s = session(
      await seed(),
      swap: (r) async => throw const YtException(YtErrorKind.rateLimited),
    );
    expect(await s.start(), isFalse);
    expect(cooldown.isPaused(MediaKind.ytVideo), isTrue);
    expect(cooldown.isPaused(MediaKind.ytmSong), isFalse);
    expect(gate.rateLimited, isTrue);
    expect(closed, 1);
  });

  test(
    'another swap error: that song is discarded, the others go on',
    () async {
      final s = session(
        await seed(),
        swap: (r) async {
          if (r.id == 'r0') throw StateError('boom');
          return r;
        },
      );
      expect(await s.start(), isTrue);
      expect(registered, ['r1', 'r2', 'r3']);
      expect(gate.rateLimited, isFalse);
      expect(cooldown.isPaused(MediaKind.ytVideo), isFalse);
      s.close();
    },
  );

  List<String?> queued() => [
    for (final i in handler.queueIds) online.entryOf(i)?.result.id,
  ];

  test('swap to one video for every song: queued once', () async {
    final s = session(await seed(), swap: (r) async => _r('same'));
    expect(await s.start(), isTrue);
    expect(queued(), ['s', 'same']);
    s.close();
  });

  test('swap to the seed video: skipped', () async {
    final s = session(
      await seed(),
      swap: (r) async => r.id == 'r0' ? _r('s') : r,
    );
    expect(await s.start(), isTrue);
    expect(queued(), ['s', 'r1', 'r2', 'r3']);
    s.close();
  });

  test('swap to a video suggested lately: skipped', () async {
    log.addSuggestion(_r('kr0'), 'old');
    final s = session(await seed(), swap: (r) async => _r('k${r.id}'));
    expect(await s.start(), isTrue);
    expect(queued(), ['s', 'kr1', 'kr2', 'kr3']);
    s.close();
  });

  test('a disliked swapped video is not queued and is forgotten', () async {
    final s = session(
      await seed(),
      swap: (r) async => _r('k${r.id}'),
      filter: testGate(tracks: ['kr0']),
    );
    expect(await s.start(), isTrue);
    expect(queued(), ['s', 'kr1', 'kr2', 'kr3']);
    expect(suggested, isNot(contains('kr0')));
    s.close();
  });

  test(
    'the artist of the swapped result counts, not the original one',
    () async {
      final blocked = suggestionArtistKey(_r('kr0'));
      final s = session(
        await seed(),
        swap: (r) async => r.id == 'r0' ? _r('kr0') : _r('x${r.id}'),
        filter: testGate(artists: [blocked]),
      );
      expect(await s.start(), isTrue);
      expect(queued(), ['s', 'xr1', 'xr2', 'xr3']);
      s.close();
    },
  );

  test('close() during a swap: nothing is registered or queued', () async {
    final gate = Completer<void>();
    final s = session(
      await seed(),
      swap: (r) async {
        await gate.future;
        return r;
      },
    );
    final started = s.start();
    await pumpEventQueue();
    s.close();
    gate.complete();
    expect(await started, isFalse);
    expect(registered, isEmpty);
    expect(queued(), ['s']);
  });

  test('a swap that hangs is a discarded song after the timeout', () async {
    var n = 0;
    final s = session(
      await seed(),
      swapTimeout: const Duration(milliseconds: 20),
      swap: (r) => ++n == 1 ? Completer<YtResult?>().future : Future.value(r),
    );
    expect(await s.start(), isTrue);
    expect(registered, ['r1', 'r2', 'r3']);
    s.close();
  });

  test(
    'a short group holds the next request back: queue events run no more swaps',
    () async {
      var calls = 0;
      final s = session(
        await seed(),
        swap: (r) async {
          calls++;
          return calls == 1 ? r : null;
        },
      );
      expect(await s.start(), isTrue);
      expect(calls, 6);
      for (var i = 0; i < 3; i++) {
        await handler.skipToQueueItem(0);
        await pumpEventQueue();
      }
      expect(calls, 6);
      s.close();
    },
  );

  test('swap errors: that song is dropped and the next group waits', () async {
    var calls = 0;
    final s = session(
      await seed(),
      swap: (r) async {
        calls++;
        throw StateError('boom');
      },
    );
    expect(await s.start(), isFalse);
    expect(calls, 6);
  });
}
