import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../data/repositories/track_repository.dart';
import '../online/query_cleaner.dart';
import '../online/youtube_service.dart';
import 'stream_cache.dart';
import 'stream_key.dart';

enum StreamPhase { queued, downloading, ready, failed }

/// A queue entry that can be streamed: its cache key and what to download.
class StreamItem {
  const StreamItem(this.key, this.result);
  final String key;
  final YtResult result;
}

/// Where a streamed track starts from: the cached [file] or the stream [url]
/// (with the [headers] to open it with). Exactly one of the two is set.
class StreamStart {
  const StreamStart.file(File this.file)
      : url = null,
        headers = const {};
  const StreamStart.url(Uri this.url, this.headers) : file = null;
  final File? file;
  final Uri? url;
  final Map<String, String> headers;
}

class _Job {
  _Job(this.key, this.result) {
    done.future.ignore(); // the error reaches ready() callers only
  }
  final String key;
  final YtResult result;
  final done = Completer<File>();
  var phase = StreamPhase.queued;

  /// A `ready()` caller waits for it: runs first, even out of the queue window.
  var requested = false;

  /// Callers that keep the job requested for good (`ready`, `start`), and callers
  /// that only wait for the address (`keep: false`). The job goes back to being a
  /// prefetch once the second kind is all done and the first kind is absent.
  var keepers = 0, soft = 0;

  /// Token of the running attempt; cancelled on timeout, on leaving the queue, on dispose.
  CancelToken? cancel;
  var dropped = false;

  /// The restart of the running attempt was asked for: its failure is not a failed attempt.
  var restarting = false;

  /// Age-gated video: the YouTube Music track downloaded in its place (tried once).
  YtResult? substitute;
  var ageTried = false;

  /// Last stream address of the running attempt, its headers and when it expires.
  Uri? streamUrl;
  Map<String, String> headers = const {};
  DateTime? urlExpires;

  /// Completed (and replaced) each time an address arrives: wakes who waits for it.
  var urlWake = Completer<void>();

  /// Timings of the last attempt (ms from the start of `_download`); null = not reached.
  DateTime? t0;
  int? spawn, urlMs, downloaded, post, cached;
  var attempt = 0;
}

/// Downloads the queue's online tracks into the [StreamCache] ahead of the
/// player (at most [maxParallel] at once, queue order, one per key).
/// The handler calls [setQueue] before [ready] (45.4).
class StreamPreparer {
  StreamPreparer({
    required this.cache,
    required this.tracks,
    required this.youtube,
    required this.isMetered,
    this.maxParallel = 2,
    this.meteredAhead = 3,
    this.cooldown = const Duration(minutes: 5),
    this.attemptTimeout = const Duration(minutes: 5),
    this.startTimeout = const Duration(seconds: 90),
    this.stallTimeout = const Duration(seconds: 30),
    this.ageSearchTimeout = const Duration(seconds: 20),
    this.clock = DateTime.now,
  }) {
    // A key promoted out of the cache (StreamCache.forget) is no longer ready.
    cache.onForgotten = (key) {
      if (_disposed || phases.value[key] != StreamPhase.ready) return;
      phases.value = {...phases.value}..remove(key);
    };
    // An evicted file is no longer ready: the queue walk may fetch it again.
    cache.onEvicted = (f) {
      if (_disposed) return;
      final stem = p.basenameWithoutExtension(f.path);
      final gone = [
        for (final e in phases.value.entries)
          if (e.value == StreamPhase.ready && streamFileName(e.key) == stem) e.key
      ];
      if (gone.isNotEmpty) phases.value = {...phases.value}..removeWhere((k, _) => gone.contains(k));
    };
  }

  final StreamCache cache;
  final TrackRepository tracks;
  final YoutubeService youtube;
  final Future<bool> Function() isMetered;
  final int maxParallel, meteredAhead;

  /// Pause of the prefetch after a 403/429 (like Shuffle+'s source cooldown).
  final Duration cooldown;

  /// Longest a single download attempt may take.
  final Duration attemptTimeout;

  /// Longest wait for the first progress event (yt-dlp extraction comes first).
  final Duration startTimeout;

  /// An attempt that reports no progress for this long is aborted (hung network).
  final Duration stallTimeout;

  /// Longest wait for the search of an age-restricted video's substitute.
  final Duration ageSearchTimeout;

