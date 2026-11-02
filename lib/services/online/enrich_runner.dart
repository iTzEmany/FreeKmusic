import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/app_log.dart';
import '../../core/clock.dart';
import '../../data/repositories/credits_repository.dart';
import 'enrich_engine.dart';
import 'enrich_parts.dart';

/// What one run of [EnrichRunner] did: tracks worked, and the ids that got
/// something (`updated`) or were asked with an empty answer (`none`), per part.
class EnrichRound {
  int worked = 0;

  /// The run stopped on an error (logged), lost a write (a track or a whole
  /// block not saved) or stopped with [noAnswer]: the rest of the library waits
  /// for the next run; what was read before it is written and counted here.
  bool failed = false;

  /// The run stopped because the sources answered none of the last tracks.
  bool noAnswer = false;

  /// A source answered «too many requests» and its part was left out.
  bool limited = false;

  /// Every part was refused before the ids were used up.
  bool allRefused = false;

  /// The run ended with tracks in a row that got no answer (offline), cancel aside.
  bool endedSilent = false;

  /// Tracks gone through (a cancelled one is not counted).
  int processed = 0;
  final Map<EnrichPart, List<int>> updated = {};
  final Map<EnrichPart, List<int>> none = {};

  /// Tracks recognised in this run, by `RecogSource.name`.
  final Map<String, int> sources = {};

  static Set<int> _tracks(Map<EnrichPart, List<int>> m) => {for (final l in m.values) ...l};

  /// Distinct tracks that got something.
  int get updatedTracks => _tracks(updated).length;

  /// Distinct tracks asked in vain for every part (one that got a part is not counted twice).
  int get notFoundTracks => _tracks(none).difference(_tracks(updated)).length;
}

/// Where a run takes its ids from, and how far it got.
abstract class EnrichIds {
  /// The next at most [limit] ids to work on; empty when there are no more.
  Future<List<int>> chunk(
    Set<EnrichPart> parts,
    AskMode mode,
    DateTime now,
    int limit,
  );

  /// [id] is being worked on.
  void tried(int id);

  /// A block ends: the position is kept.
  void checkpoint();

  /// The progress is cheap to read: report it after each track.
  bool get perTrack => false;

  /// Tracks done and tracks in all, for the progress line.
  Future<({int done, int total})> progress(Set<EnrichPart> parts, DateTime now);
}

/// A fixed list of ids (the manual job), each once.
class FixedIds implements EnrichIds {
  FixedIds(this.ids);

  final List<int> ids;
  int _next = 0, _done = 0;

  @override
  Future<List<int>> chunk(
    Set<EnrichPart> parts,
    AskMode mode,
    DateTime now,
    int limit,
  ) async {
    final to = _next + limit < ids.length ? _next + limit : ids.length;
    final chunk = ids.sublist(_next, to);
    _next = to;
    return chunk;
  }

  @override
  void tried(int id) => _done++;

  @override
  void checkpoint() {}

  @override
  bool get perTrack => true;

  @override
  Future<({int done, int total})> progress(
    Set<EnrichPart> parts,
    DateTime now,
  ) async => (done: _done, total: ids.length);
}

/// The library by id, from a bookmark (the last track tried) to the end, then
/// once from the start up to the bookmark. One cursor per run: it loads,
/// advances and saves the bookmark, nobody else.
class MarkCursor implements EnrichIds {
  MarkCursor(this.repo, {int Function()? load, this.save})
    : _start = load?.call() ?? 0 {
    _after = _saved = _start;
  }

  final CreditsRepository repo;

  /// Called with the bookmark, once per block. Without it every run starts
  /// from the first track.
  final void Function(int id)? save;
  final int _start;
  late int _after, _saved;
  late var _canWrap = _start > 0;
  late final _wrapTo = _start; // the wrap pass goes up to here
  var _wrapped = false;

