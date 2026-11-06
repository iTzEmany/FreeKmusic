import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/filter_counts_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/library/rules/rule_parser.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/filter_counts_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FilterCountsRepository repo;

  Future<void> add(int id, String artist, {List<String> genres = const [], String? details, bool ignored = false, bool missing = false}) async {
    await db.into(db.tracks).insert(TracksCompanion.insert(
        id: Value(id), path: '/$id.mp3', title: 't$id', albumKey: 'k', format: 'mp3', sizeBytes: 1,
        mtimeMs: 1, addedAt: 1, artist: Value(artist), ignored: Value(ignored), missing: Value(missing)));
    for (var i = 0; i < genres.length; i++) {
      await db.into(db.trackGenres).insert(TrackGenresCompanion.insert(trackId: id, genre: genres[i], position: i));
    }
    if (details != null) {
      await db.into(db.trackEnrich).insert(TrackEnrichCompanion.insert(trackId: Value(id), details: Value(details)));
    }
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = FilterCountsRepository(db);
    await add(1, 'Queen', genres: ['Rock', 'Pop'], details: '{"label":"EMI"}');
    await add(2, 'queen feat. Bowie', genres: ['rock'], details: '{"label":"emi"}');
    await add(3, 'Édith', genres: ['Pop'], details: '{"label":"Other"}');
    await add(4, 'Hidden', genres: ['Rock'], ignored: true, details: '{"label":"EMI"}');
    await add(5, 'Gone', genres: ['Rock'], missing: true);
    await db.into(db.artistCountries).insert(ArtistCountriesCompanion.insert(artistKey: 'queen', country: const Value('GB'), checkedAt: 1));
    await db.into(db.artistCountries).insert(ArtistCountriesCompanion.insert(artistKey: 'hidden', country: const Value('US'), checkedAt: 1));
    await db.into(db.artistCountries).insert(ArtistCountriesCompanion.insert(artistKey: 'edith', checkedAt: 1)); // not found
  });
  tearDown(() => db.close());

  test('artists: exact spelling (case folded), hidden out; every count is what the rule selects', () async {
    final artists = await repo.counts(FilterList.artists);
    expect(artists, [const ValueCount('Édith', 1), const ValueCount('Queen', 1), const ValueCount('queen feat. Bowie', 1)]);
    final tracks = TrackRepository(db);
    for (final v in artists) {
      final n = await tracks.countByRules(parseRules('artista:"${v.value}",').expr);
      expect(n, v.count, reason: v.value);
    }
  });

  test('genres: all genres, case folded, old column as fallback, no double count', () async {
    await add(6, 'Old'); // no track_genres row, only the column
    await db.customStatement("UPDATE tracks SET genre = 'Rock' WHERE id IN (1, 6)");
    final g = await repo.counts(FilterList.genres);
    expect(g, [const ValueCount('Rock', 3), const ValueCount('Pop', 2)]);
    final tracks = TrackRepository(db);
    for (final v in g) {
      expect(await tracks.countByRules(parseRules('genere:"${v.value}",').expr), v.count, reason: v.value);
    }
  });

  test('labels and genres fold like the rule: ASCII case only, accents stay apart', () async {
    await add(7, 'X', genres: ['Électro'], details: '{"label":"Éditions"}');
    await add(8, 'Y', genres: ['électro'], details: '{"label":"éditions"}');
    final g = await repo.counts(FilterList.genres, query: 'electro');
    expect(g.map((v) => v.count), [1, 1]);
    final l = await repo.counts(FilterList.labels, query: 'edit');
    expect(l.map((v) => v.count), [1, 1]);
    final tracks = TrackRepository(db);
    for (final v in [...g, ...l]) {
      final f = g.contains(v) ? 'genere' : 'etichetta';
      expect(await tracks.countByRules(parseRules('$f:"${v.value}",').expr), 1);
    }
  });

  test('the list providers load once and the query filters in memory', () async {
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    const p0 = (list: FilterList.genres, query: '');
    const p1 = (list: FilterList.genres, query: 'ro');
    c.listen(filterValueCountsProvider(p0), (_, _) {});
    c.listen(filterValueCountsProvider(p1), (_, _) {});
    const live = (rules: 'artista:queen', limit: 1);
    c.listen(liveRuleCountProvider(live), (_, _) {});
    final all = await c.read(filterValueCountsProvider(p0).future);
    final some = await c.read(filterValueCountsProvider(p1).future);
    expect(some, all.where((v) => v.value.toLowerCase().contains('ro')).toList());
    expect(await c.read(liveRuleCountProvider(live).future), 1);
  });

  test('countries: only found ones, from visible tracks', () async {
    expect(await repo.counts(FilterList.countries), [const ValueCount('GB', 2)]);
    expect(await TrackRepository(db).countByRules(parseRules('nazionalita:GB').expr), 2);
  });

  test('labels: folded, hidden out', () async {
    expect((await repo.counts(FilterList.labels)).map((v) => v.count), [2, 1]);
  });

  test('text search ignores case and accents', () async {
    expect(await repo.counts(FilterList.artists, query: 'EDI'), [const ValueCount('Édith', 1)]);
    expect(await repo.counts(FilterList.genres, query: 'zzz'), isEmpty);
  });
}
