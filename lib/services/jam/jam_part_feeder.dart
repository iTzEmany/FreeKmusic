import 'dart:async';
import 'dart:math';

import '../../core/app_log.dart';
import 'jam_models.dart';
import 'jam_state.dart';

/// Part keys of library track [ids], in order: the id itself, and `id~n` for the
/// n-th repeat of the same track (a key is unique within a part, invariant 3).
List<String> jamPartKeys(Iterable<int> ids) {
  final seen = <int, int>{};
  return [
    for (final id in ids)
      () {
        final n = seen.update(id, (v) => v + 1, ifAbsent: () => 0);
        return n == 0 ? '$id' : '$id~$n';
      }(),
  ];
}

/// The library track id a part key stands for.
int? jamPartKeyId(String key) => int.tryParse(key.split('~').first);

/// Feeds this device's part of «Coda insieme» into the Jam (R-99, R-100, R-101).
///
/// The part is a list of keys. With the Jam in `together` mode the feeder sends the
/// next key as an `add` carrying `partKey` whenever the Jam holds fewer than
/// `ceil(maxJamItems / participants)` of our items after the current one. It never
/// sends a key that is in the Jam or was played; a sent key that leaves the Jam
/// unplayed was removed by someone and is forgotten; a failed send puts it back (invariant 3). With the part empty and
/// nothing of ours coming, it asks [suggest] for one track (R-102). It does nothing
/// in `host` mode, and picks up again when the Jam returns to `together`.
class JamPartFeeder {
  JamPartFeeder({
    required this.ownId,
    required List<String> part,
    required this.send,
    required this.itemOf,
    required this.suggest,
  })  : _waiting = [...part],
        _ord = {for (final (i, k) in part.indexed) k: i};

  final String ownId;

  /// Sends a command to the Jam (host: applies it).
  final Future<JamResult> Function(JamCommand) send;

  /// The item for a part key, with `partKey` set; null when the track is gone.
  final Future<JamItem?> Function(String key) itemOf;

  /// A suggested item (`suggested: true`) for a part that ran out, or null.
  final Future<JamItem?> Function(JamState) suggest;

  final List<String> _waiting;
  final Map<String, int> _ord; // position in the original part
  final _played = <String>{};
  var _seen = <String>{}; // sent and observed in the Jam
  var _inJam = <String>{};
  final _pending = <String, int>{}; // sent, not observed yet: key -> state version after the add
  // Sent but the answer was lost (transport error): the host may have applied it.
  // key -> version when sent. A state past it without the key: resend; a resend of a
  // key the host did apply is a no-op in the reducer.
  final _uncertain = <String, int>{};
  String? _flying; // taken from the part, being sent right now
  int? _sugVersion; // a suggestion sent, not observed yet
  JamState? _last;
  Future<void>? _running;
  var _dirty = false;
  var _disposed = false;

  /// Keys not yet in the Jam, in part order (what the guest finds when it leaves).
  List<String> get unsent =>
      {..._pending.keys, ..._uncertain.keys, ?_flying, ..._waiting}.toList()..sort((a, b) => _ord[a]!.compareTo(_ord[b]!));

  /// Library ids of our part left to play, for [js] in «Coda insieme»: our items after the
  /// current one, in order, then what the feeder still holds. Online items stay in the Jam
  /// for the host (D-93) and are not part of it. Empty in «Coda dell'host».
  List<int> remaining(JamState js) {
    if (js.mode != JamMode.together) return const [];
    final inJam = {
      for (final (n, i) in js.items.indexed)
        if (n > js.currentIndex && i.ownerDeviceId == ownId) i.partKey,
    };
    return [
      for (final (n, i) in js.items.indexed)
        if (n > js.currentIndex && i.ownerDeviceId == ownId) ?int.tryParse(i.ref ?? ''),
      for (final k in unsent)
        if (!inJam.contains(k)) ?jamPartKeyId(k),
    ];
  }

  /// The owner removed [key] from the Jam: it leaves the part for good (R-100).
  void forget(String key) {
    _ord.remove(key);
    _waiting.remove(key);
    _pending.remove(key);
    _uncertain.remove(key);
    _seen.remove(key);
  }

  void dispose() => _disposed = true;

  /// A new Jam state. The future completes when the feeder has nothing more to do.
  Future<void> update(JamState s) {
    _last = s;
    if (s.mode != JamMode.together) return _running ?? Future.value();
    _observe(s);
    _dirty = true;
    return _running ??= _run();
  }

