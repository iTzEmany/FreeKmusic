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
}
