import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../core/text_utils.dart';
import 'retry_policy.dart';
import 'youtube_service.dart';

enum DownloadStatus {
  queued,
  downloading,

  /// A transient error: it goes back to [queued] after [DownloadItem.retryDelay].
  waitingRetry,
  done,
  failed,
  cancelled,
}

class DownloadItem {
  const DownloadItem({
    required this.id,
    required this.result,
    this.status = DownloadStatus.queued,
    this.progress = 0,
    this.error,
    this.path,
    this.tag,
    this.attempt = 0,
    this.retryDelay,
  });

  final int id;
  final YtResult result;
  final DownloadStatus status;
  final double progress;
  final YtErrorKind? error;
  final String? path;

  /// Opaque label from whoever queued it (e.g. `import:<id>:<row>`).
  final String? tag;

  /// Automatic retries already scheduled; [retryDelay] is the current wait.
  final int attempt;
  final Duration? retryDelay;

  DownloadItem copyWith(
          {DownloadStatus? status,
          double? progress,
          YtErrorKind? error,
          String? path,
          int? attempt,
          Duration? retryDelay}) =>
      DownloadItem(
        id: id,
        result: result,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        error: error ?? this.error,
        path: path ?? this.path,
        tag: tag,
        attempt: attempt ?? this.attempt,
        retryDelay: retryDelay ?? this.retryDelay,
      );
}

typedef Downloader = Stream<DownloadProgress> Function(
    YtResult result, Directory outDir, CancelToken cancel);

/// Queue that runs up to [maxParallel] downloads at once, in arrival order.
class DownloadQueue {
  DownloadQueue({
    int maxParallel = 1,
    required this.downloader,
    required this.outDir,
    required this.onChanged,
    this.onDownloaded,
    this.onSettled,
    this.retryPolicy,
    this.wait = _sleep,
    this.uiInterval = const Duration(milliseconds: 200),
  }) : _maxParallel = maxParallel.clamp(1, 3);

  final Downloader downloader;
  final Future<Directory?> Function() outDir;
  final void Function(List<DownloadItem> items) onChanged;
  /// May answer the final path when the file moved (Android publishes it): the item takes it.
  final Future<Object?> Function(String path)? onDownloaded;

  /// Called once per item when it reaches done, failed or cancelled for good
  /// (after [onDownloaded] for the done ones); a retry is not a settlement.
  final void Function(DownloadItem item)? onSettled;
  final Duration uiInterval;

  /// Null = a failure is final at once.
  final RetryPolicy? retryPolicy;

  /// Injectable so tests need no real clock.
  final Future<void> Function(Duration) wait;

  static Future<void> _sleep(Duration d) => Future<void>.delayed(d);

  final List<DownloadItem> _items = [];
  final Map<int, CancelToken> _tokens = {};
  final Set<int> _active = {};
  int _maxParallel;
  int _nextId = 1;
  bool _disposed = false;

  int get maxParallel => _maxParallel;

  /// Takes effect at once when raised; running downloads are never stopped
  /// when it is lowered, the queue just starts fewer new ones.
  set maxParallel(int v) {
    _maxParallel = v.clamp(1, 3);
    _pump();
  }

  List<DownloadItem> get items => List.unmodifiable(_items);

  void add(YtResult r, {String? tag}) {
    _items.add(DownloadItem(id: _nextId++, result: r, tag: tag));
    _emit();
    _pump();
  }

  void cancel(int id) {
    _tokens[id]?.cancel();
    final i = _items.indexWhere((e) => e.id == id);
    if (i >= 0 &&
        (_items[i].status == DownloadStatus.queued ||
            _items[i].status == DownloadStatus.waitingRetry)) {
      _items[i] = _items[i].copyWith(status: DownloadStatus.cancelled);
      _emit();
      _settle(id);
    }
  }

  /// Cancels every queued or running item for which [test] is true.
  void cancelWhere(bool Function(DownloadItem item) test) {
    for (final e in List.of(_items)) {
      final live = e.status == DownloadStatus.queued ||
          e.status == DownloadStatus.waitingRetry ||
          e.status == DownloadStatus.downloading;
      if (live && test(e)) cancel(e.id);
    }
  }

