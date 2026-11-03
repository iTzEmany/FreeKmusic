import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show listEquals;

import '../../core/app_log.dart';
import '../../core/import_row.dart';
import '../../data/db/app_database.dart';
import '../audio/codecore_audio_handler.dart' show PlaybackFailure, PlaybackFailureReason;
import '../audio/online_entries.dart';
import '../import/track_matcher.dart';
import '../online/youtube_service.dart';
import '../online/ytm_radio_parser.dart';
import '../online/ytm_radio_service.dart';
import 'insertion_plan.dart';
import 'seed_resolver.dart';
import 'shuffle_host.dart';
import 'suggestion_log.dart';
import 'suggestion_pool.dart';

/// The user's choices (settings, phase 31.12).
class ShufflePlusConfig {
  const ShufflePlusConfig({this.enabled = false, this.every = 4, this.unmeteredOnly = true});

  final bool enabled;

  /// One suggestion every [every] songs (3 to 10).
  final int every;
  final bool unmeteredOnly;
}

/// Told to the user once.
enum ShufflePlusNotice { rateLimited, tooManyErrors }

class _Seed {
  _Seed(this.track);

  final Track track;
  String? videoId;
  bool fetched = false;
  bool searchOnly = false;
  bool dead = false;
}

/// Puts a song you do not have in the queue every N songs of a shuffled
/// list. It works from [ShuffleHost] events; every piece of the outside
/// world is passed in so it runs on fakes.
class ShufflePlusController {
  ShufflePlusController({
    required this.host,
    required this.online,
    required this.log,
    required this.resolver,
    required this.radio,
    required this.config,
    required this.jamActive,
    required this.isMetered,
    required this.toolAvailable,
    required this.loadTracks,
    required this.loadLibrary,
    required this.hasDownload,
    this.prepare,
    this.enrichSuggested,
    this.enrichTimeout = blockEnrichTimeout,
    SuggestionPool? pool,
    DateTime Function()? now,
    Random? random,
  })  : pool = pool ?? SuggestionPool(),
        _now = now ?? DateTime.now,
        _random = random ?? Random();

  static const minRadioGap = Duration(minutes: 1);
  static const rateLimitPause = Duration(minutes: 15);
  static const retryAfterError = Duration(minutes: 2);
  static const seedsLifetime = 8;
  static const minSourceSize = 5;
  static const maxErrors = 3;
  static const prepareAttempts = 2;
  static const maxAhead = 3;

  /// Suggestions queued before they are enriched together (D-353).
  static const blockSize = 3;

  /// Longest the next suggestion waits for the enrichment of a block.
  static const blockEnrichTimeout = Duration(seconds: 60);

  final ShuffleHost host;
  final OnlineEntries online;
  final SuggestionLog log;
  final SuggestionPool pool;
  final SeedResolver resolver;
  final YtmRadioService radio;
  final ShufflePlusConfig Function() config;
  final bool Function() jamActive;

  /// True on a metered (mobile data) network.
  final Future<bool> Function() isMetered;
  final Future<bool> Function() toolAvailable;
  final Future<List<Track>> Function(List<int> ids) loadTracks;
  final Future<LibraryIndex> Function() loadLibrary;
  final bool Function(String videoId) hasDownload;

  /// Gets the stream address of a suggestion ready (throws when it cannot).
  /// A suggestion enters the queue only after this succeeds, so it never
  /// reaches its turn with a slow or failing address. Null: no preparation.
  final Future<void> Function(YtResult r)? prepare;

  /// Enriches the queue entries [ids] (text, curiosities, credits), waiting no
  /// longer than the given time; no new suggestion until it is done or [enrichTimeout]
  /// has passed. Null: no enrichment.
  final Future<void> Function(List<int> ids, Duration within)? enrichSuggested;
  final Duration enrichTimeout;
  final DateTime Function() _now;
  final Random _random;

  final _notices = StreamController<ShufflePlusNotice>.broadcast();
  Stream<ShufflePlusNotice> get notices => _notices.stream;

  final _subs = <StreamSubscription<Object?>>[];
  Timer? _timer;
  bool _running = false, _again = false, _disposed = false;

  int? _curId;
  int _played = 0;
  final _maxPos = <int, Duration>{};
  final _duration = <int, Duration>{};
  final _mine = <int>{};
  final _block = <int>[]; // suggestions queued since the last enrichment
  Future<void>? _enriching; // the block being enriched: no new suggestion meanwhile

