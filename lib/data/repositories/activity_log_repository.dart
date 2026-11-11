import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// The Registro on disk: one row per thing that ended, kept for [keep].
class ActivityLogRepository {
  ActivityLogRepository(this._db);

  static const keep = Duration(days: 30);

  final AppDatabase _db;

  Future<int> add({
    required int at,
    required String kind,
    required String name,
    int done = 0,
    int total = 0,
    bool failed = false,
    String? detail,
  }) => _db
      .into(_db.activityLogRows)
      .insert(
        ActivityLogRowsCompanion.insert(
          at: at,
          kind: kind,
          name: name,
          done: Value(done),
          total: Value(total),
          failed: Value(failed ? 1 : 0),
          detail: Value(detail),
        ),
      );

  /// Rewrites the row [id] (an import line that goes on until its end).
  Future<void> update(int id, {required int at, required int done, required int total, required bool failed, String? detail}) =>
      (_db.update(_db.activityLogRows)..where((r) => r.id.equals(id))).write(ActivityLogRowsCompanion(
        at: Value(at),
        done: Value(done),
        total: Value(total),
        failed: Value(failed ? 1 : 0),
        detail: Value(detail),
      ));

  /// The import line whose detail carries [key] (null = none yet).
  Future<int?> idOfImport(String key) async {
    final r = await (_db.select(_db.activityLogRows)
          ..where((r) => r.kind.equals('import') & r.detail.like('%"key":"$key"%'))
          ..limit(1))
        .getSingleOrNull();
    return r?.id;
  }

  /// Newest first. With [before] (the last row seen) only the older ones come,
  /// so rows added meanwhile do not shift the page.
  Future<List<ActivityLogRow>> page({required int limit, ({int at, int id})? before}) =>
      (_db.select(_db.activityLogRows)
            ..where((r) => before == null
                ? const Constant(true)
                : r.at.isSmallerThanValue(before.at) | (r.at.equals(before.at) & r.id.isSmallerThanValue(before.id)))
            ..orderBy([
              (r) => OrderingTerm.desc(r.at),
              (r) => OrderingTerm.desc(r.id),
            ])
            ..limit(limit))
          .get();

  /// The rows added after row [id] (a bigger id), newest first.
  Future<List<ActivityLogRow>> newerThan(int id) =>
      (_db.select(_db.activityLogRows)
            ..where((r) => r.id.isBiggerThanValue(id))
            ..orderBy([(r) => OrderingTerm.desc(r.at), (r) => OrderingTerm.desc(r.id)]))
          .get();

  /// The rows with these [ids], [chunk] at a time (SQLite caps the variables of a query).
  Future<List<ActivityLogRow>> byIds(List<int> ids, {int chunk = 500}) async {
    final rows = <ActivityLogRow>[];
    for (var i = 0; i < ids.length; i += chunk) {
      final part = ids.sublist(i, i + chunk > ids.length ? ids.length : i + chunk);
      rows.addAll(await (_db.select(_db.activityLogRows)..where((r) => r.id.isIn(part))).get());
    }
    return rows;
  }

  /// Fires when the table changes (a row added, dropped or cleared).
  Stream<void> changes() => _db.tableUpdates(TableUpdateQuery.onTable(_db.activityLogRows));

  Future<int> count() async {
    final n = _db.activityLogRows.id.count();
    final q = _db.selectOnly(_db.activityLogRows)..addColumns([n]);
    return (await q.getSingle()).read(n) ?? 0;
  }

  /// How many rows there are per kind, outcome and «nobody answered» (the
  /// detail of a stopped completion), for the counts of the Registro filters.
  Future<List<({String kind, bool failed, bool noAnswer, int n})>> countsByKind() async {
    final rows = await _db.customSelect(
      'SELECT kind, failed, COALESCE(CASE WHEN json_valid(detail) THEN json_extract(detail, \'\$.noAnswer\') END = 1, 0) AS na, COUNT(*) AS n '
      'FROM ${_db.activityLogRows.actualTableName} GROUP BY kind, failed, na',
      readsFrom: {_db.activityLogRows},
    ).get();
    return [
      for (final r in rows)
        (
          kind: r.read<String>('kind'),
          failed: r.read<int>('failed') != 0,
          noAnswer: r.read<int>('na') != 0,
          n: r.read<int>('n'),
        ),
    ];
  }

  /// Drops the rows older than [keep] (run at start).
  Future<int> prune(int nowMs) => (_db.delete(
    _db.activityLogRows,
  )..where((r) => r.at.isSmallerThanValue(nowMs - keep.inMilliseconds))).go();

  Future<void> clear() => _db.delete(_db.activityLogRows).go();
}
