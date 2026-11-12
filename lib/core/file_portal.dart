import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_log.dart';

/// Linux: without an xdg-desktop-portal FileChooser the file picker never
/// answers. True when the session bus has no such portal; false when it has
/// one or when it cannot be told (no `gdbus`).
Future<bool> filePortalMissing({
  Future<Process> Function(String, List<String>) start = Process.start,
}) async {
  if (!Platform.isLinux) return false;
  Process? proc;
  try {
    proc = await start('gdbus', [
      'introspect', '--session',
      '--dest', 'org.freedesktop.portal.Desktop',
      '--object-path', '/org/freedesktop/portal/desktop',
    ]);
    final out = StringBuffer();
    proc.stdout.transform(utf8.decoder).listen(out.write);
    unawaited(proc.stderr.drain<void>());
    // gdbus introspect has no --timeout: a hung process is killed here.
    final code = await proc.exitCode.timeout(const Duration(seconds: 3));
    return code != 0 || !out.toString().contains('org.freedesktop.portal.FileChooser');
  } on TimeoutException catch (e) {
    proc?.kill();
    AppLog.w('the file portal does not answer', e);
    return true; // an unresponsive portal would hang the picker too
  } on ProcessException catch (e) {
    AppLog.w('cannot check the file portal', e);
    return false;
  }
}
