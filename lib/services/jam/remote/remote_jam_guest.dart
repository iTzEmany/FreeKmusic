import 'dart:async';
import 'dart:typed_data';

import '../../../core/app_log.dart';
import '../jam_clock.dart';
import '../jam_guest.dart' show JamJoinOutcome;
import '../jam_guest_link.dart';
import '../jam_host.dart' show JamRequest;
import '../jam_models.dart';
import 'broker_entry.dart';
import 'jam_bridge.dart';
import 'jam_crypto.dart' show JamKey;
import 'jam_friends.dart';
import 'jam_invite.dart';
import 'jam_protocol.dart';
import 'mqtt_link.dart';

enum _Phase { idle, joining, running, closed }

/// Guest side of a remote Jam over the MQTT bridge: enters with a QR or a code,
/// follows the host's STATE, sends commands as CMD and waits for RESULT.
/// All timing runs on [tick] (a 1 s timer in production, called by hand in
/// tests) against the injected clock.
class RemoteJamGuest implements JamGuestLink {
  RemoteJamGuest({
    required this.protocol,
    required this.linkFactory,
    this.brokers = kDefaultJamBrokers,
    DateTime Function()? now,
    this.friends,
    this.leaveGrace = const Duration(milliseconds: 500),
    this.bridgeWaits = kJamBridgeWaits,
  }) : _now = now ?? DateTime.now;

  final JamProtocol protocol;
  final MqttLink Function() linkFactory;

  /// Saved friends: recognise the host from its label, swap `AK` after the ACCEPT.
  final JamFriends? friends;

  /// Brokers tried, in order, for the retained CODE of a typed code.
  final List<BrokerEntry> brokers;
  final DateTime Function() _now;

  /// Time left to the LEAVE to go out before the bridge is stopped.
  final Duration leaveGrace;
  final List<Duration> bridgeWaits;

  /// 60 s of the host (R-150) plus a margin, counted from the publication.
  static const requestWait = Duration(seconds: 62);
  static const nextBrokerAfter = Duration(seconds: 5);

  /// A CODE counts as expired only this long after its `exp` (clock skew).
  static const codeSlackMs = 2 * 60 * 1000;
  static const codeWait = Duration(seconds: 4);
  static const resultWait = Duration(seconds: 10);
  static const timeWait = Duration(seconds: 3);
  static const pingEvery = Duration(seconds: 30);
  static const silentAfter = Duration(seconds: 45);
  static const lostAfter = Duration(minutes: 10);

  _Phase _phase = _Phase.idle;
  bool _cancelled = false;
  JamBridge? _bridge;
  JamChannel? _channel;
  Uint8List? _requestBytes;
  String? _requestTopic;
  bool _requestSent = false;
  Completer<JamJoinOutcome?>? _accept;
  final _wakers = <void Function()>[];
  DateTime? _syncAt;
  Timer? _timer;
  StreamSubscription<Object?>? _msgSub, _connSub, _statusSub;
  JamState? _state;
  JamLinkState _link = JamLinkState.ok;
  bool _silent = false;
  var _reqSeq = 0;
  late DateTime _lastHeard, _lastPing, _lastSync;
  final _pending = <String, Completer<JamResult>>{};
  final _probes = <int, List<Completer<int?>>>{};
  final _deadlines = <({DateTime at, void Function() fire})>[];
  final _states = StreamController<JamState>.broadcast();
  final _lost = StreamController<void>.broadcast();
  final _links = StreamController<JamLinkState>.broadcast();

  @override
  JamState? get state => _state;
  @override
  Stream<JamState> get states => _states.stream;
  @override
  Stream<void> get lost => _lost.stream;
  @override
  JamHostFiles? get files => null;
  @override
  JamLinkState get link => _link;
  @override
  Stream<JamLinkState> get links => _links.stream;

  /// Enters the Jam of [invite]; the keys of the pair live until [dispose].
  Future<JamJoinOutcome> join(
    JamInvite invite, {
    required String ownDeviceId,
    required String ownName,
  }) async {
    if (_phase != _Phase.idle) return JamJoinOutcome.unreachable;
    _phase = _Phase.joining;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    try {
      final o = await _join(invite, ownDeviceId, ownName);
      if (o != JamJoinOutcome.accepted) await _shutdown();
      return o;
    } on Object {
      await _shutdown();
      rethrow;
    }
  }

