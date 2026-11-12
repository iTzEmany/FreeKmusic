import 'package:codecore/core/platform.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/folder_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/folder_actions.dart';
import 'package:drift/native.dart';
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
    test('permission granted, a folder, an empty library: scans', () async {
      await repo.add('/m');
      var scans = 0;
      final tracks = TrackRepository(db);
      expect(await scanIfPermissionLate(repo, tracks, () async => true, () async => scans++), isTrue);
      expect(scans, 1);
    });

    test('no permission, no folder or a library with tracks: nothing', () async {
      var scans = 0;
      final tracks = TrackRepository(db);
      expect(await scanIfPermissionLate(repo, tracks, () async => true, () async => scans++), isFalse, reason: 'no folder');
      await repo.add('/m');
      expect(await scanIfPermissionLate(repo, tracks, () async => false, () async => scans++), isFalse);
      await db.into(db.tracks).insert(TracksCompanion.insert(
          path: '/m/a.mp3', title: 'A', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1));
      expect(await scanIfPermissionLate(repo, tracks, () async => true, () async => scans++), isFalse);
      expect(scans, 0);
    });
  });
}
