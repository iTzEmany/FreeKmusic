import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/library/rules/rule_parser.dart';
import 'package:codecore/services/backup/restore_service.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

// Characterization (phase 87.1): a backup written by the app at schema 14
// (the one before the current 15, so also «the penultimate») still restores
// whole. The fixture holds 4 tracks, the playlist «Mix» ordered Time, Bohemian
// Rhapsody, No One Knows, a smart playlist, a followed artist and some settings.
final _fixture = File('test/fixtures/backup/v14_backup.zip');

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('lb'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('the manifest of a v14 backup is read and accepted by this app', () async {
    final plan = await inspectBackup(_fixture, deviceId: 'old-phone', schemaVersion: kSchemaVersion);
    expect((plan.schemaVersion, plan.trackCount, plan.playlistCount, plan.sameDevice), (14, 4, 1, true));
  });

  test('a full restore of a v14 backup keeps playlists, order, smart rules, followed artists and settings', () async {
    final dbFile = File(p.join(dir.path, 'codecore.sqlite'));
    final staging = Directory(p.join(dir.path, 'restore'));
    SharedPreferences.setMockInitialValues({'deviceId': 'this-device'});
    final prefs = await SharedPreferences.getInstance();
    await stageFullRestore(_fixture, staging);
    expect(
        await applyPendingRestore(
            dbFile: dbFile, staging: staging, prefs: prefs, coversDir: Directory(p.join(dir.path, 'covers')),
            schemaVersion: kSchemaVersion),
        isTrue);

    final db = AppDatabase(NativeDatabase(dbFile)); // opening it runs the 14 -> current migration
    addTearDown(db.close);
    expect((await db.customSelect('PRAGMA user_version').getSingle()).data.values.first, kSchemaVersion);

    final playlist = (await db.select(db.playlists).getSingle());
    expect(playlist.name, 'Mix');
    final rows = await (db.select(db.playlistTracks)..orderBy([(r) => OrderingTerm.asc(r.position)])).get();
    final titles = [for (final r in rows) (await (db.select(db.tracks)..where((t) => t.id.equals(r.trackId))).getSingle()).title];
    expect(titles, ['Time', 'Bohemian Rhapsody', 'No One Knows']);

    final smart = await db.select(db.smartPlaylists).getSingle();
    expect((smart.name, smart.rules, smart.sort, smart.limitCount), ('Regina', 'artista:Queen anno>1970', 'title', 10));
    expect((await db.select(db.followedArtists).getSingle()).ytmId, 'UCqueen');
    // D-397: the stored rule still selects the same tracks (Queen and Queens of the Stone Age, after 1970).
    final selected = await TrackRepository(db).watchByRules(parseRules(smart.rules).expr).first;
    expect(selected.map((t) => t.title), unorderedEquals(['Bohemian Rhapsody', 'No One Knows']));

    expect(prefs.getString('theme'), 'oled');
    expect(prefs.getInt('crossfadeSeconds'), 4);
    expect(prefs.getDouble('shuffleKeepRatio'), 0.5);
    expect(prefs.getStringList('jamNames'), ['Anna', 'Luca']);
    expect(prefs.getBool('smartAdd'), isTrue);
    expect(prefs.getString('deviceId'), 'this-device', reason: 'device-bound keys are never restored');
  });

  test('GAP today: a staged database newer than this app is NOT refused by applyPendingRestore', () async {
    final dbFile = File(p.join(dir.path, 'codecore.sqlite'))..writeAsStringSync('current');
    final staging = Directory(p.join(dir.path, 'restore'));
    SharedPreferences.setMockInitialValues({'deviceId': 'this-device'});
    final prefs = await SharedPreferences.getInstance();
    await stageFullRestore(_fixture, staging);
    final raw = sqlite.sqlite3.open(p.join(staging.path, 'codecore.sqlite'));
    raw.execute('PRAGMA user_version = ${kSchemaVersion + 1}');
    raw.close();
    expect(
        await applyPendingRestore(
            dbFile: dbFile, staging: staging, prefs: prefs, coversDir: Directory(p.join(dir.path, 'covers')),
            schemaVersion: kSchemaVersion),
        isTrue);
    // _checkStagedDatabase opens it through AppDatabase, and drift rewrites user_version to the
    // current one (onUpgrade also runs on a downgrade) before the check reads it. Only the manifest
    // gate below works. Flips if the check reads the version before opening with drift.
    expect(prefs.getString('theme'), 'oled');
  });

  test('a manifest from a newer schema is refused', () async {
    final a = Archive()
      ..addFile(ArchiveFile.bytes(
          'manifest.json', utf8.encode(jsonEncode({'backupFormat': 1, 'schemaVersion': kSchemaVersion + 1}))));
    final zip = File(p.join(dir.path, 'newer.zip'))..writeAsBytesSync(ZipEncoder().encode(a));
    await expectLater(inspectBackup(zip, deviceId: 'x', schemaVersion: kSchemaVersion), throwsA(isA<RestoreException>()));
  });
}
