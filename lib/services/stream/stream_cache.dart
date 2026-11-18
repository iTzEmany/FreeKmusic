import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../core/paths.dart';
import '../memory/disk_space.dart';
import 'stream_key.dart';

const _mb = 1024 * 1024;

/// LRU cache of streamed tracks: one file per key, last use = modified time.
class StreamCache {
  StreamCache(
    this.dir, {
    this.limitBytes = 500 * _mb,
    Future<int?> Function()? freeSpace,
    Future<void> Function(File)? delete,
  }) : _freeSpace =
           freeSpace ?? (() async => (await diskSpaceOf(dir.path))?.freeBytes),
       _delete = delete ?? ((f) => f.delete());

  /// `<appSupportDir>/stream_cache`, outside every music folder; with [volumeDir]
  /// (the app folder of the chosen SD volume, D-579) `<volumeDir>/stream_cache`.
  static Future<StreamCache> inAppSupport({
    int limitBytes = 500 * _mb,
    String volumeDir = '',
  }) async => StreamCache(
    Directory(
      p.join(
        volumeDir.isEmpty ? await appSupportDir() : volumeDir,
        'stream_cache',
      ),
    ),
    limitBytes: limitBytes,
  );

  /// [volumeDir] if its `stream_cache` folder can be created, listed and written there, else ''
  /// (the internal one, logged): a card that is read-only, half-gone or lists nothing (sdcardfs
  /// answers errno 13 to a listing of a folder it just created) must not leave streams without a cache.
  static Future<String> usableVolume(String volumeDir) async {
    if (volumeDir.isEmpty) return '';
    final d = Directory(p.join(volumeDir, 'stream_cache'));
    try {
      await d.create(recursive: true);
      await d.list().drain<void>();
      final probe = File(p.join(d.path, '.probe'));
      await probe.writeAsString('');
      await probe.delete();
      return volumeDir;
    } on FileSystemException catch (e, st) {
      AppLog.w(
        'stream cache: $volumeDir not usable, using the internal folder',
        e,
        st,
      );
      return '';
    }
  }

  /// An opened cache on [volumeDir] or, when it cannot be used or opened, on the internal folder;
  /// `volume` is the one really in use ('' = internal).
  static Future<({StreamCache cache, String volume})> openWithFallback(
    String volumeDir, {
    int limitBytes = 500 * _mb,
  }) async {
    final volume = await usableVolume(volumeDir);
    final cache = await inAppSupport(limitBytes: limitBytes, volumeDir: volume);
    try {
      await cache.open();
      return (cache: cache, volume: volume);
    } on FileSystemException catch (e, st) {
      if (volume.isEmpty) rethrow;
      AppLog.w(
        'stream cache: $volume could not be opened, using the internal folder',
        e,
        st,
      );
      final internal = await inAppSupport(limitBytes: limitBytes);
      await internal.open();
      return (cache: internal, volume: '');
    }
  }

  /// Deletes the cache folder of a volume left behind ([volumeDir] as in [inAppSupport]); nothing else.
  static Future<void> deleteAt(String volumeDir) async {
    final d = Directory(
      p.join(
        volumeDir.isEmpty ? await appSupportDir() : volumeDir,
        'stream_cache',
      ),
    );
    try {
      if (await d.exists()) await d.delete(recursive: true);
    } on FileSystemException catch (e, st) {
      AppLog.w('old stream cache not removed: ${d.path}', e, st);
    }
  }

  /// Start-up: the cache left on the volume of the previous run ([last]) goes, once the new one is open
  /// on [current]; never the one in use. Both as [volumeDir] in [inAppSupport].
  static Future<void> dropLeftBehind({
    required String? last,
    required String current,
  }) async {
    if (last != null && last != current) await deleteAt(last);
  }

  /// Space always left free on the disk (D-84).
  static const freeMargin = 500 * _mb;

  final Directory dir;

  /// Keys of the favourites: over the limit they go only when nothing else is left (D-577).
  Future<Set<String>> Function()? keepLonger;

