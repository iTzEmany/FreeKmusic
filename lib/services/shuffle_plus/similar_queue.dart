import 'dart:async';

import '../../core/app_log.dart';
import '../audio/codecore_audio_handler.dart';
import '../audio/online_entries.dart' show isOnlineId;
import '../online/youtube_service.dart';
import 'radio_fill.dart';

/// Songs similar to the one picked in Search, added at the end of the queue
/// after it: a first block, then another whenever few songs are left after
/// the current one (D-467). It lives until [close]: another queue starts (none
/// of its songs is queued any more), or a Jam begins. A download that swaps
/// the seed's id keeps it alive: the songs it added are still there.
class SimilarQueue {
  SimilarQueue({
    required this.handler,
    required this.fill,
    required this.seedId,
    required this.seedVideoId,
    required this.register,
    required this.onSuggested,
    required this.onClosed,
    required this.blocked,
    this.block = 10,
    this.low = 5,
    this.retryAfter = const Duration(minutes: 1),
    DateTime Function()? now,
    Timer Function(Duration, void Function())? schedule,
  }) : _now = now ?? DateTime.now,
       _schedule = schedule ?? Timer.new;

  final CodecoreAudioHandler handler;
  final RadioFill fill;

  /// The queue id of the seed, and its YouTube id (never suggested again).
  final int seedId;
  final String? seedVideoId;

  /// The queue id of a suggestion (its library track when downloaded).
  final Future<int?> Function(YtResult r, String seedTitle) register;
  final void Function(YtResult r, String seedTitle) onSuggested;
  final void Function() onClosed;

  /// True when the session must end (a Jam started).
  final bool Function() blocked;

  /// Songs asked for at once, and the songs left after the current one under
  /// which another block is asked.
  final int block, low;

  /// Wait after a failed request, so an error never makes a tight loop.
  final Duration retryAfter;
  final DateTime Function() _now;
  final Timer Function(Duration, void Function()) _schedule;

  final _seen = <String>{};
  late final _ids = <int>{seedId}; // the seed and what the session queued
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _timer;
  DateTime? _backoff;
  bool _busy = false, _closed = false;

  bool get closed => _closed;

  /// Asks the first block; true when at least one song came. The refill
  /// starts only then (an empty first block ends the session).
  Future<bool> start() async {
    if (seedVideoId != null) _seen.add(seedVideoId!);
    final n = await _take(block);
    if (_closed) return false;
    if (n == 0) {
      close();
      return false;
    }
    _subs
      ..add(handler.queueChanges.listen((_) => _check()))
      ..add(handler.currentTrackStream.listen((_) => _check()));
    // A failure inside the first block holds the next request back.
    final at = n < block ? _next() : null;
    at != null ? _wait(at) : _check();
    return true;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    onClosed();
  }

  /// A Jam started, or none of the session's songs is queued: another queue
  /// took over.
  bool _gone() {
    if (blocked()) return true;
    final queued = handler.queueIds.toSet();
    return !_ids.any(queued.contains);
  }

  void _check() {
    if (_closed) return;
    if (_gone()) return close();
    if (_busy || _timer != null) return;
    final left = handler.queueIds.length - 1 - handler.currentIndex;
    if (left >= low) return;
    unawaited(_refill());
  }

  Future<void> _refill() async {
    final n = await _take(block);
    if (_closed || n >= block) return;
    // Short of songs while the gate or a failure holds the radio: come back then.
    final at = _next();
    if (at != null) _wait(at);
  }

  /// When a request may be made again (null: now).
  DateTime? _next() {
    final now = _now();
    final gate = fill.gate.nextAsk;
    final b = _backoff;
    final times = [?gate, ?b].where(now.isBefore);
    return times.isEmpty ? null : times.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  void _wait(DateTime at) {
    _timer?.cancel();
    _timer = _schedule(at.difference(_now()), () {
      _timer = null;
      _check();
    });
  }

  /// Up to [want] songs at the end of the queue; returns how many got in.
  /// After every await the session may be over: nothing touches the queue then.
  Future<int> _take(int want) async {
    _busy = true;
    var added = 0;
    try {
      await for (final c in fill.take(
        want,
        inQueue: _seen.contains,
        cancelled: () => _closed,
      )) {
        final id = await register(c.result, c.seedTitle);
        if (_closed) break;
        if (_gone()) {
          close();
          break;
        }
        if (id == null) continue;
        _seen.add(c.result.id);
        // Two videos can match the same library track.
        if (!isOnlineId(id) && _ids.contains(id)) continue;
        _ids.add(id);
        handler.insertAt(handler.queueIds.length, id);
        // Logged once queued; a library track is no suggestion to remember.
        if (isOnlineId(id)) onSuggested(c.result, c.seedTitle);
        added++;
      }
    } on YtException catch (e, st) {
      AppLog.w('similar queue stopped', e, st);
      if (e.kind == YtErrorKind.rateLimited) fill.gate.trip();
      _backoff = _now().add(retryAfter);
    } on Object catch (e, st) {
      AppLog.w('similar queue stopped', e, st);
      _backoff = _now().add(retryAfter);
    } finally {
      _busy = false;
    }
    if (!_closed && _gone()) close();
    return added;
  }
}
