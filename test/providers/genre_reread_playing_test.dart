import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/genre_reread_providers.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/startup_providers.dart';
import 'package:codecore/services/tags/tag_reader.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Reader implements TagReader {
  int calls = 0;
  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async {
    calls++;
    return const TagInfo();
  }
}

void main() {
  test('the genre re-read waits while the player plays (D-390)', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.tracks).insert(TracksCompanion.insert(
        path: '/a.mp3', title: 'a', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1,
        genre: const Value('Rock')));
    final reader = _Reader();
    final playing = StreamController<bool>();
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      settingsStoreProvider.overrideWithValue(store),
      tagReaderProvider.overrideWithValue(reader),
      startupSettledProvider.overrideWith((ref) async {}),
      isPlayingProvider.overrideWith((ref) => playing.stream),
    ]);
    addTearDown(() async {
      c.dispose();
      await playing.close();
      await db.close();
    });
    c.listen(isPlayingProvider, (_, _) {});
    playing.add(true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    c.read(genreRereadStartProvider);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(reader.calls, 0, reason: 'music is playing');
    playing.add(false);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(reader.calls, 1);
  });
}
