import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../data/db/app_database.dart' show Folder, Track;
import '../scanner/library_scanner.dart' show audioExtensions;

/// Audio files handed to the desktop app («Apri con», a second launch): the
/// arguments of `main` and the runner channel `freekmusic/window` (the runner
/// keeps the paths until [start]/`opened` asks for them, D-736).
class OpenFiles {
  OpenFiles({
    MethodChannel? channel,
    required this.folders,
    required this.trackAt,
    required this.scan,
    required this.play,
    required this.addFolder,
    required this.onOutside,
    required this.onPortal,
    Future<bool> Function(String path)? exists,
  }) : _exists = exists ?? ((path) => File(path).exists()),
       _channel = channel ?? const MethodChannel('freekmusic/window');

  final Future<bool> Function(String path) _exists;

  final MethodChannel _channel;
  final Future<List<Folder>> Function() folders;
  final Future<Track?> Function(String path) trackAt;

  /// Reads the new [path] into the library, under [folder].
  final Future<void> Function(Folder folder, String path) scan;

  /// The first track plays now, the others follow in order.
  final Future<void> Function(List<Track> tracks) play;
  final Future<void> Function(String dir) addFolder;

  /// Flatpak documents-portal files the app cannot read by folder: the UI explains.
  final void Function(List<String> paths) onPortal;

  /// Files outside every library folder: the UI offers «Aggiungi alla libreria».
  final void Function(List<String> paths) onOutside;

  Future<void> _chain = Future.value();

  /// Plays [args] (what `main` got) and listens to the files that arrive later.
  Future<void> start(List<String> args) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'opened') await _take();
    });
    await handle(args);
    await _take();
  }

  Future<void> _take() async {
    try {
      final paths = await _channel.invokeListMethod<String>('takeFiles') ?? [];
      await handle(paths);
    } on PlatformException catch (e, st) {
      AppLog.w('open-with files not readable', e, st);
    } on MissingPluginException catch (e, st) {
      AppLog.w('open-with channel missing in this runner', e, st);
    }
  }

  /// Audio paths only (an argument may be a flag or a `file://` address).
  static List<String> audioPaths(Iterable<String> raw) => [
    for (final a in raw)
      if (_toPath(a) case final path?
          when audioExtensions.contains(p.extension(path).replaceFirst('.', '').toLowerCase()))
        path,
  ];

  static String? _toPath(String a) {
    if (!a.startsWith('file:')) return a;
    try {
      return Uri.parse(a).toFilePath();
    } on Object catch (e) {
      AppLog.d('bad file address: $a', e);
      return null;
    }
  }

  /// A file seen through the Flatpak documents portal (`/run/user/<uid>/doc/...`).
  static bool isPortalPath(String path) => RegExp(r'^/run/user/\d+/doc/').hasMatch(path);

  /// One launch at a time, so two quick «Apri con» keep their order.
  Future<void> handle(Iterable<String> raw) => _chain = _chain.then((_) => _handle(raw));

  Future<void> _handle(Iterable<String> raw) async {
    // Arguments come from outside: absolute, normalized, and only files that exist.
    final paths = <String>[];
    for (final path in audioPaths(raw).map((a) => p.normalize(p.absolute(a)))) {
      if (await _exists(path)) {
        paths.add(path);
      } else {
        AppLog.w('open-with: $path does not exist');
      }
    }
    if (paths.isEmpty) return;
    try {
      final all = await folders();
      final tracks = <Track>[];
      final outside = <String>[];
      final portal = <String>[];
      for (final path in paths) {
        var t = await trackAt(path);
        if (t == null) {
          final home = all.where((f) => p.isWithin(f.path, path)).firstOrNull;
          if (home == null && isPortalPath(path)) {
            // No library row for a file the app cannot read by folder: nothing is written, the user is told.
            AppLog.i('open-with: portal file $path is outside the readable folders, not played');
            portal.add(path);
            continue;
          }
          if (home == null) {
            outside.add(path);
            continue;
          }
          await scan(home, path);
          t = await trackAt(path);
        }
        if (t == null) {
          AppLog.w('open-with: $path is not readable as a track');
        } else {
          tracks.add(t);
        }
      }
      if (tracks.isNotEmpty) await play(tracks);
      if (outside.isNotEmpty) onOutside(outside);
      if (portal.isNotEmpty) onPortal(portal);
    } on Object catch (e, st) {
      AppLog.w('open-with failed', e, st);
    }
  }

  /// «Aggiungi alla libreria»: their folders join the library, then they play.
  Future<void> addToLibrary(List<String> paths) async {
    try {
      for (final dir in {for (final path in paths) p.dirname(path)}) {
        await addFolder(dir);
      }
      await handle(paths);
    } on Object catch (e, st) {
      AppLog.w('open-with: could not add to the library', e, st);
    }
  }
}
