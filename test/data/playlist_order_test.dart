import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/playlist_ops.dart';
import 'package:codecore/services/backup/backup_service.dart';
import 'package:codecore/services/backup/restore_service.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

// Characterization (phase 87.1): the manual order, `playlist_tracks.position`.

void main() {
  late AppDatabase db;
  late PlaylistRepository repo;
  late ProviderContainer container;
  late PlaylistOps ops;
  late List<int> t; // track ids a..e
  late int pl;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = PlaylistRepository(db);
    container = ProviderContainer(overrides: [playlistRepositoryProvider.overrideWithValue(repo)]);
    ops = container.read(playlistOpsProvider);
    t = [
      for (final n in ['a', 'b', 'c', 'd', 'e'])
        await db.into(db.tracks).insert(TracksCompanion.insert(
            path: '/$n.mp3', title: n, albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1)),
    ];
    pl = await repo.create('Mix');
    await repo.addTracks(pl, t);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Titles in manual order, joined; also checks the positions are exactly 0..n-1.
  Future<String> order(AppDatabase d, int playlistId) async {
    final rows = await (d.select(d.playlistTracks)
          ..where((r) => r.playlistId.equals(playlistId))
          ..orderBy([(r) => OrderingTerm.asc(r.position)]))
        .get();
    final titles = [for (final r in rows) (await (d.select(d.tracks)..where((x) => x.id.equals(r.trackId))).getSingle()).title];
    expect([for (final r in rows) r.position], [for (var i = 0; i < rows.length; i++) i]);
    return titles.join();
  }

  test('reorder moves one track and keeps the positions contiguous', () async {
    await ops.reorder(pl, 0, 3);
    expect(await order(db, pl), 'bcdae');
    await ops.reorder(pl, 4, 0);
    expect(await order(db, pl), 'ebcda');
  });

  test('removing a track closes the gap; undo puts it back at its row', () async {
    await ops.reorder(pl, 4, 1); // a e b c d
    final undo = await ops.removeTrack(pl, t[4], index: 1, length: 5);
    expect(await order(db, pl), 'abcd');
    await undo();
    expect(await order(db, pl), 'aebcd');
  });

  test('removing several tracks and undoing restores the order they had', () async {
    await ops.reorder(pl, 0, 4); // b c d e a
    final undo = await ops.removeTracks(pl, [t[2], t[0]]);
    expect(await order(db, pl), 'bde');
    await undo();
    expect(await order(db, pl), 'bcdea');
  });

  test('the manual order survives a backup and a full restore', () async {
    await ops.reorder(pl, 0, 4); // b c d e a
    final dir = Directory.systemTemp.createTempSync('po');
    addTearDown(() => dir.deleteSync(recursive: true));
    SharedPreferences.setMockInitialValues({'deviceId': 'A'});
    final prefs = await SharedPreferences.getInstance();
    final zip = File(p.join(dir.path, 'b.zip'));
    await BackupService(
      db: db, prefs: prefs, coversDir: Directory(p.join(dir.path, 'covers')),
      downloadsFile: File(p.join(dir.path, 'none.json')), deviceId: 'A',
    ).createBackup(zip.path);
    await db.close(); // one database open at a time
    final staging = Directory(p.join(dir.path, 'restore'));
    final dbFile = File(p.join(dir.path, 'codecore.sqlite'));
    await stageFullRestore(zip, staging);
    expect(
        await applyPendingRestore(
            dbFile: dbFile, staging: staging, prefs: prefs, coversDir: Directory(p.join(dir.path, 'covers')),
            schemaVersion: kSchemaVersion),
        isTrue);
    final restored = AppDatabase(NativeDatabase(dbFile));
    addTearDown(restored.close);
    expect(await order(restored, pl), 'bcdea');
  });

  test('undo of removing a shadow row puts it back where it was', () async {
    final s = await TrackRepository(db).ensureStreamRow(YtResult(id: 'v1', title: 'S', channel: 'Ch', duration: Duration.zero));
    await repo.addStreamTracks(pl, [s]);
    await repo.reorder(pl, 5, 1); // a S b c d e
    final undo = await ops.removeTrack(pl, s, index: 1, length: 6);
    expect(await order(db, pl), 'abcde');
    await undo();
    expect(await order(db, pl), 'aSbcde');
  });
}
