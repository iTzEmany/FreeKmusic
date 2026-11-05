import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/activity_log_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ActivityLogRepository repo;
  const day = 86400000;
  const now = 100 * day;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ActivityLogRepository(db);
  });
  tearDown(() => db.close());

  test('pages come newest first and the count is the whole table', () async {
    for (final at in [3, 1, 2]) {
      await repo.add(at: at, kind: 'scan', name: 'n$at');
    }
    expect((await repo.page(limit: 2)).map((r) => r.name), ['n3', 'n2']);
    expect((await repo.page(limit: 2, offset: 2)).map((r) => r.name), ['n1']);
    expect(await repo.count(), 3);
  });

  test('prune drops what is older than 30 days; the exact boundary and 29 days stay', () async {
    for (final d in [31, 30, 29]) {
      await repo.add(at: now - d * day, kind: 'scan', name: '$d');
    }
    await repo.add(at: now - 30 * day - 1, kind: 'scan', name: 'just over');
    expect(await repo.prune(now), 2);
    expect((await repo.page(limit: 10)).map((r) => r.name), ['29', '30']);
  });

  test('two rows with the same time come back the last added first', () async {
    await repo.add(at: 5, kind: 'scan', name: 'first');
    await repo.add(at: 5, kind: 'scan', name: 'second');
    expect((await repo.page(limit: 10)).map((r) => r.name), ['second', 'first']);
  });

  test('clear empties the table', () async {
    await repo.add(at: now, kind: 'radio', name: '', detail: '{"a":1}');
    await repo.clear();
    expect(await repo.count(), 0);
  });

  test('countsByKind marks «nobody answered» only by the real key, not by a word in the detail', () async {
    await repo.add(at: 1, kind: 'enrichBackground', name: '', failed: true, detail: '{"noAnswer":true}');
    await repo.add(at: 2, kind: 'enrichBackground', name: '', failed: true, detail: '{"note":"noAnswer"}');
    final rows = await repo.countsByKind();
    expect(rows.where((r) => r.noAnswer).fold<int>(0, (a, r) => a + r.n), 1);
    expect(rows.where((r) => !r.noAnswer).fold<int>(0, (a, r) => a + r.n), 1);
  });
}
