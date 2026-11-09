import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/backup/backup_service.dart';
import 'package:codecore/services/backup/restore_service.dart' show mergeBackup;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory dir;
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('bk');
    // In memory: `VACUUM INTO` copies it the same way, and a file database
    // would cost a disk sync per schema statement in every setUp.
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      'theme': 'oled',
      'compactMode': true,
      'playbackSpeed': 1.25,
      'volume': 3,
      'notDuplicates': ['a', 'b'],
      'unsyncedLyrics': ['2', '5'],
      'deviceId': 'dev-1',
      'deviceName': 'Telefono',
      'trustedDevices': '[]',
      'enrichMark': 42,
      'playlistSorts': '{"12":"title:asc"}',
    });
    prefs = await SharedPreferences.getInstance();
    final folder = await db
        .into(db.folders)
        .insert(FoldersCompanion.insert(path: '/music', addedAt: 1));
    for (var i = 0; i < 3; i++) {
      await db
          .into(db.tracks)
          .insert(
            TracksCompanion.insert(
              path: '/music/$i.mp3',
              title: 'T$i',
              albumKey: 'k',
              format: 'mp3',
              sizeBytes: 1,
              mtimeMs: 1,
              addedAt: 1,
              folderId: Value(folder),
              isFavorite: Value(i == 0),
              playCount: Value(i == 0 ? 5 : 0),
              lastPlayedAt: Value(i == 0 ? 99 : null),
              lyricsPlain: Value(i == 0 ? 'la la' : null),
              lyricsSynced: Value(i == 0 ? '[00:01.00]la' : null),
              curiosities: Value(i == 0 ? 'curious' : null),
            ),
          );
    }
    final pl = await db
        .into(db.playlists)
        .insert(PlaylistsCompanion.insert(name: 'Mix', createdAt: 1));
    await db
        .into(db.playlistTracks)
        .insert(
          PlaylistTracksCompanion.insert(
            playlistId: pl,
            trackId: 1,
            position: 0,
          ),
        );
    await db
        .into(db.playlistTracks)
        .insert(
          PlaylistTracksCompanion.insert(
            playlistId: pl,
            trackId: 3,
            position: 1,
          ),
        );
    await db
        .into(db.playlistTracks)
        .insert(
          PlaylistTracksCompanion.insert(
            playlistId: pl,
            trackId: 2,
            position: 2,
          ),
        );
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  BackupService service({File? downloads}) {
    final covers = Directory(p.join(dir.path, 'covers'))..createSync();
    File(p.join(covers.path, 'a.jpg')).writeAsBytesSync(List.filled(500, 7));
    File(p.join(covers.path, 'b.bin')).writeAsBytesSync(List.filled(500, 0));
    return BackupService(
      db: db,
      prefs: prefs,
      coversDir: covers,
      downloadsFile: downloads ?? File(p.join(dir.path, 'downloads.json')),
      deviceId: 'dev-1',
      platform: 'linux',
      now: () => DateTime(2026, 10, 19, 12),
    );
  }

  test('the file name carries the date', () {
    expect(
      BackupService.fileName(DateTime(2026, 3, 7)),
      'codecore-backup-2026-03-07.zip',
    );
  });

  test('the zip holds manifest, settings, user data, database, covers and downloads', () async {
    final dl = File(p.join(dir.path, 'downloads.json'))
      ..writeAsStringSync('{"youtube:x":"/a.mp3"}');
    final out = p.join(dir.path, 'out.zip');
    final s = await service(downloads: dl).createBackup(out);
    expect(s.tracks, 3);
    expect(s.playlists, 1);
    expect(s.covers, 2);
    expect(s.bytes, File(out).lengthSync());

    final zip = ZipDecoder().decodeBytes(File(out).readAsBytesSync());
    expect(zip.files.map((f) => f.name).toSet(), {
      'manifest.json',
      'settings.json',
      'user_data.json',
      'codecore.sqlite',
      'downloads.json',
      'covers/a.jpg',
      'covers/b.bin',
    });
    String text(String n) => utf8.decode(zip.findFile(n)!.content as List<int>);
    final manifest = jsonDecode(text('manifest.json')) as Map;
    expect(manifest['backupFormat'], 1);
    expect(manifest['schemaVersion'], db.schemaVersion);
    expect(manifest['deviceId'], 'dev-1');
    expect(manifest['folders'], ['/music']);

    final settings = jsonDecode(text('settings.json')) as Map;
    expect(settings.containsKey('deviceId'), isFalse);
    expect(
      settings.containsKey('enrichMark'),
      isFalse,
      reason: 'bound to this device',
    );
    expect(settings.containsKey('deviceName'), isFalse);
    expect(
      settings.containsKey('trustedDevices'),
      isFalse,
      reason: 'bound to this device',
    );
    expect(settings['compactMode'], {'t': 'bool', 'v': true});
    expect(settings['playbackSpeed'], {'t': 'double', 'v': 1.25});
    expect(settings['notDuplicates'], {
      't': 'list',
      'v': ['a', 'b'],
    });
    expect(jsonDecode(text('user_data.json'))['format'], 1);
  });

  test(
    'the copied database opens with the same counts; temporary files are gone',
    () async {
      final out = p.join(dir.path, 'out.zip');
      final tmp = Directory(p.join(dir.path, 'tmp'))..createSync();
      await IOOverrides.runZoned(
        () => service().createBackup(out),
        getSystemTempDirectory: () => tmp,
      );
      expect(tmp.listSync(), isEmpty, reason: 'the work folder is removed');
      final zip = ZipDecoder().decodeBytes(File(out).readAsBytesSync());
      final copy = File(p.join(dir.path, 'copy.sqlite'))
        ..writeAsBytesSync(
          zip.findFile('codecore.sqlite')!.content as List<int>,
        );
      final db2 = AppDatabase(NativeDatabase(copy));
      addTearDown(db2.close);
      expect((await db2.select(db2.tracks).get()).length, 3);
      expect((await db2.select(db2.playlists).get()).single.name, 'Mix');
    },
  );

  test(
    'settings survive a round trip, without the device-bound keys',
    () async {
      final json =
          jsonDecode(jsonEncode(settingsToJson(prefs))) as Map<String, dynamic>;
      SharedPreferences.setMockInitialValues({'deviceId': 'other'});
      final fresh = await SharedPreferences.getInstance();
      await applySettingsJson(fresh, {
        ...json,
        'deviceId': {'t': 'string', 'v': 'hacked'},
      });
      expect(fresh.getString('theme'), 'oled');
      expect(fresh.getBool('compactMode'), isTrue);
      expect(fresh.getDouble('playbackSpeed'), 1.25);
      expect(fresh.getStringList('notDuplicates'), ['a', 'b']);
      expect(fresh.getStringList('unsyncedLyrics'), ['2', '5']);
      expect(fresh.getString('deviceId'), 'other');
      expect(fresh.getString('playlistSorts'), '{"12":"title:asc"}');
    },
  );

  /// A library with the same three tracks as [db] and none of its user data.
  Future<AppDatabase> freshLibrary() async {
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    for (var i = 0; i < 3; i++) {
      await fresh
          .into(fresh.tracks)
          .insert(
            TracksCompanion.insert(
              path: '/music/$i.mp3',
              title: 'T$i',
              albumKey: 'k',
              format: 'mp3',
              sizeBytes: 1,
              mtimeMs: 1,
              addedAt: 1,
            ),
          );
    }
    return fresh;
  }

  /// Backup of [db] restored (merged) into [fresh]; [edit] may rewrite the zip's JSON files first.
  Future<void> restoreInto(
    AppDatabase fresh, {
    void Function(Map<String, Map<String, dynamic>> json)? edit,
  }) async {
    final out = p.join(dir.path, 'rt.zip');
    await service().createBackup(out);
    if (edit != null) {
      final zip = ZipDecoder().decodeBytes(File(out).readAsBytesSync());
      final json = {
        for (final n in ['manifest.json', 'user_data.json'])
          n: jsonDecode(
            utf8.decode(zip.findFile(n)!.content as List<int>),
          ) as Map<String, dynamic>,
      };
      edit(json);
      final enc = Archive();
      for (final f in zip.files) {
        final body = json[f.name] != null
            ? utf8.encode(jsonEncode(json[f.name]))
            : f.content as List<int>;
        enc.addFile(ArchiveFile(f.name, body.length, body));
      }
      File(out).writeAsBytesSync(ZipEncoder().encode(enc));
    }
    await mergeBackup(
      File(out),
      fresh,
      Directory(p.join(dir.path, 'restored-covers'))..createSync(),
    );
  }

  Future<void> expectSameUserData(AppDatabase fresh) async {
    final favs = (await fresh.select(fresh.tracks).get())
        .where((t) => t.isFavorite)
        .map((t) => t.path);
    expect(favs, ['/music/0.mp3']);
    final t0 = (await fresh.select(fresh.tracks).get()).firstWhere(
      (t) => t.path == '/music/0.mp3',
    );
    expect((t0.playCount, t0.lastPlayedAt), (5, 99));
    expect(
      (t0.lyricsPlain, t0.lyricsSynced, t0.curiosities),
      ('la la', '[00:01.00]la', 'curious'),
    );
    final pl = await fresh.select(fresh.playlists).getSingle();
    expect(pl.name, 'Mix');
    final items = await fresh.select(fresh.playlistTracks).get();
    expect(
      [for (final i in items) (i.trackId, i.position)],
      [(1, 0), (3, 1), (2, 2)],
    );
  }

  test('hand-typed transliterations travel in settings.json and user_data.json; a backup without them stays valid', () async {
    final out = p.join(dir.path, 'rom.zip');
    // Track 3 has no other user data: the transliteration alone must keep it in.
    await prefs.setString(
      'manualRomanization',
      '{"1":"la la","3":"ra ra"}',
    );
    await service().createBackup(out);
    final zip = ZipDecoder().decodeBytes(File(out).readAsBytesSync());
    Map<String, dynamic> read(String n) =>
        jsonDecode(utf8.decode(zip.findFile(n)!.content as List<int>))
            as Map<String, dynamic>;
    expect(read('settings.json')['manualRomanization'], {
      't': 'string',
      'v': '{"1":"la la","3":"ra ra"}',
    });
    final fresh = await freshLibrary();
    final report = await mergeBackup(
      File(out),
      fresh,
      Directory(p.join(dir.path, 'rom-covers'))..createSync(),
    );
    expect(report.romanizations, {1: 'la la', 3: 'ra ra'});

    // Older backup: no field at all.
    await prefs.remove('manualRomanization');
    await service().createBackup(out);
    final older = await mergeBackup(
      File(out),
      await freshLibrary(),
      Directory(p.join(dir.path, 'rom-covers'))..createSync(),
    );
    expect(older.romanizations, isEmpty);
    expect(older.recognized, greaterThan(0));
  });

  test('a backup in today\'s format restores into a fresh library with the same user data', () async {
    final fresh = await freshLibrary();
    await restoreInto(
      fresh,
      edit: (j) {
        expect(j['manifest.json']!['playlistCount'], 1);
        expect(j['manifest.json']!['trackCount'], 3);
      },
    );
    await expectSameUserData(fresh);
  });

  test('a backup with unknown extra fields (top level and inside entries) restores as if they were absent', () async {
    final fresh = await freshLibrary();
    await restoreInto(
      fresh,
      edit: (j) {
        j['manifest.json']!['future'] = {'x': 1};
        j['user_data.json']!['future'] = [1, 2];
        (j['user_data.json']!['tracks'] as List).first['whatever'] = 7;
        (j['user_data.json']!['playlists'] as List).first['extra'] = 'y';
        ((j['user_data.json']!['playlists'] as List).first['items'] as List)
                .first['more'] =
            true;
      },
    );
    await expectSameUserData(fresh);
  });
}
