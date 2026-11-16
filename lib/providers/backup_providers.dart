import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/paths.dart';
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