  /// The slider value; may change at runtime.
  int limitBytes;
  final Future<int?> Function() _freeSpace;
  final Future<void> Function(File) _delete;
  final _pins = <String, int>{};
  var _evicting = Future<void>.value();

  /// stem -> file, refreshed by every folder scan and kept by put/remove.
  Map<String, File>? _index;
  var _mutations =
      0; // bumped by put/_remove: a scan that raced with one must not publish

  /// Called with each file the cache deletes to make room (evict/clear).
  void Function(File)? onEvicted;

  /// Called with the key of each [forget]: its file left the cache.
  void Function(String key)? onForgotten;

  /// Bytes in the folder, measured after `open` and every `evict`.
  int usedBytes = 0;

  /// Creates the folder, drops interrupted downloads, measures what is left.
  Future<void> open() async {
    await dir.create(recursive: true);
    await for (final e in dir.list()) {
      if (e is File && e.path.endsWith('.part')) await _remove(e);
      // Temp folders of the preparer's interrupted downloads.
      if (e is Directory && p.basename(e.path).startsWith('.dl-')) {
        try {
          await e.delete(recursive: true);
        } on FileSystemException catch (err, st) {
          AppLog.w('stream cache: cannot delete ${e.path}', err, st);
        }
      }
    }
    await _measure();
  }

  String _stem(File f) => p.basenameWithoutExtension(f.path);

  /// The cached file (any extension), or null.
  Future<File?> fileFor(String key) async {
    final name = streamFileName(key);
    final indexed = _index?[name];
    if (_index != null) {
      if (indexed == null || await indexed.exists()) return indexed;
      _index = null; // deleted behind our back (e.g. the OS cleared cacheDir): rescan
    }
    for (final e in await _files()) {
      if (_stem(e.file) == name) return e.file;
    }
    return null;
  }

  /// Moves a finished `<name>.<ext>.part` in as [key], then trims the cache.
  /// The new file is pinned during the trim so it is never its own victim.
  /// With [trim] false nothing is evicted (a prefetch must not push out the near tracks).
  Future<File> put(String key, File part, {bool trim = true}) async {
    await dir.create(recursive: true);
    final name = streamFileName(key);
    final ext = p.extension(p.basenameWithoutExtension(part.path));
    for (final e in await _files()) {
      if (_stem(e.file) == name) await _remove(e.file);
    }
    final f = await part.rename(p.join(dir.path, '$name$ext'));
    _mutations++;
    _index?[name] = f;
    if (!trim) return f;
    pin(key);
    try {
      await evict();
    } finally {
      unpin(key);
    }
    return f;
  }

  /// Drops [key] from the index: its file was moved out of the cache.
  void forget(String key) {
    _mutations++;
    _index?.remove(streamFileName(key));
    onForgotten?.call(key);
  }

  /// Deletes the unpinned files whose name starts with [stemPrefix] and were last used before
  /// [cutoff]; returns how many went. Other files are never touched.
  Future<int> expire(DateTime cutoff, {required String stemPrefix}) async {
    var n = 0;
    for (final e in await _files()) {
      if (!_stem(e.file).startsWith(stemPrefix) || !e.time.isBefore(cutoff)) {
        continue;
      }
      // Looked at again just before deleting: it may have been pinned or used meanwhile.
      if (_pins.keys.map(streamFileName).contains(_stem(e.file))) continue;
      try {
        if (!(await e.file.lastModified()).isBefore(cutoff)) continue;
      } on FileSystemException catch (err, st) {
        AppLog.w(
          'stream cache: cannot read the time of ${e.file.path}',
          err,
          st,
        );
        continue;
      }
      if (await _remove(e.file)) {
        n++;
        onEvicted?.call(e.file);
      }
    }
    if (n > 0) await _measure();
    return n;
  }

  /// Marks [key] as just used.
  Future<void> touch(String key) async {
    final f = await fileFor(key);
    if (f == null) return;
    try {
      await f.setLastModified(DateTime.now());
    } on FileSystemException catch (e, st) {
      AppLog.w('stream cache: cannot touch ${f.path}', e, st);
    }
  }

