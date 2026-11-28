import 'dart:async';

import '../../core/app_log.dart';
import 'offers.dart';

class _Group {
  _Group(this.parts, String firstOfferId) : ids = {firstOfferId};
  final int parts;
  final Set<String> ids; // the offers that belong to the group: only these touch it
  final first = Completer<bool>();
  late Future<bool> tail = first.future;
  int last = 1; // the highest part handled so far
  int inflight = 1; // parts accepted or waiting to be (part 1 counts until it ends)
  int? playlistId;
  Timer? wait, idle;
}

/// Receiver side of a playlist over 500 tracks, which arrives as several offers with the same key (D-762).
/// Part 1 asks the user; the next parts, in order, with the same `parts` and from the same sender (id, address
/// and, if signed, fingerprint), are accepted by themselves, each after the previous one wrote its part. The
/// wait for the user's answer on part 1 is bounded by [offerTtl]; once answered, the group lives while a part is
/// being received and then [offerTtl] more from the last activity. Part 1 refused, expired or cancelled: the
/// other parts are refused. A part that does not fit (another sender, a repeated or out-of-order number, another
/// `parts`) is never touched: it asks as a normal offer. A part whose accept throws is logged and the following
/// parts go on (the playlist just misses that part).
class PlaylistParts {
  PlaylistParts({required this.accept, required this.decline});

  final Future<void> Function(IncomingOffer) accept, decline;
  final _groups = <String, _Group>{};

  // Keyed by sender too: the same key from another id, address or fingerprint is another group.
  String _key(String fromId, String host, String? fp, String key) => '$fromId|$host|$fp|$key';
  String _k(IncomingOffer o) => _key(o.fromId, o.fromHost, o.callerFingerprint, o.playlist?.key ?? '');

  /// The group [o] belongs to (only offers handled here, never a look-alike).
  _Group? _member(IncomingOffer o) {
    final g = _groups[_k(o)];
    return g != null && g.ids.contains(o.offerId) ? g : null;
  }

  /// Would a part [part] of [parts] with this key from this sender be accepted by itself?
  bool accepts(String fromId, String host, String? fp, String key, int part, int parts) {
    final g = _groups[_key(fromId, host, fp, key)];
    return g != null && g.parts == parts && part == g.last + 1 && part <= g.parts;
  }

  /// True when the offer is handled here (no question to the user); call it for every new offer.
  bool handle(IncomingOffer o) {
    final pl = o.playlist;
    if (pl == null || pl.parts < 2) return false;
    final k = _k(o);
    if (pl.part == 1) {
      if (_groups.containsKey(k)) return false; // a repeated part 1 never replaces the group
      final g = _Group(pl.parts, o.offerId);
      g.wait = Timer(offerTtl, () => _drop(g, k));
      _groups[k] = g;
      return false;
    }
    final g = _groups[k];
    if (g == null || !accepts(o.fromId, o.fromHost, o.callerFingerprint, pl.key, pl.part, pl.parts)) return false;
    g.ids.add(o.offerId);
    g.last = pl.part;
    g.inflight++;
    g.idle?.cancel();
    final prev = g.tail, done = Completer<bool>();
    g.tail = done.future;
    unawaited(prev.then((ok) async {
      try {
        await (ok ? accept(o) : decline(o));
      } on Object catch (e, st) {
        AppLog.w('playlist part ${pl.part}/${pl.parts} failed', e, st);
      } finally {
        done.complete(ok);
        g.inflight--;
        if (pl.part == pl.parts) {
          _drop(g, k);
        } else {
          _arm(g, k);
        }
      }
    }));
    return true;
  }

  /// Nobody is receiving or waiting: the group ends [offerTtl] from now.
  void _arm(_Group g, String k) {
    g.idle?.cancel();
    if (g.first.isCompleted && g.inflight == 0) g.idle = Timer(offerTtl, () => _drop(g, k));
  }

  /// Ends the group: pending parts are refused, later ones ask as usual.
  void _drop(_Group g, String key) {
    g.wait?.cancel();
    g.idle?.cancel();
    if (!g.first.isCompleted) g.first.complete(false);
    if (identical(_groups[key], g)) _groups.remove(key);
  }

  /// The user answered yes to part 1: its download may take as long as it needs.
  void answered(IncomingOffer o) {
    final g = _member(o);
    if (g != null && o.playlist?.part == 1) g.wait?.cancel();
  }

  /// Part 1 ended ([ok]: it was received) or was refused: lets the next parts go on or be refused.
  void firstDone(IncomingOffer o, {required bool ok}) {
    final g = _member(o);
    if (g == null || o.playlist?.part != 1 || g.first.isCompleted) return;
    g.wait?.cancel();
    g.first.complete(ok);
    g.inflight--;
    _arm(g, _k(o));
  }

  /// The playlist already written for this group, to append the part to.
  int? playlistFor(IncomingOffer o) => (o.playlist?.part ?? 1) > 1 ? _member(o)?.playlistId : null;

  void wrote(IncomingOffer o, int playlistId) => _member(o)?.playlistId = playlistId;

  void dispose() {
    for (final g in _groups.values) {
      g.wait?.cancel();
      g.idle?.cancel();
    }
    _groups.clear();
  }
}
