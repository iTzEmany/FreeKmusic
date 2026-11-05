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

  /// Newest first; [offset] rows are skipped.
  Future<List<ActivityLogRow>> page({required int limit, int offset = 0}) =>
      (_db.select(_db.activityLogRows)
            ..orderBy([
              (r) => OrderingTerm.desc(r.at),
              (r) => OrderingTerm.desc(r.id),
            ])
            ..limit(limit, offset: offset))
          .get();

  Future<int> count() async {
    final n = _db.activityLogRows.id.count();
    final q = _db.selectOnly(_db.activityLogRows)..addColumns([n]);
    return (await q.getSingle()).read(n) ?? 0;
  }

  /// How many rows there are per kind, outcome and «nobody answered» (the
  /// detail of a stopped completion), for the counts of the Registro filters.
  Future<List<({String kind, bool failed, bool noAnswer, int n})>> countsByKind() async {
    final rows = await _db.customSelect(
      'SELECT kind, failed, COALESCE(detail LIKE \'%"noAnswer":true%\', 0) AS na, COUNT(*) AS n '
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
