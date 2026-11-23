import 'dart:io';

import 'package:flutter/services.dart';

import '../../core/app_log.dart';
import '../update/desktop_update.dart';

/// Restarts the whole process (a restore must not leave the old one alive).
abstract class AppRestart {
  /// True: the restart started and the process is about to end. False: not
  /// possible here, the UI asks the user to close and reopen the app.
  Future<bool> restart();
}

class AndroidRestart implements AppRestart {
  AndroidRestart({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('codecore/restart');

  final MethodChannel _channel;

  @override
  Future<bool> restart() async {
    try {
      return await _channel.invokeMethod<bool>('restart') ?? false;
    } on MissingPluginException catch (e, st) {
      AppLog.w('restart channel missing', e, st);
      return false;
    } on PlatformException catch (e, st) {
      AppLog.w('restart failed', e, st);
      return false;
    }
  }
}

class DesktopRestart implements AppRestart {
  DesktopRestart({
    DetachedStarter? start,
    void Function(int code)? exitApp,
    Map<String, String>? env,
    String? executable,
  }) : _start = start ?? startDetached,
       _exit = exitApp ?? exit,
       _env = env ?? Platform.environment,
       _exe = executable ?? Platform.resolvedExecutable;

  final DetachedStarter _start;
  final void Function(int) _exit;
  final Map<String, String> _env;
  final String _exe;

  @override
  Future<bool> restart() async {
    // A Flatpak sandbox cannot relaunch itself from inside.
    if (_env.containsKey('FLATPAK_ID')) return false;
    final image = _env['APPIMAGE'];
    final exe = image == null || image.isEmpty ? _exe : image;
    try {
      await _start(exe, const []);
    } on Object catch (e, st) {
      AppLog.w('restarting $exe failed', e, st);
      return false;
    }
    _exit(0);
    return true;
  }
}