  Future<void> _run() async {
    try {
      while (_dirty) {
        _dirty = false;
        await _fill();
      }
    } on Object catch (e, st) {
      AppLog.w('jam: part feeder failed', e, st);
    } finally {
      _running = null;
    }
  }

  void _observe(JamState s) {
    final cur = s.currentIndex;
    final inJam = <String>{};
    var after = 0;
    for (final (n, it) in s.items.indexed) {
      if (it.ownerDeviceId != ownId) continue;
      if (n > cur) after++;
      final k = it.partKey;
      if (k == null) continue;
      inJam.add(k);
      if (n <= cur) _played.add(k);
    }
    _inJam = inJam;
    final gone = <String>[
      for (final k in _seen)
        if (!inJam.contains(k) && !_played.contains(k)) k,
      for (final e in _pending.entries)
        if (!inJam.contains(e.key) && s.version >= e.value) e.key,
    ];
    _pending.removeWhere((k, v) => inJam.contains(k) || gone.contains(k));
    final retry = <String>[];
    _uncertain.removeWhere((k, v) {
      if (inJam.contains(k)) return true;
      if (s.version > v) {
        retry.add(k);
        return true;
      }
      return false;
    });
    for (final k in retry) {
      if (_ord.containsKey(k)) _waiting.add(k);
    }
    if (retry.isNotEmpty) _waiting.sort((a, b) => _ord[a]!.compareTo(_ord[b]!));
    _seen = inJam;
    final sv = _sugVersion;
    if (sv != null && (s.version >= sv || after > 0)) _sugVersion = null;
    _waiting.removeWhere((k) => inJam.contains(k) || _played.contains(k));
    // Seen in the Jam and gone unplayed: someone removed it, it stays removed.
    for (final k in gone) {
      forget(k);
    }
  }

  Future<void> _fill() async {
    while (true) {
      final s = _last;
      if (_disposed || s == null || s.mode != JamMode.together || s.ended) return;
      if (!await _step(s)) return;
    }
  }

  /// One send. True: something was consumed, look again.
  Future<bool> _step(JamState s) async {
    try {
      return await _stepInner(s);
    } finally {
      _flying = null;
    }
  }

  Future<bool> _stepInner(JamState s) async {
    if (jamQueueFull(s, reserve: jamManualSeats, inFlight: _pending.length + _uncertain.length)) return false; // the last seats are for hand-made adds (D-264)
    final quota = (maxJamItems / max(1, s.participants.length)).ceil();
    var mine = _pending.length + _uncertain.length + (_sugVersion == null ? 0 : 1);
    for (final (n, it) in s.items.indexed) {
      if (n > s.currentIndex && it.ownerDeviceId == ownId) mine++;
    }
    if (_waiting.isNotEmpty) {
      if (mine >= quota) return false;
      final key = _waiting.removeAt(0);
      _flying = key;
      if (_inJam.contains(key) || _played.contains(key) || _pending.containsKey(key) ||
          _uncertain.containsKey(key)) {
        return true;
      }
      void putBack() {
        if (!_ord.containsKey(key)) return; // forgotten meanwhile
        _waiting
          ..add(key)
          ..sort((a, b) => _ord[a]!.compareTo(_ord[b]!));
      }
      final JamItem? item;
      try {
        item = await itemOf(key);
      } on Object {
        putBack(); // a failure never loses a track
        rethrow;
      }
      if (item == null) {
        AppLog.d('jam: part track $key is not available, dropped');
        _ord.remove(key);
        return true;
      }
      void unsure() {
        if (_ord.containsKey(key)) _uncertain[key] = s.version;
      }
      try {
        final r = await send(JamCommand.add(item));
        if (r.isOk) {
          if (!_inJam.contains(key)) _pending[key] = r.state!.version;
          return true;
        }
        final e = r.error;
        if (e == JamError.forbidden || e == JamError.invalid) {
          AppLog.w('jam: part track $key refused ($e), dropped');
          _ord.remove(key);
          return true;
        }
        if (e == JamError.notFound) {
          unsure(); // transport error: the host may have applied it
        } else {
          putBack(); // full, ended: a real answer, try again later
        }
        return false;
      } on Object {
        unsure();
        rethrow;
      }
    }
    if (mine > 0) return false;
    final item = await suggest(s);
    if (item == null) return false;
    final r = await send(JamCommand.add(item));
    if (!r.isOk) return false;
    _sugVersion = r.state!.version;
    return true;
  }
}
