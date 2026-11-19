import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../data/db/app_database.dart' show Track;
import '../stream/stream_cache.dart';
import '../stream/stream_key.dart';
import 'karaoke_video.dart';

/// Stem prefix of every karaoke video in the cache: what the expiry looks at.
final _stemPrefix = streamFileName('video:karaoke:');

String _keyOf(String id) => 'video:karaoke:youtube:$id';

/// The low-quality video-only streams of karaoke videos, kept in the smart cache (D-649): 15 minutes
/// after their last use, on every platform; fixed while playing (`cached`/`download` until `release`)
/// and while the track waits in the manual queue (D-651).
class KaraokeVideoCache {
  KaraokeVideoCache({
    required this.cache,
    required this.source,
    Dio? dio,
    this.canPrefetch = _yes,
    this.clock = DateTime.now,
    this.lifetime = const Duration(minutes: 15),
  }) : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 30)));

  final StreamCache cache;
  final KaraokeVideoSource source;
  final Dio _dio;

  /// False on a metered network with «prefetch on mobile data» off.
  final Future<bool> Function() canPrefetch;
  final DateTime Function() clock;
  final Duration lifetime;
  static Future<bool> _yes() async => true;

  final _inflight = <String, Future<void>>{};
  final _latest = <String, KaraokeVideoStream>{}; // newest address asked while a download ran
  final _queued = <String>[]; // manual-queue ids, in order, each pinned
  final _tried = <String>{};
  Timer? _timer;
  Future<void>? _worker;
  var _again = false;

  /// The cached video of [id] or null; a hit is touched and fixed until [release].
  Future<File?> cached(String id) async {
    final f = await cache.fileFor(_keyOf(id));
    if (f == null) return null;
    cache.pin(_keyOf(id)); // before any await: the expiry must not take it
    await cache.touch(_keyOf(id));
    return f;
  }

  /// The player is done with [id]: the 15 minutes can start.
  void release(String id) {
    // Touch first, then unpin: the expiry never sees it unpinned and old.
    unawaited(cache.touch(_keyOf(id)).whenComplete(() => cache.unpin(_keyOf(id))));
  }

  /// Downloads the stream of [id] in the background, fixed until [release]. One download per id.
  void download(String id, KaraokeVideoStream s) {
    cache.pin(_keyOf(id));
    unawaited(_fetch(id, s, trim: true).catchError((Object e, StackTrace st) => AppLog.w('karaoke video $id: download failed', e, st)));
  }

  Future<void> _fetch(String id, KaraokeVideoStream s, {required bool trim}) {
    final running = _inflight[id];
    if (running != null) {
      _latest[id] = s;
      return running;
    }
    return _inflight[id] = _download(id, s, trim)
        .catchError((Object e, StackTrace st) {
          final next = _latest.remove(id); // failed: retry once with the newest address, if one came
          if (next == null) Error.throwWithStackTrace(e, st);
          return _download(id, next, trim);
        })
        .whenComplete(() {
          _latest.remove(id);
          _inflight.remove(id); // a block: a returned future would be awaited
        });
  }

  Future<void> _download(String id, KaraokeVideoStream s, bool trim) async {
    final key = _keyOf(id);
    if (await cache.fileFor(key) != null) return;
    await cache.dir.create(recursive: true);
    // A `.part` in the cache folder: `open` drops it if the app dies mid-download.
    final part = File(p.join(cache.dir.path, '${streamFileName(key)}.mp4.part'));
    try {
      await _dio.download(s.url.toString(), part.path, options: Options(headers: s.headers));
      await cache.put(key, part, trim: trim);
    } finally {
      if (await part.exists()) await part.delete();
    }
  }

  /// Deletes the unfixed videos unused for [lifetime] now and every 2 minutes.
  void startExpiry({Duration every = const Duration(minutes: 2)}) {
    unawaited(expire());
    _timer ??= Timer.periodic(every, (_) => unawaited(expire()));
  }

  Future<void> expire() async {
    try {
      await cache.expire(clock().subtract(lifetime), stemPrefix: _stemPrefix);
    } on Object catch (e, st) {
      AppLog.w('karaoke video: expiry failed', e, st);
    }
  }

  void dispose() {
    _timer?.cancel();
    _queued.forEach(release);
    _queued.clear();
  }

  /// The karaoke videos of the manual queue [userAhead] are fetched in order, one at a time, and stay
  /// fixed while queued; the ones that left it are released.
  void prefetchQueue(List<Track> userAhead) {
    final ids = {for (final t in userAhead) if (isKaraokeVideo(t)) karaokeVideoId(t)!}.toList();
    for (final id in _queued.where((i) => !ids.contains(i)).toList()) {
      _queued.remove(id);
      _tried.remove(id);
      release(id);
    }
    for (final id in ids) {
      if (!_queued.contains(id)) cache.pin(_keyOf(id));
    }
    _queued
      ..clear()
      ..addAll(ids);
    if (_worker != null) {
      _again = true; // the running pass may be on its way out: it looks again
      return;
    }
    _worker = _prefetchAll().whenComplete(() => _worker = null);
  }

  Future<void> _prefetchAll() async {
    String? next() => _queued.where((i) => !_tried.contains(i)).firstOrNull;
    do {
      _again = false;
      await _pass(next);
    } while (_again);
  }

  Future<void> _pass(String? Function() next) async {
    for (var id = next(); id != null; id = next()) {
      try {
        if (!await canPrefetch()) return; // asked again at the next queue change
      } on Object catch (e, st) {
        AppLog.w('karaoke video: prefetch check failed', e, st);
        return; // not tried: the next queue change asks again
      }
      _tried.add(id);
      try {
        if (await cache.fileFor(_keyOf(id)) != null) continue;
        await _fetch(id, await source.videoUrl(id), trim: false);
      } on Object catch (e, st) {
        AppLog.w('karaoke video $id: prefetch failed', e, st);
      }
    }
  }
}
