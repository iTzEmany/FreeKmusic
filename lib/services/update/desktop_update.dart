import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import 'update_target.dart';

typedef DetachedStarter = Future<void> Function(String exe, List<String> args);
typedef ProcessRunner = Future<ProcessResult> Function(
  String exe,
  List<String> args,
);

/// Installs a downloaded update on desktop: silent Inno Setup on Windows,
/// in-place AppImage swap on Linux; every other package opens the browser.
class DesktopUpdate {
  DesktopUpdate({
    DetachedStarter? start,
    ProcessRunner? run,
    void Function(int code)? exitApp,
    Map<String, String>? env,
    String? browserCommand,
  }) : _start = start ?? _startDetached,
       _run = run ?? Process.run,
       _exit = exitApp ?? exit,
       _env = env ?? Platform.environment,
       _browser =
           browserCommand ??
           (Platform.isMacOS
               ? 'open'
               : Platform.isWindows
               ? 'rundll32'
               : 'xdg-open');

  final DetachedStarter _start;
  final ProcessRunner _run;
  final void Function(int) _exit;
  final Map<String, String> _env;
  final String _browser;

  static Future<void> _startDetached(String exe, List<String> args) =>
      Process.start(exe, args, mode: ProcessStartMode.detached);

  /// [fallback] (the asset URL) is opened in the browser whenever the
  /// package cannot install itself, e.g. a read-only AppImage folder.
  Future<void> install(File f, UpdateTarget t, {Uri? fallback}) async {
    switch (t.kind) {
      case UpdateKind.windows:
        await _start(f.path, [
          '/SILENT',
          '/SUPPRESSMSGBOXES',
          '/NORESTART',
          '/CLOSEAPPLICATIONS',
        ]);
        _exit(0);
      case UpdateKind.appImage:
        if (await _replaceAppImage(f)) return;
        if (fallback != null) await openBrowser(fallback);
      default:
        if (fallback != null) await openBrowser(fallback);
    }
  }

  Future<void> openBrowser(Uri url) => _browser == 'rundll32'
      ? _start(_browser, ['url.dll,FileProtocolHandler', url.toString()])
      : _start(_browser, [url.toString()]);

  /// False when the swap could not be done (nothing was changed).
  Future<bool> _replaceAppImage(File downloaded) async {
    final current = _env['APPIMAGE'];
    if (current == null || current.isEmpty) return false;
    final staged = File('$current.new');
    try {
      await downloaded.copy(staged.path);
      final chmod = await _run('chmod', ['755', staged.path]);
      if (chmod.exitCode != 0) throw ProcessException('chmod', [staged.path]);
      await staged.rename(current);
    } on Object catch (e, st) {
      AppLog.w('AppImage update in ${p.dirname(current)} failed', e, st);
      if (await staged.exists()) await staged.delete();
      return false;
    }
    await _start(current, const []);
    _exit(0);
    return true;
  }
}
