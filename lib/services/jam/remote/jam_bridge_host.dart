import 'dart:async';
import 'dart:typed_data';

import '../../../core/app_log.dart';
import '../jam_host.dart';
import '../jam_models.dart';
import 'broker_entry.dart';
import 'jam_beacon.dart';
import 'jam_bridge.dart';
import 'jam_crypto.dart' show JamKey;
import 'jam_friends.dart';
import 'jam_protocol.dart';

const _codeLife = Duration(minutes: 2);
const _pingEvery = Duration(seconds: 30);
const _maxTriesPerSecond = 10;

/// The code before a renewal still opens requests for this long.
const _prevCodeGrace = Duration(seconds: 10);

class _Code {
  _Code(this.text, this.keys, this.madeAt);
  final String text;
  final JamCodeKeys keys;
  final DateTime madeAt;
  String get topic => JamProtocol.codeTopic(keys.topicId);
}

/// Host side of the remote Jam: lobby, code, requests and one [JamChannel] per
/// remote guest, on top of a [JamBridge]. It listens to [JamHost.changes] and
/// never touches the Jam rules itself (flows 1, 3-7). Ending the session is the
/// caller's job; [stop] only says goodbye and throws every key away.
class JamBridgeHost {
  JamBridgeHost({
    required this.protocol,
    required this.host,
    required this.bridge,
    DateTime Function()? now,
    this.friends,
    this.autoAcceptFriends,
    this.beacon,
    this.stopGrace = const Duration(milliseconds: 500),
    this.pack = packStateOffThread,
  }) : _now = now ?? DateTime.now;

  final JamProtocol protocol;
  final JamHost host;
  final JamBridge bridge;
  final DateTime Function() _now;

  /// Saved friends and the announce key `AK`; null = no friends (a random `AK` per switch-on).
  final JamFriends? friends;

  /// «Accetta gli amici senza chiedere», read at every request.
  final bool Function()? autoAcceptFriends;

  /// Bluetooth announcement of this Jam while running; null = none (R-136).
  final JamBeacon? beacon;

  /// [stop] waits this long before disconnecting: the MQTT client may drop
  /// buffered writes on disconnect.
  final Duration stopGrace;

  /// Packs a STATE for the wire (JSON, fit, zlib), off the UI thread when big.
  /// A parameter so that tests can slow it down or break it.
  final Future<Uint8List?> Function(JamState) pack;

  JamHostSecrets? _s;
  Uint8List? _ownAk; // used only without [friends]
  final _pending = <String, JamChannel>{}; // JamRequest.id -> channel
  final _members = <String, JamChannel>{}; // member id -> channel
  // Channels whose request carried a valid friend proof: only they may overwrite a saved friend.
  final _proven = Expando<bool>();
  final _codeChanged = StreamController<void>.broadcast();
  _Code? _code, _prev;
  DateTime? _prevUntil;
  final _unsent = <String, Uint8List>{}; // member id -> ACCEPT not published
  String? _goneTopic;
  int _codeGen = 0;
  bool _codeBusy = false;
  int _advWindow = -1;
  bool _advOn = false; // believed to be announcing
  // STATE delivery (K-JD-09). One pack at a time, of the latest version, shared
  // by every channel; the cheap AEAD is then done per channel on this thread.
  int _delivered = -1; // latest version sealed and published to the channels
  Object? _packToken; // set while a pack is in flight (identifies it)
  int _packedV = -1;
  Uint8List? _packedBytes; // the pack of [_packedV]
  final _want = <String, JamChannel>{}; // member id -> channel owed the latest STATE
  final _has = <String, int>{}; // member id -> latest version sent to it
  final _waiting = <(int, void Function())>[]; // RESULTs waiting for their STATE
  int _rateSec = 0, _rateN = 0;
  late DateTime _lastPing;
  Timer? _timer;
  final _subs = <StreamSubscription<Object?>>[];

  bool get running => _s != null;

  /// The 6 B id of this switch-on's Jam; null when off.
  Uint8List? get jamId => _s?.jamId;

  /// The code to show (`XXXX-XXXX`) and when it stops working; null when none.
  String? get code => _code == null ? null : JamProtocol.formatCode(_code!.text);
  DateTime? get codeExpiresAt => _code?.madeAt.add(_codeLife);