  bool get _stopped => _cancelled || _phase == _Phase.closed;

  Future<JamJoinOutcome> _join(
    JamInvite invite,
    String ownId,
    String ownName,
  ) async {
    Uint8List? jamId = invite.jamId, hpk = invite.hpk, proof = invite.token;
    var route = invite.brokers;
    JamCodeKeys? codeKeys;
    try {
      if (invite.code != null) {
        codeKeys = await protocol.deriveCode(invite.code!);
        final found = await _lookupCode(codeKeys);
        if (_stopped) return JamJoinOutcome.cancelled;
        if (found == null) return JamJoinOutcome.codeInvalid;
        final (info, on) = found;
        if (info.gone ||
            info.expMs + codeSlackMs < _now().millisecondsSinceEpoch) {
          return JamJoinOutcome.codeExpired;
        }
        jamId = info.jamId;
        hpk = info.hpk;
        proof = codeKeys.kc.bytes;
        route = info.brokers.isEmpty ? [on] : info.brokers;
      }
      if (_stopped) return JamJoinOutcome.cancelled;
      if (jamId == null || hpk == null || proof == null || route.isEmpty) {
        return JamJoinOutcome.codeInvalid;
      }
      // The proof of a friend only goes out when the label of the announcement is theirs.
      JamKey? friendKey;
      final label = invite.friendLabel, f = friends;
      if (label != null && f != null) {
        await f.ready;
        final fr = f.match(protocol, label, _now().millisecondsSinceEpoch);
        if (fr != null) friendKey = JamKey(fr.fkp);
      }
      final req = protocol.buildRequest(
        jamId: jamId,
        hpk: hpk,
        proof: proof,
        id: ownId,
        name: ownName,
        friendKey: friendKey,
      );
      friendKey?.dispose();
      if (req == null) return JamJoinOutcome.codeInvalid;
      _channel = req.channel;
      _requestBytes = req.bytes;
      _requestTopic = JamProtocol.requestTopic(jamId);
    } finally {
      codeKeys?.dispose();
    }
    if (_stopped) return JamJoinOutcome.cancelled;
    // A growable copy: the host's own list is appended to it on ACCEPT.
    final bridge = _bridge = JamBridge(linkFactory(), [...route], waits: bridgeWaits);
    _msgSub = bridge.messages.listen(_onIncoming);
    _connSub = bridge.connections.listen((_) => _onConnected());
    _statusSub = bridge.statuses.listen((_) => _refreshLink());
    bridge
      ..subscribe(_channel!.recvTopic)
      ..start();
    final c = _accept = Completer<JamJoinOutcome?>();
    // The 62 s start when the REQUEST is published, see _onConnected.
    final r = await c.future;
    if (r != null) return r;
    return _stopped ? JamJoinOutcome.cancelled : JamJoinOutcome.expired;
  }

  /// The CODE of [keys] on each of [brokers] in turn, 4 s per broker.
  Future<(JamCodeInfo, BrokerEntry)?> _lookupCode(JamCodeKeys keys) async {
    final topic = JamProtocol.codeTopic(keys.topicId);
    for (final b in brokers) {
      if (_stopped) return null;
      final link = linkFactory();
      final got = Completer<JamCodeInfo?>();
      // nowMs 0: expiry is judged here, so "expired" differs from "invalid".
      final sub = link.messages.listen((m) {
        if (m.topic != topic || m.payload.isEmpty || got.isCompleted) return;
        final i = protocol.openCode(m.payload, keys.kc, nowMs: 0);
        if (i != null) got.complete(i);
      });
      try {
        await link.connect(b);
        link.subscribe(topic);
        final info = await _within(got, codeWait);
        if (info != null) return (info, b);
      } on Object catch (e, st) {
        AppLog.w('remote jam: code lookup on $b failed', e, st);
      } finally {
        await sub.cancel();
        link.disconnect();
      }
    }
    return null;
  }

  /// Completes [c] with null after [d] (judged by [tick]) or on [cancelJoin].
  Future<T?> _within<T>(Completer<T?> c, Duration d) {
    void giveUp() {
      if (!c.isCompleted) c.complete(null);
    }

    _deadlines.add((at: _now().add(d), fire: giveUp));
    _wakers.add(giveUp);
    return c.future.whenComplete(() => _wakers.remove(giveUp));
  }

  @override
  void cancelJoin() {
    _cancelled = true;
    _wakeAll();
  }

