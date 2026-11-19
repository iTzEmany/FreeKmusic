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
final _stemPrefix = streamFileName('karaoke:video:');

String _keyOf(String id) => 'karaoke:video:youtube:$id';

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
  }) : _dio = dio ?? Dio();

  final StreamCache cache;
  final KaraokeVideoSource source;
  final Dio _dio;

  /// False on a metered network with «prefetch on mobile data» off.
  final Future<bool> Function() canPrefetch;
  final DateTime Function() clock;
  final Duration lifetime;
  static Future<bool> _yes() async => true;

  final _inflight = <String, Future<void>>{};
  final _queued = <String>[]; // manual-queue ids, in order, each pinned
  final _tried = <String>{};
  Timer? _timer;
  Future<void>? _worker;

  /// The cached video of [id] or null; a hit is touched and fixed until [release].
  Future<File?> cached(String id) async {
    final f = await cache.fileFor(_keyOf(id));
    if (f == null) return null;
    await cache.touch(_keyOf(id));
    cache.pin(_keyOf(id));
    return f;
  }

  /// The player is done with [id]: the 15 minutes can start.
  void release(String id) {
    cache.unpin(_keyOf(id));
    unawaited(cache.touch(_keyOf(id)));
  }

  /// Downloads the stream of [id] in the background, fixed until [release]. One download per id.
  void download(String id, KaraokeVideoStream s) {
    cache.pin(_keyOf(id));
    unawaited(_fetch(id, s, trim: true).catchError((Object e, StackTrace st) => AppLog.w('karaoke video $id: download failed', e, st)));
  }

  Future<void> _fetch(String id, KaraokeVideoStream s, {required bool trim}) =>
      _inflight[id] ??= _download(id, s, trim).whenComplete(() {
        _inflight.remove(id); // a block: a returned future would be awaited
      });

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

  void dispose() => _timer?.cancel();

  /// The karaoke videos of the manual queue [userAhead] are fetched in order, one at a time, and stay
  /// fixed while queued; the ones that left it are released.
  void prefetchQueue(List<Track> userAhead) {
    final ids = [for (final t in userAhead) if (isKaraokeVideo(t)) karaokeVideoId(t)!];
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
      ..addAll(ids.toSet());
    _worker ??= _prefetchAll().whenComplete(() => _worker = null);
  }

  Future<void> _prefetchAll() async {
    String? next() => _queued.where((i) => !_tried.contains(i)).firstOrNull;
    for (var id = next(); id != null; id = next()) {
      try {
        if (!await canPrefetch()) return; // asked again at the next queue change
        _tried.add(id);
        if (await cache.fileFor(_keyOf(id)) != null) continue;
        await _fetch(id, await source.videoUrl(id), trim: false);
      } on Object catch (e, st) {
        _tried.add(id);
        AppLog.w('karaoke video $id: prefetch failed', e, st);
      }
    }
  }
}
