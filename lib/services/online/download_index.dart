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

  Future<void> load() async {
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
    _map.remove(key);
    if (key.startsWith('youtube:')) _map.remove(key.substring('youtube:'.length));
    return _persist();
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
    _map[downloadIndexKey(source, id)] = path;
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
      } on Object catch (e, st) {
        AppLog.w('downloads index write failed', e, st);
      }
    });
  }

  static File defaultFile(String supportDir) =>
      File(p.join(supportDir, 'downloads.json'));
}
