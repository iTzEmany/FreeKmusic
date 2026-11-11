import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/backup_merge.dart';
import '../../data/repositories/backup_merge_helpers.dart';
import '../../data/repositories/backup_merge_tables.dart';
import '../../data/repositories/playlist_sync_repository.dart';
import '../../ui/theme/custom_theme.dart';
import '../shuffle_plus/dislike_store.dart';
import 'user_data.dart';
import '../../data/settings/settings_store.dart'
    show
        genreRereadAfterKey,
        genreRereadDoneKey,
        handWrittenLyricsKey,
        manualRomanizationKey,
        recogPassAfterKey,
        recogPassDoneKey,
        unsyncedLyricsKey;
import 'backup_service.dart';

class RestoreException implements Exception {
  const RestoreException(this.message);

  final String message;

  @override
  String toString() => 'RestoreException($message)';
}

/// What a backup file says about itself.
class RestorePlan {
  const RestorePlan({
    required this.createdAt,
    required this.appVersion,
    required this.platform,
    required this.schemaVersion,
    required this.trackCount,
    required this.playlistCount,
    required this.sameDevice,
  });

  final int createdAt, schemaVersion, trackCount, playlistCount;
  final String appVersion, platform;

  /// Same `deviceId`, or every folder of the backup exists here: «Sostituisci
  /// tutto» is offered only then.
  final bool sameDevice;
}

const _stagedDb = 'codecore.sqlite';
const _stagedDislikes = 'dislikes.json';
const _readyMarker = 'ready';
const _customThemesKey = 'customThemes';

/// Settings «Unisci» never applies: they hold ids of this database or state
/// of this device's session, which mean nothing (or something wrong) here.
const kMergeSkippedKeys = {
  'playlistSorts', // playlist ids
  unsyncedLyricsKey, // track ids
  manualRomanizationKey, // track ids
  handWrittenLyricsKey, // track ids
  'reviewDismissed', // track ids
  'reviewChecked', // track ids
  'lastQueueIds', // track ids of the saved queue
  'lastQueueUser',
  'lastIndex',
  'lastPositionMs',
  'lastContextKind', // may name a playlist of the other database
  'lastContextName',
  'notDuplicates', // DuplicateGroup keys built on track ids
  'jamAside', // saved queue (track ids) of a Jam in progress on that device
  // Timers of this device's own sessions: a copied one would skip or fire a run here.
  'jamLatencyMs', // audio output latency calibration of this device
  'releasesLastRunAt',
  'exportifyLastSyncAt',
  'exportifyOpenedAt',
  'exportifySnoozeUntil',
};

/// Copies the `theme/` pictures of [archive] into [themeDir] (existing files win).
void _extractThemeImages(Archive archive, Directory themeDir) {
  for (final f in archive.files) {
    final leaf = f.isFile ? zipLeaf(f.name, 'theme/') : null;
    if (leaf == null) continue;
    final target = File(p.join(themeDir.path, leaf));
    if (target.existsSync()) continue;
    themeDir.createSync(recursive: true);
    target.writeAsBytesSync(f.content as List<int>);
  }
}

/// Points each custom theme's picture at the same file name in [themeDir], when
/// it is there: the backup stored the path of the other device.
Future<void> _relinkThemeImages(SharedPreferences prefs, Directory themeDir) async {
  final themes = CustomThemes.decode(prefs.getString(_customThemesKey));
  var out = themes;
  for (final t in themes.items) {
    final path = t.background.imagePath;
    if (path == null) continue;
    final local = p.join(themeDir.path, path.split(RegExp(r'[\\/]')).last);
    if (local != path && File(local).existsSync()) {
      out = out.put(t.copyWith(background: t.background.copyWith(imagePath: local)));
    }
  }
  if (out != themes) await prefs.setString(_customThemesKey, out.encode());
}

/// «Unisci» settings: the backup wins except for device-bound and id-bound keys;
/// custom themes are united by id (the backup's wins on the same id). Returns how many
/// themes did not fit (the list is full); a `theme` setting naming one of them is not applied.
Future<int> _applyMergedSettings(
  SharedPreferences prefs,
  Map<String, dynamic> json,
  Directory? themeDir,
) async {
  final rest = {...json}..removeWhere((k, _) => kMergeSkippedKeys.contains(k));
  var dropped = 0;
  final mine = rest[_customThemesKey];
  if (mine is Map && mine['v'] is String) {
    var themes = CustomThemes.decode(prefs.getString(_customThemesKey));
    for (final t in CustomThemes.decode(mine['v'] as String).items) {
      final next = themes.put(t);
      if (identical(next, themes)) dropped++;
      themes = next;
    }
    rest[_customThemesKey] = {'t': 'string', 'v': themes.encode()};
    final sel = rest['theme'];
    final id = sel is Map && sel['v'] is String ? customThemeIdOf(sel['v'] as String) : null;
    if (id != null && themes.byId(id) == null) rest.remove('theme');
  }
  await applySettingsJson(prefs, rest);
  if (themeDir != null) await _relinkThemeImages(prefs, themeDir);
  return dropped;
}

