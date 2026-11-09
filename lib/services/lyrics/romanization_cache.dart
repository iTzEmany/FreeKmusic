import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../../core/app_log.dart';

/// How long a «no transliteration» answer is believed before asking again.
const kRomanizationRetryAfter = Duration(days: 30);

const romanizationCacheFileName = 'romanization_cache.json';

/// What the cache knows about a track: the transliterated LRC, or [lrc] null
/// for «NetEase has none» (still fresh). [age] is how old the entry is.
class CachedRomanization {
  const CachedRomanization(this.lrc, this.age);

  final String? lrc;
  final Duration age;
}

typedef _Entry = ({String? lrc, int at, String? key});

/// Transliterated LRCs found online (D-458): one JSON file in the data folder
/// (never in the backup, the text is fetched again when missing). Writes are
/// atomic (`.tmp` + rename) and one at a time; the JSON work runs in an
/// isolate. An entry remembers the title and artist it was asked with: if they
/// change it counts as unknown.
class RomanizationCache {
  RomanizationCache({
    required this.file,
    DateTime Function()? now,
    this.liveIds,
  }) : _now = now ?? DateTime.now;

  /// Resolved lazily: the data folder is only known asynchronously.
  final Future<File> Function() file;

  /// Ids of the tracks that exist; on the first load the entries of the others go.
  final Future<Set<int>> Function()? liveIds;
  final DateTime Function() _now;

  Map<int, _Entry>? _entries;
  Future<void> _writing = Future.value();

  Future<Map<int, _Entry>> _load() async {
    final cached = _entries;
    if (cached != null) return cached;
    var out = <int, _Entry>{};
    var pruned = false;
    try {
      final f = await file();
      if (await f.exists()) {
        final raw = await f.readAsString();
        out = await Isolate.run(() => _decode(raw));
      }
    } on Object catch (e, st) {
      AppLog.w('romanization cache unreadable, starting empty', e, st);
      out = {};
    }
    try {
      final live = out.isEmpty ? null : await liveIds?.call();
      if (live != null) {
        final before = out.length;
        out.removeWhere((id, _) => !live.contains(id));
        pruned = out.length != before;
      }
    } on Object catch (e, st) {
      AppLog.w('romanization cache not pruned', e, st);
    }
    final loaded = _entries ??= out;
    if (pruned) await _flush();
    return loaded;
  }

  static Map<int, _Entry> _decode(String raw) {
    final out = <int, _Entry>{};
    final json = jsonDecode(raw);
    if (json is! Map) return out;
    for (final e in json.entries) {
      final id = int.tryParse('${e.key}');
      final v = e.value;
      if (id == null || v is! Map || v['at'] is! int) continue;
      out[id] = (
        lrc: v['lrc'] is String ? v['lrc'] as String : null,
        at: v['at'] as int,
        key: v['k'] is String ? v['k'] as String : null,
      );
    }
    return out;
  }

  /// The entry of [trackId] asked with [key] (title and artist); null when
  /// there is none, [key] changed, or a «none» is old enough to ask again.
  Future<CachedRomanization?> get(int trackId, {String? key}) async {
    final e = (await _load())[trackId];
    if (e == null || e.key != key) return null;
    final age = Duration(milliseconds: _now().millisecondsSinceEpoch - e.at);
    if (e.lrc == null && age > kRomanizationRetryAfter) return null;
    return CachedRomanization(e.lrc, age);
  }

  /// Stores [lrc] for [trackId]; null records «none» with today's date.
  Future<void> put(int trackId, String? lrc, {String? key}) async {
    (await _load())[trackId] = (
      lrc: lrc,
      at: _now().millisecondsSinceEpoch,
      key: key,
    );
    await _flush();
  }

  Future<void> _flush() {
    final data = {
      for (final e in _entries!.entries)
        '${e.key}': {
          if (e.value.lrc != null) 'lrc': e.value.lrc,
          'at': e.value.at,
          if (e.value.key != null) 'k': e.value.key,
        },
    };
    return _writing = _writing.then((_) => _write(data));
  }

  Future<void> _write(Map<String, Object?> data) async {
    try {
      final json = await Isolate.run(() => jsonEncode(data));
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