  /// Fires when the code changes (renewal included).
  Stream<void> get codeChanges => _codeChanged.stream;

  int get _ms => _now().millisecondsSinceEpoch;

  Uint8List get _announceKey => friends?.announceKey ?? _ownAk!;

  /// The friends' label to announce now (BLE packet and QR), changes every 30 s.
  Uint8List friendLabel() =>
      protocol.friendLabelAt(_announceKey, _ms, protocol.fingerprint(_s!.hpk));

  /// 26 B Bluetooth announcement of the current window; null when off.
  Uint8List? advert() {
    final s = _s;
    if (s == null) return null;
    final i = kDefaultJamBrokers.indexOf(bridge.broker ?? bridge.brokers.first);
    return protocol.advertAt(s, _ms, ak: _announceKey, broker: i < 0 ? 0xFF : i);
  }

  /// Starts the announcement, then renews it with each 30 s window of the QR.
  void _advertise({required bool first}) {
    final b = beacon, bytes = advert();
    if (b == null || bytes == null) return;
    _advWindow = JamProtocol.windowOf(_ms);
    _advOn = true;
    (first ? b.startAdvertising(bytes) : b.updateAdvertising(bytes)).catchError((Object e, StackTrace st) {
      AppLog.w('jam bridge: advertising failed', e, st);
      return false;
    }).then((ok) {
      if (!ok) _advOn = false; // the next window starts it again
    });
  }

  /// Members that already got their ACCEPT (the first envelope of a pair).
  Iterable<MapEntry<String, JamChannel>> get _live =>
      _members.entries.where((e) => !_unsent.containsKey(e.key));