/// Reads `manifest.json` of [zip] and judges it. Refuses a `backupFormat` this
/// app does not know and a database newer than itself.
Future<RestorePlan> inspectBackup(
  File zip, {
  required String deviceId,
  required int schemaVersion,
  bool Function(String folder)? folderExists,
}) async {
  final Map<String, dynamic> m;
  try {
    final input = InputFileStream(zip.path);
    try {
      final entry = ZipDecoder().decodeStream(input).findFile('manifest.json');
      if (entry == null) throw const RestoreException('manifest.json missing');
      m = jsonDecode(
        utf8.decode(entry.content as List<int>),
      ) as Map<String, dynamic>;
    } finally {
      await input.close();
    }
  } on RestoreException {
    rethrow;
  } on Object catch (e) {
    throw RestoreException('not a FreeKmusic backup: $e');
  }
  final format = (m['backupFormat'] as num?)?.toInt() ?? 0;
  if (format < 1 || format > kBackupFormat) {
    throw RestoreException('backupFormat $format not supported');
  }
  final schema = (m['schemaVersion'] as num?)?.toInt() ?? 0;
  if (schema > schemaVersion) {
    throw RestoreException('backup from a newer app (schema $schema)');
  }
  final exists = folderExists ?? (f) => Directory(f).existsSync();
  final folders = [for (final f in (m['folders'] as List? ?? const [])) '$f'];
  return RestorePlan(
    createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
    appVersion: '${m['appVersion'] ?? ''}',
    platform: '${m['platform'] ?? ''}',
    schemaVersion: schema,
    trackCount: (m['trackCount'] as num?)?.toInt() ?? 0,
    playlistCount: (m['playlistCount'] as num?)?.toInt() ?? 0,
    sameDevice:
        m['deviceId'] == deviceId ||
        (folders.isNotEmpty && folders.every(exists)),
  );
}

/// Extracts only the things a full restore needs into [staging]; the
/// `ready` marker is written last so a half-extracted folder is never applied.
/// Entry names are checked: nothing can leave [staging].
Future<void> stageFullRestore(File zip, Directory staging) async {
  if (staging.existsSync()) staging.deleteSync(recursive: true);
  staging.createSync(recursive: true);
  final zipPath = zip.path, dest = staging.path;
  await Isolate.run(() {
    final input = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      for (final f in archive.files) {
        if (!f.isFile) continue;
        final String? target;
        final theme = zipLeaf(f.name, 'theme/'), cover = zipLeaf(f.name, 'covers/');
        if (theme != null) {
          target = p.join(dest, 'theme', theme);
        } else if (f.name == _stagedDb ||
            f.name == 'settings.json' ||
            f.name == _stagedDislikes) {
          target = p.join(dest, f.name);
        } else if (cover != null) {
          target = p.join(dest, 'covers', cover);
        } else {
          target = null;
        }
        if (target == null) continue;
        Directory(p.dirname(target)).createSync(recursive: true);
        File(target).writeAsBytesSync(f.content as List<int>);
      }
    } finally {
      input.closeSync();
    }
  });
  if (!File(p.join(dest, _stagedDb)).existsSync()) {
    staging.deleteSync(recursive: true);
    throw const RestoreException('the backup has no database');
  }
  File(p.join(dest, _readyMarker)).writeAsStringSync('1');
}