  List<int>? _source;
  List<Track> _sourceTracks = const [];
  bool _eligible = false;
  List<_Seed> _seeds = [];
  int _suggestedWithSeeds = 0;
  final List<String> _lastArtists = [];
  LibraryIndex? _library;
  DateTime? _libraryAt;

  DateTime? _lastRadio, _retryAt, _pausedUntil;
  bool _rateNoticeShown = false;
  int _errors = 0;
  bool _sessionOff = false;

  /// Whether the three-failures stop is in force.
  bool get stoppedForSession => _sessionOff;

  void start() {
    _subs
      ..add(host.changes.listen((_) => poke()))
      ..add(host.positionStream.listen(_onPosition))
      ..add(host.durationStream.listen(_onDuration))
      ..add(host.failures.listen(_onFailure));
    poke();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    unawaited(_notices.close());
  }

  /// Looks again at everything (an event, a setting or the clock changed).
  void poke() {
    if (_disposed) return;
    if (_running) {
      _again = true;
      return;
    }
    unawaited(_run());
  }

  Future<void> _run() async {
    _running = true;
    try {
      await log.load();
      do {
        _again = false;
        await _step();
      } while (_again && !_disposed);
    } on Object catch (e, st) {
      AppLog.w('shuffle+ step failed', e, st);
      _retryAt = _now().add(retryAfterError);
      _wakeAt(_retryAt!);
    } finally {
      _running = false;
    }
  }

  int? get _current {
    final ids = host.queueIds, i = host.currentIndex;
    return i >= 0 && i < ids.length ? ids[i] : null;
  }

  void _onPosition(Duration p) {
    final id = _current;
    if (id == null) return;
    final old = _maxPos[id];
    if (old == null || p > old) _maxPos[id] = p;
  }

  void _onDuration(Duration? d) {
    final id = _current;
    if (id != null && d != null) _duration[id] = d;
  }

  void _onFailure(PlaybackFailure f) {
    if (f.reason != PlaybackFailureReason.onlineUnavailable &&
        f.reason != PlaybackFailureReason.networkUnavailable) {
      return;
    }
    if (++_errors < maxErrors || _sessionOff) return;
    _sessionOff = true;
    _notices.add(ShufflePlusNotice.tooManyErrors);
    poke();
  }

  void _wakeAt(DateTime at) {
    _timer?.cancel();
    final wait = at.difference(_now());
    _timer = Timer(wait.isNegative ? Duration.zero : wait, poke);
  }

  Future<void> _step() async {
    await _followCurrent();
    await _forgetGone();
    switch (await _gate()) {
      case _Gate.off:
        await _removePending();
      case _Gate.idle:
        break;
      case _Gate.go:
        await _suggest();
    }
  }

  /// Counts songs passed and closes the suggestion that was playing.
  Future<void> _followCurrent() async {
    final cur = _current;
    if (cur == _curId) return;
    final prev = _curId;
    _curId = cur;
    // Only our own suggestions leave the queue: a radio station or a stream
    // the user picked stays, so next and previous can come back to it.
    if (prev != null && _mine.contains(prev)) {
      await _finish(prev);
    } else if (prev != null) {
      _maxPos.remove(prev);
      _duration.remove(prev);
    }
    if (cur != null) _played = _mine.contains(cur) ? 0 : _played + 1;
  }

  Future<void> _finish(int id) async {
    final entry = online[id];
    final pos = _maxPos.remove(id) ?? Duration.zero;
    final length = _duration.remove(id);
    if (entry != null) {
      final heard = length != null && pos >= length - const Duration(seconds: 3);
      if (pos >= const Duration(seconds: 10)) _errors = 0;
      if (log.latest(entry.result.id)?.outcome == SuggestionOutcome.queued) {
        log.setOutcome(entry.result.id,
            heard ? SuggestionOutcome.heard : SuggestionOutcome.skipped);
      }
    }
    await _drop(id);
  }

  Future<void> _drop(int id) async {
    _mine.remove(id);
    await host.removeQueueId(id);
    online.forget(id);
  }

  /// Suggestions the user took out of the queue.
  Future<void> _forgetGone() async {
    final ids = host.queueIds.toSet();
    for (final id in _mine.toList()) {
      if (ids.contains(id) || id == _curId) continue;
      _mine.remove(id);
      final entry = online[id];
      if (entry != null && log.latest(entry.result.id)?.outcome == SuggestionOutcome.queued) {
        log.setOutcome(entry.result.id, SuggestionOutcome.skipped);
      }
      online.forget(id);
    }
  }

