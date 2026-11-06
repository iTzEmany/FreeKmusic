import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/artist_country_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ArtistCountryRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ArtistCountryRepository(db);
  });
  tearDown(() => db.close());

  test('upsert stores the country upper case with its source, and a second upsert replaces it', () async {
    await repo.upsert('radiohead', country: 'gb', source: 'musicbrainz', checkedAtMs: 10);
    final row = (await repo.of('radiohead'))!;
    expect((row.country, row.source, row.checkedAt), ('GB', 'musicbrainz', 10));

    await repo.upsert('radiohead', country: 'US', source: 'wikidata', checkedAtMs: 20);
    expect((await repo.of('radiohead'))!.country, 'US');
    expect(await db.select(db.artistCountries).get(), hasLength(1));
  });

  test('a not-found artist keeps a row with no country but a date; unknown keys are absent', () async {
    await repo.upsert('nobody', checkedAtMs: 5);
    final many = await repo.ofMany(['nobody', 'other']);
    expect(many.keys, ['nobody']);
    expect((many['nobody']!.country, many['nobody']!.checkedAt), (null, 5));
    expect(await repo.of('other'), isNull);
  });

  test('libraryArtistNames leaves out the artists of ignored and missing tracks', () async {
    Future<void> add(String path, String artist, {bool ignored = false, bool missing = false}) =>
        db.into(db.tracks).insert(TracksCompanion.insert(
            path: path, title: 't', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1,
            artist: Value(artist), ignored: Value(ignored), missing: Value(missing)));
    await add('/a', 'Shown');
    await add('/b', 'Ignored', ignored: true);
    await add('/c', 'Gone', missing: true);
    expect(await repo.libraryArtistNames(), ['Shown']);
  });
}
