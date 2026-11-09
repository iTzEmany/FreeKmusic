import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/app_log.dart';
import '../import/track_matcher.dart' show matchTitleKey;
import '../../core/artist_key.dart';

/// What is known about the YouTube Music id of one library song.
class SeedEntry {
  const SeedEntry(this.id, this.at);

  /// The id, `''` when the song was searched and not found.
  final String id;
  final int at;

  bool get found => id.isNotEmpty;
}

/// `seed_ids.json`: `title|artist` of a library song -> the id of the same
/// song on YouTube Music, so a song is searched once. A «not found» is
/// forgotten after [notFoundTtl] (the catalogue changes); a found id never.
class SeedIndex {
  SeedIndex({
    required this.file,
    this.notFoundTtl = const Duration(days: 30),
    this.writeDelay = const Duration(seconds: 2),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Resolved lazily: the app folder is only known asynchronously.
  final Future<File> Function() file;
  final Duration notFoundTtl;
  final Duration writeDelay;
  final DateTime Function() _now;

  Map<String, SeedEntry>? _entries;
  Timer? _timer;
  Future<void> _writing = Future.value();

  /// Same key the library matching uses: title without remaster/feat. tails
  /// and the first credited artist.
  static String keyOf(String title, String? artist) =>
      '${matchTitleKey(title)}|${artistKey(artist)}';

  Future<Map<String, SeedEntry>> _load() async {
    final cached = _entries;
    if (cached != null) return cached;
    final out = <String, SeedEntry>{};
    try {
      final f = await file();
      if (await f.exists()) {
        final raw = jsonDecode(await f.readAsString());
        if (raw is Map) {
          for (final e in raw.entries) {
            final v = e.value;
            if (v is Map && v['id'] is String && v['at'] is int) {
              out['${e.key}'] = SeedEntry(v['id'] as String, v['at'] as int);
            }
          }
        }
      }
    } on Object catch (e, st) {
      AppLog.w('seed index unreadable, starting empty', e, st);
      out.clear();
    }
    return _entries ??= out;
  }

  /// The known answer for [key]; null when never searched or when a «not
  /// found» is older than the limit.
  Future<SeedEntry?> get(String key) async {
    final m = await _load();
    final e = m[key];
    if (e == null) return null;
    if (!e.found &&
        _now().millisecondsSinceEpoch - e.at > notFoundTtl.inMilliseconds) {
      m.remove(key);
      _scheduleWrite();
      return null;
    }
    return e;
  }

  /// Keeps [id] (`''` = not found) for [key].
  Future<void> put(String key, String id) async {
    final m = await _load();
    m[key] = SeedEntry(id, _now().millisecondsSinceEpoch);
    _scheduleWrite();
  }

  /// Forgets every id (Memoria > «Svuota cache»).
  Future<void> clear() async {
    (await _load()).clear();
    await flush();
  }

  void _scheduleWrite() {
    _timer?.cancel();
    _timer = Timer(writeDelay, () => unawaited(flush()));
  }

  /// Writes now (also called when the debounce fires).
  Future<void> flush() {
    _timer?.cancel();
    // Serialized: a write never starts before the previous one ends, and
    // flush() completes only when the file is closed.
    return _writing = _writing.then((_) => _writeNow());
  }

  /// Cancels the pending debounce, writes what is left and waits for it.
  Future<void> dispose() async {
    await flush();
    _timer?.cancel();
  }

  Future<void> _writeNow() async {
    final m = _entries;
    if (m == null) return;
    try {
      final f = await file();
      await f.parent.create(recursive: true);
      await f.writeAsString(
        jsonEncode({
          for (final e in m.entries)
            e.key: {'id': e.value.id, 'at': e.value.at},
        }),
      );
    } on Object catch (e, st) {
      AppLog.w('seed index write failed', e, st);
    }
  }
}
