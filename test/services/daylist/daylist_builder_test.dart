import 'dart:math';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/daylist/daylist_builder.dart';
import 'package:codecore/services/daylist/daylist_slots.dart';
import 'package:codecore/services/daylist/mood_table.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_radio_parser.dart';
import 'package:codecore/services/shuffle_plus/suggestion_pool.dart';
import 'package:flutter_test/flutter_test.dart';

Track track(int id, String genre, {String? artist, int plays = 0}) => Track(
  coverSource: 0,
  id: id,
  path: '/m/$id.mp3',
  title: 'Song $id',
  artist: artist ?? 'Band $id',
  genre: genre,
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
  playCount: plays,
);

SuggestionCandidate cand(String id, String seedTitle) => SuggestionCandidate(
  YtResult(id: id, title: 'T$id', channel: 'C$id', duration: const Duration(seconds: 200)),
  seedTitle,
  RadioKind.song,
);

// Tarda sera (22-24): prefers lo-fi, jazz, soul; avoids metal, punk; 30%.
final night = DateTime(2026, 11, 9, 22, 30);
const slot = 5;

DaylistInputs inputs(
  List<Track> lib, {
  List<DaylistPlay> plays = const [],
  DaylistSuggest? suggest,
  DaylistConfig? config,
  Iterable<String> Function(SuggestionCandidate)? genresOfSuggestion,
}) => DaylistInputs(
  config: config ?? DaylistConfig.defaults(),
  moods: MoodTable.defaults(),
  now: () => night,
  random: Random(1),
  library: lib,
  plays: plays,
  suggest: suggest,
  genresOfSuggestion: genresOfSuggestion,
);

List<DaylistPlay> playsOf(Iterable<int> ids, {int hour = 23}) => [
  for (final i in ids) (trackId: i, playedAt: DateTime(2026, 11, 1, hour)),
];

void main() {
  final builder = DaylistBuilder();
  const genres = ['lo-fi', 'jazz', 'soul', 'ambient'];
  final lib = [for (var i = 1; i <= 120; i++) track(i, genres[i % 4])];

  // A suggest closure that makes ids s1.. and records what it was given.
  List<List<Track>> seedsSeen = [];
  DaylistSuggest fake({int available = 100}) => (seeds, want, accept, inQueue) async* {
    seedsSeen.add(seeds);
    var n = 0;
    for (var i = 0; i < available && n < want; i++) {
      final c = cand('s$i', seeds[i % seeds.length].title);
      if (inQueue(c.result.id) || !accept(c)) continue;
      n++;
      yield c;
    }
  };
  setUp(() => seedsSeen = []);

  test('50 songs, the slot quota of suggestions, no repeats, name with up to 3 genres', () async {
    final r = await builder.build(inputs(lib, plays: playsOf(List.generate(60, (i) => i + 1)), suggest: fake()));
    expect(r.slotIndex, slot);
    expect(r.items.length, 50);
    expect(r.items.where((i) => i.suggestion != null).length, 15);
    final ids = [for (final i in r.items) i.track?.id.toString() ?? i.suggestion!.result.id];
    expect(ids.toSet().length, 50);
    expect(r.genres.length, inInclusiveRange(1, 3));
    expect(r.tooFew, isFalse);
    expect(r.isShort, isFalse);
  });

  test('seeds are the songs most played in the slot hours, not those of other hours', () async {
    final plays = [
      ...playsOf([7, 7, 7, 3, 3], hour: 23),
      ...playsOf([11, 11, 11, 11, 11, 11], hour: 10), // another slot
    ];
    await builder.build(inputs(lib, plays: plays, suggest: fake()));
    final seeds = [for (final s in seedsSeen.first) s.id];
    expect(seeds.take(2), [7, 3]);
    expect(seeds, isNot(contains(11)));
  });

  test('avoided genres and genres without taste match are out, also from suggestions', () async {
    final mixed = [...lib, for (var i = 200; i < 230; i++) track(i, 'metal'), for (var i = 300; i < 310; i++) track(i, 'zouk')];
    final plays = playsOf([...List.generate(60, (i) => i + 1), 200, 201, 300]);
    final r = await builder.build(
      inputs(
        mixed,
        plays: plays,
        suggest: fake(),
        // the radio says every second suggestion is metal
        genresOfSuggestion: (c) => c.result.id.hashCode.isEven ? ['Metal'] : ['jazz'],
      ),
    );
    for (final i in r.items) {
      if (i.track != null) expect(['metal', 'zouk'], isNot(contains(i.track!.genre)));
      if (i.suggestion != null) expect(i.suggestion!.result.id.hashCode.isEven, isFalse);
    }
    expect(r.items.length, 50);
  });

  test('at least 3 different genres among the own songs when the library has them', () async {
    final skew = [for (var i = 1; i <= 60; i++) track(i, 'jazz'), track(100, 'lo-fi'), track(101, 'soul')];
    final r = await builder.build(inputs(skew, plays: playsOf([...List.generate(60, (i) => i + 1), 100, 101])));
    final g = {for (final i in r.items) i.track!.genre};
    expect(g, containsAll(['jazz', 'lo-fi', 'soul']));
  });

  test('a slot without history uses its taste and the most played songs overall as seeds', () async {
    final l = [for (var i = 1; i <= 40; i++) track(i, genres[i % 3], plays: i), track(99, 'metal', plays: 9999)];
    final r = await builder.build(inputs(l, suggest: fake()));
    expect(r.items.length, 50); // 35 own + 15 suggested
    expect(seedsSeen.first.first.id, 40);
    expect([for (final i in r.items) i.track?.id], isNot(contains(99)));
  });

  test('suggestions that fail leave the daylist with own songs only', () async {
    final r = await builder.build(inputs(lib, plays: playsOf([1, 2, 3]), suggest: (a, b, c, d) => Stream.error(Exception('offline'))));
    expect(r.items.length, 50);
    expect(r.items.every((i) => i.track != null), isTrue);
  });

  test('fewer than 50 shortens the list, fewer than 15 creates none', () async {
    final few = [for (var i = 1; i <= 20; i++) track(i, 'jazz')];
    var r = await builder.build(inputs(few, plays: playsOf([1, 2])));
    expect(r.items.length, 20);
    expect(r.isShort, isTrue);
    expect(r.tooFew, isFalse);
    r = await builder.build(inputs(few.take(14).toList(), plays: playsOf([1, 2])));
    expect(r.tooFew, isTrue);
    expect(r.items, isEmpty);
  });
}
