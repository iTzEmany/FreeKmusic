import 'package:flutter/services.dart';

import '../../core/app_log.dart';

enum AndroidInstallResult { started, needsPermission, differentSigner, failed }

/// Android side of the in-app update (channel `codecore/update`).
class AndroidUpdate {
  AndroidUpdate({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('codecore/update');

  final MethodChannel _channel;

  Future<String> abi() async => (await _channel.invokeMethod<String>('abi'))!;

  Future<bool> canInstall() async =>
      (await _channel.invokeMethod<bool>('canInstall')) ?? false;

  Future<void> openInstallSettings() =>
      _channel.invokeMethod<void>('openInstallSettings');

  /// [path] must be inside `cache/updates`. The installer only starts when the
  /// permission is granted and the APK is signed like the installed app.
  Future<AndroidInstallResult> install(String path) async {
    try {
      if (!await canInstall()) return AndroidInstallResult.needsPermission;
      final same = await _channel.invokeMethod<bool>('sameSigner', {
        'path': path,
      });
      if (same != true) return AndroidInstallResult.differentSigner;
      await _channel.invokeMethod<void>('install', {'path': path});
      return AndroidInstallResult.started;
    } on PlatformException catch (e, st) {
      AppLog.w('apk install failed', e, st);
      return AndroidInstallResult.failed;
    }
  }
}