  /// Time source of the `stream timing` log line (injectable for tests).
  final DateTime Function() clock;

  /// Phase per key, updated only when it changes (never the byte count).
  final phases = ValueNotifier<Map<String, StreamPhase>>({});

  var _queue = <StreamItem>[];
  final _jobs = <String, _Job>{};
  final _pinned = <String>{};
  var _tmpSeq = 0;
  var _active = 0;
  final _yielding = <_Job>{};
  var _pumping = false, _again = false, _disposed = false;
  Timer? _resume;
  DateTime? _pausedUntil;

  /// Keys of the entries given to the last [setQueue].
  Set<String> get queuedKeys => {for (final i in _queue) i.key};

  /// The upcoming online entries, current first. Pins current + next 2.
  void setQueue(List<StreamItem> items) {
    if (_disposed) return;
    if (items.isEmpty && _queue.isEmpty) return;
    _queue = List.of(items);
    final want = {for (final i in items.take(3)) i.key};
    for (final k in _pinned.difference(want)) {
      cache.unpin(k);
    }
    for (final k in want.difference(_pinned)) {
      cache.pin(k);
    }
    _pinned
      ..clear()
      ..addAll(want);
    // Forget what nobody waits for any more.
    final inQueue = {for (final i in items) i.key};
    _jobs.removeWhere((k, j) {
      if (inQueue.contains(k) || j.requested) return false;
      j.dropped = true;
      j.cancel?.cancel('left the queue');
      return true;
    });
    final keep = {...inQueue, ..._jobs.keys};
    if (phases.value.keys.any((k) => !keep.contains(k))) {
      phases.value = {
        for (final e in phases.value.entries)
          if (keep.contains(e.key)) e.key: e.value,
      };
    }
    _pump();
  }

  /// The cached file of [key], downloading it first (ahead of the queue) when
  /// needed. Errors after the second failed attempt. The key is pinned until
  /// the file is handed back; from then on the queue window pins it.
  Future<File> ready(String key, YtResult r) async {
    if (_disposed) throw StateError('disposed');
    cache.pin(key);
    try {
      return await _cached(key, r) ?? await _job(key, r).done.future;
    } finally {
      cache.unpin(key);
    }
  }

  /// Like [ready], but returns as soon as the stream address is known (R-71):
  /// the first of a live address of the job and the cached file.
  ///
  /// With [keep] false the job goes back to being a prefetch once the address is
  /// known (it yields to picks and leaves with the queue window), unless someone
  /// else asked for it meanwhile. For callers that only warm an address up.
  Future<StreamStart> start(String key, YtResult r, {bool keep = true}) async {
    if (_disposed) throw StateError('disposed');
    cache.pin(key);
    try {
      final file = await _cached(key, r);
      if (file != null) return StreamStart.file(file);
      // The address the prefetch got has expired meanwhile: ask for a new one (R-79),
      // unless the download is through and only the file is left to wait for.
      final old = _jobs[key];
      if (old != null && old.streamUrl != null && old.downloaded == null && !_live(old)) return await restart(key, r, keep: keep);
      final job = _job(key, r, keep: keep);
      try {
        return await _firstOf(job);
      } finally {
        if (!keep) _release(job);
      }
    } finally {
      cache.unpin(key);
    }
  }

  /// A new start for a key whose address expired (R-76): the file when it is
  /// there, else the running attempt is cancelled and run again for a fresh address.
  Future<StreamStart> restart(String key, YtResult r, {bool keep = true}) async {
    if (_disposed) throw StateError('disposed');
    cache.pin(key);
    try {
      final file = await _cached(key, r);
      if (file != null) return StreamStart.file(file);
      final running = _jobs[key]; // read after the await: it may have finished meanwhile
      if (running != null && running.phase == StreamPhase.downloading) {
        running.restarting = true;
        running.cancel?.cancel('stream address expired');
      }
      final job = _job(key, r, keep: keep)..streamUrl = null;
      try {
        return await _firstOf(job);
      } finally {
        if (!keep) _release(job);
      }
    } finally {
      cache.unpin(key);
    }
  }

  /// The cached file of [key] (with its shadow row), or null: no download starts.
  Future<File?> cachedFile(String key, YtResult r) => _cached(key, r);

