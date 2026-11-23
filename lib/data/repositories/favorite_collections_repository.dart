import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// The canonical key of a favourite album: its `albumKey` without the `stream|` prefix, so the
/// favourite survives promote/demote (which rewrite the key between the two forms).
String favoriteAlbumKey(String key) => key.startsWith(_streamPrefix) ? key.substring(_streamPrefix.length) : key;

const _streamPrefix = 'stream|';

/// Favourite albums and playlists (v23). Album key = [favoriteAlbumKey], playlist key = `Playlists.uuid`.
class FavoriteCollectionsRepository {
  FavoriteCollectionsRepository(this._db);

  final AppDatabase _db;

  static const album = 'album', playlist = 'playlist';

  static String _canon(String kind, String key) => kind == album ? favoriteAlbumKey(key) : key;

  /// Idempotent: a second add keeps the first `addedAt`.
  Future<void> add(String kind, String key, {int? addedAt}) => _db.into(_db.favoriteCollections).insert(
        FavoriteCollectionsCompanion.insert(kind: kind, key: _canon(kind, key), addedAt: addedAt == null ? const Value.absent() : Value(addedAt)),
        mode: InsertMode.insertOrIgnore,
      );

  Future<void> remove(String kind, String key) =>
      (_db.delete(_db.favoriteCollections)..where((r) => r.kind.equals(kind) & r.key.equals(_canon(kind, key)))).go();

  Future<void> toggle(String kind, String key) => _db.transaction(() async {
        if (await isFavoriteNow(kind, key)) {
          await remove(kind, key);
        } else {
          await add(kind, key);
        }
      });

  Future<bool> isFavoriteNow(String kind, String key) async =>
      await (_db.select(_db.favoriteCollections)..where((r) => r.kind.equals(kind) & r.key.equals(_canon(kind, key)))).getSingleOrNull() != null;

  /// Keys of [kind], most recently added first.
  Stream<List<String>> watch(String kind) => (_db.select(_db.favoriteCollections)
        ..where((r) => r.kind.equals(kind))
        ..orderBy([(r) => OrderingTerm.desc(r.addedAt), (r) => OrderingTerm.asc(r.key)]))
      .watch()
      .map((rows) => [for (final r in rows) r.key]);

  Stream<bool> isFavorite(String kind, String key) =>
      (_db.select(_db.favoriteCollections)..where((r) => r.kind.equals(kind) & r.key.equals(_canon(kind, key)))).watch().map((r) => r.isNotEmpty);
}
