import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../db/app_database.dart';

/// What the user deleted (D-668, schema v24). Writes join the caller's transaction (drift keeps it in the zone).
/// Only user metadata and saved streamed rows get one: never a file on disk, never a local row (kind 0).
class SyncTombstoneRepository {
  SyncTombstoneRepository(this._db);

  final AppDatabase _db;

  /// Upsert that keeps the highest `deletedAt`.
  Future<void> record(String kind, String key, {int? at}) => _db.customInsert(
        'INSERT INTO sync_tombstones (kind, key, deleted_at) VALUES (?, ?, ?) '
        'ON CONFLICT(kind, key) DO UPDATE SET deleted_at = MAX(deleted_at, excluded.deleted_at)',
        variables: [Variable.withString(kind), Variable.withString(key), Variable.withInt(at ?? nowMs())],
        updates: {_db.syncTombstones},
      );

  /// The item is back (added again here): its tombstone goes.
  Future<void> clear(String kind, String key) =>
      (_db.delete(_db.syncTombstones)..where((t) => t.kind.equals(kind) & t.key.equals(key))).go();

  /// Tombstones deleted after [since] (all of them when null).
  Future<List<SyncTombstone>> all({int? since}) => (_db.select(_db.syncTombstones)
        ..where((t) => since == null ? const Constant(true) : t.deletedAt.isBiggerThanValue(since)))
      .get();
}
