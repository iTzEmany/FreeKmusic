import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/artist_alias_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ArtistAliasRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ArtistAliasRepository(db);
  });
  tearDown(() => db.close());

  test('merge: b becomes an alias of a; the group lists the main first', () async {
    await repo.merge('A', 'B');
    expect(await repo.mainOf('B'), 'A');
    expect(await repo.mainOf('A'), 'A');
    expect(await repo.groupOf('B'), ['A', 'B']);
    expect(await repo.groupOf('Z'), ['Z']);
  });

  test('a main that gets merged into another takes its aliases along (no chain)', () async {
    await repo.merge('B', 'A');
    await repo.merge('C', 'B');
    expect([for (final x in ['A', 'B', 'C']) await repo.mainOf(x)], ['C', 'C', 'C']);
    expect(await repo.groupOf('A'), hasLength(3));
    expect((await repo.allAliases()).values.toSet(), {'C'});
  });

  test('merging through an alias uses its main; merging a group into itself does nothing', () async {
    await repo.merge('A', 'B');
    await repo.merge('B', 'C');
    expect(await repo.groupOf('C'), ['A', 'B', 'C']);
    await repo.merge('C', 'A');
    expect(await repo.groupOf('B'), ['A', 'B', 'C']);
  });

  test('split: an alias leaves; when the main leaves, the oldest alias leads the rest', () async {
    await repo.merge('A', 'B');
    await repo.merge('A', 'C');
    await repo.split('C');
    expect(await repo.groupOf('A'), ['A', 'B']);
    expect(await repo.groupOf('C'), ['C']);
    await repo.merge('A', 'C');
    await repo.split('A');
    expect(await repo.groupOf('A'), ['A']);
    expect((await repo.groupOf('C')).toSet(), {'B', 'C'});
    expect(await repo.mainOf('C'), 'B');
    await repo.split('B');
    expect(await db.select(db.artistAliases).get(), isEmpty);
    await repo.split('nobody');
  });

  test('not-same pairs are unordered, and merging the profiles clears the pair', () async {
    await repo.markNotSame('B', 'A');
    expect(await repo.isNotSame('A', 'B'), isTrue);
    expect(await repo.isNotSame('A', 'C'), isFalse);
    await repo.markNotSame('A', 'B');
    expect(await db.select(db.artistNotSame).get(), hasLength(1));
    await repo.merge('A', 'B');
    expect(await repo.isNotSame('A', 'B'), isFalse);
  });

  test('markNotSame on two profiles of one group saves nothing; the table refuses an unordered pair', () async {
    await repo.merge('A', 'B');
    await repo.markNotSame('B', 'A');
    expect(await db.select(db.artistNotSame).get(), isEmpty);
    await expectLater(
        db.customStatement("INSERT INTO artist_not_same (a, b, created_at) VALUES ('Z', 'A', 1)"), throwsA(anything));
  });

  test('merging two groups clears every different pair between their profiles', () async {
    await repo.merge('A', 'B');
    await repo.merge('C', 'D');
    await repo.markNotSame('B', 'D');
    await repo.markNotSame('A', 'X');
    await repo.merge('A', 'C');
    expect([for (final r in await db.select(db.artistNotSame).get()) (r.a, r.b)], [('A', 'X')]);
  });

  test('markNotSame orders by UTF-8 bytes, like the CHECK constraint', () async {
    await repo.markNotSame('\uFF21', '\u{1F600}');
    expect(await repo.isNotSame('\u{1F600}', '\uFF21'), isTrue);
  });

  test('split of the main keeps the remaining aliases\' createdAt', () async {
    await repo.merge('A', 'B', createdAt: 5);
    await repo.merge('A', 'C', createdAt: 10);
    await repo.merge('A', 'D', createdAt: 20);
    await repo.split('A');
    final rows = await db.select(db.artistAliases).get();
    expect({for (final r in rows) r.aliasId: r.createdAt}, {'C': 10, 'D': 20});
    expect(rows.every((r) => r.mainId == 'B'), isTrue);
  });

  test('separate marks the pair different; rejoin undoes it, for an alias and for the main', () async {
    await repo.merge('A', 'B');
    var group = await repo.separate('B');
    expect(await repo.groupOf('A'), ['A']);
    expect(await repo.isNotSame('A', 'B'), isTrue);
    await repo.rejoin(group, 'B');
    expect(await repo.groupOf('A'), ['A', 'B']);
    expect(await repo.isNotSame('A', 'B'), isFalse);
    group = await repo.separate('A');
    await repo.rejoin(group, 'A');
    expect(await repo.groupOf('B'), ['A', 'B']);
  });

  test('unmarkNotSame removes the pair whatever the order', () async {
    await repo.markNotSame('A', 'B');
    await repo.unmarkNotSame('B', 'A');
    expect(await repo.isNotSame('A', 'B'), isFalse);
  });
}
