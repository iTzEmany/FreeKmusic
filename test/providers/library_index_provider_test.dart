import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/core/import_row.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the library index is rebuilt when songs are added', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    Future<void> add(String title) => db.into(db.tracks).insert(TracksCompanion.insert(
          path: '/m/$title.mp3',
          title: title,
          albumKey: 'k',
          format: 'mp3',
          sizeBytes: 1,
          mtimeMs: 1,
          addedAt: 1,
          artist: const Value('Band'),
          durationMs: const Value(100000),
        ));
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    container.listen(libraryIndexProvider, (_, _) {});
    bool has(dynamic index, String title) =>
        index.find(ImportRow(index: 0, title: title, artists: const ['Band'], durationMs: 100000)) != null;

    await add('One');
    var index = await container.read(libraryIndexProvider.future);
    for (var i = 0; i < 100 && !has(index, 'One'); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      index = await container.read(libraryIndexProvider.future);
    }
    expect(has(index, 'One'), isTrue);
    expect(has(index, 'Two'), isFalse);

    await add('Two');
    for (var i = 0; i < 100 && !has(index, 'Two'); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      index = await container.read(libraryIndexProvider.future);
    }
    expect(has(index, 'Two'), isTrue);
  });

  /// Runs the first read inside the fake clock (its timer is a fake one); the
  /// isolate of `compute` is let to finish in real time.
  Future<void> settle(WidgetTester t) => t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));

  testWidgets('the index is rebuilt after 5 minutes, and a closed container leaves no timer', (t) async {
    final repo = _Repo();
    final c = ProviderContainer(overrides: [trackRepositoryProvider.overrideWithValue(repo)]);
    c.listen(libraryIndexProvider, (_, _) {});
    await settle(t);
    expect(repo.calls, 1);
    await t.pump(const Duration(minutes: 4, seconds: 59));
    expect(repo.calls, 1);
    await t.pump(const Duration(seconds: 1));
    await settle(t);
    expect(repo.calls, 2);
    c.dispose(); // the test fails if a timer is left pending
  });

  testWidgets('a failed read is not kept for 5 minutes: it is retried soon', (t) async {
    final repo = _Repo()..failFirst = true;
    final c = ProviderContainer(overrides: [trackRepositoryProvider.overrideWithValue(repo)]);
    c.listen(libraryIndexProvider, (_, _) {});
    await settle(t);
    expect(c.read(libraryIndexProvider).hasError, isTrue);
    await t.pump(const Duration(seconds: 6));
    await settle(t);
    await t.pump();
    expect(repo.calls, 2);
    expect(c.read(libraryIndexProvider).hasValue, isTrue);
    c.dispose();
  });
}

class _Repo implements TrackRepository {
  int calls = 0;
  bool failFirst = false;

  @override
  Stream<int> watchCount({bool favoritesOnly = false}) => const Stream.empty();
  @override
  Future<List<LibraryEntryLite>> liteEntries() async {
    calls++;
    if (failFirst && calls == 1) throw StateError('db');
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}
