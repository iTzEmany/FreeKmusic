import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/play_history_repository.dart';
import 'package:codecore/data/repositories/stats_queries.dart';
import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> track(
    String t, {
    int kind = 0,
    bool missing = false,
    bool ignored = false,
  }) => db
      .into(db.tracks)
      .insert(
        TracksCompanion.insert(
          path: '/$t',
          title: t,
          albumKey: t,
          format: 'mp3',
          sizeBytes: 1,
          mtimeMs: 1,
          addedAt: 1,
          kind: Value(kind),
          missing: Value(missing),
          ignored: Value(ignored),
        ),
      );

  test('music still in the library, since the date; not episodes, streams, missing or hidden ones', () async {
    final history = PlayHistoryRepository(db);
    final ok = await track('ok');
    final from = DateTime(2026, 8, 1);
    for (final (id, at) in [
      (ok, DateTime(2026, 8, 2, 22, 5)),
      (ok, DateTime(2026, 7, 31)), // before
      (await track('ep', kind: 1), DateTime(2026, 9)),
      (await track('stream', kind: 2), DateTime(2026, 9)),
      (await track('gone', missing: true), DateTime(2026, 9)),
      (await track('hidden', ignored: true), DateTime(2026, 9)),
    ]) {
      await history.start(id, at.millisecondsSinceEpoch);
    }
    final rows = await StatsQueries(db).listensSince(from);
    expect(rows, [(trackId: ok, playedAt: DateTime(2026, 8, 2, 22, 5))]);
  });

  test('the period is read through the plays_at index, not a scan', () async {
    final plan = await db
        .customSelect(
          'EXPLAIN QUERY PLAN $listensSinceSql',
          variables: [Variable.withInt(0)],
        )
        .get();
    expect(
      plan.map((r) => r.read<String>('detail')).join('\n'),
      contains('plays_at'),
    );
  });
}
