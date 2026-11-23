import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final now = DateTime.now().millisecondsSinceEpoch;
  int ago(int minutes) => now - minutes * 60000;
  Future<int> add(String t, {bool missing = false, bool ignored = false}) =>
      db.into(db.tracks).insert(TracksCompanion.insert(
        path: '/m/$t', title: t, albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1,
        missing: Value(missing), ignored: Value(ignored)));
  Future<void> play(int id, int at, int? ctx) => db.into(db.plays).insert(
    PlaysCompanion.insert(trackId: id, playedAt: at, context: Value(ctx)));
  Future<Map<int?, LastPlay>> last() async => {
    for (final p in await LibraryQueries(db).watchLastPlayPerContext().first) p.context: p,
  };

  test('no plays: nothing', () async {
    expect(await last(), isEmpty);
  });

  test('the latest play of each context, null, negative and huge contexts included', () async {
    final a = await add('a'), b = await add('b');
    await play(a, ago(50), null);
    await play(b, ago(40), null);
    await play(a, ago(30), -3);
    await play(b, ago(20), 1 << 50);
    final r = await last();
    expect(r[null]!.track.id, b);
    expect(r[null]!.at, ago(40));
    expect(r[-3]!.track.id, a);
    expect(r[1 << 50]!.track.id, b);
  });

  test('a missing or ignored latest track falls back to the latest valid play of the context', () async {
    final a = await add('a'), m = await add('m', missing: true), ig = await add('ig', ignored: true);
    await play(a, ago(30), 4);
    await play(m, ago(10), 4);
    await play(a, ago(30), 7);
    await play(ig, ago(10), 7);
    await play(m, ago(5), 9); // nothing valid at all: the context is absent
    final r = await last();
    expect((r[4]!.track.id, r[4]!.at), (a, ago(30)));
    expect(r[7]!.track.id, a);
    expect(r.containsKey(9), isFalse);
  });

  test('a tie gives one row for the context', () async {
    final a = await add('a'), b = await add('b');
    await play(a, ago(10), 8);
    await play(b, ago(10), 8);
    final r = await LibraryQueries(db).watchLastPlayPerContext().first;
    expect(r, hasLength(1));
    expect(r.single.at, ago(10));
  });

  test('plays older than 90 days are not read', () async {
    final a = await add('a');
    await play(a, now - 91 * 86400000, 1);
    await play(a, now - 89 * 86400000, 2);
    final r = await last();
    expect(r.containsKey(1), isFalse);
    expect(r.containsKey(2), isTrue);
  });

  test('a shadow row (an online entry that is not saved) is not a Riprendi track', () async {
    final id = await db.into(db.tracks).insert(TracksCompanion.insert(
      path: 'x', title: 'x', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1,
      kind: const Value(2)));
    await play(id, ago(5), 4);
    expect((await last()).containsKey(4), isFalse);
  });

  test('the name of the context comes with its latest play', () async {
    final a = await add('a');
    await db.into(db.plays).insert(PlaysCompanion.insert(
      trackId: a, playedAt: ago(9), context: const Value(1), contextName: const Value('Old')));
    await db.into(db.plays).insert(PlaysCompanion.insert(
      trackId: a, playedAt: ago(3), context: const Value(1), contextName: const Value('New')));
    expect((await last())[1]!.contextName, 'New');
  });

  test('the query reads the period through plays_at', () async {
    final rows = await db.customSelect(
      'EXPLAIN QUERY PLAN $lastPlayPerContextSql',
      variables: [Variable<int>(0)]).get();
    expect(rows.map((r) => r.read<String>('detail')).join('\n'), contains('USING INDEX plays_at'));
  });
}
