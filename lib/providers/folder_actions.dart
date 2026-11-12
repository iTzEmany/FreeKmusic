
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/permissions.dart';
import '../core/platform.dart';
import '../data/repositories/folder_repository.dart';
import 'folder_ops.dart';
import 'library_providers.dart';

/// Scans every folder, after the audio permission (the denial is remembered).
Future<void> scanWithPermission(WidgetRef ref) async {
  final ok = await ensureAudioPermission();
  ref.read(permissionDeniedProvider.notifier).set(!ok);
  final prefs = await SharedPreferences.getInstance();
  if (!ok) {
    await prefs.setBool(kScanNeedsPermission, true);
    return;
  }
  await ref.read(scanStateProvider.notifier).scanAll();
  await prefs.setBool(kScanNeedsPermission, false);
}

/// The one «add folder» flow: pick, store, scan.
Future<void> addFolderAndScan(WidgetRef ref) async {
  final path = await FilePicker.getDirectoryPath();
  if (path == null) return;
  await ref.read(folderOpsProvider).add(path);
  await scanWithPermission(ref);
}

Future<void> addDefaultFolderAndScan(WidgetRef ref) async {
  final path = (await resolveDefaultFolders()).library;
  await ref.read(folderOpsProvider).add(path);
  await scanWithPermission(ref);
}

/// R-228: when the library has no folder, adds the default one and scans it.
/// True when it did. Called at startup by the app.
Future<bool> ensureDefaultFolder(
  FolderRepository folders,
  Future<void> Function() scan, {
  Future<DefaultFolders> Function() resolve = resolveDefaultFolders,
}) async {
  if ((await folders.getAll()).isNotEmpty) return false;
  await folders.add((await resolve()).library);
  await scan();
  return true;
}

/// Set when a scan was skipped because the audio permission was missing; cleared after a scan.
const kScanNeedsPermission = 'scan_needs_permission';

bool _lateScanning = false;

/// Android only: the last scan was skipped for the missing audio permission and it is granted now
/// (onboarding, then the settings), so the library is scanned. True when it did. Never two at once.
Future<bool> scanIfPermissionLate(
  SharedPreferences prefs,
  Future<bool> Function() granted,
  Future<void> Function() scan, {
  bool? android,
}) async {
  if (!(android ?? isAndroid) || _lateScanning || !(prefs.getBool(kScanNeedsPermission) ?? false)) return false;
  _lateScanning = true;
  try {
    if (!await granted()) return false;
    await scan();
    await prefs.setBool(kScanNeedsPermission, false);
    return true;
  } finally {
    _lateScanning = false;
  }
}
