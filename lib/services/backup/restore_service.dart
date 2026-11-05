import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/backup_merge.dart';
import '../../data/repositories/playlist_sync_repository.dart';
import 'user_data.dart';
import '../../data/settings/settings_store.dart' show recogPassAfterKey, recogPassDoneKey;
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
const _readyMarker = 'ready';

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
      m = jsonDecode(utf8.decode(entry.content as List<int>)) as Map<String, dynamic>;
    } finally {
      await input.close();
    }
  } on RestoreException {
    rethrow;
  } on Object catch (e) {
    throw RestoreException('not a Codecore backup: $e');
  }
  final format = (m['backupFormat'] as num?)?.toInt() ?? 0;
  if (format < 1 || format > kBackupFormat) throw RestoreException('backupFormat $format not supported');
  final schema = (m['schemaVersion'] as num?)?.toInt() ?? 0;
  if (schema > schemaVersion) throw RestoreException('backup from a newer app (schema $schema)');
  final exists = folderExists ?? (f) => Directory(f).existsSync();
  final folders = [for (final f in (m['folders'] as List? ?? const [])) '$f'];
  return RestorePlan(
    createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
    appVersion: '${m['appVersion'] ?? ''}',
    platform: '${m['platform'] ?? ''}',
    schemaVersion: schema,
    trackCount: (m['trackCount'] as num?)?.toInt() ?? 0,
    playlistCount: (m['playlistCount'] as num?)?.toInt() ?? 0,
    sameDevice: m['deviceId'] == deviceId || (folders.isNotEmpty && folders.every(exists)),
  );
}

/// Extracts only the three things a full restore needs into [staging]; the
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
        if (f.name == _stagedDb || f.name == 'settings.json') {
          target = p.join(dest, f.name);
        } else if (f.name.startsWith('covers/') && p.basename(f.name) == f.name.substring(7) && f.name.length > 7) {
          target = p.join(dest, 'covers', p.basename(f.name));
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
}) async {
  final stagedDb = File(p.join(staging.path, _stagedDb));
  if (!File(p.join(staging.path, _readyMarker)).existsSync() || !stagedDb.existsSync()) {
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

    final settings = File(p.join(staging.path, 'settings.json'));
    if (settings.existsSync()) {
      await applySettingsJson(prefs, jsonDecode(settings.readAsStringSync()) as Map<String, dynamic>);
    }
    final covers = Directory(p.join(staging.path, 'covers'));
    if (covers.existsSync()) {
      coversDir.createSync(recursive: true);
      for (final f in covers.listSync().whereType<File>()) {
        final target = File(p.join(coversDir.path, p.basename(f.path)));
        if (!target.existsSync()) f.copySync(target.path);
      }
    }
    _quietDelete(staging);
    AppLog.i('restore applied; the previous database is in ${backup.path}');
    return true;
  } on Object catch (e, st) {
    AppLog.e('restore failed, keeping the current database', e, st);
    if (movedOriginal && !dbFile.existsSync() && backup.existsSync()) backup.renameSync(dbFile.path);
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
  } finally {
    raw.close();
  }
  if (v > schemaVersion) throw RestoreException('the backup database is newer (schema $v)');
  final db = AppDatabase(NativeDatabase(f));
  try {
    final check = await db.customSelect('PRAGMA quick_check').get();
    if (check.length != 1 || check.single.data.values.first != 'ok') {
      throw const RestoreException('the backup database is damaged');
    }
  } finally {
    await db.close();
  }
}

void _quietDelete(Directory d) {
  try {
    d.deleteSync(recursive: true);
  } on FileSystemException catch (e) {
    AppLog.w('could not remove ${d.path}', e);
  }
}

/// «Unisci a questa libreria»: merges the user data of [zip] into [db] (see
/// [mergeUserData]) and copies its covers into [coversDir] without
/// overwriting any. The database file of the backup is not used.
Future<MergeReport> mergeBackup(File zip, AppDatabase db, Directory coversDir) async {
  final input = InputFileStream(zip.path);
  late final UserData data;
  var windows = Platform.isWindows;
  try {
    final archive = ZipDecoder().decodeStream(input);
    final entry = archive.findFile('user_data.json');
    if (entry == null) throw const RestoreException('user_data.json missing');
    data = UserData.fromJson(jsonDecode(utf8.decode(entry.content as List<int>)) as Map<String, dynamic>);
    final manifest = archive.findFile('manifest.json');
    if (manifest != null) {
      final m = jsonDecode(utf8.decode(manifest.content as List<int>)) as Map<String, dynamic>;
      windows = windows || m['platform'] == 'windows';
    }
    coversDir.createSync(recursive: true);
    for (final f in archive.files) {
      if (!f.isFile || !f.name.startsWith('covers/') || f.name.length <= 7) continue;
      final target = File(p.join(coversDir.path, p.basename(f.name)));
      if (!target.existsSync()) target.writeAsBytesSync(f.content as List<int>);
    }
  } on RestoreException {
    rethrow;
  } on FormatException catch (e) {
    throw RestoreException('unreadable backup: ${e.message}');
  } finally {
    await input.close();
  }
  final resolver = await PlaylistSyncRepository(db).resolver(caseInsensitive: windows);
  return mergeUserData(db, data, resolver, coversDir: coversDir);
}
