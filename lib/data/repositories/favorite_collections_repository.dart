import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// Favourite albums and playlists (v23). Album key = `albumKey`, playlist key = `Playlists.uuid`.
class FavoriteCollectionsRepository {
  FavoriteCollectionsRepository(this._db);

  final AppDatabase _db;

  static const album = 'album', playlist = 'playlist';

  /// Idempotent: a second add keeps the first `addedAt`.
  Future<void> add(String kind, String key, {int? addedAt}) => _db.into(_db.favoriteCollections).insert(
        FavoriteCollectionsCompanion.insert(kind: kind, key: key, addedAt: addedAt == null ? const Value.absent() : Value(addedAt)),
        mode: InsertMode.insertOrIgnore,
      );

  Future<void> remove(String kind, String key) =>
      (_db.delete(_db.favoriteCollections)..where((r) => r.kind.equals(kind) & r.key.equals(key))).go();

  Future<void> toggle(String kind, String key) => _db.transaction(() async {
        if (await isFavoriteNow(kind, key)) {
          await remove(kind, key);
        } else {
          await add(kind, key);
        }
      });

  Future<bool> isFavoriteNow(String kind, String key) async =>
      await (_db.select(_db.favoriteCollections)..where((r) => r.kind.equals(kind) & r.key.equals(key))).getSingleOrNull() != null;

  /// Keys of [kind], most recently added first.
  Stream<List<String>> watch(String kind) => (_db.select(_db.favoriteCollections)
        ..where((r) => r.kind.equals(kind))
        ..orderBy([(r) => OrderingTerm.desc(r.addedAt), (r) => OrderingTerm.asc(r.key)]))
      .watch()
      .map((rows) => [for (final r in rows) r.key]);

  Stream<bool> isFavorite(String kind, String key) =>
      (_db.select(_db.favoriteCollections)..where((r) => r.kind.equals(kind) & r.key.equals(key))).watch().map((r) => r.isNotEmpty);
}
