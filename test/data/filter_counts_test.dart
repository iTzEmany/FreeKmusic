import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/filter_counts_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
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
    repo = FilterCountsRepository(db, TrackRepository(db));
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

  test('artists: main artist folded, hidden tracks out, count then name', () async {
    expect(await repo.counts(FilterList.artists), [const ValueCount('Queen', 2), const ValueCount('Édith', 1)]);
  });

  test('genres: all genres of a track, case folded, hidden out', () async {
    expect(await repo.counts(FilterList.genres), [const ValueCount('Pop', 2), const ValueCount('Rock', 2)]);
  });

  test('countries: only found ones, from visible tracks', () async {
    expect(await repo.counts(FilterList.countries), [const ValueCount('GB', 2)]);
  });

  test('labels: folded, hidden out', () async {
    expect(await repo.counts(FilterList.labels), [const ValueCount('EMI', 2), const ValueCount('Other', 1)]);
  });

  test('text search ignores case and accents', () async {
    expect(await repo.counts(FilterList.artists, query: 'EDI'), [const ValueCount('Édith', 1)]);
    expect(await repo.counts(FilterList.genres, query: 'zzz'), isEmpty);
  });

  test('live count: a newer request makes the older one answer null; limit caps', () async {
    const d = Duration(milliseconds: 20);
    final old = repo.liveCount('artista:queen', debounce: d);
    final fresh = repo.liveCount('artista:queen', debounce: d);
    expect(await old, isNull);
    expect(await fresh, 2);
    expect(await repo.liveCount('artista:queen', limit: 1, debounce: d), 1);
  });
}
