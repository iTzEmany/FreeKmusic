import 'dart:async';

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
  }) : _channel = channel ?? const MethodChannel('freekmusic/window');

  final MethodChannel _channel;
  final Future<List<Folder>> Function() folders;
  final Future<Track?> Function(String path) trackAt;

  /// Reads the new [path] into the library, under [folder].
  final Future<void> Function(Folder folder, String path) scan;

  /// The first track plays now, the others follow in order.
  final Future<void> Function(List<Track> tracks) play;
  final Future<void> Function(String dir) addFolder;

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

  /// One launch at a time, so two quick «Apri con» keep their order.
  Future<void> handle(Iterable<String> raw) => _chain = _chain.then((_) => _handle(raw));

  Future<void> _handle(Iterable<String> raw) async {
    final paths = audioPaths(raw);
    if (paths.isEmpty) return;
    try {
      final all = await folders();
      final tracks = <Track>[];
      final outside = <String>[];
      for (final path in paths) {
        var t = await trackAt(path);
        if (t == null) {
          final home = all.where((f) => p.isWithin(f.path, path)).firstOrNull;
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
