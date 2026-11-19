import 'package:flutter/services.dart';

import '../../core/app_log.dart';

enum AndroidInstallResult { started, needsPermission, differentSigner, failed }

/// Android side of the in-app update (channel `codecore/update`).
/// `openInstallSettings` never throws: it answers whether the screen opened.
class AndroidUpdate {
  AndroidUpdate({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('codecore/update');

  final MethodChannel _channel;

  Future<String> abi() async => (await _channel.invokeMethod<String>('abi'))!;

  /// False when it cannot be told; never throws.
  Future<bool> canInstall() async {
    try {
      return (await _channel.invokeMethod<bool>('canInstall')) ?? false;
    } on PlatformException catch (e, st) {
      AppLog.w('install permission unknown', e, st);
    } on MissingPluginException catch (e, st) {
      AppLog.w('install permission unknown', e, st);
    }
    return false;
  }

  Future<bool> openInstallSettings() async {
    try {
      await _channel.invokeMethod<void>('openInstallSettings');
      return true;
    } on PlatformException catch (e, st) {
      AppLog.w('install settings not opened', e, st);
    } on MissingPluginException catch (e, st) {
      AppLog.w('install settings not opened', e, st);
    }
    return false;
  }

  /// [path] must be inside `cache/updates`. The installer only starts when the
  /// permission is granted and the APK is signed like the installed app.
  Future<AndroidInstallResult> install(String path) async {
    try {
      // Signer first: no sensitive permission request for an APK we would refuse.
      final same = await _channel.invokeMethod<bool>('sameSigner', {
        'path': path,
      });
      if (same != true) return AndroidInstallResult.differentSigner;
      if (!await canInstall()) return AndroidInstallResult.needsPermission;
      await _channel.invokeMethod<void>('install', {'path': path});
      return AndroidInstallResult.started;
    } on PlatformException catch (e, st) {
      AppLog.w('apk install failed', e, st);
      return AndroidInstallResult.failed;
    } on MissingPluginException catch (e, st) {
      AppLog.w('apk install failed', e, st);
      return AndroidInstallResult.failed;
    }
  }
}
