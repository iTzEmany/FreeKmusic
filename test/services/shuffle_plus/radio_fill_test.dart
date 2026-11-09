import 'dart:io';

import '../../support/suggestion_gate_fake.dart';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_radio_parser.dart';
import 'package:codecore/services/shuffle_plus/radio_fill.dart';
import 'package:codecore/services/shuffle_plus/radio_gate.dart';
import 'package:codecore/services/shuffle_plus/seed_index.dart';
import 'package:codecore/services/shuffle_plus/seed_resolver.dart';
import 'package:codecore/services/shuffle_plus/suggestion_log.dart';
import 'package:codecore/services/shuffle_plus/suggestion_pool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

YtResult song(String id) => YtResult(
  id: id,
  title: 'Title $id',
  channel: 'Artist $id',
  duration: const Duration(seconds: 200),
  artists: ['Artist $id'],
  album: 'Album',
);

void main() {
  test('only the first request of the session ignores the gap; '
      'later ones wait for it, with the same continuation', () async {
    final dir = Directory.systemTemp.createTempSync('radio_fill');
    addTearDown(() => dir.deleteSync(recursive: true));
    final resolver = SeedResolver(
      downloads: DownloadIndex(File(p.join(dir.path, 'd.json'))),
      index: SeedIndex(file: () async => File(p.join(dir.path, 's.json'))),
      searchSongs: (q) async => const [],
    );
    final now = DateTime(2026, 11, 4);
    final gate = RadioGate(now: () => now)..asked(); // inside the gap
    final calls = <String?>[];
    final fill = RadioFill(
      seeds: [RadioSeed.online('seed', 'Seed')],
      resolver: resolver,
      radioPage: (id, {continuation}) async {
        calls.add(continuation);
        return RadioPage([
          RadioItem(song('seed'), RadioKind.song, isSeed: true),
          RadioItem(song('r${calls.length}'), RadioKind.song),
        ], continuation: 'next');
      },
      log: SuggestionLog(
        file: () async => File(p.join(dir.path, 'l.json')),
        writeDelay: const Duration(days: 1),
      ),
      filter: testGate(),
      gate: gate,
      inLibrary: (r) => false,
    );
    Future<List<String>> take() =>
        fill.take(1, inQueue: (_) => false).map((c) => c.result.id).toList();

    expect(await take(), ['r1']); // gap ignored: first of the session
    expect(await take(), isEmpty); // pool empty, gap closed: no request
    expect(calls, [null]);
    gate.lastRadio = now.subtract(RadioGate.minGap * 2);
    expect(await take(), ['r2']);
    expect(calls, [null, 'next']);
  });

  group('seeds and pool', () {
    late Directory dir;
    late int searches;
    late List<YtResult> found;
    late List<String> asked;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('radio_fill2');
      addTearDown(() => dir.deleteSync(recursive: true));
      searches = 0;
      found = [];
      asked = [];
    });

    Track libTrack(int id) => Track(
      coverSource: 0,
      id: id,
      path: '/m/$id.mp3',
      title: 'Song $id',
      artist: 'Band $id',
      genre: 'Rock',
      albumKey: 'k',
      durationMs: 200000,
      format: 'mp3',
      sizeBytes: 1,
      mtimeMs: 1,
      hasCover: false,
      isFavorite: false,
      enrichStatus: 0,
      userEdited: false,
      missing: false,
      ignored: false,
      kind: 0,
      addedAt: 1,
      playCount: 0,
    );

    RadioFill fill(
      List<RadioSeed> seeds,
      RadioPage Function(String id) pageOf,
    ) {
      var t = DateTime(2026, 11, 4); // the gap never holds a test back
      return RadioFill(
        seeds: seeds,
        resolver: SeedResolver(
          downloads: DownloadIndex(File(p.join(dir.path, 'd.json'))),
          index: SeedIndex(file: () async => File(p.join(dir.path, 's.json'))),
          searchSongs: (q) async {
            searches++;
            return found;
          },
        ),
        radioPage: (id, {continuation}) async {
          asked.add(id);
          return pageOf(id);
        },
        log: SuggestionLog(
          file: () async => File(p.join(dir.path, 'l.json')),
          writeDelay: const Duration(days: 1),
        ),
        filter: testGate(),
        gate: RadioGate(now: () => t = t.add(const Duration(minutes: 2))),
        inLibrary: (r) => false,
      );
    }

    YtResult by(String id, String artist) => YtResult(
      id: id,
      title: 'Title $id',
      channel: artist,
      duration: const Duration(seconds: 200),
      artists: [artist],
      album: 'Album',
    );

    Future<List<String>> ids(RadioFill f, int want, {int maxRequests = 4}) => f
        .take(want, inQueue: (_) => false, maxRequests: maxRequests)
        .map((c) => c.result.id)
        .toList();

    test('the same artist is never served twice in a row', () async {
      final f = fill([RadioSeed.online('s', 'S')], (id) {
        final items = [
          for (final r in [('a1', 'A'), ('a2', 'A'), ('b1', 'B'), ('c1', 'C')])
            RadioItem(by(r.$1, r.$2), RadioKind.song),
        ];
        return RadioPage([
          RadioItem(song('s'), RadioKind.song, isSeed: true),
          ...items,
        ]);
      });
      expect(await ids(f, 4), ['a1', 'b1', 'c1', 'a2']);
    });

    test('a seed the resolver cannot find is skipped, now and later', () async {
      final f = fill(
        [RadioSeed(libTrack(1)), RadioSeed.online('s', 'S')],
        (id) => RadioPage([
          RadioItem(song('s'), RadioKind.song, isSeed: true),
          RadioItem(song('r${asked.length}'), RadioKind.song),
        ], continuation: 'next'),
      );
      expect(await ids(f, 2), ['r1', 'r2']);
      expect(asked, ['s', 's']); // never the dead seed's id
      expect(searches, 1); // not searched again
    });

    test(
      'an online seed whose radio has no seed row is not looked up',
      () async {
        final f = fill([
          RadioSeed.online('s', 'S'),
        ], (id) => RadioPage([RadioItem(song('r'), RadioKind.song)]));
        expect(await ids(f, 1), ['r']);
        expect(searches, 0);
        expect(asked, ['s']);
      },
    );

    test('the search counts in the request budget', () async {
      found = [
        YtResult(
          id: 'v1',
          title: 'Song 1',
          channel: 'Band 1',
          duration: const Duration(seconds: 200),
          artists: ['Band 1'],
          album: 'Album',
        ),
      ];
      final f = fill([
        RadioSeed(libTrack(1)),
      ], (id) => RadioPage([RadioItem(song('r'), RadioKind.song)]));
      // Search + radio = 2 requests: no second radio page for the clip.
      expect(await ids(f, 1, maxRequests: 2), ['r']);
      expect(searches, 1);
      expect(asked, ['v1']);
    });

    test('a row accept refuses does not count and costs no extra request', () async {
      final f = fill([RadioSeed.online('s', 'S')], (id) {
        return RadioPage([
          RadioItem(song('s'), RadioKind.song, isSeed: true),
          for (final r in [('a', 'A'), ('b', 'B'), ('c', 'C'), ('d', 'D')])
            RadioItem(by(r.$1, r.$2), RadioKind.song),
        ]);
      });
      final got = await f
          .take(2, inQueue: (_) => false, maxRequests: 1, accept: (c) => c.result.id != 'a' && c.result.id != 'b')
          .map((c) => c.result.id)
          .toList();
      expect(got, ['c', 'd']); // two refused rows burned no budget and no slot
      expect(asked, ['s']);
      // not marked used: another taker of the pool still gets 'a' when it comes back
      f.pool.addPage('s', 'S', RadioPage([RadioItem(by('a', 'A'), RadioKind.song)]));
      expect(await ids(f, 1), ['a']);
    });
  });
}
