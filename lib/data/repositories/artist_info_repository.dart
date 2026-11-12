import 'package:drift/drift.dart';
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

  // Hand-set artist images (D-566) live in this table as `image:<library artist key>` rows
  // whose [body] is the cover key: no schema change, and no clash with the bios (an
  // `artistKey` never contains the prefix of a library key).
  static const _imagePrefix = 'image:';

  /// Library artist key -> cover key of the image the user picked.
  Stream<Map<String, String>> watchImages() => _imageRows().watch().map(_images);

  Future<Map<String, String>> images() async => _images(await _imageRows().get());

  SimpleSelectStatement<$ArtistInfosTable, ArtistInfo> _imageRows() =>
      _db.select(_db.artistInfos)..where((r) => r.artistKey.like('$_imagePrefix%'));

  static Map<String, String> _images(List<ArtistInfo> rows) => {
    for (final r in rows)
      if (r.artistKey.startsWith(_imagePrefix)) r.artistKey.substring(_imagePrefix.length): r.body,
  };

  Future<void> setImage(String libraryKey, String coverKey) => _db
      .into(_db.artistInfos)
      .insertOnConflictUpdate(
        ArtistInfosCompanion.insert(
          artistKey: '$_imagePrefix$libraryKey',
          body: coverKey,
          sourceUrl: '',
          lang: '',
          fetchedAt: nowMs(),
        ),
      );

  Future<void> clearImage(String libraryKey) =>
      (_db.delete(_db.artistInfos)..where((r) => r.artistKey.equals('$_imagePrefix$libraryKey'))).go();
}
