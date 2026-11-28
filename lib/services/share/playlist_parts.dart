import 'dart:async';

import 'offers.dart';

class _Group {
  _Group(this.first);
  final Completer<bool> first;
  Future<bool> tail = Future.value(false);
  int? playlistId;
  Timer? timer;
}

/// Receiver side of a playlist over 500 tracks, which arrives as several offers with the same key (D-762).
/// Part 1 asks the user; the next parts of the same sender (same id, address and, if signed, fingerprint)
/// are accepted by themselves, each after the previous one wrote its part. If part 1 is refused or expires
/// (after [offerTtl]) the others are refused. A part from anyone else is never touched: it asks as usual.
class PlaylistParts {
  PlaylistParts({required this.accept, required this.decline});

  final Future<void> Function(IncomingOffer) accept, decline;
  final _groups = <String, _Group>{};

  // Keyed by sender too: the same key from another id, address or fingerprint is another group.
  String _k(IncomingOffer o) => '${o.fromId}|${o.fromHost}|${o.callerFingerprint}|${o.playlist?.key}';

  _Group? _of(IncomingOffer o) => _groups[_k(o)];

  /// True when the offer is handled here (no question to the user); call it for every new offer.
  bool handle(IncomingOffer o) {
    final pl = o.playlist;
    if (pl == null || pl.parts < 2) return false;
    if (pl.part == 1) {
      final g = _Group(Completer<bool>());
      g.tail = g.first.future;
      g.timer = Timer(offerTtl, () => _drop(g, _k(o)));
      _groups[_k(o)] = g;
      return false;
    }
    final g = _of(o);
    if (g == null) return false;
    final prev = g.tail, done = Completer<bool>();
    g.tail = done.future;
    unawaited(prev.then((ok) async {
      if (ok) {
        await accept(o);
      } else {
        await decline(o);
      }
      done.complete(ok);
      if (pl.part == pl.parts) _drop(g, _k(o));
    }));
    return true;
  }

  /// Ends the group: pending parts are refused, later ones ask as usual.
  void _drop(_Group g, String key) {
    g.timer?.cancel();
    if (!g.first.isCompleted) g.first.complete(false);
    if (identical(_groups[key], g)) _groups.remove(key);
  }

  /// Part 1 was accepted ([ok]) or refused: lets the next parts go on or be refused.
  void firstDone(IncomingOffer o, {required bool ok}) {
    final g = _of(o);
    if (g != null && o.playlist?.part == 1 && !g.first.isCompleted) g.first.complete(ok);
  }

  /// The playlist already written for this sender's group, to append the part to.
  int? playlistFor(IncomingOffer o) => (o.playlist?.part ?? 1) > 1 ? _of(o)?.playlistId : null;

  void wrote(IncomingOffer o, int playlistId) => _of(o)?.playlistId = playlistId;

  void dispose() {
    for (final g in _groups.values) {
      g.timer?.cancel();
    }
    _groups.clear();
  }
}
