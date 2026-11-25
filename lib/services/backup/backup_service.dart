import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_info.dart';
import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/backup_queries.dart';
import '../../data/repositories/track_kinds.dart';
import '../../data/settings/jam_secret_store.dart';
import '../import/import_options.dart' show importDownloadTooPrefix;
import '../../data/settings/settings_store.dart'
    show
        SettingsStore,
        enrichMarkKey,
        flatpakNoticeShownKey,
        genreRereadAfterKey,
        genreRereadDoneKey,
        lastSeenVersionKey,
        closeToTrayKey,
        windowBoundsKey,
        recogPassAfterKey,
        recogPassDoneKey,
        savedOnlinePlaylistPrefix,
        storageModeD665Key;

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
  flatpakNoticeShownKey,
  recogPassAfterKey,
  recogPassDoneKey,
  genreRereadAfterKey,
  genreRereadDoneKey,
  storageModeD665Key,
  lastSeenVersionKey,
  closeToTrayKey,
  windowBoundsKey,
  // State of this device's own sessions: a copy would be wrong (or skip a prompt) elsewhere.
  'jamBlePermAsked',
  'lastUpdateCheckDay',
  'releasesRetryAt',
  'releasesLastNotifiedAt',
  // Folder and time of the weekly backup (R-241) belong to this device.
  'autoBackup',
  'backupFolder',
  'backupLastAt',
  'streamCacheVolume',
  // Layout of this screen (D-739): list/grid and its density stay on the PC.
  'libraryGrid',
  'libraryGridChosen',
  'libraryDensity',
  'sidePanel',
};

bool _staysOnDevice(String k) => kDeviceBoundKeys.contains(k) || k.startsWith(importDownloadTooPrefix) || k.startsWith(savedOnlinePlaylistPrefix);

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
    if (!_staysOnDevice(k))
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
    if (_staysOnDevice(e.key) || v is! Map) continue;
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

/// Creates `freekmusic-backup-YYYY-MM-DD.zip`: the database (a consistent copy
/// via `VACUUM INTO`), settings, the portable user data, covers and
/// `downloads.json` and `dislikes.json`. The temporary files are ours and always removed.
class BackupService {
  BackupService({
    required this.db,
    required this.prefs,
    required this.coversDir,
    this.themeDir,
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

  /// Pictures of the custom themes; left out of the zip when null or missing.
  final Directory? themeDir;
  final File downloadsFile;

  /// `dislikes.json`; left out of the zip when null or missing.
  final File? dislikesFile;
  final String deviceId, platform;
  final DateTime Function() _now;

  static String fileName(DateTime d) =>
      'freekmusic-backup-${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.zip';

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
        handWritten: SettingsStore(prefs).readHandWrittenLyrics(),
      );
      final trackCount = (await (db.select(
        db.tracks,
      )..where((t) => t.kind.isNotValue(kStreamKind) | t.saved.equals(true))).get()).length;
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
      final themeImages = (themeDir?.existsSync() ?? false)
          ? [for (final f in themeDir!.listSync().whereType<File>()) f.path]
          : <String>[];
      final downloads = downloadsFile.existsSync() ? downloadsFile.path : null;
      final dislikes = (dislikesFile?.existsSync() ?? false)
          ? dislikesFile!.path
          : null;
      final tmpPath = tmp.path;
      await Isolate.run(
        () => _zip(outPath, tmpPath, covers, themeImages, downloads, dislikes),
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

/// Time between two automatic backups.
const kBackupEvery = Duration(days: 7);

/// Whether the weekly backup (R-241) is due: never made, or 7 days or more ago.
bool isBackupDue(DateTime? lastAt, DateTime now) => lastAt == null || now.difference(lastAt) >= kBackupEvery;

/// How many automatic backups stay in the folder.
const kBackupsKept = 3;

/// Automatic backups have their own name, so keeping the newest 3 never touches a manual one.
String autoBackupName(DateTime d) => BackupService.fileName(d).replaceFirst('freekmusic-backup-', 'freekmusic-auto-');

final _autoBackupName = RegExp(r'^freekmusic-auto-\d{4}-\d{2}-\d{2}\.zip$');

/// R-241: when [enabled], a [folder] is chosen and [isBackupDue], writes
/// `freekmusic-auto-<date>.zip` there and keeps the newest [kBackupsKept]
/// (by the date in the name; the zip just written always stays, other files are
/// never touched). The folder is probed (the `.part` file) before the heavy work, and the zip
/// is renamed into place only when complete, so a failure leaves no partial zip and no
/// existing one truncated. Returns whether a backup was made; a failure goes to
/// [onError] (and AppLog) and leaves [saveLastAt] uncalled.
Future<bool> runAutoBackupIfDue({
  required BackupService service,
  required bool enabled,
  required String folder,
  required DateTime? lastAt,
  required DateTime now,
  required Future<void> Function(DateTime) saveLastAt,
  required void Function(Object error, StackTrace st) onError,
}) async {
  if (!enabled || folder.isEmpty || !isBackupDue(lastAt, now)) return false;
  final name = autoBackupName(now);
  final part = File(p.join(folder, '$name.part'));
  try {
    await part.create();
    try {
      await service.createBackup(part.path);
      await part.rename(p.join(folder, name));
    } on Object {
      if (part.existsSync()) await part.delete();
      rethrow;
    }
    await saveLastAt(now);
    final others = [
      await for (final f in Directory(folder).list())
        if (f is File && _autoBackupName.hasMatch(p.basename(f.path)) && p.basename(f.path) != name) f,
    ]..sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    for (final f in others.skip(kBackupsKept - 1)) {
      await f.delete();
    }
    return true;
  } on Object catch (e, st) {
    AppLog.w('automatic backup failed', e, st);
    onError(e, st);
    return false;
  }
}

/// Runs [runAutoBackupIfDue] and, after a failure, nothing more until the next app start
/// (resume and focus would redo the heavy work and fill the Registro).
class AutoBackupRunner {
  bool _failed = false;

  Future<bool> run({
    required BackupService service,
    required bool enabled,
    required String folder,
    required DateTime? lastAt,
    required DateTime now,
    required Future<void> Function(DateTime) saveLastAt,
    required void Function(Object error, StackTrace st) onError,
  }) async {
    if (_failed) return false;
    final ok = await runAutoBackupIfDue(
      service: service,
      enabled: enabled,
      folder: folder,
      lastAt: lastAt,
      now: now,
      saveLastAt: saveLastAt,
      onError: (e, st) {
        _failed = true;
        onError(e, st);
      },
    );
    return ok;
  }

  /// A failure outside the run (the service could not be built): also blocks retries.
  void fail() => _failed = true;
  bool get failed => _failed;
}

const _alreadyCompressed = {'.jpg', '.jpeg', '.png', '.webp'};

void _zip(
  String outPath,
  String tmp,
  List<String> covers,
  List<String> themeImages,
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
  for (final t in themeImages) {
    enc.addFileSync(File(t), 'theme/${p.basename(t)}', ZipFileEncoder.store);
  }
  enc.closeSync();
}
