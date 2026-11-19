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

  /// True when the update started (the app then exits); false when it fell
  /// back to the browser ([fallback], the asset URL) or could not run.
  Future<bool> install(File f, UpdateTarget t, {Uri? fallback}) async {
    var done = false;
    if (t.kind == UpdateKind.windows) {
      // /CLOSEAPPLICATIONS: running yt-dlp/ffmpeg children may stay locked (to try on Windows).
      done = await _launch(f.path, const [
        '/SILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/CLOSEAPPLICATIONS',
      ]);
    } else if (t.kind == UpdateKind.appImage) {
      done = await _replaceAppImage(f);
    }
    if (done) {
      _exit(0);
      return true;
    }
    if (fallback != null) await openBrowser(fallback);
    return false;
  }

  /// False when nothing could open [url]; never throws. On Android/iOS no
  /// process is started (the caller uses LinkOpener).
  Future<bool> openBrowser(Uri url) => Platform.isAndroid || Platform.isIOS
      ? Future.value(false)
      : _launch(
          _browser,
          _browser == 'rundll32'
              ? ['url.dll,FileProtocolHandler', url.toString()]
              : [url.toString()],
        );

  Future<bool> _launch(String exe, List<String> args) async {
    try {
      await _start(exe, args);
      return true;
    } on Object catch (e, st) {
      AppLog.w('starting $exe failed', e, st);
      return false;
    }
  }

  /// False when the swap or the restart did not happen.
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
    // shortcut: la vecchia AppImage è già sostituita se la nuova non parte; ripristino se servirà
    return _launch(current, const []);
  }
}