  void _wakeAll() {
    for (final w in [..._wakers]) {
      w();
    }
    final a = _accept;
    if (a != null && !a.isCompleted) a.complete(null);
  }

  void _onConnected() {
    if (_phase == _Phase.joining) {
      if (!_requestSent) {
        _requestSent = _bridge!.publish(_requestTopic!, _requestBytes!);
        if (_requestSent) {
          final c = _accept!;
          _deadlines.add((
            at: _now().add(requestWait),
            fire: () {
              if (!c.isCompleted) c.complete(null);
            },
          ));
        }
      }
    } else if (_phase == _Phase.running) {
      _sync();
    }
  }

  void _onIncoming(MqttIncoming m) {
    final ch = _channel;
    if (ch == null || m.topic != ch.recvTopic) return;
    if (_phase != _Phase.joining && _phase != _Phase.running) return;
    final msg = ch.open(m.payload);
    if (msg == null) return;
    if (_phase == _Phase.joining) {
      _onJoining(msg);
    } else {
      _onRunning(msg);
    }
  }

  void _onJoining(JamMessage msg) {
    final c = _accept;
    if (c == null || c.isCompleted) return;
    switch (msg.type) {
      case JamMsg.accept:
        // The host's list becomes the reserve of the bridge.
        final list = _bridge!.brokers;
        for (final b in msg.brokers) {
          if (!list.any((o) => o.sameAs(b))) list.add(b);
        }
        _phase = _Phase.running;
        _lastHeard = _lastPing = _lastSync = _now();
        _apply(msg.state!);
        _befriend(msg.body);
        c.complete(JamJoinOutcome.accepted);
      case JamMsg.no:
        c.complete(
          msg.body['why'] == 'busy'
              ? JamJoinOutcome.busy
              : JamJoinOutcome.declined,
        );
    }
  }

  /// Saves the host as a friend and sends our `AK` (nobody gives it before the accept).
  void _befriend(Map<String, Object?> accept) {
    final f = friends, ch = _channel, ak = unb64u(accept['ak']);
    if (f == null || ch == null || ak == null) return;
    final id = accept['host'] as String, name = accept['name'] as String;
    final fkp = Uint8List.fromList(ch.keys.fkp.bytes);
    unawaited(() async {
      try {
        await f.ready;
        await f.save(id, name, ak, fkp);
        _sendMsg(JamMsg.friend, {'ak': b64u(f.announceKey)});
      } on Object catch (e, st) {
        AppLog.w('remote jam: could not save the host as a friend', e, st);
      }
    }());
  }

  void _onRunning(JamMessage msg) {
    _lastHeard = _now();
    _syncAt = null;
    _silent = false;
    switch (msg.type) {
      case JamMsg.state:
        _apply(msg.state!);
      case JamMsg.result:
        final req = msg.body['req'] as String;
        final c = _pending.remove(req);
        if (c == null) break;
        final err = msg.body['err'];
        final s = _state;
        // The new state itself comes as STATE: here only whether it worked.
        c.complete(
          err is String
              ? JamResult.fail(
                  JamError.values.asNameMap()[err] ?? JamError.invalid,
                )
              : s == null
              ? const JamResult.fail(JamError.invalid)
              : JamResult.ok(s),
        );
      case JamMsg.ping:
        // A STATE we never got: ask for it.
        if ((msg.body['v'] as int) > (_state?.version ?? -1)) _sync();
      case JamMsg.bye:
        _markLost();
      case JamMsg.time:
        final t0 = msg.body['t0'] as int;
        for (final c in _probes.remove(t0) ?? <Completer<int?>>[]) {
          c.complete(msg.body['t'] as int);
        }
    }
    _refreshLink();
  }

  void _apply(JamState s) {
    if (_state != null && s.version < _state!.version) return;
    _state = s;
    if (!_states.isClosed) _states.add(s);
    if (s.ended) unawaited(_shutdown());
  }

  bool _sendMsg(int type, Object? body) {
    final ch = _channel, b = _bridge;
    if (ch == null || b == null) return false;
    final bytes = ch.seal(type, body);
    return bytes != null && b.publish(ch.sendTopic, bytes);
  }

  void _sync() {
    _syncAt = _now();
    _sendMsg(JamMsg.sync, {'v': _state?.version ?? -1});
  }

