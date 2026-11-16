import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/app_log.dart';

/// What a cached page is, which sets how long it counts as fresh.
enum CatalogKind {
  artist(Duration(days: 2)),
  album(Duration(days: 14)),
  discography(Duration(days: 14)),
  songs(Duration(days: 2)),
  chart(Duration(hours: 24));

  const CatalogKind(this.ttl);

  final Duration ttl;
}

/// A page read back from the cache; [expired] copies are still good offline.
class CatalogEntry {
  const CatalogEntry(this.json, this.storedAt, this.expired);

  final Object? json;
  final DateTime storedAt;
  final bool expired;
}

/// Artist, album and list pages kept in memory and in one JSON file, so a page
/// seen before opens without the network and, offline, still opens. Beyond
/// [max] pages the least recently used go; an expired page is kept (until
/// pushed out) because an old copy beats an error.
class CatalogCache {
  CatalogCache({
    required this.file,
    this.max = 60,
    DateTime Function()? now,
    this.writeDelay = const Duration(seconds: 2),
  }) : _now = now ?? DateTime.now;

  /// Resolved lazily: the app folder is only known asynchronously.
  final Future<File> Function() file;
  final int max;
  final Duration writeDelay;
  final DateTime Function() _now;

  Map<String, _Stored>? _entries;
  Timer? _timer;
  Future<void> _writing = Future.value();

  static String _key(CatalogKind kind, String key) => '${kind.name}:$key';

  Future<Map<String, _Stored>> _load() async {
    final cached = _entries;
    if (cached != null) return cached;
    final out = <String, _Stored>{};
    try {
      final f = await file();
      if (await f.exists()) {
        final raw = jsonDecode(await f.readAsString());
        if (raw is Map) {
          for (final e in raw.entries) {
            final v = _Stored.fromJson(e.value);
            if (v != null) out['${e.key}'] = v;
          }
        }
      }
    } on Object catch (e, st) {
      AppLog.w('catalog cache unreadable, starting empty', e, st);
      out.clear();
    }
    return _entries ??= out;
  }

  /// The copy of [key], fresh or not; null when there is none. Counts as a use.
  Future<CatalogEntry?> get(CatalogKind kind, String key) async {
    final e = (await _load())[_key(kind, key)];
    if (e == null) return null;
    final now = _now();
    e.usedAt = now.millisecondsSinceEpoch;
    _scheduleWrite();
    final stored = DateTime.fromMillisecondsSinceEpoch(e.storedAt);
    return CatalogEntry(e.json, stored, now.difference(stored) > kind.ttl);
  }

  /// [json] must be plain JSON (what the models' `toJson` give). With
  /// [keepDate] an existing copy keeps its stored date (its freshness): used to
  /// add to a page without renewing it.
  Future<void> put(CatalogKind kind, String key, Object? json, {bool keepDate = false}) async {
    final m = await _load();
    final now = _now().millisecondsSinceEpoch;
    m[_key(kind, key)] = _Stored(keepDate ? m[_key(kind, key)]?.storedAt ?? now : now, now, json);
    if (m.length > max) {
      final byUse = m.entries.toList()
        ..sort((a, b) => a.value.usedAt.compareTo(b.value.usedAt));
      for (final e in byUse.take(m.length - max)) {
        m.remove(e.key);
      }
    }
    _scheduleWrite();
  }

  /// The stored JSON of every page of [kind], without counting as a use.
  Future<List<Object?>> allJson(CatalogKind kind) async {
    final prefix = '${kind.name}:';
    return [
      for (final e in (await _load()).entries)
        if (e.key.startsWith(prefix)) e.value.json,
    ];
  }

  Future<int> count() async => (await _load()).length;

  Future<void> clear() async {
    (await _load()).clear();
    await flush();
  }

  /// Bytes the cache takes on disk (for «Memoria»).
  Future<int> sizeBytes() async {
    await flush();
    try {
      final f = await file();
      return await f.exists() ? await f.length() : 0;
    } on Object catch (e, st) {
      AppLog.w('catalog cache size unknown', e, st);
      return 0;
    }
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
          jsonEncode({for (final e in m.entries) e.key: e.value.toJson()}));
    } on Object catch (e, st) {
      AppLog.w('catalog cache write failed', e, st);
    }
  }
}

class _Stored {
  _Stored(this.storedAt, this.usedAt, this.json);

  final int storedAt;
  int usedAt;
  final Object? json;

  Map<String, Object?> toJson() => {'s': storedAt, 'u': usedAt, 'd': json};

  static _Stored? fromJson(Object? j) {
    if (j is! Map) return null;
    final s = j['s'], u = j['u'];
    if (s is! int || u is! int || j['d'] == null) return null;
    return _Stored(s, u, j['d']);
  }
}
