import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_log.dart';

/// Tests set it to true to exercise the Android path on a Linux host.
@visibleForTesting
bool? debugIsAndroidOverride;

bool get isAndroid => debugIsAndroidOverride ?? Platform.isAndroid;
/// Tests set it to false to see the phone layout on a Linux host.
@visibleForTesting
bool? debugIsDesktopOverride;

bool get isDesktop =>
    debugIsDesktopOverride ??
    (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

/// Where the library and the downloads live by default on this device.
class DefaultFolders {
  const DefaultFolders({required this.library, required this.downloads});
  final String library;
  final String downloads;
}

/// The one place that knows the default folders of each platform (R-227).
/// Android: `Music` (scan root) and `Music/FreeKmusic` (published by MediaStore);
/// desktop: the system Music folder and `<Music>/FreeKmusic`; iOS: the app
/// documents folder for both. The folders are created when missing.
/// [platform], [env] and [documentsDir] are seams for tests.
Future<DefaultFolders> resolveDefaultFolders({
  String? platform,
  Map<String, String>? env,
  Future<String> Function()? documentsDir,
  bool create = true,
}) async {
  final os = platform ?? (isAndroid ? 'android' : Platform.operatingSystem);
  final e = env ?? Platform.environment;
  final String music;
  switch (os) {
    case 'android':
      music = '/storage/emulated/0/Music';
    case 'ios':
      final docs = await (documentsDir ?? () async => (await getApplicationDocumentsDirectory()).path)();
      return DefaultFolders(library: docs, downloads: docs);
    case 'windows':
      music = p.windows.join(e['USERPROFILE'] ?? '', 'Music');
    case 'linux':
      music = await _xdgMusicDir(e);
    default:
      music = p.join(e['HOME'] ?? '', 'Music');
  }
  // Android and iOS paths are always POSIX; desktop ones follow the host (tests run on every OS).
  final ctx = switch (os) { 'windows' => p.windows, 'android' || 'ios' => p.posix, _ => p.context };
  if (!ctx.isAbsolute(music)) {
    // No HOME / USERPROFILE: never a relative path.
    final docs = await (documentsDir ?? () async => (await getApplicationDocumentsDirectory()).path)();
    return DefaultFolders(library: docs, downloads: docs);
  }
  final folders = DefaultFolders(library: music, downloads: ctx.join(music, 'FreeKmusic'));
  if (create) {
    for (final d in [folders.library, folders.downloads]) {
      try {
        await Directory(d).create(recursive: true);
      } on FileSystemException catch (err, st) {
        // Android without the storage permission: MediaStore creates it on publish.
        AppLog.w('default folder not created: $d', err, st);
      }
    }
  }
  return folders;
}

/// `XDG_MUSIC_DIR` (env, then `user-dirs.dirs`, then `xdg-user-dir MUSIC`), else `~/Music`.
/// A value that is `$HOME` itself means the folder is disabled: it never counts.
Future<String> _xdgMusicDir(Map<String, String> env) async {
  final home = env['HOME'] ?? '';
  String? expand(String v) {
    final x = v.replaceAll(r'$HOME', home);
    // Relative values and «/» are never a music folder.
    return !p.isAbsolute(x) || x == '/' || p.equals(x, home) ? null : p.normalize(x);
  }

  final fromEnv = expand(env['XDG_MUSIC_DIR'] ?? '');
  if (fromEnv != null) return fromEnv;
  try {
    final conf = env['XDG_CONFIG_HOME'] ?? p.join(home, '.config');
    final lines = await File(p.join(conf, 'user-dirs.dirs')).readAsLines();
    for (final l in lines) {
      final m = RegExp(r'^\s*XDG_MUSIC_DIR="([^"]*)"').firstMatch(l);
      final v = m == null ? null : expand(m.group(1)!);
      if (v != null) return v;
    }
  } on FileSystemException catch (e, st) {
    AppLog.w('user-dirs.dirs not readable, asking xdg-user-dir', e, st);
  }
  try {
    final r = await Process.run('xdg-user-dir', ['MUSIC'], environment: env);
    final out = expand('${r.stdout}'.trim());
    if (r.exitCode == 0 && out != null) return out;
  } on ProcessException catch (e, st) {
    AppLog.w('xdg-user-dir not available, using ~/Music', e, st);
  }
  return p.join(home, 'Music');
}

/// `getExternalStorageDirectory()` on Android (where 1.5.1 kept the downloads), else null.
Future<String?> androidAppMusicDir() async => isAndroid ? (await getExternalStorageDirectory())?.path : null;