  /// The cached file of [key] (touched, with its shadow row), or null.
  Future<File?> _cached(String key, YtResult r) async {
    final file = await cache.fileFor(key);
    if (file == null) return null;
    await cache.touch(key);
    // A file cached by an earlier session may have lost its row: plays need it.
    if (await tracks.streamRow(key) == null) await tracks.upsertStreamRow(key, r, file);
    _setPhase(key, StreamPhase.ready);
    return file;
  }

  /// The job of [key] (new if absent or failed), marked as requested.
  _Job _job(String key, YtResult r, {bool keep = true}) {
    if (_disposed) throw StateError('disposed');
    var job = _jobs[key];
    if (job == null || job.phase == StreamPhase.failed) {
      job = _jobs[key] = _Job(key, r);
    }
    job.requested = true;
    keep ? job.keepers++ : job.soft++;
    _pump();
    return job;
  }

  /// A `keep: false` caller got its answer: back to a prefetch if nobody else wants the job.
  void _release(_Job job) {
    if (--job.soft == 0 && job.keepers == 0) job.requested = false;
  }

  /// True while the address is still usable: an address about to expire is no
  /// use to a player that opens it later.
  bool _live(_Job job) =>
      job.streamUrl != null && clock().isBefore(job.urlExpires!.subtract(const Duration(minutes: 1)));

  /// The first of a live address and the file; throws if the job fails first.
  Future<StreamStart> _firstOf(_Job job) async {
    final file = job.done.future.then<StreamStart?>(StreamStart.file);
    file.ignore(); // an early return must not leave its failure unhandled
    while (true) {
      if (_live(job)) return StreamStart.url(job.streamUrl!, job.headers);
      final first = await Future.any([file, job.urlWake.future.then<StreamStart?>((_) => null)]);
      if (first != null) return first;
    }
  }

  void _onUrl(_Job j, Uri url, Map<String, String> headers) {
    final now = clock();
    final expire = int.tryParse(url.queryParameters['expire'] ?? '');
    j
      ..streamUrl = url
      ..headers = headers
      ..urlExpires = expire != null && expire > 0 && expire <= 8640000000000 // DateTime's range, in s
          ? DateTime.fromMillisecondsSinceEpoch(expire * 1000)
          : now.add(const Duration(hours: 5))
      ..urlMs = now.difference(j.t0!).inMilliseconds;
    final wake = j.urlWake;
    j.urlWake = Completer<void>();
    wake.complete();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _resume?.cancel();
    for (final j in _jobs.values) {
      j.cancel?.cancel('disposed');
      _fail(j, StateError('disposed'));
    }
    _pinned.forEach(cache.unpin);
    _pinned.clear();
    phases.dispose();
  }

  void _setPhase(String key, StreamPhase ph) {
    if (!_disposed && phases.value[key] != ph) phases.value = {...phases.value, key: ph};
  }

  void _fail(_Job j, Object error) {
    j.phase = StreamPhase.failed;
    _setPhase(j.key, StreamPhase.failed);
    if (!j.done.isCompleted) j.done.completeError(error);
  }

  void _pump() {
    if (_pumping) {
      _again = true;
      return;
    }
    _pumping = true;
    unawaited(() async {
      try {
        do {
          _again = false;
          await _fill();
        } while (_again && !_disposed);
      } on Object catch (e, st) {
        AppLog.w('stream preparer: scheduling failed', e, st);
        for (final j in _jobs.values.toList()) {
          if (j.requested && j.phase == StreamPhase.queued) _fail(j, e);
        }
      } finally {
        _pumping = false;
      }
    }());
  }