/// Run at start-up **before** the database is opened. If a staged restore is
/// waiting: the current database is renamed `*.before-restore` (never
/// deleted), the staged one takes its place, settings are applied and covers
/// are merged (existing files win). Any error leaves the original database
/// where it was. Returns true if a restore was applied.
Future<bool> applyPendingRestore({
  required File dbFile,
  required Directory staging,
  required SharedPreferences prefs,
  required Directory coversDir,
  required int schemaVersion,
  Directory? themeDir,
  File? dislikesFile,
  File? daylistFile,
  File? romanizationCacheFile,
}) async {
  final stagedDb = File(p.join(staging.path, _stagedDb));
  if (!File(p.join(staging.path, _readyMarker)).existsSync() ||
      !stagedDb.existsSync()) {
    if (staging.existsSync()) _quietDelete(staging); // half-extracted leftovers
    return false;
  }
  final backup = File('${dbFile.path}.before-restore');
  var movedOriginal = false;
  try {
    await _checkStagedDatabase(stagedDb, schemaVersion);
    if (backup.existsSync()) backup.deleteSync();
    if (dbFile.existsSync()) {
      dbFile.renameSync(backup.path);
      movedOriginal = true;
    }
    for (final ext in ['-wal', '-shm']) {
      final side = File('${dbFile.path}$ext');
      if (side.existsSync()) side.deleteSync();
    }
    stagedDb.renameSync(dbFile.path);
    // The restored rows may be older: the recognition pass must run again.
    await prefs.remove(recogPassAfterKey);
    await prefs.remove(recogPassDoneKey);
    // Same for the genre re-read: the restored database may lack track_genres rows.
    await prefs.remove(genreRereadAfterKey);
    await prefs.remove(genreRereadDoneKey);
    // Playlist ids belong to the replaced database: an older backup without
    // the key must not leave sorts pointing at other playlists (D-424).
    await prefs.remove('playlistSorts');
    // Track ids too: the set belongs to the replaced database (D-472).
    await prefs.remove(unsyncedLyricsKey);
    await prefs.remove(manualRomanizationKey);
    await prefs.remove(handWrittenLyricsKey);

    final settings = File(p.join(staging.path, 'settings.json'));
    if (settings.existsSync()) {
      await applySettingsJson(
        prefs,
        jsonDecode(settings.readAsStringSync()) as Map<String, dynamic>,
      );
    }
    // «Non mi piace» choices replace the current ones; a backup without the
    // file (older than fase 101) leaves them as they are, like downloads.json.
    final dislikes = File(p.join(staging.path, _stagedDislikes));
    if (dislikesFile != null && dislikes.existsSync()) {
      dislikesFile.parent.createSync(recursive: true);
      final tmp = dislikes.copySync('${dislikesFile.path}.tmp');
      tmp.renameSync(dislikesFile.path);
    }
    // It holds ids of the replaced database's tracks (a wrong list otherwise).
    if (daylistFile != null && daylistFile.existsSync()) {
      try {
        daylistFile.deleteSync();
      } on FileSystemException catch (e, st) {
        AppLog.w('daylist file not removed', e, st);
      }
    }
    // Keyed by track id, and ids are reassigned by the restored database.
    if (romanizationCacheFile != null && romanizationCacheFile.existsSync()) {
      try {
        romanizationCacheFile.deleteSync();
      } on FileSystemException catch (e, st) {
        AppLog.w('romanization cache not removed', e, st);
      }
    }
    final covers = Directory(p.join(staging.path, 'covers'));
    if (covers.existsSync()) {
      coversDir.createSync(recursive: true);
      for (final f in covers.listSync().whereType<File>()) {
        final target = File(p.join(coversDir.path, p.basename(f.path)));
        if (!target.existsSync()) f.copySync(target.path);
      }
    }
    final themes = Directory(p.join(staging.path, 'theme'));
    if (themeDir != null) {
      if (themes.existsSync()) {
        themeDir.createSync(recursive: true);
        for (final f in themes.listSync().whereType<File>()) {
          final target = File(p.join(themeDir.path, p.basename(f.path)));
          if (!target.existsSync()) f.copySync(target.path);
        }
      }
      await _relinkThemeImages(prefs, themeDir);
    }
    _quietDelete(staging);
    AppLog.i('restore applied; the previous database is in ${backup.path}');
    return true;
  } on Object catch (e, st) {
    AppLog.e('restore failed, keeping the current database', e, st);
    if (movedOriginal && !dbFile.existsSync() && backup.existsSync()) {
      backup.renameSync(dbFile.path);
    }
    _quietDelete(staging);
    return false;
  }
}

/// Opens the staged copy and asks SQLite whether it is sound and not newer
/// than this app.
Future<void> _checkStagedDatabase(File f, int schemaVersion) async {
  // Read the version with plain sqlite first: drift's onUpgrade rewrites user_version on open.
  final raw = sqlite.sqlite3.open(f.path, mode: sqlite.OpenMode.readOnly);
  final int v;
  try {
    v = raw.select('PRAGMA user_version').single.values.first as int;
    // Before drift opens the file and runs migrations on a damaged one.
    final check = raw.select('PRAGMA quick_check');
    if (check.length != 1 || check.single.values.first != 'ok') {
      throw const RestoreException('the backup database is damaged');
    }
  } finally {
    raw.close();
  }
  if (v > schemaVersion) {
    throw RestoreException('the backup database is newer (schema $v)');
  }
}

