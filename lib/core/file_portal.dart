import 'dart:async';
import 'dart:io';

import 'app_log.dart';

/// Linux: without an xdg-desktop-portal FileChooser the file picker never
/// answers. True when the session bus has no such portal; false when it has
/// one or when it cannot be told (no `gdbus`).
Future<bool> filePortalMissing({
  Future<ProcessResult> Function(String, List<String>) run = Process.run,
}) async {
  if (!Platform.isLinux) return false;
  try {
    final r = await run('gdbus', [
      'introspect', '--session',
      '--dest', 'org.freedesktop.portal.Desktop',
      '--object-path', '/org/freedesktop/portal/desktop',
    ]).timeout(const Duration(seconds: 3)); // gdbus introspect has no --timeout
    return r.exitCode != 0 ||
        !'${r.stdout}'.contains('org.freedesktop.portal.FileChooser');
  } on TimeoutException catch (e) {
    AppLog.w('the file portal does not answer', e);
    return true; // an unresponsive portal would hang the picker too
  } on ProcessException catch (e) {
    AppLog.w('cannot check the file portal', e);
    return false;
  }
}
