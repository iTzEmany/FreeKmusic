import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_radio_parser.dart';
import 'package:codecore/services/shuffle_plus/genre_mix.dart';
import 'package:codecore/services/shuffle_plus/seed_index.dart';
import 'package:codecore/services/shuffle_plus/seed_resolver.dart';
import 'package:codecore/services/shuffle_plus/suggestion_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Track track(int id) => Track(
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

YtResult song(String id, String artist) => YtResult(
  id: id,
  title: 'Title $id',
  channel: artist,
  duration: const Duration(seconds: 200),
  artists: [artist],
  album: 'Album',
);

/// A radio page: the seed, then ten songs by ten different artists.
RadioPage page(String seed) => RadioPage([
  RadioItem(song(seed, 'Seed'), RadioKind.song, isSeed: true),
  for (var i = 0; i < 10; i++)
    RadioItem(song('$seed-r$i', 'Artist $seed $i'), RadioKind.song),
]);

void main() {
  late Directory dir;
  late SeedResolver resolver;
  late SuggestionLog log;
  late List<String> asked;
  late List<String?> continuations;
  var searches = 0;
  GenreMixOff? off;
  var radioFails = false;
  var rateLimited = false;
  var cancelled = false;
  var allInLibrary = false;
  RadioPage Function(String id, String? continuation)? pages;
  var inLibrary = <String>{};

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('genre_mix');
    addTearDown(() => dir.deleteSync(recursive: true));
    final downloads = DownloadIndex(File(p.join(dir.path, 'downloads.json')));
    for (var i = 1; i <= 40; i++) {
      await downloads.add('dl$i', '/m/$i.mp3');
    }
    searches = 0;
    resolver = SeedResolver(
      downloads: downloads,
      index: SeedIndex(file: () async => File(p.join(dir.path, 'seeds.json'))),
      searchSongs: (q) async {
        searches++;
        return const [];
      },
    );
    log = SuggestionLog(
      file: () async => File(p.join(dir.path, 'suggestions.json')),
      writeDelay: const Duration(days: 1),
    );
    asked = [];
    continuations = [];
    off = null;
    radioFails = false;
    rateLimited = false;
    cancelled = false;
    allInLibrary = false;
    pages = null;
    inLibrary = {};
  });

  Future<List<GenreMixState>> run(int tracks) => genreMix(
    tracks: [for (var i = 1; i <= tracks; i++) track(i)],
    offReason: () async => off,
    resolver: resolver,
    radioPage: (id, {continuation}) async {
      asked.add(id);
      continuations.add(continuation);
      if (rateLimited) throw const YtException(YtErrorKind.rateLimited);
      if (radioFails) throw const YtException(YtErrorKind.network);
      return pages?.call(id, continuation) ?? page(id);
    },
    log: log,
    loadInLibrary: () async =>
        (r) => allInLibrary || inLibrary.contains(r.id),
    cancelled: () => cancelled,
  ).toList();

  test('one slot for every 2 library songs: 3 incoming first, then each one as it is found', () async {
    final states = await run(6);
    expect(states.first.incoming, 3);
    expect(states.first.suggested, isEmpty);
    expect([for (final s in states) s.suggested.length], [0, 1, 2, 3, 3]);
    expect([for (final s in states) s.incoming], [3, 2, 1, 0, 0]);
    expect(states.last.suggested.map((r) => r.id).toSet(), hasLength(3));
  });

  test('seeds are songs of the genre, found without a search', () async {
    await run(6);
    expect(asked, isNotEmpty);
    expect(asked.every((id) => RegExp(r'^dl[1-6]$').hasMatch(id)), isTrue);
    expect(searches, 0);
  });

  test('at most genreMixMax suggestions however long the genre', () async {
    final states = await run(40);
    expect(states.first.incoming, 9);
    expect(states.last.suggested, hasLength(9));
  });

  test('songs already in the library are not suggested', () async {
    inLibrary = {
      for (final id in ['dl1', 'dl2', 'dl3', 'dl4', 'dl5', 'dl6'])
        for (var i = 0; i < 10; i++) '$id-r$i',
    };
    final states = await run(6);
    expect(
      states.last.suggested.where((r) => inLibrary.contains(r.id)),
      isEmpty,
    );
  });

  test(
    'a metered network, a Jam or no tool: the reason and no request',
    () async {
      for (final reason in GenreMixOff.values) {
        off = reason;
        final states = await run(6);
        expect(states, hasLength(1));
        expect(states.single.off, reason);
        expect(states.single.suggested, isEmpty);
        expect(states.single.incoming, 0);
      }
      expect(asked, isEmpty);
    },
  );

  test('a radio that fails ends with nothing incoming and no error', () async {
    radioFails = true;
    final states = await run(6);
    expect(states.last.incoming, 0);
    expect(states.last.suggested, isEmpty);
    expect(states.last.off, isNull);
  });

  test('fewer than 2 library songs: no slot at all', () async {
    expect(await run(1), isEmpty);
  });

  test('a rate limit keeps what was found and says why', () async {
    rateLimited = true;
    final states = await run(6);
    expect(states.last.off, GenreMixOff.rateLimited);
    expect(states.last.incoming, 0);
    expect(asked, hasLength(1), reason: 'no request after the 429');
  });

  test('cancelled (page left): no request at all', () async {
    cancelled = true;
    final states = await run(6);
    expect(asked, isEmpty);
    expect(states.last.incoming, 0);
  });

  test('a radio of songs already in the library or repeated: stops at the request budget', () async {
    allInLibrary = true;
    pages = (id, c) => RadioPage([
      RadioItem(song(id, 'Seed'), RadioKind.song, isSeed: true),
      RadioItem(song('$id-${c ?? 'first'}', 'Artist'), RadioKind.song),
    ], continuation: 'next');
    final states = await run(40);
    // The budget counts a seed's id lookup too (4 units): 3 pages here, ids known.
    expect(asked.length + searches, 3);
    expect(states.last.suggested, isEmpty);
    expect(states.last.incoming, 0);
  });

  test('a radio page of 2 songs with a continuation: the second page is followed', () async {
    pages = (id, c) => RadioPage([
      RadioItem(song(id, 'Seed'), RadioKind.song, isSeed: true),
      for (var i = 0; i < 2; i++) RadioItem(song('$id-${c ?? 'p1'}-$i', 'Artist $id ${c ?? 'p1'} $i'), RadioKind.song),
    ], continuation: c == null ? 'next' : null);
    final states = await run(6);
    expect(continuations, contains('next'));
    expect(asked.first, asked[1], reason: 'the same radio, next page');
    expect(states.last.suggested, hasLength(3));
    expect(states.last.suggested.any((r) => r.id.contains('-next-')), isTrue);
  });
}