  void start() {
    if (_s != null) return;
    final s = _s = protocol.newHostSecrets();
    _ownAk = friends == null ? protocol.crypto.randomBytes(32) : null;
    _lastPing = _now();
    _resetDelivery();
    bridge.subscribe(JamProtocol.requestTopic(s.jamId));
    _subs
      ..add(bridge.messages.listen(_onMessage))
      ..add(bridge.connections.listen((_) => _republish()))
      ..add(host.changes.listen((_) => _onChanges()));
    final b = beacon;
    if (b != null) {
      _subs.add(b.failed.listen((k) {
        if (k == JamBeaconKind.advertise) _advOn = false; // retried at the next window
      }));
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    bridge.start();
    _advertise(first: true);
    if (bridge.status == JamBridgeStatus.up) _republish();
  }

  /// Once a second: expiry of requests, `PING`, code renewal.
  void tick() {
    if (_s == null) return;
    host.expire();
    if (JamProtocol.windowOf(_ms) != _advWindow) _advertise(first: !_advOn);
    final now = _now();
    if (now.difference(_lastPing) >= _pingEvery) {
      _lastPing = now;
      final v = host.state?.version ?? 0;
      for (final e in _live) {
        _send(e.value, JamMsg.ping, {'v': v, 't': _ms});
      }
    }
    final pu = _prevUntil;
    if (pu != null && !now.isBefore(pu)) _dropPrev();
    final c = _code;
    if (c != null && !_codeBusy && now.difference(c.madeAt) >= _codeLife) {
      unawaited(_newCode());
    }
  }

  // ---- code ----------------------------------------------------------------

  /// Makes a code (Argon2id, in an isolate) and keeps renewing it until [stopCode].
  Future<void> startCode() => _newCode();

  Future<void> _newCode() async {
    final s = _s;
    if (s == null) return;
    final gen = ++_codeGen;
    _codeBusy = true;
    try {
      final text = protocol.generateCode();
      final keys = await protocol.deriveCode(text);
      if (_s != s || gen != _codeGen) {
        keys.dispose();
        return;
      }
      _dropPrev();
      _clearGone();
      final old = _code;
      if (old != null) {
        _publishCode(old, gone: true);
        _goneTopic = old.topic;
        _prev = old;
        _prevUntil = _now().add(_prevCodeGrace);
      }
      final c = _code = _Code(text, keys, _now());
      _publishCode(c, gone: false);
      _codeChanged.add(null);
    } on Object catch (e, st) {
      AppLog.w('jam bridge: code failed', e, st);
    } finally {
      _codeBusy = false;
    }
  }

  /// The code stops working: guests who type it read «gone».
  void stopCode() {
    _codeGen++;
    final c = _code;
    if (c == null) return;
    _clearGone();
    _publishCode(c, gone: true);
    _goneTopic = c.topic;
    _dropCode(clear: false);
    _codeChanged.add(null);
  }

  void _dropCode({required bool clear}) {
    final c = _code;
    if (c == null) return;
    if (clear) _retain(c.topic, Uint8List(0));
    c.keys.dispose();
    _code = null;
  }

  void _dropPrev() {
    _prev?.keys.dispose();
    _prev = null;
    _prevUntil = null;
  }

  void _clearGone() {
    final t = _goneTopic;
    if (t != null) _retain(t, Uint8List(0));
    _goneTopic = null;
  }

  void _publishCode(_Code c, {required bool gone}) {
    final s = _s;
    if (s == null) return;
    _retain(
      c.topic,
      protocol.sealCode(
        c.keys.kc,
        JamCodeInfo(
          jamId: s.jamId,
          hpk: s.hpk,
          expMs: _ms + _codeLife.inMilliseconds,
          brokers: _brokers(),
          gone: gone,
        ),
      ),
    );
  }

  void _retain(String topic, Uint8List bytes) =>
      bridge.publish(topic, bytes, retain: true);

  /// The broker in use first (QR, CODE and ACCEPT).
  List<BrokerEntry> _brokers() {
    final cur = bridge.broker;
    return [
      ?cur,
      for (final b in bridge.brokers)
        if (b != cur) b,
    ];
  }

  /// QR text of the current 30 s window; null when the bridge is off.
  String? currentQr() {
    final s = _s;
    if (s == null) return null;
    return protocol.encodeQr(
      JamQr(
        jamId: s.jamId,
        token: protocol.token(s, _ms),
        hpk: s.hpk,
        friendLabel: friendLabel(),
        brokers: _brokers(),
      ),
    );
  }

  // ---- incoming ------------------------------------------------------------

  void _onMessage(({String topic, Uint8List payload}) m) {
    final s = _s;
    if (s == null) return;
    if (m.topic == JamProtocol.requestTopic(s.jamId)) {
      _onRequest(s, m.payload);
      return;
    }
    for (final e in _members.entries) {
      if (e.value.recvTopic == m.topic) {
        _onGuest(e.key, e.value, m.payload);
        return;
      }
    }
  }

  /// Charges [n] AEAD attempts to the per-second budget; false when it is spent.
  bool _take(int n) {
    final sec = _ms ~/ 1000;
    if (sec != _rateSec) {
      _rateSec = sec;
      _rateN = 0;
    }
    if (_rateN + n > _maxTriesPerSecond) {
      protocol.drops.drop('rate'); // dropped before any decryption
      return false;
    }
    _rateN += n;
    return true;
  }

  void _onRequest(JamHostSecrets s, Uint8List bytes) {
    // Only messages that would reach the AEAD use the budget.
    final wellFormed =
        bytes.length >= 2 + 32 + 24 + 16 &&
        bytes.length <= JamWire.maxRequest &&
        bytes[0] == JamWire.version &&
        bytes[1] == JamWire.tRequest;
    final now = _now();
    // A code opens requests for 2 min, the previous one for 10 s more (R-139).
    final c = _code;
    final cur = c != null && now.difference(c.madeAt) < _codeLife ? c : null;
    final pu = _prevUntil;
    final prev = pu != null && now.isBefore(pu) ? _prev : null;
    // T_w and T_(w-1) plus the KC: the attempts openRequest really makes.
    if (wellFormed && !_take(2 + (cur != null ? 1 : 0))) return;
    var r = protocol.openRequest(bytes, s, hostMs: _ms, kc: cur?.keys.kc);
    if (r == null && wellFormed && prev != null && _take(3)) {
      r = protocol.openRequest(bytes, s, hostMs: _ms, kc: prev.keys.kc);
    }
    if (r == null) return;
    // A friend is recognised by the proof made with the FKp saved for its id (R-143).
    final saved = r.friendProof == null ? null : friends?.byId(r.id);
    var friend = false;
    if (saved != null) {
      final k = JamKey(saved.fkp);
      friend = protocol.friendProofValid(k, s.jamId, r.gpk, r.friendProof!);
      k.dispose();
    }
    final a = host.admitRequest(
      id: r.id,
      name: friend ? saved!.name : r.name,
      remote: true,
      friend: friend,
      autoAccept: friend && (autoAcceptFriends?.call() ?? false),
    );
    switch (a.status) {
      case JamAdmitStatus.accepted:
        _pending[a.request!.id] = r.channel;
        if (friend) _proven[r.channel] = true;
      case JamAdmitStatus.full || JamAdmitStatus.busy:
        _send(r.channel, JamMsg.no, {'why': 'busy'});
        r.channel.dispose();
      case JamAdmitStatus.tooMany || JamAdmitStatus.bad:
        r.channel.dispose();
    }
  }

  void _onGuest(String id, JamChannel ch, Uint8List bytes) {
    final m = ch.open(bytes);
    if (m == null) return;
    host.touch(id);
    switch (m.type) {
      case JamMsg.cmd:
        final r = host.apply(m.command!, from: id);
        _onChanges();
        final result = {
          'req': m.body['req'],
          if (r.isOk) 'v': r.state!.version else 'err': r.error!.name,
        };
        final v = r.isOk ? r.state!.version : -1;
        if (v > _delivered) {
          // The new STATE goes out before the RESULT: wait for its delivery.
          _waiting.add((v, () {
            if (_members[id] != ch) {
              AppLog.d('jam bridge: RESULT dropped, member gone');
              return;
            }
            _send(ch, JamMsg.result, result);
          }));
          _pump(); // the delivery of v may need a pack that nobody asked for
        } else {
          _send(ch, JamMsg.result, result);
        }
      case JamMsg.sync:
        final st = host.state;
        if (st != null && (m.body['v'] as int) < st.version) {
          _has[id] = -1; // the guest lacks it, whatever we believed
          _sendState([id]);
        } else {
          _send(ch, JamMsg.ping, {'v': st?.version ?? 0, 't': _ms}); // alive
        }
      case JamMsg.leave:
        host.removeMember(id);
      case JamMsg.friend:
        _befriend(id, ch, m.body['ak'] as String);
      case JamMsg.gTime:
        _send(ch, JamMsg.time, {'t0': m.body['t0'], 't': _ms});
    }
  }

  // ---- host changes --------------------------------------------------------

  void _onChanges() {
    if (_s == null) return;
    for (final id in [..._pending.keys]) {
      final r = host.requests[id];
      if (r != null && r.status == JamRequestStatus.pending) continue;
      final ch = _pending.remove(id)!;
      if (r != null && r.status == JamRequestStatus.accepted) {
        _accept(r.fromId, ch);
      } else {
        if (r != null && r.status == JamRequestStatus.declined) {
          _send(ch, JamMsg.no, {'why': 'declined'});
        }
        ch.dispose(); // expired or vanished: nothing is answered
      }
    }
    final st = host.state;
    // Also gone: replaced by a LAN guest of the same id (K-JD-02).
    final gone = [
      for (final id in _members.keys)
        if (!host.memberIds.contains(id) ||
            st?.participant(id)?.remote != true)
          id,
    ];
    if (st != null) {
      _sendState([
        for (final e in _live)
          if (!gone.contains(e.key)) e.key,
      ]);
    }
    final why = (st?.ended ?? true) ? 'ended' : 'removed';
    for (final id in gone) {
      _send(_members[id]!, JamMsg.bye, {'why': why});
      _release(id);
    }
  }

  /// Sends ACCEPT and adopts the channel; false when the state does not fit.
  bool _accept(String id, JamChannel ch) {
    final st = host.state;
    final fitted = st == null ? null : protocol.fitState(st);
    if (fitted == null) {
      AppLog.w('jam bridge: state too big for ACCEPT, member removed');
      ch.dispose();
      host.removeMember(id);
      return false;
    }
    if (_members.containsKey(id)) _release(id);
    _members[id] = ch;
    _has[id] = st!.version;
    bridge.subscribe(ch.recvTopic);
    final b = ch.seal(JamMsg.accept, {
      'host': host.deviceId,
      'name': host.deviceName,
      'state': fitted,
      'brokers': JamProtocol.brokersJson(_brokers()),
      'ak': b64u(_announceKey),
      't': _ms,
    });
    if (b == null) {
      AppLog.w('jam bridge: ACCEPT too big, member removed');
      _release(id);
      host.removeMember(id);
      return false;
    }
    if (!bridge.publish(ch.sendTopic, b)) _unsent[id] = b; // resent on reconnect
    return true;
  }

  /// The guest's `AK` came after the ACCEPT: both sides save each other (R-143).
  void _befriend(String id, JamChannel ch, String akText) {
    final f = friends, ak = unb64u(akText);
    if (f == null || ak == null) return;
    // A saved entry changes only for a guest that proved it is that friend; one
    // removed since the proof (the user dropped it mid-session) does not come back.
    final proven = _proven[ch] == true, saved = f.byId(id) != null;
    if (saved != proven) {
      AppLog.w('jam bridge: FRIEND not allowed (saved entry without proof, or removed since), nothing saved');
      return;
    }
    final name = host.state?.participant(id)?.name ?? id;
    f.save(id, name, ak, Uint8List.fromList(ch.keys.fkp.bytes)).catchError((Object e, StackTrace st) {
      AppLog.w('jam bridge: could not save a friend', e, st);
    });
  }

  void _release(String id) {
    final ch = _members.remove(id);
    _unsent.remove(id);
    _has.remove(id);
    _want.remove(id);
    if (ch == null) return;
    bridge.unsubscribe(ch.recvTopic);
    ch.dispose();
  }

  // ---- sending -------------------------------------------------------------

  bool _send(JamChannel ch, int type, Map<String, Object?> body) {
    final b = ch.seal(type, body);
    if (b == null) {
      AppLog.w('jam bridge: message $type too big, not sent');
      return false;
    }
    return bridge.publish(ch.sendTopic, b);
  }

  void _resetDelivery() {
    _delivered = -1;
    _packToken = null; // a pack still in flight is ignored when it ends
    _packedV = -1;
    _packedBytes = null;
    _want.clear();
    _has.clear();
    _waiting.clear();
  }

  /// Owes the latest STATE to the members [ids] (their channels now: a member
  /// that rejoins meanwhile has another one and is skipped).
  void _sendState(Iterable<String> ids) {
    for (final id in ids) {
      final ch = _members[id];
      if (ch != null) _want[id] = ch;
    }
    _pump();
  }

  /// Delivers what is owed, packing the latest version if needed. At most one
  /// pack runs; versions that pile up meanwhile cost one more pack, not one
  /// each.
  void _pump() {
    final s = _s, st = host.state;
    if (s == null || st == null || _packToken != null) return;
    _want.removeWhere((id, _) => (_has[id] ?? -1) >= st.version);
    if (_want.isEmpty && !_waiting.any((w) => w.$1 > _delivered)) return;
    final bytes = _packedBytes;
    if (_packedV == st.version && bytes != null) {
      _deliver(st.version, bytes);
    } else {
      unawaited(_runPack(s, st));
    }
  }

  Future<void> _runPack(JamHostSecrets s, JamState st) async {
    final token = _packToken = Object();
    var again = false;
    try {
      Uint8List? bytes;
      var failed = false;
      try {
        bytes = await pack(st);
      } on Object catch (e, t) {
        AppLog.w('jam bridge: state pack failed', e, t);
        failed = true;
      }
      if (_s != s || !identical(_packToken, token)) {
        AppLog.d('jam bridge: state ${st.version} packed after stop, dropped');
        return;
      }
      final cur = host.state;
      if (cur == null) return;
      if (cur.version != st.version) {
        AppLog.d('jam bridge: state ${st.version} superseded, packing ${cur.version}');
        again = true;
        return;
      }
      if (failed) bytes = _packInline(cur); // RESULTs must not wait for ever
      if (bytes != null) {
        _packedV = cur.version;
        _packedBytes = bytes;
      }
      _deliver(cur.version, bytes);
    } on Object catch (e, t) {
      AppLog.w('jam bridge: state delivery failed', e, t);
    } finally {
      if (identical(_packToken, token)) _packToken = null;
      if (again && _s == s) _pump();
    }
  }

  Uint8List? _packInline(JamState st) {
    try {
      return packState(st);
    } on Object catch (e, t) {
      AppLog.w('jam bridge: inline state pack failed', e, t);
      return null;
    }
  }

  /// Seals and publishes [bytes] (version [v]) to the members owed it, then
  /// lets the RESULTs that waited for it go out. [bytes] null: too big or not
  /// packable, nothing is sent but the RESULTs are not held back.
  void _deliver(int v, Uint8List? bytes) {
    final want = {..._want};
    _want.clear();
    if (bytes == null) {
      AppLog.w('jam bridge: state $v too big or not packed, not sent');
    } else {
      for (final e in want.entries) {
        final ch = _members[e.key];
        if (ch != e.value || _unsent.containsKey(e.key)) {
          AppLog.d('jam bridge: member ${e.key} changed, state $v skipped');
        } else if (_sealState(ch!, bytes)) {
          _has[e.key] = v;
        }
      }
    }
    if (v > _delivered) _delivered = v;
    final due = _waiting.where((w) => w.$1 <= _delivered).toList();
    _waiting.removeWhere((w) => w.$1 <= _delivered);
    for (final w in due) {
      w.$2();
    }
  }

  bool _sealState(JamChannel ch, Uint8List bytes) {
    try {
      final b = ch.sealPacked(JamMsg.state, bytes);
      if (b == null) {
        AppLog.w('jam bridge: state too big, not sent');
        return false;
      }
      return bridge.publish(ch.sendTopic, b);
    } on StateError catch (e, t) {
      AppLog.w('jam bridge: state not sent, channel released', e, t);
      return false;
    }
  }

  /// After a (re)connection: lobby, code, and the state to everybody.
  void _republish() {
    final s = _s;
    if (s == null) return;
    _retain(JamProtocol.lobbyTopic(s.jamId), protocol.lobby(s.hpk));
    final c = _code;
    if (c != null) _publishCode(c, gone: false);
    // ACCEPT first: the guest takes envelopes in counter order.
    for (final e in [..._unsent.entries]) {
      if (bridge.publish(_members[e.key]!.sendTopic, e.value)) {
        _unsent.remove(e.key);
      }
    }
    for (final id in _members.keys) {
      _has[id] = -1; // the broker may have lost what we sent: all again
    }
    _sendState([for (final e in _live) e.key]);
  }

  // ---- off -----------------------------------------------------------------

  Future<void> stop() async {
    final s = _s;
    if (s == null) return;
    _s = null;
    _timer?.cancel();
    _advWindow = -1;
    _advOn = false;
    unawaited(beacon?.stopAdvertising());
    for (final x in _subs) {
      unawaited(x.cancel());
    }
    _subs.clear();
    // Whatever is in flight, the guests must get the latest STATE (`ended`
    // above all) before the channels go: packed and sealed here, in line.
    final st = host.state;
    if (st != null && _delivered < st.version) {
      final bytes = _packedV == st.version ? _packedBytes : _packInline(st);
      if (bytes == null) {
        AppLog.w('jam bridge: final state too big, not sent');
      } else {
        for (final e in _live) {
          if ((_has[e.key] ?? -1) < st.version) _sealState(e.value, bytes);
        }
      }
    }
    _resetDelivery();
    _retain(JamProtocol.lobbyTopic(s.jamId), Uint8List(0));
    _clearGone();
    _codeGen++;
    _dropCode(clear: true);
    _dropPrev();
    bridge.unsubscribe(JamProtocol.requestTopic(s.jamId));
    for (final id in [..._members.keys]) {
      _release(id);
    }
    for (final ch in _pending.values) {
      ch.dispose();
    }
    _pending.clear();
    _ownAk?.fillRange(0, 32, 0);
    _ownAk = null;
    s.dispose();
    await Future<void>.delayed(stopGrace);
    bridge.stop();
  }

  /// [stop] and close [codeChanges].
  Future<void> dispose() async {
    await stop();
    await _codeChanged.close();
  }
}
