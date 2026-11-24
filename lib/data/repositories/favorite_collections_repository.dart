import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../db/tables.dart' show TombstoneKind;
import 'sync_tombstone_repository.dart';
import 'track_kinds.dart' show libraryRowSql;

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
  Future<void> add(String kind, String key, {int? addedAt}) async {
    final k = _canon(kind, key);
    if (k.isEmpty) return; // e.g. a bare 'stream|': no album to favourite
    await _db.transaction(() async {
      await _db.into(_db.favoriteCollections).insert(
            FavoriteCollectionsCompanion.insert(kind: kind, key: k, addedAt: addedAt == null ? const Value.absent() : Value(addedAt)),
            mode: InsertMode.insertOrIgnore,
          );
      final t = _tombstoneKind(kind, k);
      if (t != null) await SyncTombstoneRepository(_db).clear(t, k);
    });
  }

  /// The tombstone kind of a favourite, or null when it never travels: an `unknown|` album key
  /// holds a local folder path (D-668).
  static String? _tombstoneKind(String kind, String key) {
    if (kind == playlist) return TombstoneKind.favoritePlaylist;
    return key.startsWith('unknown|') ? null : TombstoneKind.favoriteAlbum;
  }

  /// The album [oldKey] became [newKey] (tags edited, row demoted): its favourite follows, unless a track
  /// still has the old key. Call it after the rows are written, in their transaction.
  Future<void> followAlbumKey(String oldKey, String newKey) async {
    final o = favoriteAlbumKey(oldKey), n = favoriteAlbumKey(newKey);
    if (o == n || n.isEmpty) return;
    await _db.customUpdate(
      'UPDATE OR IGNORE favorite_collections SET key = ? WHERE kind = ? AND key = ? '
      'AND NOT EXISTS (SELECT 1 FROM tracks WHERE album_key IN (?, ?) AND missing = 0 AND ignored = 0 AND ${libraryRowSql()})',
      variables: [Variable(n), const Variable(album), Variable(o), Variable(o), Variable('$_streamPrefix$o')],
      updates: {_db.favoriteCollections},
    );
    // Both albums were favourites: the ignored update left the old key behind. No tombstone, the album lives on.
    await _db.customUpdate(
      'DELETE FROM favorite_collections WHERE kind = ? AND key = ? '
      'AND NOT EXISTS (SELECT 1 FROM tracks WHERE album_key IN (?, ?) AND missing = 0 AND ignored = 0 AND ${libraryRowSql()})',
      variables: [const Variable(album), Variable(o), Variable(o), Variable('$_streamPrefix$o')],
      updates: {_db.favoriteCollections},
    );
  }

  /// Removing a favourite leaves a tombstone in the same transaction (not for `unknown|` album keys).
  Future<void> remove(String kind, String key) => _db.transaction(() async {
        final k = _canon(kind, key);
        final n = await (_db.delete(_db.favoriteCollections)..where((r) => r.kind.equals(kind) & r.key.equals(k))).go();
        final t = _tombstoneKind(kind, k);
        if (n > 0 && t != null) await SyncTombstoneRepository(_db).record(t, k);
      });

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
