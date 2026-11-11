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
      'introspect', '--session', '--timeout', '3',
      '--dest', 'org.freedesktop.portal.Desktop',
      '--object-path', '/org/freedesktop/portal/desktop',
    ]);
    return r.exitCode != 0 ||
        !'${r.stdout}'.contains('org.freedesktop.portal.FileChooser');
  } on ProcessException catch (e) {
    AppLog.w('cannot check the file portal', e);
    return false;
  }
}
