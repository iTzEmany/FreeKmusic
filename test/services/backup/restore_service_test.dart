import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/backup/backup_service.dart';
import 'package:codecore/services/backup/restore_service.dart';
import 'package:codecore/services/shuffle_plus/dislike_store.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory dir;
  const schema = kSchemaVersion;

  setUp(() => dir = Directory.systemTemp.createTempSync('rs'));
  tearDown(() => dir.deleteSync(recursive: true));

  // Every database starts in memory: creating the schema on disk costs a sync
  // per statement, which took tens of seconds on a busy disk. `VACUUM INTO`
  // (what the backup itself uses) writes a file in one go when one is needed.

  /// A real backup of a database with [titles] as tracks and [folders] as
  /// music folders.
  Future<File> makeBackup(List<String> titles,
      {String deviceId = 'dev-A', List<String> folders = const [], Future<void> Function(AppDatabase)? seed, File? dislikes, Map<String, Object> extraPrefs = const {}}) async {
    final db = AppDatabase(NativeDatabase.memory());
    for (final f in folders) {
      await db.into(db.folders).insert(FoldersCompanion.insert(path: f, addedAt: 1));
    }
    for (final t in titles) {
      await db.into(db.tracks).insert(TracksCompanion.insert(
          path: '/m/$t.mp3', title: t, albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1));
    }
    await seed?.call(db);
    SharedPreferences.setMockInitialValues(
        {'theme': 'oled', 'deviceId': deviceId, 'genreRereadAfter': 7, 'genreRereadDone': 1, ...extraPrefs});
    final prefs = await SharedPreferences.getInstance();
    final covers = Directory(p.join(dir.path, 'src-covers'))..createSync();
    File(p.join(covers.path, 'new.jpg')).writeAsBytesSync([1, 2, 3]);
    File(p.join(covers.path, 'both.jpg')).writeAsBytesSync([9, 9]);
    final out = File(p.join(dir.path, 'b-${titles.length}.zip'));
    await BackupService(
      db: db, prefs: prefs, coversDir: covers, downloadsFile: File(p.join(dir.path, 'none.json')), dislikesFile: dislikes, deviceId: deviceId,
    ).createBackup(out.path);
    await db.close();
    return out;
  }

  group('inspectBackup', () {
    test('reads the manifest; same device by id, or by folders that all exist', () async {
      final zip = await makeBackup(['a', 'b']);
      var plan = await inspectBackup(zip, deviceId: 'dev-A', schemaVersion: schema);
      expect(plan.sameDevice, isTrue);
      expect(plan.trackCount, 2);
      expect(plan.platform, isNotEmpty);

      plan = await inspectBackup(zip, deviceId: 'dev-B', schemaVersion: schema, folderExists: (_) => true);
      expect(plan.sameDevice, isFalse, reason: 'this backup has no folders (none in its DB)');

      final withFolders = await makeBackup(['a'], folders: const ['/music', '/more']);
      plan = await inspectBackup(withFolders, deviceId: 'dev-B', schemaVersion: schema, folderExists: (_) => true);
      expect(plan.sameDevice, isTrue, reason: 'every folder of the backup exists here');
      plan = await inspectBackup(withFolders, deviceId: 'dev-B', schemaVersion: schema, folderExists: (f) => f == '/music');
      expect(plan.sameDevice, isFalse, reason: 'one folder is missing');
    });

    test('a newer schema or an unknown format is refused; a non-backup too', () async {
      Future<File> forged(Map<String, Object?> manifest) async {
        final enc = ZipEncoder();
        final a = Archive()..addFile(ArchiveFile.bytes('manifest.json', utf8.encode(jsonEncode(manifest))));
        final f = File(p.join(dir.path, 'forged-${manifest.hashCode}.zip'))..writeAsBytesSync(enc.encode(a));
        return f;
      }

      await expectLater(
          inspectBackup(await forged({'backupFormat': 1, 'schemaVersion': 99}), deviceId: 'x', schemaVersion: schema),
          throwsA(isA<RestoreException>()));
      await expectLater(
          inspectBackup(await forged({'backupFormat': 7, 'schemaVersion': 1}), deviceId: 'x', schemaVersion: schema),
          throwsA(isA<RestoreException>()));
      final junk = File(p.join(dir.path, 'junk.zip'))..writeAsStringSync('not a zip');
      await expectLater(inspectBackup(junk, deviceId: 'x', schemaVersion: schema), throwsA(isA<RestoreException>()));
    });
  });

  group('stage and apply', () {
    late File dbFile;
    late Directory staging, covers;
    late SharedPreferences prefs;

    setUp(() async {
      dbFile = File(p.join(dir.path, 'codecore.sqlite'));
      staging = Directory(p.join(dir.path, 'restore'));
      covers = Directory(p.join(dir.path, 'covers'))..createSync();
      File(p.join(covers.path, 'both.jpg')).writeAsBytesSync([5]);
      SharedPreferences.setMockInitialValues({'theme': 'light', 'deviceId': 'this-device'});
      prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      await db.into(db.tracks).insert(TracksCompanion.insert(
          path: '/m/old.mp3', title: 'old', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1));
      await db.customStatement('VACUUM INTO ?', [dbFile.path]);
      await db.close();
    });

    Future<List<String>> titles(File f) async {
      final db = AppDatabase(NativeDatabase(f));
      final t = [for (final r in await db.select(db.tracks).get()) r.title];
      await db.close();
      return t;
    }

    Future<bool> apply() => applyPendingRestore(
        dbFile: dbFile, staging: staging, prefs: prefs, coversDir: covers, schemaVersion: schema);

    test('the database is replaced, the old one kept, settings applied, covers merged without overwriting, staging removed', () async {
      await stageFullRestore(await makeBackup(['n1', 'n2']), staging);
      expect(await apply(), isTrue);
      expect(await titles(dbFile), unorderedEquals(['n1', 'n2']));
      expect(await titles(File('${dbFile.path}.before-restore')), ['old']);
      expect(prefs.getString('theme'), 'oled');
      expect(prefs.getString('deviceId'), 'this-device', reason: 'never taken from a backup');
      expect(File(p.join(covers.path, 'new.jpg')).existsSync(), isTrue);
      expect(File(p.join(covers.path, 'both.jpg')).readAsBytesSync(), [5], reason: 'the existing cover wins');
      expect(staging.existsSync(), isFalse);
    });

    test('unsyncedLyrics is dropped with the replaced database: a backup without it leaves none, one with it wins', () async {
      await prefs.setStringList('unsyncedLyrics', ['9']);
      await stageFullRestore(await makeBackup(['n1']), staging);
      expect(await apply(), isTrue);
      expect(prefs.containsKey('unsyncedLyrics'), isFalse);
      await prefs.setStringList('unsyncedLyrics', ['9']);
      await stageFullRestore(await makeBackup(['n1', 'n2'], extraPrefs: {'unsyncedLyrics': ['2']}), staging);
      expect(await apply(), isTrue);
      expect(prefs.getStringList('unsyncedLyrics'), ['2']);
    });

    test('dislikes.json travels in the backup and replaces the current one', () async {
      final src = File(p.join(dir.path, 'src-dislikes.json'))..writeAsStringSync('{"tracks":[{"id":"x"}]}');
      final live = File(p.join(dir.path, 'live', 'dislikes.json'))
        ..createSync(recursive: true)
        ..writeAsStringSync('{"tracks":[]}');
      await stageFullRestore(await makeBackup(['n1'], dislikes: src), staging);
      expect(await applyPendingRestore(
          dbFile: dbFile, staging: staging, prefs: prefs, coversDir: covers, schemaVersion: schema, dislikesFile: live),
          isTrue);
      expect(live.readAsStringSync(), '{"tracks":[{"id":"x"}]}');
    });

    test('a backup without dislikes.json leaves the current choices alone', () async {
      final live = File(p.join(dir.path, 'live', 'dislikes.json'))
        ..createSync(recursive: true)
        ..writeAsStringSync('keep');
      await stageFullRestore(await makeBackup(['n1']), staging);
      expect(await applyPendingRestore(
          dbFile: dbFile, staging: staging, prefs: prefs, coversDir: covers, schemaVersion: schema, dislikesFile: live),
          isTrue);
      expect(live.readAsStringSync(), 'keep');
    });

    test('merging adds the blocks of dislikes.json to the current ones', () async {
      final src = File(p.join(dir.path, 'src-dislikes.json'))
        ..writeAsStringSync(
          '{"tracks":[{"id":"b","title":"B","artist":"x"}],"artists":[{"key":"k","name":"K"}]}',
        );
      final zip = await makeBackup(['n1'], dislikes: src);
      final live = File(p.join(dir.path, 'live-dislikes.json'));
      final store = DislikeStore(file: () async => live, writeDelay: Duration.zero);
      await store.load();
      store.blockTrack(const DislikedTrack(videoId: 'a', title: 'A', artist: 'x'));
      final here = AppDatabase(NativeDatabase.memory());
      addTearDown(here.close);
      await mergeBackup(zip, here, Directory(p.join(dir.path, 'm-covers')), dislikes: store);
      expect([for (final t in store.tracks) t.videoId], unorderedEquals(['a', 'b']));
      expect(store.artistBlocked('k'), isTrue);
    });

    test('an unreadable dislikes.json in the zip does not fail the merge', () async {
      final src = File(p.join(dir.path, 'src-bad.json'))..writeAsStringSync('{nope');
      final zip = await makeBackup(['n1'], dislikes: src);
      final store = DislikeStore(file: () async => File(p.join(dir.path, 'l2.json')), writeDelay: Duration.zero);
      final here = AppDatabase(NativeDatabase.memory());
      addTearDown(here.close);
      await mergeBackup(zip, here, Directory(p.join(dir.path, 'm-covers2')), dislikes: store);
      expect(store.tracks, isEmpty);
    });

    test('the recognition pass bookmarks are cleared: the restored rows may be older', () async {
      await prefs.setInt('recogPassDone', 2);
      await prefs.setString('recogPassAfter', '2:50');
      await stageFullRestore(await makeBackup(['n1']), staging);
      expect(await apply(), isTrue);
      expect([prefs.containsKey('recogPassDone'), prefs.containsKey('recogPassAfter')], [false, false]);
    });

    test('track_genres and artist_countries come back with the database; the re-read bookmarks do not travel and are cleared', () async {
      await prefs.setInt('genreRereadDone', 1);
      await prefs.setInt('genreRereadAfter', 99);
      final zip = await makeBackup(['n1'], seed: (db) async {
        await db.into(db.trackGenres).insert(TrackGenresCompanion.insert(trackId: 1, genre: 'Rock', position: 0));
        await db.into(db.trackGenres).insert(TrackGenresCompanion.insert(trackId: 1, genre: 'Pop', position: 1));
        await db.into(db.artistCountries).insert(ArtistCountriesCompanion.insert(
            artistKey: 'queen', country: const Value('GB'), source: const Value('musicbrainz'), checkedAt: 5));
      });
      final settings = ZipDecoder().decodeBytes(zip.readAsBytesSync()).findFile('settings.json')!;
      final json = jsonDecode(utf8.decode(settings.content as List<int>)) as Map<String, dynamic>;
      expect(json.keys, isNot(anyOf(contains('genreRereadAfter'), contains('genreRereadDone'))));
      await stageFullRestore(zip, staging);
      expect(await apply(), isTrue);
      expect([prefs.containsKey('genreRereadAfter'), prefs.containsKey('genreRereadDone')], [false, false]);
      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);
      expect([for (final g in await db.select(db.trackGenres).get()) g.genre], ['Rock', 'Pop']);
      expect((await db.select(db.artistCountries).getSingle()).country, 'GB');
    });

    test('artist_aliases and artist_not_same come back with the database', () async {
      final zip = await makeBackup(['n1'], seed: (db) async {
        await db.into(db.artistAliases).insert(ArtistAliasesCompanion.insert(aliasId: 'UC2', mainId: 'UC1'));
        await db.into(db.artistNotSame).insert(ArtistNotSameCompanion.insert(a: 'UC1', b: 'UC3'));
      });
      await stageFullRestore(zip, staging);
      expect(await apply(), isTrue);
      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);
      expect((await db.select(db.artistAliases).getSingle()).mainId, 'UC1');
      expect((await db.select(db.artistNotSame).getSingle()).b, 'UC3');
    });

    test('podcasts come back with their source: YouTube Music and RSS (D-404)', () async {
      final zip = await makeBackup(['n1'], seed: (db) async {
        await db.into(db.podcasts).insert(PodcastsCompanion.insert(
            feedUrl: 'https://music.youtube.com/browse/MPSPPx', title: 'Show', addedAt: 1,
            source: const Value(1), sourceId: const Value('MPSPPx')));
        await db.into(db.podcasts).insert(PodcastsCompanion.insert(feedUrl: 'https://x/feed', title: 'Feed', addedAt: 2));
      });
      await stageFullRestore(zip, staging);
      expect(await apply(), isTrue);
      final db = AppDatabase(NativeDatabase(dbFile));
      addTearDown(db.close);
      final rows = await db.select(db.podcasts).get();
      expect([for (final r in rows) (r.title, r.source, r.sourceId)], [('Show', 1, 'MPSPPx'), ('Feed', 0, null)]);
    });

    test('a v14 backup is accepted and upgraded to the current schema', () async {
      final old = AppDatabase(NativeDatabase.memory());
      await old.into(old.tracks).insert(TracksCompanion.insert(
          path: '/m/v14.mp3', title: 'v14', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1));
      for (final t in ['track_credits', 'track_enrich', 'activity_log', 'track_genres', 'artist_countries']) {
        await old.customStatement('DROP TABLE $t');
      }
      await old.customStatement('ALTER TABLE tracks DROP COLUMN cover_source');
      await old.customStatement('PRAGMA user_version = 14');
      staging.createSync(recursive: true);
      await old.customStatement('VACUUM INTO ?', [p.join(staging.path, 'codecore.sqlite')]);
      await old.close();
      File(p.join(staging.path, 'ready')).writeAsStringSync('1');
      expect(await apply(), isTrue);
      expect(await titles(dbFile), ['v14']);
    });

    test('nothing staged: nothing happens', () async {
      expect(await apply(), isFalse);
      expect(await titles(dbFile), ['old']);
    });

    test('a half-extracted staging (no ready marker) is dropped and the database is untouched', () async {
      staging.createSync(recursive: true);
      File(p.join(staging.path, 'codecore.sqlite')).writeAsBytesSync([1, 2, 3]);
      expect(await apply(), isFalse);
      expect(await titles(dbFile), ['old']);
      expect(staging.existsSync(), isFalse);
    });

    test('a damaged staged database leaves the original database in place', () async {
      staging.createSync(recursive: true);
      File(p.join(staging.path, 'codecore.sqlite')).writeAsStringSync('this is not sqlite ' * 50);
      File(p.join(staging.path, 'ready')).writeAsStringSync('1');
      expect(await apply(), isFalse);
      expect(await titles(dbFile), ['old']);
      expect(File('${dbFile.path}.before-restore').existsSync(), isFalse);
      expect(prefs.getString('theme'), 'light');
    });

    test('a staged database with a corrupt page (readable header) leaves the original in place', () async {
      staging.createSync(recursive: true);
      final staged = File(p.join(staging.path, 'codecore.sqlite'));
      final raw = sqlite3.open(staged.path);
      raw.execute('PRAGMA page_size = 4096; CREATE TABLE t(x TEXT); PRAGMA user_version = 1;');
      for (var i = 0; i < 300; i++) {
        raw.execute("INSERT INTO t VALUES ('${'row $i ' * 20}')");
      }
      raw.close();
      final bytes = staged.readAsBytesSync();
      expect(bytes.length, greaterThan(8192));
      for (var i = 4096; i < 8192; i++) {
        bytes[i] = 0xAB;
      }
      staged.writeAsBytesSync(bytes);
      File(p.join(staging.path, 'ready')).writeAsStringSync('1');
      expect(await apply(), isFalse);
      expect(await titles(dbFile), ['old']);
    });

    test('a zip without a database cannot be staged; unexpected entries are never extracted', () async {
      final a = Archive()
        ..addFile(ArchiveFile.bytes('manifest.json', [1]))
        ..addFile(ArchiveFile.bytes('../evil.txt', [1]));
      final zip = File(p.join(dir.path, 'nodb.zip'))..writeAsBytesSync(ZipEncoder().encode(a));
      await expectLater(stageFullRestore(zip, staging), throwsA(isA<RestoreException>()));
      expect(File(p.join(dir.path, 'evil.txt')).existsSync(), isFalse);
    });
  });

  test('mergeBackup merges the user data and copies covers without overwriting', () async {
    final src = AppDatabase(NativeDatabase.memory());
    await src.into(src.tracks).insert(TracksCompanion.insert(
        path: '/m/x.mp3', title: 'x', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1,
        isFavorite: const Value(true)));
    SharedPreferences.setMockInitialValues({'deviceId': 'A'});
    final covers = Directory(p.join(dir.path, 'm-covers'))..createSync();
    File(p.join(covers.path, 'c1.jpg')).writeAsBytesSync([1]);
    final zip = File(p.join(dir.path, 'm.zip'));
    await BackupService(
      db: src, prefs: await SharedPreferences.getInstance(), coversDir: covers,
      downloadsFile: File(p.join(dir.path, 'none.json')), deviceId: 'A',
    ).createBackup(zip.path);
    await src.close();

    final here = AppDatabase(NativeDatabase.memory());
    addTearDown(here.close);
    await here.into(here.tracks).insert(TracksCompanion.insert(
        path: '/other/x.mp3', title: 'x', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1));
    final dest = Directory(p.join(dir.path, 'm-dest'))..createSync();
    File(p.join(dest.path, 'c1.jpg')).writeAsBytesSync([7]);
    final report = await mergeBackup(zip, here, dest);
    expect(report.recognized, 1, reason: 'same title, no artist, no duration');
    expect((await here.select(here.tracks).getSingle()).isFavorite, isTrue);
    expect(File(p.join(dest.path, 'c1.jpg')).readAsBytesSync(), [7]);
  });

  test('mergeBackup puts back hand-set covers (track and album) with their files; a track with its own hand cover keeps it', () async {
    final src = AppDatabase(NativeDatabase.memory());
    Future<void> add(AppDatabase d, String t, {int source = 0, String? key}) =>
        d.into(d.tracks).insert(TracksCompanion.insert(
            path: '/m/$t.mp3', title: t, albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1,
            coverSource: Value(source), coverKey: Value(key)));
    await add(src, 'one', source: 2, key: 'manual_one');
    await add(src, 'two', source: 1, key: 'manual_alb');
    await add(src, 'three', source: 2, key: 'manual_theirs');
    await add(src, 'auto', key: 'auto_k');
    SharedPreferences.setMockInitialValues({'deviceId': 'A'});
    final covers = Directory(p.join(dir.path, 'h-covers'))..createSync();
    for (final k in ['manual_one', 'manual_alb', 'manual_theirs', 'auto_k']) {
      File(p.join(covers.path, '$k.jpg')).writeAsBytesSync(k.codeUnits);
    }
    final zip = File(p.join(dir.path, 'h.zip'));
    await BackupService(
      db: src, prefs: await SharedPreferences.getInstance(), coversDir: covers,
      downloadsFile: File(p.join(dir.path, 'none.json')), deviceId: 'A',
    ).createBackup(zip.path);
    await src.close();

    final here = AppDatabase(NativeDatabase.memory());
    addTearDown(here.close);
    for (final t in ['one', 'two', 'auto']) {
      await add(here, t);
    }
    await add(here, 'three', source: 2, key: 'manual_mine');
    final dest = Directory(p.join(dir.path, 'h-dest'));
    await mergeBackup(zip, here, dest);
    final rows = {for (final t in await here.select(here.tracks).get()) t.title: (t.coverSource, t.coverKey)};
    expect(rows['one'], (2, 'manual_one'));
    expect(rows['two'], (1, 'manual_alb'));
    expect(rows['three'], (2, 'manual_mine'), reason: 'its own hand cover stays');
    expect(rows['auto'], (0, null), reason: 'automatic covers are not carried by the merge');
    expect(File(p.join(dest.path, 'manual_one.jpg')).readAsBytesSync(), 'manual_one'.codeUnits);
  });
}