  Future<List<int>> _query(
    Set<EnrichPart> parts,
    AskMode mode,
    DateTime now,
    int limit,
  ) => repo.dueTrackIds(
    parts,
    now,
    limit: limit,
    mode: mode,
    after: _after,
    upTo: _wrapped ? _wrapTo : null,
  );

  @override
  Future<List<int>> chunk(
    Set<EnrichPart> parts,
    AskMode mode,
    DateTime now,
    int limit,
  ) async {
    final ids = await _query(parts, mode, now, limit);
    if (ids.isNotEmpty || !_canWrap) return ids;
    _canWrap = false;
    _wrapped = true;
    _after = 0;
    return _query(parts, mode, now, limit);
  }

  @override
  void tried(int id) => _after = id;

  @override
  bool get perTrack => false;

  /// Saved before the block is written and also when it fails (or every read
  /// threw), so a bad block is not retried at each start; lost tracks come
  /// back after the wrap.
  @override
  void checkpoint() {
    if (_after > 0 && _after != _saved) {
      _saved = _after;
      save?.call(_after);
    }
  }

  @override
  Future<({int done, int total})> progress(
    Set<EnrichPart> parts,
    DateTime now,
  ) async {
    final c = await repo.enrichCounts(parts, now);
    return (done: c.complete, total: c.total);
  }
}

/// The one-off re-pass of R-176: tracks with a finished enrichment and no
/// recognition of this version, by id, from a bookmark. [query] gives the
/// candidates (see `recogPassQuery`); [needs] is `needsRecognition` on one of
/// them, so a track that needs nothing is skipped here with two reads and no
/// wait. The bookmark never passes a track that needed recognition and did not
/// get its rec saved (lost in a failed block, offline, cancelled): those come
/// back at the next start, and the pass is [complete] only without them.
class RecogPassIds implements EnrichIds {
  RecogPassIds(this.query, this.needs, {int Function()? load, this.save, this.interrupt}) {
    _scan = _saved = load?.call() ?? 0;
  }

  final Future<List<int>> Function(int after, int limit) query;
  final Future<bool> Function(int id) needs;
  final void Function(int id)? save;

  /// Asked between chunks: true stops the pass (the bookmark stays) to let other work go first.
  final Future<bool> Function()? interrupt;
  late int _scan, _saved;
  int? _hold; // the first track that needed recognition and was not saved
  var _pending = <int>[];
  var _exhausted = false;

  /// The pass stopped on [interrupt] before the end.
  bool interrupted = false;

  /// Settles the last block and says whether the whole pass went through with nothing lost.
  /// [healthy]: the round itself had no failure, silence, limit or cancel; a track still unsaved
  /// then is stably lost (no source knows it, an unreadable file): it is passed over, not held.
  Future<bool> complete({required bool healthy}) async {
    await _settle();
    if (healthy && _hold != null) {
      AppLog.i('recognition pass: track $_hold not recognised, passed over');
      _hold = null;
      await _settle();
    }
    return _exhausted && _hold == null;
  }

  Future<void> _settle() async {
    for (final id in _pending) {
      if (_hold == null && await needs(id)) _hold = id;
    }
    _pending = [];
    final mark = _hold == null ? _scan : _hold! - 1;
    if (mark != _saved) {
      _saved = mark;
      save?.call(mark);
    }
  }

  @override
  Future<List<int>> chunk(Set<EnrichPart> parts, AskMode mode, DateTime now, int limit) async {
    await _settle();
    if (await interrupt?.call() ?? false) {
      interrupted = true;
      return const [];
    }
    while (true) {
      final cands = await query(_scan, limit);
      if (cands.isEmpty) {
        _exhausted = true;
        return const [];
      }
      _scan = cands.last;
      final work = [
        for (final id in cands)
          if (await needs(id)) id,
      ];
      if (work.isNotEmpty) return _pending = work;
      await _settle(); // a block of tracks that need nothing: the bookmark moves on
    }
  }

  @override
  void tried(int id) {}

  @override
  void checkpoint() {}

  @override
  bool get perTrack => false;