  bool isPinned(String key) => _pins.containsKey(key);

  void pin(String key) => _pins.update(key, (n) => n + 1, ifAbsent: () => 1);

  void unpin(String key) {
    final n = (_pins[key] ?? 0) - 1;
    n > 0 ? _pins[key] = n : _pins.remove(key);
  }

  /// min(slider, free space − margin), never negative (K-05). [used] defaults to [usedBytes].
  Future<int> effectiveLimit([int? used]) async {
    final free = await _freeSpace();
    // The cache's own bytes are free space too, so they count towards the room.
    final room = free == null
        ? limitBytes
        : free + (used ?? usedBytes) - freeMargin;
    return (room < limitBytes ? room : limitBytes).clamp(0, limitBytes);
  }

  /// Deletes least recently used files until under the limit, skipping pinned ones.
  Future<void> evict() {
    // Serialized: concurrent puts must not trim against a stale measure.
    final run = _evicting.then((_) => _evict());
    _evicting = run.catchError((Object _) {});
    return run;
  }

  Future<void> _evict() async {
    await _measure();
    final limit = await effectiveLimit(usedBytes);
    final files = await _files();
    var used = usedBytes;
    var favourites = const <String>{};
    try {
      favourites = await keepLonger?.call() ?? favourites;
    } on Object catch (e, st) {
      AppLog.w('stream cache: favourites unavailable, plain LRU', e, st);
    }
    final dear = {for (final k in favourites) streamFileName(k)};
    // Stable by false < true: oldest first within each group, favourites last.
    files.sort((a, b) {
      final d =
          (dear.contains(_stem(a.file)) ? 1 : 0) -
          (dear.contains(_stem(b.file)) ? 1 : 0);
      return d != 0 ? d : a.time.compareTo(b.time);
    });
    final pinned = _pins.keys.map(streamFileName).toSet();
    for (final e in files) {
      if (used <= limit) break;
      if (pinned.contains(_stem(e.file))) continue;
      if (await _remove(e.file)) {
        used -= e.size;
        onEvicted?.call(e.file);
      }
    }
    await _measure(); // K-06: a failed delete is retried at the next evict
  }

  /// Deletes everything except the [keep] keys and the pinned ones (tracks being downloaded or played: deleting their file would cut them off).
  Future<void> clear({Set<String> keep = const {}}) async {
    final kept = {...keep, ..._pins.keys}.map(streamFileName).toSet();
    for (final e in await _files()) {
      if (!kept.contains(_stem(e.file)) && await _remove(e.file)) {
        onEvicted?.call(e.file);
      }
    }
    await _measure();
  }

  Future<List<({File file, int size, DateTime time})>> _files() async {
    final out = <({File file, int size, DateTime time})>[];
    final index = <String, File>{};
    final seen = _mutations;
    if (!await dir.exists()) {
      _index = null;
      return out;
    }
    await for (final e in dir.list()) {
      if (e is! File || e.path.endsWith('.part')) continue;
      final s = await e.stat();
      if (s.type != FileSystemEntityType.file) continue;
      out.add((file: e, size: s.size, time: s.modified));
      index[_stem(e)] = e;
    }
    // Swapped whole; a scan that raced with a put/remove is stale, so the next fileFor rescans.
    _index = seen == _mutations ? index : null;
    return out;
  }

  /// Re-reads the folder size into [usedBytes] without evicting.
  Future<int> measure() async => _measure();

  Future<int> _measure() async =>
      usedBytes = (await _files()).fold<int>(0, (s, e) => s + e.size);

  Future<bool> _remove(File f) async {
    try {
      await _delete(f);
      _mutations++;
      _index?.remove(_stem(f));
      return true;
    } on PathNotFoundException {
      _mutations++;
      _index?.remove(_stem(f));
      return true; // already gone
    } on FileSystemException catch (e, st) {
      AppLog.w('stream cache: cannot delete ${f.path}', e, st);
      return false;
    }
  }
}