  /// The suggestion waiting after the current song leaves the queue.
  Future<void> _removePending() async {
    // The whole queue: with shuffle on, a suggestion sits after its natural
    // predecessor, so it may fall before the current song once shuffle is off.
    _block.clear();
    for (final id in host.queueIds.toList()) {
      if (id != _curId && _mine.contains(id)) await _drop(id);
    }
  }

  Future<_Gate> _gate() async {
    final cfg = config();
    if (!cfg.enabled || !host.shuffleEnabled || jamActive() || _sessionOff) {
      return _Gate.off;
    }
    await _syncSource();
    if (!_eligible || !await toolAvailable()) return _Gate.off;
    if (cfg.unmeteredOnly && await isMetered()) return _Gate.off;
    if (!host.isPlaying || _current == null) return _Gate.idle;
    final now = _now();
    final wait = [_pausedUntil, _retryAt].nonNulls.where(now.isBefore);
    if (wait.isNotEmpty) {
      _wakeAt(wait.reduce((a, b) => a.isAfter(b) ? a : b));
      return _Gate.idle;
    }
    return _Gate.go;
  }

  Future<void> _syncSource() async {
    final src = host.sourceIds;
    if (src == null) {
      _source = null;
      _eligible = false;
      return;
    }
    if (listEquals(src, _source)) return;
    _source = src;
    pool.clear();
    _seeds = [];
    _suggestedWithSeeds = 0;
    _block.clear();
    _sourceTracks = await loadTracks(src);
    _eligible = _sourceTracks.where((t) => !t.missing && t.kind == 0).length >= minSourceSize;
    final cur = _current;
    _played = cur == null || isOnlineId(cur) ? 0 : 1;
  }

  /// Fills every free slot of the plan, one suggestion after the other.
  Future<void> _suggest() async {
    while (!_disposed && await _suggestOne()) {}
  }

  List<int> _plan() => plusPlan(host.queueIds, host.currentIndex,
      config().every.clamp(3, 10),
      playedSinceLast: _played, max: maxAhead);

  /// True when one more was inserted (the plan may have more slots).
  Future<bool> _suggestOne() async {
    await _followCurrent();
    if (_enriching != null || _plan().isEmpty) return false;
    final src = _source;
    var candidate = await _take();
    if (candidate == null) {
      await _fill();
      if (_changedSince(src)) return false;
      candidate = await _take();
    }
    if (candidate == null || _changedSince(src)) return false;
    final prep = prepare;
    if (prep != null) {
      // A failed address is not a playback failure: the next candidate.
      var attempts = 0;
      while (true) {
        try {
          await prep(candidate!.result);
          break;
        } on Object catch (e) {
          AppLog.w('shuffle+ address of ${candidate!.result.id} not ready: $e');
          candidate = ++attempts >= prepareAttempts ? null : await _take();
          if (candidate == null) {
            _retryAt = _now().add(retryAfterError);
            _wakeAt(_retryAt!);
            return false;
          }
        }
        if (_disposed || _changedSince(src)) return false;
      }
      if (_disposed || _changedSince(src) || !config().enabled || !host.shuffleEnabled || jamActive()) return false;
    }
    // The queue may have changed while the radio was asked for.
    final plan = _plan();
    if (plan.isEmpty) return false;
    final at = plan.first;
    final r = candidate.result;
    final id = online.register(r, seedTitle: candidate.seedTitle, suggested: true);
    _mine.add(id);
    log.add(
      videoId: r.id,
      title: r.title,
      artist: r.artists.isEmpty ? r.channel : r.artists.join(', '),
      seedTitle: candidate.seedTitle,
    );
    _lastArtists
      ..add(suggestionArtistKey(r))
      ..removeRange(0, max(0, _lastArtists.length - 2));
    _suggestedWithSeeds++;
    host.insertAt(at, id);
    _block.add(id);
    if (_block.length >= blockSize) {
      // Not awaited: the rest of the engine (a skip, Shuffle+ turned off) goes on.
      _enriching = _enrichBlock().whenComplete(() {
        _enriching = null;
        poke();
      });
    }
    return true;
  }

