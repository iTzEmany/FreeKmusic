import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_info.dart';
import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/backup_queries.dart';
import '../../data/repositories/track_kinds.dart';
import '../../data/settings/jam_secret_store.dart';
import '../../data/settings/settings_store.dart'
    show
        SettingsStore,
        enrichMarkKey,
        genreRereadAfterKey,
        genreRereadDoneKey,
        recogPassAfterKey,
        recogPassDoneKey;

const kBackupFormat = 1;

/// Settings that belong to this device and never travel in a backup.
const kDeviceBoundKeys = {
  'deviceId',
  'deviceName',
  'trustedDevices',
  jamBlockedKey,
  jamSuspendedKey,
  jamFriendsKey,
  jamAnnounceKeyKey,
  enrichMarkKey,
  recogPassAfterKey,
  recogPassDoneKey,
  genreRereadAfterKey,
  genreRereadDoneKey,
};

class BackupSummary {
  const BackupSummary({
    required this.path,
    required this.bytes,
    required this.tracks,
    required this.playlists,
    required this.covers,
  });

  final String path;
  final int bytes, tracks, playlists, covers;
}

/// `settings.json`: every preference but the device-bound ones, with its type
/// kept (`{"key": {"t": "bool", "v": true}}`).
Map<String, Object?> settingsToJson(SharedPreferences prefs) => {
  for (final k in prefs.getKeys())
    if (!kDeviceBoundKeys.contains(k))
      k: switch (prefs.get(k)) {
        final bool v => {'t': 'bool', 'v': v},
        final int v => {'t': 'int', 'v': v},
        final double v => {'t': 'double', 'v': v},
        final String v => {'t': 'string', 'v': v},
        final List<String> v => {'t': 'list', 'v': v},
        _ => null,
      },
}..removeWhere((_, v) => v == null);

/// Writes back what [settingsToJson] wrote; device-bound keys are never set.
Future<void> applySettingsJson(
  SharedPreferences prefs,
  Map<String, dynamic> json,
) async {
  for (final e in json.entries) {
    final v = e.value;
    if (kDeviceBoundKeys.contains(e.key) || v is! Map) continue;
    final value = v['v'];
    switch (v['t']) {
      case 'bool' when value is bool:
        await prefs.setBool(e.key, value);
      case 'int' when value is num:
        await prefs.setInt(e.key, value.toInt());
      case 'double' when value is num:
        await prefs.setDouble(e.key, value.toDouble());
      case 'string' when value is String:
        await prefs.setString(e.key, value);
      case 'list' when value is List:
        await prefs.setStringList(e.key, [for (final s in value) '$s']);
    }
  }
}

/// Creates `codecore-backup-YYYY-MM-DD.zip`: the database (a consistent copy
/// via `VACUUM INTO`), settings, the portable user data, covers and
/// `downloads.json` and `dislikes.json`. The temporary files are ours and always removed.
class BackupService {
  BackupService({
    required this.db,
    required this.prefs,
    required this.coversDir,
    required this.downloadsFile,
    this.dislikesFile,
    required this.deviceId,
    String? platform,
    DateTime Function()? now,
  }) : platform = platform ?? Platform.operatingSystem,
       _now = now ?? DateTime.now;

  final AppDatabase db;
  final SharedPreferences prefs;
  final Directory coversDir;
  final File downloadsFile;

  /// `dislikes.json`; left out of the zip when null or missing.
  final File? dislikesFile;
  final String deviceId, platform;
  final DateTime Function() _now;

  static String fileName(DateTime d) =>
      'codecore-backup-${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.zip';

  Future<BackupSummary> createBackup(
    String outPath, {
    void Function(double)? onProgress,
  }) async {
    final tmp = await Directory.systemTemp.createTemp('codecore-backup');
    try {
      final dbCopy = p.join(tmp.path, 'codecore.sqlite');
      await db.customStatement('VACUUM INTO ?', [dbCopy]);

      final data = await collectUserData(
        db,
        romanizations: SettingsStore(prefs).readManualRomanizations(),
      );
      final trackCount = (await (db.select(
        db.tracks,
      )..where((t) => t.kind.isNotValue(kStreamKind))).get()).length;
      final folders = [
        for (final f in await db.select(db.folders).get()) f.path,
      ];
      final manifest = {
        'backupFormat': kBackupFormat,
        'schemaVersion': db.schemaVersion,
        'appVersion': kAppVersion,
        'createdAt': _now().millisecondsSinceEpoch,
        'platform': platform,
        'deviceId': deviceId,
        'folders': folders,
        'trackCount': trackCount,
        'playlistCount': data.playlists.length,
      };
      File(p.join(tmp.path, 'manifest.json'))
          .writeAsStringSync(jsonEncode(manifest));
      File(p.join(tmp.path, 'settings.json'))
          .writeAsStringSync(jsonEncode(settingsToJson(prefs)));
      File(p.join(tmp.path, 'user_data.json'))
          .writeAsStringSync(jsonEncode(data.toJson()));

      final covers = coversDir.existsSync()
          ? [for (final f in coversDir.listSync().whereType<File>()) f.path]
          : <String>[];
      final downloads = downloadsFile.existsSync() ? downloadsFile.path : null;
      final dislikes = (dislikesFile?.existsSync() ?? false)
          ? dislikesFile!.path
          : null;
      final tmpPath = tmp.path;
      await Isolate.run(
        () => _zip(outPath, tmpPath, covers, downloads, dislikes),
      );
      onProgress?.call(1);
      return BackupSummary(
        path: outPath,
        bytes: File(outPath).lengthSync(),
        tracks: trackCount,
        playlists: data.playlists.length,
        covers: covers.length,
      );
    } finally {
      try {
        await tmp.delete(recursive: true);
      } on FileSystemException catch (e) {
        AppLog.w('backup temp folder not removed', e);
      }
    }
  }
}

const _alreadyCompressed = {'.jpg', '.jpeg', '.png', '.webp'};

void _zip(
  String outPath,
  String tmp,
  List<String> covers,
  String? downloads,
  String? dislikes,
) {
  final enc = ZipFileEncoder()..create(outPath);
  for (final name in ['manifest.json', 'settings.json', 'user_data.json']) {
    enc.addFileSync(File(p.join(tmp, name)), name);
  }
  enc.addFileSync(File(p.join(tmp, 'codecore.sqlite')), 'codecore.sqlite');
  if (downloads != null) enc.addFileSync(File(downloads), 'downloads.json');
  if (dislikes != null) enc.addFileSync(File(dislikes), 'dislikes.json');
  for (final c in covers) {
    final level = _alreadyCompressed.contains(p.extension(c).toLowerCase())
        ? ZipFileEncoder.store
        : ZipFileEncoder.gzip;
    enc.addFileSync(File(c), 'covers/${p.basename(c)}', level);
  }
  enc.closeSync();
}
