import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import 'youtube_service.dart';

/// Small `downloads.json`: `<source>:<id>` -> absolute file path. Entries
/// written before sources existed have the bare YouTube video id as key and
/// still count as `youtube:<id>`.
class DownloadIndex {
  DownloadIndex(this._file);

  final File _file;
  Map<String, String> _map = {};

  /// `<source>:<id>` -> [size, mtimeMs] of the file when it was downloaded (`downloads.sig.json`, beside the
  /// index so its format does not change). Proves a file at the path is still the downloaded one.
  Map<String, List<int>> _sig = {};
  File get _sigFile => File(p.join(_file.parent.path, 'downloads.sig.json'));

  Future<void> load() async {
    try {
      if (await _sigFile.exists()) {
        final raw = jsonDecode(await _sigFile.readAsString());
        if (raw is Map) {
          _sig = {
            for (final e in raw.entries)
              if (e.value is List && (e.value as List).length == 2) '${e.key}': [for (final n in e.value as List) (n as num).toInt()],
          };
        }
      }
    } on Object catch (e, st) {
      AppLog.w('downloads signatures unreadable', e, st);
    }
    try {
      if (await _file.exists()) {
        final raw = jsonDecode(await _file.readAsString());
        if (raw is Map) {
          _map = {for (final e in raw.entries) '${e.key}': '${e.value}'};
        }
      }
    } on Object catch (e, st) {
      AppLog.w('downloads index unreadable', e, st);
    }
  }

  /// Every indexed file path (memory only).
  Iterable<String> get paths => _map.values;

  /// `<source>:<id>` -> path for every entry (bare legacy ids come back as `youtube:<id>`). Memory only.
  Iterable<MapEntry<String, String>> get entries =>
      _map.entries.map((e) => MapEntry(e.key.contains(':') ? e.key : 'youtube:${e.key}', e.value));

  /// Forgets the download [key] (`<source>:<id>`, or the legacy bare id).
  Future<void> remove(String key) {
    _forget(key);
    return _persist();
  }

  void _forget(String key) {
    for (final k in [key, if (key.startsWith('youtube:')) key.substring('youtube:'.length)]) {
      _map.remove(k);
      _sig.remove(k);
    }
  }

  /// Forgets every entry (whatever its key) that points at [path].
  Future<void> removeByPath(String path) {
    for (final k in [for (final e in _map.entries) if (e.value == path) e.key]) {
      _forget(k);
    }
    return _persist();
  }

  /// Drops the entries whose file is gone (only where the folder is still there: an unplugged card
  /// must not wipe the index). Without this, a user's own file later put at the same path would look
  /// like the download.
  Future<void> pruneGone() async {
    final gone = [
      for (final e in _map.entries)
        if (!File(e.value).existsSync() && Directory(p.dirname(e.value)).existsSync()) e.key,
    ];
    if (gone.isEmpty) return;
    gone.forEach(_forget);
    await _persist();
  }

  /// The file at [path] is still the one downloaded for [key]: size and mtime as recorded at download
  /// time. Entries without a signature (older index, restored backup) never match, and neither does a
  /// file edited since (shortcut: tags written after the download also break it; see [refreshSignature]).
  bool signatureMatches(String key, String path) {
    final sig = _sig[key] ?? (key.startsWith('youtube:') ? _sig[key.substring('youtube:'.length)] : null);
    if (sig == null) return false;
    try {
      final st = File(path).statSync();
      return st.type == FileSystemEntityType.file && st.size == sig[0] && st.modified.millisecondsSinceEpoch == sig[1];
    } on Object catch (e, st) {
      AppLog.w('download signature unreadable: $path', e, st);
      return false;
    }
  }

  /// Records the current size and mtime of the file of [key] (call it after the app itself rewrote the file).
  Future<void> refreshSignature(String key) {
    final path = _map[key];
    if (path != null) _stamp(key, path);
    return _persist();
  }

  void _stamp(String key, String path) {
    try {
      final st = File(path).statSync();
      if (st.type == FileSystemEntityType.file) {
        _sig[key] = [st.size, st.modified.millisecondsSinceEpoch];
        return;
      }
    } on Object catch (e, st) {
      AppLog.w('download signature not recorded: $path', e, st);
    }
    _sig.remove(key);
  }

  bool contains(String id, {MediaSource source = MediaSource.youtube}) =>
      pathFor(id, source: source) != null;

  /// Where the video was downloaded, if the file is still there.
  String? pathFor(String id, {MediaSource source = MediaSource.youtube}) =>
      pathForKey(downloadIndexKey(source, id));

  /// Like [pathFor] from the `<source>:<id>` key.
  String? pathForKey(String key) {
    final path = _map[key] ??
        (key.startsWith('youtube:') ? _map[key.substring('youtube:'.length)] : null);
    return path != null && File(path).existsSync() ? path : null;
  }

  /// The YouTube video id [path] was downloaded from. Memory only (no disk
  /// access), so it also answers for files that are gone.
  String? idForPath(String path) {
    for (final e in _map.entries) {
      if (e.value != path) continue;
      final k = e.key;
      if (k.startsWith('youtube:')) return k.substring('youtube:'.length);
      if (!k.contains(':')) return k;
    }
    return null;
  }

  Future<void> _lastWrite = Future.value();

  /// Writes are chained: parallel downloads must not interleave in the file.
  Future<void> add(String id, String path,
      {MediaSource source = MediaSource.youtube}) {
    final key = downloadIndexKey(source, id);
    _map[key] = path;
    _stamp(key, path);
    return _persist();
  }

  Future<void> _persist() {
    return _lastWrite = _lastWrite.then((_) async {
      try {
        await _file.parent.create(recursive: true);
        // Write beside, then rename: a reader never sees a half-written file.
        final tmp = File('${_file.path}.tmp');
        await tmp.writeAsString(jsonEncode(_map));
        await tmp.rename(_file.path);
        final sigTmp = File('${_sigFile.path}.tmp');
        await sigTmp.writeAsString(jsonEncode(_sig));
        await sigTmp.rename(_sigFile.path);
      } on Object catch (e, st) {
        AppLog.w('downloads index write failed', e, st);
      }
    });
  }

  static File defaultFile(String supportDir) =>
      File(p.join(supportDir, 'downloads.json'));
}
