import 'dart:convert';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/backup_merge.dart';
import 'package:codecore/data/repositories/backup_queries.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/playlist_sync_repository.dart';
import 'package:codecore/data/repositories/track_kinds.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/backup/backup_service.dart';
import 'package:codecore/services/backup/restore_service.dart';
import 'package:codecore/services/backup/user_data.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

// D-524: a playlist saved from a page holds shadow rows (kind 2); they travel in the
// portable data as their stream key and come back as new shadow rows.
void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('spb'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> addLibrary(AppDatabase db, String title) => db.into(db.tracks).insert(
        TracksCompanion.insert(
            path: '/m/$title.mp3', title: title, albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1, artist: const Value('Band')),
      );

  Future<int> idOf(AppDatabase db, String title) async =>
      (await (db.select(db.tracks)..where((t) => t.title.equals(title))).getSingle()).id;

  /// Library a, c; the playlist is [a, shadow v1, c, shadow v2].
  Future<AppDatabase> source() async {
    final db = AppDatabase(NativeDatabase.memory());
    await addLibrary(db, 'a');
    await addLibrary(db, 'c');
    final tracks = TrackRepository(db);
    final s1 = await tracks.ensureStreamRow(const YtResult(
        id: 'v1', title: 'Stream one', channel: 'Ch', duration: Duration(seconds: 90), artists: ['Art']));
    final s2 = await tracks.ensureStreamRow(const YtResult(id: 'v2', title: 'Stream two', channel: 'Ch', duration: null));
    final pl = PlaylistRepository(db);
    final id = await pl.create('Saved');
    await pl.addStreamTracks(id, [await idOf(db, 'a'), s1, await idOf(db, 'c'), s2]);
    return db;
  }

  Future<List<(int, String, String)>> playlist(AppDatabase db, String name) async {
    final id = (await (db.select(db.playlists)..where((x) => x.name.equals(name))).getSingle()).id;
    final rows = await PlaylistRepository(db).watchTracks(id).first;
    return [for (final t in rows) (t.kind, t.path, t.title)];
  }

  test('backup zip -> merge: same playlist, same order, shadow rows recreated', () async {
    final src = await source();
    addTearDown(src.close);
    SharedPreferences.setMockInitialValues({});
    final zip = File(p.join(dir.path, 'b.zip'));
    await BackupService(
      db: src,
      prefs: await SharedPreferences.getInstance(),
      coversDir: Directory(p.join(dir.path, 'covers')),
      downloadsFile: File(p.join(dir.path, 'none.json')),
      deviceId: 'dev',
    ).createBackup(zip.path);

    final here = AppDatabase(NativeDatabase.memory());
    addTearDown(here.close);
    await addLibrary(here, 'a');
    await addLibrary(here, 'c');
    final report = await mergeBackup(zip, here, Directory(p.join(dir.path, 'm-covers')));
    expect(report.playlistsCreated, 1);
    expect(report.playlistItemsSkipped, 0);
    expect(await playlist(here, 'Saved'), await playlist(src, 'Saved'));
    final row = (await TrackRepository(here).streamRow('youtube:v1'))!;
    expect((row.kind, row.title, row.artist, row.durationMs), (kStreamKind, 'Stream one', 'Art', 90000));
  });

  test('merging the same backup twice does not copy the playlist or the shadow rows again', () async {
    final src = await source();
    addTearDown(src.close);
    final data = UserData.fromJson(jsonDecode(jsonEncode((await collectUserData(src)).toJson())) as Map<String, dynamic>);
    final here = AppDatabase(NativeDatabase.memory());
    addTearDown(here.close);
    await addLibrary(here, 'a');
    await addLibrary(here, 'c');
    final resolver = await PlaylistSyncRepository(here).resolver();
    await mergeUserData(here, data, resolver);
    await mergeUserData(here, data, resolver);
    expect(await here.select(here.playlists).get(), hasLength(1));
    expect(await (here.select(here.tracks)..where((t) => t.kind.equals(kStreamKind))).get(), hasLength(2));
    expect(await playlist(here, 'Saved'), hasLength(4));
  });

  test('a backup written before shadow rows in playlists still merges (their items were left out)', () async {
    final old = UserData.fromJson({
      'format': 1,
      'createdAt': 1,
      'tracks': [],
      'playlists': [
        {
          'name': 'Old',
          'createdAt': 1,
          'items': [
            {'folder': '/m', 'relPath': 'a.mp3', 'title': 'a', 'artist': 'Band'},
            {'folder': '/m', 'relPath': 'c.mp3', 'title': 'c', 'artist': 'Band'},
          ],
        },
      ],
    });
    final here = AppDatabase(NativeDatabase.memory());
    addTearDown(here.close);
    await addLibrary(here, 'a');
    await addLibrary(here, 'c');
    await mergeUserData(here, old, await PlaylistSyncRepository(here).resolver());
    expect((await playlist(here, 'Old')).map((r) => r.$3), ['a', 'c']);
  });

  test('a stream key that is not <source>:<id> is skipped and counted', () async {
    final data = UserData(createdAt: 1, playlists: [
      const PlaylistData(name: 'Bad', createdAt: 1, items: [TrackRef(title: 'x', streamKey: 'nocolon')]),
    ]);
    final here = AppDatabase(NativeDatabase.memory());
    addTearDown(here.close);
    final report = await mergeUserData(here, data, await PlaylistSyncRepository(here).resolver());
    expect(report.playlistItemsSkipped, 1);
    expect(await here.select(here.tracks).get(), isEmpty);
  });
}
