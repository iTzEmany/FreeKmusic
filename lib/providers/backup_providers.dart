import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_log.dart';
import '../core/paths.dart';
import '../core/platform.dart';
import '../core/storage_volumes.dart' show kAndroidPrimaryRoot;
import '../services/backup/backup_service.dart';
import '../services/online/download_index.dart';
import 'database_providers.dart';
import 'settings_providers.dart';

/// A backup service over the live database and the app's own folders.
final backupServiceProvider = FutureProvider<BackupService>((ref) async {
  final support = await appSupportDir();
  return BackupService(
    db: ref.watch(databaseProvider),
    prefs: await SharedPreferences.getInstance(),
    coversDir: Directory(await coversDir()),
    themeDir: await themeDir(),
    downloadsFile: DownloadIndex.defaultFile(support),
    dislikesFile: File(p.join(support, 'dislikes.json')),
    deviceId: await ref.watch(settingsStoreProvider).deviceId(),
  );
}, retry: (_, _) => null);

/// When the last automatic backup was made (null = never); written by [AutoBackupLast.set].
final backupLastAtProvider = NotifierProvider<AutoBackupLast, DateTime?>(AutoBackupLast.new);

class AutoBackupLast extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    final ms = ref.read(settingsStoreProvider).backupLastAt;
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> set(DateTime d) async {
    await ref.read(settingsStoreProvider).writeBackupLastAt(d.millisecondsSinceEpoch);
    if (ref.mounted) state = d;
  }
}

/// Android 11+ lets the app write here with plain `dart:io`; no picker (R-241).
const kAndroidBackupDir = '$kAndroidPrimaryRoot/Documents/FreeKmusic';

/// Android: [kAndroidBackupDir], or (Android 10 and lower, where it is refused) the app's own
/// external folder, which goes away with the app. Created if missing.
Future<String> androidBackupFolder() async {
  try {
    await Directory(kAndroidBackupDir).create(recursive: true);
    return kAndroidBackupDir;
  } on FileSystemException catch (e) {
    AppLog.w('Documents/FreeKmusic not writable, backups go to the app folder', e);
    final dir = p.join(await androidAppMusicDir() ?? await appSupportDir(), 'backups');
    await Directory(dir).create(recursive: true);
    return dir;
  }
}

/// Where the automatic backups go: fixed on Android, the picked folder on desktop.
final backupFolderProvider = FutureProvider<String>(
  (ref) async => isAndroid ? androidBackupFolder() : ref.watch(settingsProvider.select((s) => s.backupFolder)),
  retry: (_, _) => null,
);