  // shortcut: the pass shows no progress of its own (the state keeps the first round's numbers); add it when the pass gets a bar.
  @override
  Future<({int done, int total})> progress(Set<EnrichPart> parts, DateTime now) async => (done: 0, total: 0);
}

/// One run over the ids of an [EnrichIds]: tracks with a part that is on and
/// due, one at a time, their writes gathered into one transaction every
/// [blockSize] tracks. No Riverpod; the state lives in the database, so a new
/// run simply carries on where the last one stopped. Single use.
class EnrichRunner {
  EnrichRunner({
    required this.engine,
    required this.ids,
    required this.parts,
    required this.waitIdle,
    this.mode = AskMode.due,
    this.onProgress,
    this.onWaiting,
    int Function()? nowMs,
  }) : _nowMs = nowMs ?? _clock;

  static int _clock() => nowMs();

  static const blockSize = 10;
  static const _chunk = 20;
  static const _maxStuck = 5;

  final EnrichEngine engine;
  final EnrichIds ids;

  /// The parts the switches turn on, read at each chunk.
  final Set<EnrichPart> Function() parts;

  /// Completes when the user leaves the app alone (and no pause is on).
  /// Only a run in [AskMode.due] waits for it.
  final Future<void> Function() waitIdle;

  /// After each committed block: tracks done, tracks in all.
  final void Function(int done, int total)? onProgress;

  /// True while the run waits for the user to leave the app alone; false when it stops waiting.
  final void Function(bool waiting)? onWaiting;
  final int Function() _nowMs;

  bool _cancelled = false;
  final _token = CancelToken();

  /// [cancel] was called.
  bool get cancelled => _cancelled;

  /// How the parts are asked.
  final AskMode mode;
  Completer<void>? _wake;

  /// No track is started after the one in progress, the request in flight is
  /// aborted, and a wait for the user ends at once.
  void cancel() {
    _cancelled = true;
    _token.cancel();
    _poke();
  }

  void _poke() {
    final w = _wake;
    if (w != null && !w.isCompleted) w.complete();
  }

  /// Waits for the user to leave the app alone, or for [cancel].
  /// While the user is busy, what is gathered is written first: a track
  /// stays claimed by the engine until its block commits.
  Future<void> _idle(List<EnrichGather> block, EnrichRound round) async {
    final wake = _wake = Completer<void>();
    final idle = waitIdle();
    var ready = false;
    unawaited(idle.then((_) => ready = true, onError: (Object _) => ready = true)); // the error surfaces below
    await Future<void>.delayed(Duration.zero); // after every microtask: an idle user is never «busy» here
    if (!ready && block.isNotEmpty && !_cancelled) {
      await _commit(block, round);
    }
    final shown = !ready;
    if (shown) onWaiting?.call(true);
    try {
      await Future.any([idle, wake.future]);
    } finally {
      if (shown) onWaiting?.call(false);
      _wake = null;
    }
  }