  Future<void> _fill() async {
    if (_disposed) return;
    // Requested jobs first, whatever the network or the pause.
    // Queue order: the current track first, keys outside the queue last.
    int rank(_Job j) {
      final i = _queue.indexWhere((q) => q.key == j.key);
      return i < 0 ? _queue.length : i;
    }
    final requested = _jobs.values.where((j) => j.requested && j.phase == StreamPhase.queued).toList()
      ..sort((a, b) => rank(a).compareTo(rank(b)));
    // K-04: at most maxParallel downloads in all. A requested job never waits for
    // prefetches: when the cap is hit, running prefetches yield (are cancelled, and
    // picked up again later by the queue walk).
    var free = maxParallel - _active;
    var waiting = requested.length;
    for (final j in requested) {
      if (free <= 0) break;
      free--;
      waiting--;
      _start(j);
    }
    if (waiting > 0) {
      for (final p in _jobs.values.toList()) {
        if (_yielding.length >= waiting) break;
        if (p.requested || p.phase != StreamPhase.downloading) continue;
        p.dropped = true;
        _yielding.add(p);
        _jobs.remove(p.key);
        _setPhase(p.key, StreamPhase.queued);
        p.cancel?.cancel('yields to a requested download');
      }
      return;
    }
    if (_pausedUntil?.isAfter(DateTime.now()) ?? false) return;
    bool? room;
    var metered = false;
    try {
      metered = await isMetered();
    } on Object catch (e, st) {
      AppLog.w('stream preparer: network kind unavailable', e, st);
    }
    for (final i in _queue.take(metered ? meteredAhead : _queue.length)) {
      if (_active >= maxParallel || _disposed) return;
      // shortcut: a key marked ready is trusted; if evicted, ready() re-downloads it.
      if (_jobs.containsKey(i.key) || phases.value[i.key] == StreamPhase.ready) continue;
      var cached = false;
      try {
        cached = await cache.fileFor(i.key) != null;
      } on Object catch (e, st) {
        AppLog.w('stream preparer: cache lookup failed', e, st);
      }
      if (_jobs.containsKey(i.key) || _active >= maxParallel || _disposed) continue; // changed meanwhile
      if (cached) {
        _setPhase(i.key, StreamPhase.ready);
      } else if (room ??= await cache.measure() < await cache.effectiveLimit()) {
        // A prefetch never evicts and can overshoot the limit by up to maxParallel
        // files (trimmed by the next requested put/evict). Room is computed once per pass.
        if (_jobs.containsKey(i.key) || _active >= maxParallel || _disposed) continue;
        _start(_jobs[i.key] = _Job(i.key, i.result));
      }
    }
  }

  void _start(_Job j) {
    _active++;
    j.phase = StreamPhase.downloading;
    _setPhase(j.key, StreamPhase.downloading);
    unawaited(_run(j));
  }

  static bool _isRateLimited(Object e) =>
      e is YtException &&
      (e.kind == YtErrorKind.rateLimited ||
          (e.detail ?? '').toLowerCase().contains('http error 403'));

  Future<void> _run(_Job j) async {
    File? part;
    Object? error;
    for (var attempt = 1; attempt <= 2 && part == null && !_disposed && !j.dropped; attempt++) {
      try {
        j.attempt = attempt;
        part = await _download(j);
      } on Object catch (e, st) {
        if (j.dropped) break; // cancelled on purpose
        if (j.restarting) {
          j.restarting = false; // restart(): run the same attempt again
          attempt--;
          continue;
        }
        AppLog.w('stream download of ${j.key} ($attempt)', e, st);
        error = e;
        if (isAgeRestricted(e) && !j.ageTried) {
          j.ageTried = true;
          j.substitute = await _ageSubstitute(j.result);
          if (j.substitute != null) {
            attempt--; // not a failed attempt: same one, with the substitute
            continue;
          }
        }
        if (isAgeRestricted(e)) break; // a retry would be refused the same way
        if (_isRateLimited(e)) {
          _pausedUntil = DateTime.now().add(cooldown);
          _resume?.cancel();
          _resume = Timer(cooldown, _pump);
          if (!j.requested) {
            // Prefetch only: forget it, the queue walk picks it up after the pause.
            final mine = identical(_jobs[j.key], j); // the key may have been re-queued
            if (mine) _jobs.remove(j.key);
            if (mine && !_disposed) phases.value = {...phases.value}..remove(j.key);
            _logTiming(j, 'failed');
            return _finish();
          }
        }
      }
    }
    if (j.dropped) {
      _yielding.remove(j);
      // Left the queue mid-download: nobody waits for it, leave no trace.
      final leftover = part;
      if (leftover != null) {
        unawaited(leftover.delete().catchError((Object e, StackTrace st) {
          AppLog.w('stream preparer: cannot delete ${leftover.path}', e, st);
          return leftover; // File.delete's future type
        }));
      }
      _logTiming(j, 'dropped');
      return _finish();
    }
    if (_disposed) error = StateError('disposed');
    if (part != null && !_disposed) {
      try {
        final file = await cache.put(j.key, part, trim: j.requested);
        await tracks.upsertStreamRow(j.key, j.result, file);
        j.cached = _ms(j);
        _logTiming(j, 'ok');
        if (identical(_jobs[j.key], j)) _jobs.remove(j.key);
        _setPhase(j.key, StreamPhase.ready);
        j.done.complete(file);
        return _finish();
      } on Object catch (e, st) {
        AppLog.w('stream cache/row of ${j.key}', e, st);
        error = e;
      }
    }
    _logTiming(j, 'failed');
    _fail(j, error ?? StateError('no download'));
    _finish();
  }

