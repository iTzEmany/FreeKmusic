import '../../core/clock.dart';
import '../db/app_database.dart';
import '../../core/artist_key.dart';

/// What Wikipedia says about an artist, one row per artist.
class ArtistInfoRepository {
  ArtistInfoRepository(this._db);

  final AppDatabase _db;

  /// The key of an artist as the library names them («Queen feat. X» → «queen»).
  static String keyOf(String artist) => artistKey(artist);

  Stream<ArtistInfo?> watch(String artist) {
    final key = keyOf(artist);
    if (key.isEmpty) return Stream.value(null);
    return (_db.select(
      _db.artistInfos,
    )..where((r) => r.artistKey.equals(key))).watchSingleOrNull();
  }

  Future<void> save(
    String artist, {
    required String body,
    required Uri source,
    required String lang,
  }) async {
    final key = keyOf(artist);
    if (key.isEmpty) return;
    await _db
        .into(_db.artistInfos)
        .insertOnConflictUpdate(
          ArtistInfosCompanion.insert(
            artistKey: key,
            body: body,
            sourceUrl: source.toString(),
            lang: lang,
            fetchedAt: nowMs(),
          ),
        );
  }
}
