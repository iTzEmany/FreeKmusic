import 'dart:io';

import 'package:flutter/services.dart';

import '../../core/app_log.dart';

/// Total and free bytes of the volume a folder lives on.
class DiskSpace {
  const DiskSpace({required this.totalBytes, required this.freeBytes});

  final int totalBytes, freeBytes;

  /// Everything that is not free (music, other apps, the system).
  int get usedBytes => totalBytes - freeBytes;
}

/// `df -B1 --output=size,avail <dir>`: a header line, then «size avail».
DiskSpace? parseDf(String output) {
  final lines = output.trim().split('\n');
  if (lines.length < 2) return null;
  final parts = lines.last.trim().split(RegExp(r'\s+'));
  if (parts.length < 2) return null;
  final total = int.tryParse(parts[0]), free = int.tryParse(parts[1]);
  if (total == null || free == null || total <= 0) return null;
  return DiskSpace(totalBytes: total, freeBytes: free.clamp(0, total));
}

/// The Android storage channel (also used by `FolderOpener`).
const storageChannelName = 'codecore/storage';
const _channel = MethodChannel(storageChannelName);

/// Free and total space where [dir] is. Android: `StatFs` through a channel;
/// Linux: `df` (`statvfs` is not reachable from Dart); Windows and anything
/// that fails: null, and the page simply leaves the figure out.
Future<DiskSpace?> diskSpaceOf(String dir) async {
  try {
    if (Platform.isAndroid) {
      final r = await _channel.invokeMapMethod<String, Object?>('diskSpace', {
        'path': dir,
      });
      final total = r?['total'], free = r?['free'];
      if (total is! int || free is! int || total <= 0) return null;
      return DiskSpace(totalBytes: total, freeBytes: free.clamp(0, total));
    }
    if (Platform.isLinux) {
      final r = await Process.run('df', ['-B1', '--output=size,avail', dir]);
      if (r.exitCode != 0) {
        AppLog.w('df failed for $dir: ${r.stderr}');
        return null;
      }
      return parseDf('${r.stdout}');
    }
  } on Object catch (e, st) {
    AppLog.w('free space of $dir unavailable', e, st);
  }
  return null;
}
