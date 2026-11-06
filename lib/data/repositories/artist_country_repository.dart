import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// `artist_countries` (D-390): the country of an artist, by `matchKey` of the
/// main artist's name. A row with no country is "searched, not found".
class ArtistCountryRepository {
  ArtistCountryRepository(this._db);

  final AppDatabase _db;

  /// [country] is ISO 3166-1 alpha-2 (stored upper case), null when [source]
  /// found nothing; [checkedAtMs] is when the answer came.
  Future<void> upsert(String artistKey, {String? country, String? source, required int checkedAtMs}) =>
      _db.into(_db.artistCountries).insertOnConflictUpdate(
            ArtistCountriesCompanion.insert(
              artistKey: artistKey,
              country: Value(country?.toUpperCase()),
              source: Value(source),
              checkedAt: checkedAtMs,
            ),
          );

  Future<ArtistCountry?> of(String artistKey) =>
      (_db.select(_db.artistCountries)..where((c) => c.artistKey.equals(artistKey))).getSingleOrNull();

  /// The rows of [artistKeys] that exist, by key.
  Future<Map<String, ArtistCountry>> ofMany(Iterable<String> artistKeys) async {
    final keys = artistKeys.toSet().toList();
    final out = <String, ArtistCountry>{};
    // SQLite caps the variables of one statement.
    for (var i = 0; i < keys.length; i += 500) {
      final chunk = keys.skip(i).take(500).toList();
      final rows = await (_db.select(_db.artistCountries)..where((c) => c.artistKey.isIn(chunk))).get();
      for (final r in rows) {
        out[r.artistKey] = r;
      }
    }
    return out;
  }

  /// The artist field of every visible track, most songs first, one per spelling
  /// (the same filter as the Libreria's artists).
  Future<List<String>> libraryArtistNames() async {
    final rows = await _db
        .customSelect(
          "SELECT MIN(artist) AS a FROM tracks WHERE missing = 0 AND ignored = 0 AND kind = 0 "
          "AND trim(COALESCE(artist, '')) <> '' GROUP BY lower(trim(artist)) ORDER BY COUNT(*) DESC, 1",
          readsFrom: {_db.tracks},
        )
        .get();
    return [for (final r in rows) r.read<String>('a')];
  }
}
