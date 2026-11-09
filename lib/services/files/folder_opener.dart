import 'dart:io';

import 'package:flutter/services.dart';

import '../../core/app_log.dart';

typedef ProcessStarter = Future<Process> Function(String exe, List<String> args);

/// Opens a folder in the system file manager: `xdg-open` on Linux, `explorer`
/// on Windows, an `ACTION_VIEW` intent (channel `codecore/storage`) on Android.
class FolderOpener {
  FolderOpener({
    MethodChannel? channel,
    ProcessStarter? start,
    bool? android,
    bool? windows,
  }) : _channel = channel ?? const MethodChannel('codecore/storage'),
       _start = start ?? Process.start,
       _android = android ?? Platform.isAndroid,
       _windows = windows ?? Platform.isWindows;

  final MethodChannel _channel;
  final ProcessStarter _start;
  final bool _android, _windows;

  static const _authority = 'content://com.android.externalstorage.documents';

  /// The DocumentsContract URI of an Android storage path (`/storage/emulated/0/Music`
  /// → `primary:Music`, an SD card keeps its volume id); null for any other path.
  static String? documentUri(String path) {
    final m = RegExp(r'^/(?:storage/emulated/0|sdcard|storage/([^/]+))(?:/(.*))?$').firstMatch(path);
    if (m == null) return null;
    final rel = (m.group(2) ?? '').replaceAll(RegExp(r'/+$'), '');
    return '$_authority/document/${Uri.encodeComponent('${m.group(1) ?? 'primary'}:$rel')}';
  }

  /// False when nothing could open [path]; the caller then copies it.
  Future<bool> open(String path) async {
    try {
      if (_android) {
        final uri = documentUri(path);
        if (uri == null) return false;
        return await _channel.invokeMethod<bool>('openFolder', {'uri': uri}) ?? false;
      }
      // explorer exits with 1 even when it worked, so the exit code says nothing.
      await _start(_windows ? 'explorer' : 'xdg-open', [path]);
      return true;
    } on Object catch (e, st) {
      AppLog.w('opening a folder failed', e, st);
      return false;
    }
  }
}