  /// One run until nothing is due, [cancel] or an error.
  Future<EnrichRound> run() async {
    final round = EnrichRound();
    final refused = <EnrichPart>{}; // a source that said «too many requests»: not again in this round
    final block = <EnrichGather>[];
    var wanted = parts();
    var exhausted = false, skipped = false; // skipped: a track of the chunk was left unvisited
    var stuck = 0; // tracks in a row that asked a source and got no answer (offline); one that asked nothing doesn't count
    Set<EnrichPart> switchedOn() => wanted = parts().difference(refused);
    try {
      try {
        while (!_cancelled && stuck < _maxStuck && switchedOn().isNotEmpty) {
          final chunk = await ids.chunk(
            wanted,
            mode,
            DateTime.fromMillisecondsSinceEpoch(_nowMs()),
            _chunk,
          );
          if (chunk.isEmpty) {
            exhausted = true;
            break;
          }
          for (final id in chunk) {
            if (_cancelled) break;
            if (mode == AskMode.due) await _idle(block, round);
            await engine.limiter.wait();
            if (_cancelled) break;
            // The switches may have changed since the chunk was read.
            if (switchedOn().isEmpty) {
              skipped = true;
              break;
            }
            try {
              final g = await engine.gather(id, wanted, mode: mode, cancel: _token);
              block.add(g);
              switch (g.signal) {
                case GatherSignal.answered:
                  stuck = 0;
                case GatherSignal.silent:
                  stuck++;
                case GatherSignal.askedNothing:
                  break;
              }
              // LRCLIB resting is temporary: the lyrics parts stay on and the chain asks it again when the rest ends.
              final lyricsRest = engine.chain.isResting;
              final limited = [
                for (final e in g.out.entries)
                  if (e.value == PartOutcome.limited && !(lyricsRest && (e.key == EnrichPart.lyrics || e.key == EnrichPart.synced))) e.key,
              ];
              if (limited.isNotEmpty) round.limited = true;
              refused.addAll(limited);
              round.processed++;
            } on Object catch (e, st) {
              // Aborted by [cancel]: not tried, so a later run starts with it.
              if (e is DioException && CancelToken.isCancel(e)) break;
              round.processed++;
              if (e is Error) {
                AppLog.e('completion: track $id not read', e, st);
              } else {
                AppLog.w('completion: track $id not read', e, st);
              }
              stuck++;
            }
            ids.tried(id);
            if (ids.perTrack) {
              final c = await ids.progress(wanted, DateTime.fromMillisecondsSinceEpoch(_nowMs()));
              onProgress?.call(c.done, c.total);
            }
            if (stuck >= _maxStuck) {
              AppLog.w('completion: $_maxStuck tracks in a row got no answer, round stopped');
              round.failed = round.noAnswer = true;
              break;
            }
            if (block.length >= blockSize) await _commit(block, round);
          }
          await _commit(block, round);
        }
      } finally {
        // Whatever was read is written, also after an error or a cancel.
        await _commit(block, round);
      }
      round.endedSilent = stuck > 0 && !_cancelled;
      round.allRefused = !exhausted && !_cancelled && stuck < _maxStuck && refused.isNotEmpty && wanted.isEmpty;
      // The last track may have refused the last part: nothing was left (read-only, no cursor move).
      if (round.allRefused && !skipped) {
        final c = await ids.progress(parts(), DateTime.fromMillisecondsSinceEpoch(_nowMs()));
        round.allRefused = c.done < c.total;
      }
    } on Object catch (e, st) {
      if (e is Error) {
        AppLog.e('completion: round stopped', e, st);
      } else {
        AppLog.w('completion: round stopped', e, st);
      }
      round.failed = true;
    }
    return round;
  }

  Future<void> _commit(List<EnrichGather> block, EnrichRound round) async {
    ids.checkpoint();
    if (block.isEmpty) return;
    final items = [...block];
    block.clear();
    try {
      for (final (i, r) in (await engine.commit(items)).indexed) {
        if (r.lost) round.failed = true;
        final src = items[i].rec?.src;
        if (src != null && !r.lost) round.sources.update(src.name, (n) => n + 1, ifAbsent: () => 1);
        if (!r.out.values.any((o) => o.answered)) continue;
        round.worked++;
        for (final MapEntry(key: part, value: o) in r.out.entries) {
          final into = switch (o) {
            PartOutcome.found => round.updated,
            PartOutcome.none => round.none,
            _ => null,
          };
          into?.putIfAbsent(part, () => []).add(r.trackId);
        }
      }
    } on Object catch (e, st) {
      if (e is Error) {
        AppLog.e('completion: block of ${items.length} not saved', e, st);
      } else {
        AppLog.w('completion: block of ${items.length} not saved', e, st);
      }
      round.failed = true;
    }
    final c = await ids.progress(
      parts(),
      DateTime.fromMillisecondsSinceEpoch(_nowMs()),
    );
    onProgress?.call(c.done, c.total);
  }
}
