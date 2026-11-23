import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
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

  test('a key with an unknown source leaves no stray shadow row; an episode path is skipped', () async {
    final here = AppDatabase(NativeDatabase.memory());
    addTearDown(here.close);
    await TrackRepository(here).ensureStreamRow(YtResult(id: 'e1', title: 'Ep', channel: 'C', duration: Duration.zero));
    await here.customStatement("UPDATE tracks SET kind = 1 WHERE path = 'stream:youtube:e1'");
    final data = UserData(createdAt: 1, playlists: [
      const PlaylistData(name: 'X', createdAt: 1, uuid: 'u1', items: [
        TrackRef(title: 'x', streamKey: 'spotify:abc'),
        TrackRef(title: 'ep', streamKey: 'youtube:e1'),
      ]),
    ]);
    final report = await mergeUserData(here, data, await PlaylistSyncRepository(here).resolver());
    expect(report.playlistItemsSkipped, 2);
    expect([for (final t in await here.select(here.tracks).get()) t.path], ['stream:youtube:e1']);
  });

  // D-607: a streamed track the user saved is library content and travels with its user data.
  group('saved stream rows (D-607)', () {
    Future<AppDatabase> savedSource() async {
      final db = AppDatabase(NativeDatabase.memory());
      final tracks = TrackRepository(db);
      await tracks.saveStream(const YtResult(
          id: 'v1', title: 'Stream one', channel: 'Ch', duration: Duration(seconds: 90), artists: ['Art'], album: 'Alb', albumId: 'MPREb_x'));
      await tracks.ensureStreamRow(const YtResult(id: 'v2', title: 'Unsaved', channel: 'Ch', duration: null));
      await db.customStatement("UPDATE tracks SET is_favorite = 1, play_count = 4, last_played_at = 99, added_at = 1234 WHERE path = 'stream:youtube:v1'");
      final pl = PlaylistRepository(db);
      final id = await pl.create('Mix');
      await pl.addStreamTracks(id, [(await tracks.streamRow('youtube:v1'))!.id]);
      return db;
    }

    UserData roundTrip(UserData d) =>
        UserData.fromJson(jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>);

    test('restore on an empty DB keeps saved rows with favourite, plays and playlist; unsaved ones stay out', () async {
      final src = await savedSource();
      addTearDown(src.close);
      final data = roundTrip(await collectUserData(src));
      expect(data.tracks.map((t) => t.ref.streamKey), ['youtube:v1']);
      final here = AppDatabase(NativeDatabase.memory());
      addTearDown(here.close);
      await mergeUserData(here, data, await PlaylistSyncRepository(here).resolver());
      final row = (await TrackRepository(here).streamRow('youtube:v1'))!;
      expect((row.saved, row.isFavorite, row.playCount, row.lastPlayedAt), (true, true, 4, 99));
      expect((row.album, row.albumKey, row.addedAt), ('Alb', 'stream|art|alb', 1234));
      expect(row.albumBrowseId, 'MPREb_x');
      expect((await TrackRepository(here).streamRow('youtube:v2')), isNull);
      expect(await playlist(here, 'Mix'), await playlist(src, 'Mix'));
      final saved = await (here.select(here.tracks)..where((t) => isLibraryRow(t))).get();
      expect(saved, hasLength(1));
    });

    test('a saved row edited by hand keeps the stream| album key; a malformed saved flag reads as false', () async {
      final data = UserData.fromJson({
        'format': 1,
        'createdAt': 1,
        'tracks': [
          {
            'ref': {'streamKey': 'youtube:e1', 'title': 'T'},
            'saved': true,
            'edit': {'title': 'T', 'artist': 'Art', 'album': 'Alb'},
          },
          {'ref': {'streamKey': 'youtube:e2', 'title': 'U'}, 'saved': 'yes'},
        ],
      });
      final here = AppDatabase(NativeDatabase.memory());
      addTearDown(here.close);
      await mergeUserData(here, data, await PlaylistSyncRepository(here).resolver());
      final e1 = (await TrackRepository(here).streamRow('youtube:e1'))!;
      expect((e1.saved, e1.albumKey), (true, 'stream|art|alb'));
      expect((await TrackRepository(here).streamRow('youtube:e2'))!.saved, false);
    });

    test('saved:true on a file ref does not abort the restore', () async {
      final data = UserData.fromJson({
        'format': 1,
        'createdAt': 1,
        'tracks': [
          {'ref': {'folder': '/m', 'relPath': 'a.mp3', 'title': 'a'}, 'saved': true, 'favorite': true},
        ],
      });
      final here = AppDatabase(NativeDatabase.memory());
      addTearDown(here.close);
      final folder = await here.into(here.folders).insert(FoldersCompanion.insert(path: '/m', addedAt: 1));
      await here.into(here.tracks).insert(TracksCompanion.insert(
          path: '/m/a.mp3', title: 'a', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1, folderId: Value(folder)));
      final report = await mergeUserData(here, data, await PlaylistSyncRepository(here).resolver());
      expect(report.favoritesAdded, 1);
    });

    test('the manifest track count includes saved rows, not the unsaved ones', () async {
      final src = await savedSource();
      addTearDown(src.close);
      SharedPreferences.setMockInitialValues({});
      final zip = File(p.join(dir.path, 'c.zip'));
      await BackupService(
        db: src,
        prefs: await SharedPreferences.getInstance(),
        coversDir: Directory(p.join(dir.path, 'covers')),
        downloadsFile: File(p.join(dir.path, 'none.json')),
        deviceId: 'dev',
      ).createBackup(zip.path);
      final manifest = ZipDecoder().decodeBytes(zip.readAsBytesSync()).findFile('manifest.json')!;
      expect((jsonDecode(utf8.decode(manifest.content as List<int>)) as Map)['trackCount'], 1);
    });

    test('an old backup without the field restores its stream rows as not saved', () async {
      final old = UserData.fromJson({
        'format': 1,
        'createdAt': 1,
        'tracks': [
          {'ref': {'streamKey': 'youtube:v1', 'title': 'Stream one'}, 'favorite': true},
        ],
      });
      final here = AppDatabase(NativeDatabase.memory());
      addTearDown(here.close);
      await mergeUserData(here, old, await PlaylistSyncRepository(here).resolver());
      final row = (await TrackRepository(here).streamRow('youtube:v1'))!;
      expect((row.saved, row.isFavorite), (false, true));
    });
  });
}
