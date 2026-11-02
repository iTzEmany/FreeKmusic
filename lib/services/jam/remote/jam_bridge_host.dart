import 'dart:async';
import 'dart:typed_data';

import '../../../core/app_log.dart';
import '../jam_host.dart';
import '../jam_models.dart';
import 'broker_entry.dart';
import 'jam_bridge.dart';
import 'jam_protocol.dart';

const _codeLife = Duration(minutes: 2);
const _pingEvery = Duration(seconds: 30);
const _maxTriesPerSecond = 10;

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
  }) : _now = now ?? DateTime.now;

  final JamProtocol protocol;
  final JamHost host;
  final JamBridge bridge;
  final DateTime Function() _now;

  JamHostSecrets? _s;
  Uint8List? _ak;
  final _pending = <String, JamChannel>{}; // JamRequest.id -> channel
  final _members = <String, JamChannel>{}; // member id -> channel
  final _codeChanged = StreamController<void>.broadcast();
  _Code? _code;
  String? _goneTopic;
  int _codeGen = 0;
  bool _codeBusy = false;
  int _sentVersion = -1;
  int _rateSec = 0, _rateN = 0;
  late DateTime _lastPing;
  Timer? _timer;
  final _subs = <StreamSubscription<Object?>>[];

  bool get running => _s != null;

  /// The code to show (`XXXX-XXXX`) and when it stops working; null when none.
  String? get code => _code == null ? null : JamProtocol.formatCode(_code!.text);
  DateTime? get codeExpiresAt => _code?.madeAt.add(_codeLife);

  /// Fires when the code changes (renewal included).
  Stream<void> get codeChanges => _codeChanged.stream;

  int get _ms => _now().millisecondsSinceEpoch;

  void start() {
    if (_s != null) return;
    final s = _s = protocol.newHostSecrets();
    _ak = protocol.crypto.randomBytes(32);
    _lastPing = _now();
    _sentVersion = -1;
    bridge.subscribe(JamProtocol.requestTopic(s.jamId));
    _subs
      ..add(bridge.messages.listen(_onMessage))
      ..add(bridge.connections.listen((_) => _republish()))
      ..add(host.changes.listen((_) => _onChanges()));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    bridge.start();
    if (bridge.status == JamBridgeStatus.up) _republish();
  }

  /// Once a second: expiry of requests, `PING`, code renewal.
  void tick() {
    if (_s == null) return;
    host.expire();
    final now = _now();
    if (now.difference(_lastPing) >= _pingEvery) {
      _lastPing = now;
      final v = host.state?.version ?? 0;
      for (final ch in _members.values) {
        _send(ch, JamMsg.ping, {'v': v, 't': _ms});
      }
    }
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
      _dropCode(clear: true);
      _clearGone();
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
        friendLabel: protocol.crypto.randomBytes(4), // friends arrive in phase 72
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

  void _onRequest(JamHostSecrets s, Uint8List bytes) {
    final sec = _ms ~/ 1000;
    if (sec != _rateSec) {
      _rateSec = sec;
      _rateN = 0;
    }
    if (++_rateN > _maxTriesPerSecond) {
      protocol.drops.drop('rate'); // dropped before any decryption
      return;
    }
    final r = protocol.openRequest(bytes, s, hostMs: _ms, kc: _code?.keys.kc);
    if (r == null) return;
    final a = host.admitRequest(id: r.id, name: r.name, remote: true);
    switch (a.status) {
      case JamAdmitStatus.accepted:
        _pending[a.request!.id] = r.channel;
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
        _send(ch, JamMsg.result, {
          'req': m.body['req'],
          if (r.isOk) 'v': r.state!.version else 'err': r.error!.name,
        });
      case JamMsg.sync:
        final st = host.state;
        if (st != null && (m.body['v'] as int) < st.version) _sendState(ch, st);
      case JamMsg.leave:
        host.removeMember(id);
      case JamMsg.gTime:
        _send(ch, JamMsg.time, {'t0': m.body['t0'], 't': _ms});
    }
  }

  // ---- host changes --------------------------------------------------------

  void _onChanges() {
    if (_s == null) return;
    final fresh = <String>{};
    for (final id in [..._pending.keys]) {
      final r = host.requests[id];
      if (r != null && r.status == JamRequestStatus.pending) continue;
      final ch = _pending.remove(id)!;
      if (r != null && r.status == JamRequestStatus.accepted) {
        if (_accept(r.fromId, ch)) fresh.add(r.fromId);
      } else {
        if (r != null && r.status == JamRequestStatus.declined) {
          _send(ch, JamMsg.no, {'why': 'declined'});
        }
        ch.dispose(); // expired or vanished: nothing is answered
      }
    }
    final gone = [
      for (final id in _members.keys)
        if (!host.memberIds.contains(id)) id,
    ];
    final st = host.state;
    if (st != null && st.version != _sentVersion) {
      _sentVersion = st.version;
      for (final e in _members.entries) {
        if (!fresh.contains(e.key) && !gone.contains(e.key)) {
          _sendState(e.value, st);
        }
      }
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
    bridge.subscribe(ch.recvTopic);
    _send(ch, JamMsg.accept, {
      'host': host.deviceId,
      'name': host.deviceName,
      'state': fitted,
      'brokers': JamProtocol.brokersJson(_brokers()),
      'ak': b64u(_ak!),
      't': _ms,
    });
    return true;
  }

  void _release(String id) {
    final ch = _members.remove(id);
    if (ch == null) return;
    bridge.unsubscribe(ch.recvTopic);
    ch.dispose();
  }

  // ---- sending -------------------------------------------------------------

  void _send(JamChannel ch, int type, Map<String, Object?> body) {
    final b = ch.seal(type, body);
    if (b == null) {
      AppLog.w('jam bridge: message $type too big, not sent');
      return;
    }
    bridge.publish(ch.sendTopic, b);
  }

  void _sendState(JamChannel ch, JamState st) {
    final j = protocol.fitState(st);
    if (j == null) {
      AppLog.w('jam bridge: state too big, not sent');
      return;
    }
    _send(ch, JamMsg.state, {'state': j});
  }

  /// After a (re)connection: lobby, code, and the state to everybody.
  void _republish() {
    final s = _s;
    if (s == null) return;
    _retain(JamProtocol.lobbyTopic(s.jamId), protocol.lobby(s.hpk));
    final c = _code;
    if (c != null) _publishCode(c, gone: false);
    final st = host.state;
    if (st != null) {
      for (final ch in _members.values) {
        _sendState(ch, st);
      }
    }
  }

  // ---- off -----------------------------------------------------------------

  void stop() {
    final s = _s;
    if (s == null) return;
    _timer?.cancel();
    for (final x in _subs) {
      unawaited(x.cancel());
    }
    _subs.clear();
    final st = host.state;
    if (st != null && st.ended && st.version != _sentVersion) {
      for (final ch in _members.values) {
        _sendState(ch, st);
      }
    }
    _retain(JamProtocol.lobbyTopic(s.jamId), Uint8List(0));
    _clearGone();
    _codeGen++;
    _dropCode(clear: true);
    bridge.unsubscribe(JamProtocol.requestTopic(s.jamId));
    for (final id in [..._members.keys]) {
      _release(id);
    }
    for (final ch in _pending.values) {
      ch.dispose();
    }
    _pending.clear();
    bridge.stop();
    _ak?.fillRange(0, 32, 0);
    _ak = null;
    s.dispose();
    _s = null;
  }

  /// [stop] and close [codeChanges].
  void dispose() {
    stop();
    _codeChanged.close();
  }
}