  /// Enriches the queued block before the next suggestion; a slow or failing
  /// enrichment never stops Shuffle+.
  Future<void> _enrichBlock() async {
    final ids = List.of(_block);
    _block.clear();
    final enrich = enrichSuggested;
    if (enrich == null) return;
    AppLog.i('shuffle+ enrich block ids=$ids');
    try {
      await enrich(ids, enrichTimeout).timeout(enrichTimeout);
    } on TimeoutException {
      AppLog.w('shuffle+ enrich block timed out ids=$ids');
    } on Object catch (e, st) {
      AppLog.w('shuffle+ enrich block failed ids=$ids', e, st);
    }
  }

  /// True when the queue's source is no longer [src]: whatever was computed
  /// for it is stale. Asks for another look, which re-syncs the source.
  bool _changedSince(List<int>? src) {
    final changed = !listEquals(host.sourceIds, src);
    if (changed) poke();
    return changed;
  }

  Future<SuggestionCandidate?> _take() async {
    await log.load();
    final queued = {
      for (final id in host.queueIds)
        if (isOnlineId(id)) ?online[id]?.result.id,
    };
    final library = _library;
    return pool.take(
      inLibrary: (r) =>
          hasDownload(r.id) ||
          (library?.find(ImportRow(
                    index: 0,
                    title: r.title,
                    artists: r.artists.isEmpty ? [r.channel] : r.artists,
                    durationMs: r.duration?.inMilliseconds,
                  )) !=
              null),
      inQueue: queued.contains,
      log: log,
      lastArtists: _lastArtists,
    );
  }

  /// One radio request, at most once a minute, for the next seed that has no
  /// page yet (or the next page of one that ran dry).
  Future<void> _fill() async {
    final src = _source;
    final now = _now();
    final last = _lastRadio;
    if (last != null && now.difference(last) < minRadioGap) {
      _retryAt = last.add(minRadioGap);
      _wakeAt(_retryAt!);
      return;
    }
    try {
      final stale = _library == null ||
          now.difference(_libraryAt!) > const Duration(minutes: 5);
      if (stale) {
        _library = await loadLibrary();
        _libraryAt = now;
        if (_changedSince(src)) return;
      }
      if (_seeds.isEmpty || _suggestedWithSeeds >= seedsLifetime) _newSeeds();
      var searches = 0;
      for (final seed in _seeds) {
        if (seed.dead) continue;
        final needsPage = !seed.fetched ||
            (pool.pending(seed.key) == 0 && pool.continuationOf(seed.key) != null);
        if (!needsPage) continue;
        if (seed.videoId == null) {
          if (searches >= 3) break;
          searches++;
          seed.videoId = await resolver.resolve(seed.track, searchOnly: seed.searchOnly);
          if (_changedSince(src)) return;
          if (seed.videoId == null) {
            seed.dead = true;
            continue;
          }
        }
        _lastRadio = _now();
        final page = await radio.page(seed.videoId!,
            continuation: seed.fetched ? pool.continuationOf(seed.key) : null);
        if (_changedSince(src)) return;
        final hasSong = page.items.any((i) => i.isSeed && i.kind == RadioKind.song);
        if (!seed.fetched && !hasSong && !seed.searchOnly) {
          // The id was a video clip's: look the song up and ask again later.
          seed.searchOnly = true;
          seed.videoId = null;
          _retryAt = _lastRadio!.add(minRadioGap);
          _wakeAt(_retryAt!);
          return;
        }
        seed.fetched = true;
        pool.addPage(seed.key, seed.track.title, page);
        return;
      }
      // Every seed is dry or unknown: other seeds next time.
      _seeds = [];
      _retryAt = _now().add(retryAfterError);
      _wakeAt(_retryAt!);
    } on YtException catch (e) {
      if (e.kind == YtErrorKind.rateLimited) {
        _pausedUntil = _now().add(rateLimitPause);
        _wakeAt(_pausedUntil!);
        if (!_rateNoticeShown) {
          _rateNoticeShown = true;
          _notices.add(ShufflePlusNotice.rateLimited);
        }
      } else {
        AppLog.w('shuffle+ request failed: $e');
        _retryAt = _now().add(retryAfterError);
        _wakeAt(_retryAt!);
      }
    }
  }

  void _newSeeds() {
    pool.clear();
    _suggestedWithSeeds = 0;
    _seeds = [
      for (final t in chooseSeeds(_sourceTracks, random: _random)) _Seed(t),
    ];
  }
}

enum _Gate { go, idle, off }

extension on _Seed {
  /// Key of the seed in the pool.
  String get key => '${track.id}';
}
