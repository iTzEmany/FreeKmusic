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
  final folders = DefaultFolders(library: music, downloads: (os == 'windows' ? p.windows : p.posix).join(music, 'FreeKmusic'));
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
Future<String> _xdgMusicDir(Map<String, String> env) async {
  final home = env['HOME'] ?? '';
  String? expand(String v) => v.isEmpty ? null : v.replaceAll(r'$HOME', home);
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
  } on FileSystemException {
    // No user-dirs.dirs: ask the tool, then fall back.
  }
  try {
    final r = await Process.run('xdg-user-dir', ['MUSIC'], environment: env);
    final out = '${r.stdout}'.trim();
    if (r.exitCode == 0 && out.isNotEmpty && out != home) return out;
  } on ProcessException {
    // xdg-user-dir not installed.
  }
  return p.join(home, 'Music');
}
