import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_log.dart';
import 'platform.dart';

/// Primary shared storage of an Android device.
const kAndroidPrimaryRoot = '/storage/emulated/0';

/// Tests set the app folders of the SD volumes instead of asking path_provider.
@visibleForTesting
List<String>? debugSdDirs;

/// App folders (`…/Android/data/<pkg>/files`) on removable volumes: the second
/// and later `getExternalStorageDirectories`. Empty off Android or without a card.
Future<List<String>> sdVolumeDirs() async {
  if (debugSdDirs case final d?) return d;
  if (!isAndroid) return const [];
  final dirs = await getExternalStorageDirectories() ?? const [];
  return writableDirs([for (final d in dirs.skip(1)) d.path]);
}

/// An unmountable card still has an entry in the list: keep only folders that exist and take a file.
@visibleForTesting
Future<List<String>> writableDirs(List<String> dirs) async => [for (final d in dirs) if (await _writable(d)) d];

Future<bool> _writable(String dir) async {
  try {
    if (!await Directory(dir).exists()) return false;
    final probe = File(p.join(dir, '.probe'));
    await probe.writeAsString('');
    await probe.delete();
    return true;
  } on FileSystemException catch (e) {
    AppLog.w('SD folder not usable, left out: $dir', e);
    return false;
  }
}

/// `/storage/1234-5678/…` -> `/storage/1234-5678`; null for any other path (the internal `emulated` too).
String? sdRootOf(String location) {
  final parts = p.split(location);
  return parts.length > 2 && parts[1] == 'storage' && parts[2] != 'emulated' && parts[2] != 'self'
      ? p.joinAll(parts.take(3))
      : null;
}

/// The download location to really use: '' (internal) when it names an SD
/// volume that is not in the device any more (card removed), else [location].
Future<String> effectiveLocation(String location) async {
  final root = sdRootOf(location);
  if (!isAndroid || root == null) return location;
  return [for (final d in await sdVolumeDirs()) sdRootOf(d)].contains(root) ? location : '';
}

/// MediaStore's name of the volume [path] is on: the SD card's, else null (primary).
String? mediaVolumeOf(String path) {
  final root = sdRootOf(path);
  return root == null ? null : p.basename(root).toLowerCase();
}
