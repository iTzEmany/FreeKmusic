import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_log.dart';
import '../core/paths.dart';
import '../data/repositories/backup_merge.dart' show MergeReport;
import '../services/backup/restore_service.dart';
import 'app_restart_provider.dart';
import 'backup_providers.dart';
import 'database_providers.dart';
import 'daylist_providers.dart';
import 'dislike_store_provider.dart';
import 'exportify_providers.dart';
import 'jam_broker_providers.dart';
import 'jam_gate_providers.dart';
import 'jam_nearby_providers.dart';
import 'settings_providers.dart';
import 'theme_providers.dart';
import 'update_providers.dart';

/// Backups: create, look inside, replace the library or merge into it.
class BackupOps {
  BackupOps(this._ref, {this.closeTimeout = const Duration(seconds: 2)});

  final Ref _ref;

  /// drift's close() waits for every stream, and paused Riverpod listeners never end them.
  final Duration closeTimeout;

  /// Writes a backup zip to [path].
  Future<void> create(String path) async {
    // The zip takes the file: make sure it is loaded and up to date.
    final s = _ref.read(dislikeStoreProvider);
    await s.load();
    await s.flush();
    await (await _ref.read(backupServiceProvider.future)).createBackup(path);
  }

  /// What the zip holds and how it fits this device; throws [RestoreException] if it is no backup.
  Future<RestorePlan> inspect(File zip) async => inspectBackup(
    zip,
    deviceId: await _ref.read(settingsStoreProvider).deviceId(),
    schemaVersion: _ref.read(schemaVersionProvider),
  );

  /// Unpacks the zip for the full restore that runs at the next start.
  Future<void> stageReplace(File zip) async =>
      stageFullRestore(zip, await restoreStagingDir());

  /// Closes the database (a Windows rename of an open file fails; elsewhere the old process
  /// stops writing), then restarts the app. False: no restart possible, the user reopens.
  Future<bool> restartAfterRestore() async {
    try {
      await _ref.read(databaseProvider).close().timeout(closeTimeout);
    } on Object catch (e, st) {
      // Also a timeout: the restart ends the process anyway.
      AppLog.w('database not closed before restart', e, st);
    }
    return _ref.read(appRestartProvider).restart();
  }

  /// Ends the process (the staged restore applies at the next launch).
  Future<void> quit() => _ref.read(appRestartProvider).quit();

  /// Merges the zip into the live library.
  Future<MergeReport> merge(File zip) async {
    final report = await mergeBackup(
      zip,
      _ref.read(databaseProvider),
      Directory(await coversDir()),
      dislikes: _ref.read(dislikeStoreProvider),
      prefs: await SharedPreferences.getInstance(),
      themeDir: await themeDir(),
    );
    await _ref
        .read(manualRomanizationProvider.notifier)
        .addMissing(report.romanizations);
    await _ref
        .read(handWrittenLyricsProvider.notifier)
        .addAll(report.handWritten);
    // The merge wrote settings.json straight into the preferences: whatever caches
    // them would later write its old value back over the merged one (or prune the new theme pictures).
    _ref.invalidate(settingsProvider);
    _ref.invalidate(customThemesProvider);
    _ref.invalidate(daylistConfigProvider);
    _ref.invalidate(moodTableProvider);
    _ref.invalidate(jamBrokersProvider);
    _ref.invalidate(jamAutoAcceptFriendsProvider);
    _ref.invalidate(jamNearbyScanProvider);
    _ref.invalidate(shazamAutoDownloadProvider);
    _ref.invalidate(checkUpdatesOnStartProvider);
    _ref.invalidate(exportifyRemindDaysProvider);
    return report;
  }
}

final backupOpsProvider = Provider<BackupOps>(BackupOps.new);
