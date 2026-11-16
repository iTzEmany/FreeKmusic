import 'dart:io';
import 'dart:math';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/shuffle_plus/seed_index.dart';
import 'package:codecore/services/shuffle_plus/seed_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Track track(int id, String title,
        {String artist = 'Pink Floyd', String? genre, int ms = 335000, bool missing = false}) =>
    Track(saved: false, coverSource: 0, 
      id: id,
      path: '/m/$id.mp3',
      title: title,
      artist: artist,
      genre: genre,
      albumKey: 'k',
      durationMs: ms,
      format: 'mp3',
      sizeBytes: 1,
      mtimeMs: 1,
      hasCover: false,
      isFavorite: false,
      enrichStatus: 0,
      userEdited: false,
      missing: missing,
      ignored: false,
      kind: 0,
      addedAt: 1,
      playCount: 0,
    );

YtResult song(String id, String title, String artist, int seconds) => YtResult(
      id: id,
      title: title,
      channel: artist,
      duration: Duration(seconds: seconds),
      artists: [artist],
      album: 'Album',
    );

void main() {
  late Directory dir;
  late DownloadIndex downloads;
  late DateTime now;
  late SeedIndex index;
  late List<String> queries;
  late List<YtResult> answer;

  SeedResolver make() => SeedResolver(
        downloads: downloads,
        index: index,
        searchSongs: (q) async {
          queries.add(q);
          return answer;
        },
      );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('seed_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    downloads = DownloadIndex(File(p.join(dir.path, 'downloads.json')));
    now = DateTime.utc(2026, 1, 1);
    index = SeedIndex(
      file: () async => File(p.join(dir.path, 'seed_ids.json')),
      now: () => now,
      writeDelay: Duration.zero,
    );
    addTearDown(() => index.dispose());
    queries = [];
    answer = [song('o7MlC_Qrmmc', 'Mother', 'Pink Floyd', 335)];
  });

  test('a downloaded song gives its id with no search', () async {
    await downloads.add('dlId', '/m/1.mp3');
    expect(await make().resolve(track(1, 'Mother')), 'dlId');
    expect(queries, isEmpty);
  });

  test('a searched song is asked once: the second time comes from the index', () async {
    final r = make();
    expect(await r.resolve(track(1, 'Mother')), 'o7MlC_Qrmmc');
    expect(await r.resolve(track(2, 'Mother (2011 Remaster)')), 'o7MlC_Qrmmc');
    expect(queries, ['Pink Floyd Mother']);
    await index.flush();
    final reread = SeedIndex(file: () async => File(p.join(dir.path, 'seed_ids.json')));
    expect((await reread.get(SeedIndex.keyOf('Mother', 'Pink Floyd')))?.id, 'o7MlC_Qrmmc');
  });

  test('clearing the index forgets every id, in memory and on disk', () async {
    await index.put('k', 'abc');
    await index.clear();
    expect(await index.get('k'), isNull);
    final reread = SeedIndex(file: () async => File(p.join(dir.path, 'seed_ids.json')));
    expect(await reread.get('k'), isNull);
  });

  test('«not found» is remembered and tried again after 30 days', () async {
    answer = const [];
    final r = make();
    expect(await r.resolve(track(1, 'Mother')), isNull);
    expect(await r.resolve(track(1, 'Mother')), isNull);
    expect(queries, hasLength(1));
    now = now.add(const Duration(days: 29));
    await r.resolve(track(1, 'Mother'));
    expect(queries, hasLength(1));
    now = now.add(const Duration(days: 2));
    answer = [song('x1', 'Mother', 'Pink Floyd', 335)];
    expect(await r.resolve(track(1, 'Mother')), 'x1');
    expect(queries, hasLength(2));
  });

  test('a candidate that needs review is not used', () async {
    // Right title and artist, but 20 s off: a score between review and sure.
    answer = [song('maybe', 'Mother', 'Pink Floyd', 355)];
    expect(await make().resolve(track(1, 'Mother')), isNull);
  });

  test('searchOnly skips the download id', () async {
    await downloads.add('clipId', '/m/1.mp3');
    expect(await make().resolve(track(1, 'Mother'), searchOnly: true), 'o7MlC_Qrmmc');
  });

  group('chooseSeeds', () {
    test('a prevailing genre (40 % or more) restricts the seeds to it', () {
      final source = [
        for (var i = 1; i <= 5; i++) track(i, 'Rock $i', genre: 'Rock'),
        for (var i = 6; i <= 10; i++) track(i, 'Other $i', genre: 'Jazz $i'),
      ];
      for (var seed = 0; seed < 10; seed++) {
        final seeds = chooseSeeds(source, random: Random(seed));
        expect(seeds, hasLength(3));
        expect(seeds.every((t) => t.genre == 'Rock'), isTrue);
      }
    });

    test('mixed genres use every song; missing files never serve', () {
      final source = [
        for (var i = 1; i <= 8; i++) track(i, 'T$i', genre: 'G$i'),
        track(9, 'Gone', missing: true),
      ];
      final seen = <int>{};
      for (var seed = 0; seed < 40; seed++) {
        seen.addAll(chooseSeeds(source, random: Random(seed)).map((t) => t.id));
      }
      expect(seen, containsAll([1, 2, 3, 4, 5, 6, 7, 8]));
      expect(seen, isNot(contains(9)));
    });

    test('fewer songs than the count: all of them; none: nothing', () {
      expect(chooseSeeds([track(1, 'A'), track(2, 'B')]), hasLength(2));
      expect(chooseSeeds(const []), isEmpty);
    });
  });
}
