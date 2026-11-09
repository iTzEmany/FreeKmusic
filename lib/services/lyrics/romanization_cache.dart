import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/app_log.dart';

/// How long a «no transliteration» answer is believed before asking again.
const kRomanizationRetryAfter = Duration(days: 30);

/// What the cache knows about a track: the transliterated LRC, or [lrc] null
/// for «NetEase has none» (still fresh).
class CachedRomanization {
  const CachedRomanization(this.lrc);

  final String? lrc;
}

/// Transliterated LRCs found online (D-458): one JSON file in the data folder
/// (never in the backup, the text is fetched again when missing). Writes are
/// atomic (`.tmp` + rename) and one at a time.
class RomanizationCache {
  RomanizationCache({required this.file, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Resolved lazily: the data folder is only known asynchronously.
  final Future<File> Function() file;
  final DateTime Function() _now;

  Map<int, ({String? lrc, int at})>? _entries;
  Future<void> _writing = Future.value();

  Future<Map<int, ({String? lrc, int at})>> _load() async {
    final cached = _entries;
    if (cached != null) return cached;
    final out = <int, ({String? lrc, int at})>{};
    try {
      final f = await file();
      if (await f.exists()) {
        final raw = jsonDecode(await f.readAsString());
        if (raw is Map) {
          for (final e in raw.entries) {
            final id = int.tryParse('${e.key}');
            final v = e.value;
            if (id == null || v is! Map || v['at'] is! int) continue;
            final lrc = v['lrc'];
            out[id] = (lrc: lrc is String ? lrc : null, at: v['at'] as int);
          }
        }
      }
    } on Object catch (e, st) {
      AppLog.w('romanization cache unreadable, starting empty', e, st);
      out.clear();
    }
    return _entries ??= out;
  }

  /// The entry of [trackId]; null when there is none or a «none» is old enough to ask again.
  Future<CachedRomanization?> get(int trackId) async {
    final e = (await _load())[trackId];
    if (e == null) return null;
    if (e.lrc == null) {
      final age = _now().millisecondsSinceEpoch - e.at;
      if (age > kRomanizationRetryAfter.inMilliseconds) return null;
    }
    return CachedRomanization(e.lrc);
  }

  /// Stores [lrc] for [trackId]; null records «none» with today's date.
  Future<void> put(int trackId, String? lrc) async {
    (await _load())[trackId] = (lrc: lrc, at: _now().millisecondsSinceEpoch);
    await _flush();
  }

  Future<void> _flush() {
    final json = jsonEncode({
      for (final e in _entries!.entries)
        '${e.key}': {
          if (e.value.lrc != null) 'lrc': e.value.lrc,
          'at': e.value.at,
        },
    });
    return _writing = _writing.then((_) => _write(json));
  }

  Future<void> _write(String json) async {
    try {
      final f = await file();
      await f.parent.create(recursive: true);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(json, flush: true);
      await tmp.rename(f.path);
    } on Object catch (e, st) {
      AppLog.w('romanization cache not saved', e, st);
    }
  }
}
