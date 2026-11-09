import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../core/app_log.dart';
import '../memory/disk_space.dart' show storageChannelName;

typedef ProcessStarter = Future<Process> Function(String exe, List<String> args);

/// Opens a folder in the system file manager: `xdg-open` on Linux, `explorer`
/// on Windows, an `ACTION_VIEW` intent (channel `codecore/storage`) on Android.
class FolderOpener {
  FolderOpener({
    MethodChannel? channel,
    ProcessStarter? start,
    bool? android,
    bool? windows,
  }) : _channel = channel ?? const MethodChannel(storageChannelName),
       _start = start ?? Process.start,
       _android = android ?? Platform.isAndroid,
       _windows = windows ?? Platform.isWindows;

  final MethodChannel _channel;
  final ProcessStarter _start;
  final bool _android, _windows;

  static const _wait = Duration(seconds: 3);
  static const _authority = 'content://com.android.externalstorage.documents';

  /// The DocumentsContract URI of an Android storage path (`/storage/emulated/0/Music`
  /// → `primary:Music`, an SD card keeps its volume id); null for any other path,
  /// for other users' storage, `..` and the app folders DocumentsUI does not open.
  static String? documentUri(String path) {
    final clean = path.replaceAll(RegExp(r'/+'), '/').replaceAll(RegExp(r'/$'), '');
    if (clean.split('/').contains('..')) return null;
    final m =
        RegExp(r'^/(?:storage/emulated/0|sdcard|storage/self/primary)(?:/(.*))?$').firstMatch(clean) ??
        RegExp(r'^/storage/(?!(?:emulated|self)(?:/|$))([^/]+)(?:/(.*))?$').firstMatch(clean);
    if (m == null) return null;
    final primary = m.groupCount == 1;
    final volume = primary ? 'primary' : m.group(1)!;
    final rel = (primary ? m.group(1) : m.group(2)) ?? '';
    if (RegExp(r'^Android/(?:data|obb)(?:/|$)').hasMatch(rel)) return null;
    return '$_authority/document/${Uri.encodeComponent('$volume:$rel')}';
  }

  /// False when nothing could open [path]; the caller then copies it.
  Future<bool> open(String path) async {
    try {
      if (_android) {
        final uri = documentUri(path);
        if (uri == null) return false;
        return await _channel.invokeMethod<bool>('openFolder', {'uri': uri}) ?? false;
      }
      // explorer would open Documents for a folder that is gone.
      if (!await Directory(path).exists()) return false;
      final proc = await _start(_windows ? 'explorer' : 'xdg-open', [path]);
      unawaited(proc.stdout.drain<void>());
      unawaited(proc.stderr.drain<void>());
      // explorer exits with 1 even when it worked, so only xdg-open's code counts;
      // a file manager that is still running after the timeout did open.
      if (_windows) return true;
      return await proc.exitCode.timeout(_wait, onTimeout: () => 0) == 0;
    } on Object catch (e, st) {
      AppLog.w('opening a folder failed', e, st);
      return false;
    }
  }
}