  void clearFinished() {
    _items.removeWhere((e) =>
        e.status == DownloadStatus.done ||
        e.status == DownloadStatus.failed ||
        e.status == DownloadStatus.cancelled);
    _emit();
  }

  /// Cancels everything (app closing); `.part` files are removed by the downloader.
  void dispose() {
    _disposed = true;
    for (final t in _tokens.values) {
      t.cancel();
    }
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].status == DownloadStatus.queued ||
          _items[i].status == DownloadStatus.waitingRetry) {
        _items[i] = _items[i].copyWith(status: DownloadStatus.cancelled);
      }
    }
  }

  void _emit() {
    if (!_disposed) onChanged(items);
  }

  void _settle(int id) {
    if (_disposed) return;
    final i = _items.indexWhere((e) => e.id == id);
    if (i >= 0) onSettled?.call(_items[i]);
  }

  void _replace(int id, DownloadItem Function(DownloadItem) f) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i >= 0) _items[i] = f(_items[i]);
  }

  void _pump() {
    if (_disposed) return;
    while (_active.length < _maxParallel) {
      final i = _items.indexWhere((e) => e.status == DownloadStatus.queued);
      if (i < 0) return;
      final item = _items[i];
      _active.add(item.id);
      _items[i] = item.copyWith(status: DownloadStatus.downloading);
      unawaited(_runOne(item).whenComplete(() {
        _active.remove(item.id);
        _pump();
      }));
    }
  }

  Future<void> _runOne(DownloadItem item) async {
    var retrying = false;
    final token = CancelToken();
    _tokens[item.id] = token;
    _emit();
    try {
      final dir = await outDir();
      if (dir == null) {
        throw const YtException(YtErrorKind.changed, 'no output folder');
      }
      var lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
      String? path;
      final sub = item.result.subdir;
      final target = sub == null || sanitizeFileName(sub) == 'track'
          ? dir
          : Directory(p.join(dir.path, sanitizeFileName(sub)));
      await for (final prog in downloader(item.result, target, token)) {
        if (prog.path != null) path = prog.path;
        final now = DateTime.now();
        if (now.difference(lastEmit) >= uiInterval) {
          lastEmit = now;
          _replace(item.id, (e) => e.copyWith(progress: prog.fraction));
          _emit();
        }
      }
      if (token.isCancelled || path == null) {
        _replace(item.id, (e) => e.copyWith(status: DownloadStatus.cancelled));
      } else {
        _replace(item.id,
            (e) => e.copyWith(status: DownloadStatus.done, progress: 1, path: path));
        final moved = await onDownloaded?.call(path);
        if (moved is String && moved != path) _replace(item.id, (e) => e.copyWith(path: moved));
      }
    } on YtException catch (e, st) {
      AppLog.w('download of ${item.result.id} failed (${e.kind})', e.detail, st);
      retrying = _failOrRetry(item, e.kind, token);
    } on Object catch (e, st) {
      AppLog.e('download failed', e, st);
      retrying = _failOrRetry(item, YtErrorKind.internal, token); // our own failure, not YouTube's
    } finally {
      _tokens.remove(item.id);
      _emit();
      if (!retrying) _settle(item.id);
    }
  }

  /// Marks [item] failed, or schedules another attempt; true when retrying.
  bool _failOrRetry(DownloadItem item, YtErrorKind kind, CancelToken token) {
    final retries = _items.firstWhere((e) => e.id == item.id).attempt;
    final delay = token.isCancelled ? null : retryPolicy?.nextDelay(retries, kind);
    if (delay == null) {
      _replace(item.id,
          (x) => x.copyWith(status: DownloadStatus.failed, error: kind));
      return false;
    }
    _replace(
        item.id,
        (x) => x.copyWith(
            status: DownloadStatus.waitingRetry,
            error: kind,
            attempt: retries + 1,
            retryDelay: delay));
    unawaited(wait(delay).then((_) {
      final i = _items.indexWhere((e) => e.id == item.id);
      if (_disposed || i < 0 || _items[i].status != DownloadStatus.waitingRetry) {
        return;
      }
      _items[i] = _items[i].copyWith(status: DownloadStatus.queued);
      _emit();
      _pump();
    }));
    return true;
  }
}
