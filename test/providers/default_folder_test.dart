import 'dart:async';

import 'package:codecore/core/platform.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/folder_repository.dart';
import 'package:codecore/providers/folder_actions.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FolderRepository repo;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    repo = FolderRepository(db);
  });

  Future<DefaultFolders> fake() async => const DefaultFolders(library: '/m/Music', downloads: '/m/Music/FreeKmusic');

  test('empty folders table: adds the default library folder and scans, once', () async {
    var scans = 0;
    expect(await ensureDefaultFolder(repo, () async => scans++, resolve: fake), isTrue);
    expect(await ensureDefaultFolder(repo, () async => scans++, resolve: fake), isFalse);
    expect([for (final f in await repo.getAll()) f.path], ['/m/Music']);
    expect(scans, 1);
  });

  test('a library that already has a folder is left alone', () async {
    await repo.add('/other');
    var scans = 0;
    expect(await ensureDefaultFolder(repo, () async => scans++, resolve: fake), isFalse);
    expect((await repo.getAll()).length, 1);
    expect(scans, 0);
  });

  group('scanIfPermissionLate', () {
    Future<SharedPreferences> prefs(bool flagged) async {
      SharedPreferences.setMockInitialValues({if (flagged) kScanNeedsPermission: true});
      return SharedPreferences.getInstance();
    }

    test('Android, the last scan was skipped for the permission, granted now: scans and clears the flag', () async {
      final p = await prefs(true);
      var scans = 0;
      expect(await scanIfPermissionLate(p, () async => true, () async => scans++, android: true), isTrue);
      expect(scans, 1);
      expect(p.getBool(kScanNeedsPermission), isFalse);
      expect(await scanIfPermissionLate(p, () async => true, () async => scans++, android: true), isFalse);
    });

    test('no flag (an empty library alone proves nothing), not Android or still denied: nothing', () async {
      var scans = 0;
      expect(await scanIfPermissionLate(await prefs(false), () async => true, () async => scans++, android: true), isFalse);
      expect(await scanIfPermissionLate(await prefs(true), () async => true, () async => scans++, android: false), isFalse);
      expect(await scanIfPermissionLate(await prefs(true), () async => false, () async => scans++, android: true), isFalse);
      expect(scans, 0);
    });

    test('two calls at once scan once', () async {
      final p = await prefs(true);
      var scans = 0;
      final gate = Completer<void>();
      Future<void> scan() async {
        scans++;
        await gate.future;
      }

      final a = scanIfPermissionLate(p, () async => true, scan, android: true);
      final b = scanIfPermissionLate(p, () async => true, scan, android: true);
      gate.complete();
      expect(await Future.wait([a, b]), [true, false]);
      expect(scans, 1);
    });
  });
}
