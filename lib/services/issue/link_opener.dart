import 'dart:io';

import 'package:flutter/services.dart';

import '../../core/app_log.dart';

/// Opens web addresses and reads the device facts the Android side knows
/// (channel `codecore/link`); desktop uses the system opener.
class LinkOpener {
  LinkOpener({MethodChannel? channel, bool? android})
    : _channel = channel ?? const MethodChannel('codecore/link'),
      _android = android ?? Platform.isAndroid;

  final MethodChannel _channel;
  final bool _android;

  /// False when nothing could open [url].
  Future<bool> open(String url) async {
    try {
      if (_android) {
        return await _channel.invokeMethod<bool>('openUrl', {'url': url}) ??
            false;
      }
      if (Platform.isWindows) {
        await Process.start('rundll32', ['url.dll,FileProtocolHandler', url]);
      } else {
        await Process.start(Platform.isMacOS ? 'open' : 'xdg-open', [url]);
      }
      return true;
    } on Object catch (e, st) {
      AppLog.w('opening a link failed', e, st);
      return false;
    }
  }

  /// `model`, `os` and `build` on Android; empty elsewhere.
  Future<Map<String, String>> deviceInfo() async {
    if (!_android) return const {};
    try {
      final m = await _channel.invokeMapMethod<String, String>('deviceInfo');
      return m ?? const {};
    } on Object catch (e, st) {
      AppLog.w('reading device info failed', e, st);
      return const {};
    }
  }
}
