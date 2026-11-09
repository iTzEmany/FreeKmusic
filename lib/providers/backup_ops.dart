import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/paths.dart';
import '../data/repositories/backup_merge.dart' show MergeReport;
import '../services/backup/restore_service.dart';
import 'backup_providers.dart';
import 'database_providers.dart';
import 'dislike_store_provider.dart';
import 'settings_providers.dart';

/// Backups: create, look inside, replace the library or merge into it.
class BackupOps {
  BackupOps(this._ref);

  final Ref _ref;

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

  /// Merges the zip into the live library.
  Future<MergeReport> merge(File zip) async {
    final report = await mergeBackup(
      zip,
      _ref.read(databaseProvider),
      Directory(await coversDir()),
      dislikes: _ref.read(dislikeStoreProvider),
    );
    await _ref
        .read(manualRomanizationProvider.notifier)
        .addMissing(report.romanizations);
    await _ref
        .read(handWrittenLyricsProvider.notifier)
        .addAll(report.handWritten);
    return report;
  }
}

final backupOpsProvider = Provider<BackupOps>(BackupOps.new);