  /// First YouTube Music song other than [r] lasting within 10 s of it (any, if [r] has no length).
  Future<YtResult?> _ageSubstitute(YtResult r) async {
    try {
      final c = cleanSearchQuery(r.title, r.channel);
      final found = await youtube.searchSongs('${c.title} ${c.artist}'.trim()).timeout(ageSearchTimeout);
      for (final s in found) {
        final d = r.duration, sd = s.duration;
        if (s.id == r.id || (d != null && (sd == null || (sd - d).inSeconds.abs() > 10))) continue;
        AppLog.i('age fallback ${r.id} -> ${s.id}');
        return s;
      }
    } on Object catch (e, st) {
      AppLog.w('age fallback search for ${r.id} failed', e, st);
    }
    return null;
  }

  int _ms(_Job j) => clock().difference(j.t0!).inMilliseconds;

  /// One line per job: where the time of a streamed track went.
  void _logTiming(_Job j, String result) {
    String v(int? x) => x?.toString() ?? '-';
    AppLog.i('stream timing key=${j.key} requested=${j.requested ? 1 : 0} attempt=${j.attempt} '
        'spawn=${v(j.spawn)} url=${v(j.urlMs)} downloaded=${v(j.downloaded)} post=${v(j.post)} cached=${v(j.cached)} result=$result');
  }

  void _finish() {
    _active--;
    if (!_disposed) _pump();
  }

  /// Downloads into a temp folder inside the cache and returns the file as
  /// `<key>.<ext>.part`, the shape [StreamCache.put] takes.
  Future<File> _download(_Job j) async {
    final name = streamFileName(j.key);
    // A folder and a token per attempt: a hung attempt must not share them with the retry.
    final tmp = Directory(p.join(cache.dir.path, '.dl-$name-${_tmpSeq++}'));
    final cancel = j.cancel = CancelToken();
    j.t0 = clock();
    j.spawn = j.urlMs = j.downloaded = j.post = j.cached = null;
    j.streamUrl = null;
    try {
      String? path;
      // One attempt that hangs counts as a failed attempt.
      path = await (() async {
        String? found;
        var stalled = false, downloaded = false;
        Timer? dog;
        void arm(Duration wait) {
          dog?.cancel();
          dog = Timer(wait, () {
            stalled = true;
            cancel.cancel('attempt stalled'); // the downloader ends its stream on cancel
          });
        }
        arm(startTimeout);
        try {
          await for (final e in youtube.download(j.substitute ?? j.result, tmp,
              cancel: cancel, options: const DownloadOptions(emitStreamUrl: true))) {
            j.spawn ??= _ms(j);
            final u = e.streamUrl;
            if (u != null) _onUrl(j, u, e.headers ?? const {});
            found = e.path ?? found;
            if (e.path != null) j.downloaded ??= _ms(j);
            // 100% reached: yt-dlp is silent while ffmpeg post-processes; only attemptTimeout applies.
            if (e.total > 0 && e.received >= e.total) downloaded = true;
            if (downloaded) {
              j.downloaded ??= _ms(j);
              dog?.cancel();
            } else if (e.received > 0 || e.path != null || u == null) {
              // An address-only event is not download progress: keep startTimeout until real progress.
              arm(stallTimeout);
            }
          }
        } on Object {
          if (stalled) throw TimeoutException('download stalled', stallTimeout);
          rethrow;
        } finally {
          dog?.cancel();
        }
        if (stalled) throw TimeoutException('download stalled', stallTimeout);
        j.post = _ms(j);
        return found;
      })().timeout(attemptTimeout, onTimeout: () {
        cancel.cancel('attempt timed out');
        throw TimeoutException('download attempt', attemptTimeout);
      });
      if (path == null) throw StateError('download ended without a file');
      return await File(path).rename(p.join(cache.dir.path, '$name${p.extension(path)}.part'));
    } finally {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    }
  }
}
