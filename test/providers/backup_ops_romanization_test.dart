import 'dart:convert';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/backup_ops.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/dislike_store_provider.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/theme_providers.dart';
import 'package:codecore/services/backup/backup_service.dart';
import 'package:codecore/services/shuffle_plus/dislike_store.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'BackupOps.merge adds the backup\'s transliterations through the setting',
    () async {
      final dir = Directory.systemTemp.createTempSync('bkops');
      addTearDown(() => dir.deleteSync(recursive: true));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              null,
            ),
      );

      Future<AppDatabase> library() async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await db
            .into(db.tracks)
            .insert(
              TracksCompanion.insert(
                path: '/m/a.mp3',
                title: 'A',
                albumKey: 'k',
                format: 'mp3',
                sizeBytes: 1,
                mtimeMs: 1,
                addedAt: 1,
                lyricsPlain: const Value('la la'),
              ),
            );
        return db;
      }

      // The backup of a library whose track has a typed transliteration.
      SharedPreferences.setMockInitialValues({
        'manualRomanization': '{"1":"mine"}',
        'handWrittenLyrics': ['1'],
      });
      final source = await library();
      final covers = Directory(p.join(dir.path, 'src-covers'))..createSync();
      final zip = p.join(dir.path, 'b.zip');
      await BackupService(
        db: source,
        prefs: await SharedPreferences.getInstance(),
        coversDir: covers,
        downloadsFile: File(p.join(dir.path, 'downloads.json')),
        deviceId: 'dev',
        platform: 'linux',
        now: () => DateTime(2026, 11, 8),
      ).createBackup(zip);

      // Another device: same track, nothing typed yet.
      SharedPreferences.setMockInitialValues({});
      final target = await library();
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(target),
          settingsStoreProvider.overrideWithValue(await SettingsStore.open()),
          dislikeStoreProvider.overrideWithValue(
            DislikeStore(
              file: () async => File(p.join(dir.path, 'dislikes.json')),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      await c.read(backupOpsProvider).merge(File(zip));
      expect(c.read(manualRomanizationProvider), {1: 'mine'});
      expect(c.read(handWrittenLyricsProvider), {1});
      expect((await SettingsStore.open()).readHandWrittenLyrics(), {1});
      // One already here is never overwritten.
      await c.read(manualRomanizationProvider.notifier).addMissing({
        1: 'other',
        2: 'new',
      });
      expect(c.read(manualRomanizationProvider), {1: 'mine', 2: 'new'});
      expect((await SettingsStore.open()).readManualRomanizations(), {
        1: 'mine',
        2: 'new',
      });
    },
  );

  test('BackupOps.merge reloads the settings and themes the providers had cached', () async {
    final dir = Directory.systemTemp.createTempSync('bkops2');
    addTearDown(() => dir.deleteSync(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final theme = jsonEncode([
      {'id': 't1', 'name': 'One', 'base': 'notte', 'overrides': <String, int>{}, 'background': {'kind': 'none'}},
    ]);
    SharedPreferences.setMockInitialValues({'accent': 'rosa', 'customThemes': theme});
    final source = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);
    final zip = p.join(dir.path, 'b.zip');
    await BackupService(
      db: source,
      prefs: await SharedPreferences.getInstance(),
      coversDir: Directory(p.join(dir.path, 'src-covers'))..createSync(),
      downloadsFile: File(p.join(dir.path, 'downloads.json')),
      deviceId: 'dev',
      platform: 'linux',
      now: () => DateTime(2026, 11, 8),
    ).createBackup(zip);

    SharedPreferences.setMockInitialValues({});
    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(target),
        settingsStoreProvider.overrideWithValue(await SettingsStore.open()),
        dislikeStoreProvider.overrideWithValue(
          DislikeStore(file: () async => File(p.join(dir.path, 'dislikes.json'))),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(settingsProvider).accent, 'viola'); // cached before the merge
    expect(c.read(customThemesProvider).items, isEmpty);
    await c.read(backupOpsProvider).merge(File(zip));
    expect(c.read(settingsProvider).accent, 'rosa');
    expect(c.read(customThemesProvider).byId('t1')?.name, 'One');
  });
}