void _quietDelete(Directory d) {
  try {
    d.deleteSync(recursive: true);
  } on FileSystemException catch (e) {
    AppLog.w('could not remove ${d.path}', e);
  }
}

/// What [mergeBackup] reads out of the zip: the JSON texts and the extracted database.
typedef _MergeInput = ({String userData, String? manifest, String? dislikes, String? settings, bool hasDb});

/// Unpacks the zip off the UI isolate (a separate function so the closure holds only these strings): the database goes to [tmp], theme pictures
/// and covers to their folders (existing files win); the small JSON files come back as text.
_MergeInput _extractForMerge(String zipPath, String tmp, String? themeDir, String coversDir, bool wantSettings) {
  final input = InputFileStream(zipPath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    String? text(String name) {
      final e = archive.findFile(name);
      return e == null ? null : utf8.decode(e.content as List<int>);
    }

    final userData = text('user_data.json');
    if (userData == null) throw const RestoreException('user_data.json missing');
    final db = archive.findFile(_stagedDb);
    if (db != null) File(p.join(tmp, _stagedDb)).writeAsBytesSync(db.content as List<int>);
    if (themeDir != null) _extractThemeImages(archive, Directory(themeDir));
    Directory(coversDir).createSync(recursive: true);
    for (final f in archive.files) {
      final leaf = f.isFile ? zipLeaf(f.name, 'covers/') : null;
      if (leaf == null) continue;
      final target = File(p.join(coversDir, leaf));
      if (!target.existsSync()) target.writeAsBytesSync(f.content as List<int>);
    }
    return (
      userData: userData,
      manifest: text('manifest.json'),
      dislikes: text(_stagedDislikes),
      settings: wantSettings ? text('settings.json') : null,
      hasDb: db != null,
    );
  } finally {
    input.closeSync();
  }
}

Future<_MergeInput> _extractOffThread(String zip, String tmp, String? theme, String covers, bool settings) =>
    Isolate.run(() => _extractForMerge(zip, tmp, theme, covers, settings));

/// «Unisci a questa libreria»: merges the user data of [zip] into [db] (see
/// [mergeUserData]) and copies its covers into [coversDir] without
/// overwriting any. The backup's database is read for history, tags, smart
/// playlists and podcasts. With [prefs] the backup's settings are applied too
/// (see [kMergeSkippedKeys]).
Future<MergeReport> mergeBackup(
  File zip,
  AppDatabase db,
  Directory coversDir, {
  DislikeStore? dislikes,
  SharedPreferences? prefs,
  Directory? themeDir,
}) async {
  final tmp = Directory.systemTemp.createTempSync('merge');
  try {
    final tmpPath = tmp.path;
    final x = await _extractOffThread(zip.path, tmpPath, themeDir?.path, coversDir.path, prefs != null);
    final data = UserData.fromJson(jsonDecode(x.userData) as Map<String, dynamic>);
    var windows = Platform.isWindows;
    if (x.manifest != null) {
      windows = windows || (jsonDecode(x.manifest!) as Map<String, dynamic>)['platform'] == 'windows';
    }
    // «Non mi piace» blocks are added to the current ones (union).
    if (dislikes != null && x.dislikes != null) {
      try {
        await dislikes.load();
        dislikes.mergeJson(jsonDecode(x.dislikes!));
      } on Object catch (e, st) {
        AppLog.w('dislikes.json of the backup unreadable, blocks skipped', e, st);
      }
    }
    Map<String, dynamic>? settings;
    if (x.settings != null) {
      try {
        settings = jsonDecode(x.settings!) as Map<String, dynamic>;
      } on Object catch (e, s) {
        AppLog.w('settings.json of the backup unreadable, settings skipped', e, s);
      }
    }
    final resolver = await PlaylistSyncRepository(db).resolver(caseInsensitive: windows);
    final staged = x.hasDb ? File(p.join(tmpPath, _stagedDb)) : null;
    // One transaction: user data first (it creates the shadow rows of playlists).
    final report = await db.transaction(() async {
      final r = await mergeUserData(db, data, resolver, coversDir: coversDir);
      if (staged != null) {
        r.tables = await mergeBackupTables(db, staged, resolver, coversDir: coversDir);
      }
      return r;
    });
    if (prefs != null && settings != null) {
      report.themesDropped = await _applyMergedSettings(prefs, settings, themeDir);
    }
    return report;
  } on FormatException catch (e) {
    throw RestoreException('unreadable backup: ${e.message}');
  } finally {
    _quietDelete(tmp);
  }
}