  void _refreshLink() {
    final st = _bridge?.status;
    final l =
        st == JamBridgeStatus.retrying || st == JamBridgeStatus.unreachable
        ? JamLinkState.reconnecting
        : _silent
        ? JamLinkState.hostSilent
        : JamLinkState.ok;
    if (l == _link || _phase != _Phase.running) return;
    _link = l;
    if (!_links.isClosed) _links.add(l);
  }

  /// One step of every timer: deadlines, PING, SYNC after silence, loss.
  void tick() {
    final t = _now();
    for (final d in [..._deadlines]) {
      if (t.isBefore(d.at)) continue;
      _deadlines.remove(d);
      d.fire();
    }
    if (_phase != _Phase.running) return;
    if (t.difference(_lastHeard) >= lostAfter) {
      _markLost();
      return;
    }
    if (t.difference(_lastPing) >= pingEvery) {
      _lastPing = t;
      _sendMsg(JamMsg.gPing, <String, Object?>{});
    }
    _silent = t.difference(_lastHeard) >= silentAfter;
    final since = _lastSync.isAfter(_lastHeard) ? _lastSync : _lastHeard;
    if (_silent && t.difference(since) >= silentAfter) {
      _lastSync = t;
      _sync();
    }
    final sa = _syncAt;
    if (sa != null && t.difference(sa) >= nextBrokerAfter) {
      _syncAt = null; // the new connection sends its own SYNC
      _bridge?.next();
    }
    _refreshLink();
  }

  @override
  Future<JamResult> send(JamCommand cmd) async {
    if (_phase != _Phase.running) return const JamResult.fail(JamError.ended);
    final req = '${++_reqSeq}';
    final c = _pending[req] = Completer<JamResult>();
    if (!_sendMsg(JamMsg.cmd, {'req': req, 'cmd': cmd.toJson()})) {
      _pending.remove(req);
      return const JamResult.fail(JamError.notFound);
    }
    _deadlines.add((
      at: _now().add(resultWait),
      fire: () {
        if (_pending.remove(req) != null) {
          c.complete(const JamResult.fail(JamError.notFound));
        }
      },
    ));
    return c.future;
  }

  /// Gives up on one probe (timeout or send failure).
  void _drop(int t0, Completer<int?> c) {
    _probes[t0]?.remove(c);
    if (_probes[t0]?.isEmpty ?? false) _probes.remove(t0);
    if (!c.isCompleted) c.complete(null);
  }

  @override
  Future<JamTimeSample?> probeHostTime(int Function() localNow) async {
    if (_phase != _Phase.running) return null;
    final t0 = localNow();
    final c = Completer<int?>();
    (_probes[t0] ??= []).add(c);
    if (!_sendMsg(JamMsg.gTime, {'t0': t0})) {
      _drop(t0, c);
      return null;
    }
    _deadlines.add((at: _now().add(timeWait), fire: () => _drop(t0, c)));
    final hostMs = await c.future;
    return hostMs == null ? null : (t0: t0, hostMs: hostMs, t1: localNow());
  }

  /// A remote guest does not forward LAN requests.
  @override
  Future<bool> invite(JamRequest request) async => false;

  @override
  Future<void> leave() async {
    if (_phase == _Phase.running) {
      _sendMsg(JamMsg.leave, <String, Object?>{});
      if (leaveGrace > Duration.zero) await Future<void>.delayed(leaveGrace);
    }
    await _shutdown();
  }

  void _markLost() {
    if (!_lost.isClosed) _lost.add(null);
    unawaited(_shutdown());
  }

  /// Stops the work and throws the keys away; idempotent.
  Future<void> _shutdown() async {
    if (_phase == _Phase.closed) return;
    _phase = _Phase.closed;
    _wakeAll();
    _timer?.cancel();
    _timer = null;
    await _msgSub?.cancel();
    await _connSub?.cancel();
    await _statusSub?.cancel();
    _bridge?.dispose();
    _bridge = null;
    _channel?.dispose();
    _channel = null;
    _requestBytes = null;
    for (final c in _pending.values) {
      c.complete(const JamResult.fail(JamError.ended));
    }
    _pending.clear();
    for (final l in _probes.values) {
      for (final c in l) {
        c.complete(null);
      }
    }
    _probes.clear();
    _deadlines.clear();
  }

  @override
  Future<void> dispose() async {
    await _shutdown();
    await _states.close();
    await _lost.close();
    await _links.close();
  }
}
