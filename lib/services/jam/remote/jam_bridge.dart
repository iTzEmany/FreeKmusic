import 'dart:async';
import 'dart:typed_data';

import '../../../core/app_log.dart';
import 'broker_entry.dart';
import 'mqtt_link.dart';

/// `connecting`: first attempts since start. `up`: connected. `retrying`: an
/// established connection was lost. `unreachable`: every broker failed since
/// start (R-125); attempts go on.
enum JamBridgeStatus { connecting, up, retrying, unreachable }

/// Waits between attempts (flow 5); the last one repeats.
const kJamBridgeWaits = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
  Duration(seconds: 16),
  Duration(seconds: 30),
];

/// One MQTT connection over an ordered list of brokers: on a loss it retries the
/// same broker at once, then the next ones in a loop with growing waits, and
/// redoes the subscriptions on every (re)connection (R-123, R-125, R-126).
class JamBridge {
  JamBridge(this._link, this.brokers) : assert(brokers.isNotEmpty);

  final MqttLink _link;
  final List<BrokerEntry> brokers;

  final _topics = <String>{};
  final _status = StreamController<JamBridgeStatus>.broadcast();
  final _connections = StreamController<BrokerEntry>.broadcast();
  JamBridgeStatus _st = JamBridgeStatus.connecting;
  int _idx = 0;
  int _gen = 0;
  bool _running = false;
  Timer? _wait;
  StreamSubscription<void>? _lostSub;

  JamBridgeStatus get status => _st;
  Stream<JamBridgeStatus> get statuses => _status.stream;

  /// The broker in use, null while not up.
  BrokerEntry? get broker => _st == JamBridgeStatus.up ? brokers[_idx] : null;

  /// Fires after each successful (re)connection, subscriptions already redone:
  /// the owner republishes its retained and state messages here.
  Stream<BrokerEntry> get connections => _connections.stream;
  Stream<MqttIncoming> get messages => _link.messages;

  void start() {
    if (_running) return;
    _running = true;
    _lostSub = _link.onDisconnected.listen((_) {
      if (!_running || _st != JamBridgeStatus.up) return;
      _set(JamBridgeStatus.retrying);
      _connect(_idx); // same broker first
    });
    _connect(0);
  }

  /// Gives up the broker in use for the next one (the host went quiet there).
  void next() {
    if (!_running || _st != JamBridgeStatus.up) return;
    _set(JamBridgeStatus.retrying);
    _connect((_idx + 1) % brokers.length);
  }

  void stop() {
    _running = false;
    _gen++;
    _wait?.cancel();
    _lostSub?.cancel();
    _link.disconnect();
    _set(JamBridgeStatus.connecting); // before dispose closes the controllers
  }

  void dispose() {
    stop();
    _status.close();
    _connections.close();
  }

  /// Remembered and redone after every reconnection.
  void subscribe(String topic) {
    if (!_topics.add(topic)) return;
    if (_st != JamBridgeStatus.up) return;
    try {
      _link.subscribe(topic);
    } on Object catch (e, st) {
      AppLog.w(
        'bridge: subscribe failed: $topic',
        e,
        st,
      ); // redone on reconnect
    }
  }

  void unsubscribe(String topic) {
    if (_topics.remove(topic) && _st == JamBridgeStatus.up) {
      try {
        _link.unsubscribe(topic);
      } on Object catch (e, st) {
        AppLog.w('bridge: unsubscribe failed: $topic', e, st);
      }
    }
  }

  /// False when not connected: the message is dropped, the owner resends on `connections`.
  bool publish(String topic, Uint8List bytes, {bool retain = false}) {
    if (_st != JamBridgeStatus.up) return false;
    try {
      _link.publish(topic, bytes, retain: retain);
      return true;
    } on Object catch (e, st) {
      // Socket gone but onDisconnected not fired yet.
      AppLog.w('bridge: publish failed: $topic', e, st);
      return false;
    }
  }

  void _set(JamBridgeStatus s) {
    if (s == _st) return;
    _st = s;
    _status.add(s);
  }

  Future<void> _connect(int from) async {
    final gen = ++_gen;
    var i = from;
    var failures = 0;
    while (gen == _gen) {
      try {
        await _link.connect(brokers[i]);
        if (gen != _gen) {
          // Else a newer attempt owns the link.
          if (!_running) {
            _link.disconnect();
          }
          return;
        }
        _idx = i;
        _set(JamBridgeStatus.up);
        for (final t in _topics) {
          try {
            _link.subscribe(t);
          } on Object catch (e, st) {
            AppLog.w('bridge: subscribe failed: $t', e, st);
          }
        }
        _connections.add(brokers[i]);
        return;
      } on Object catch (e, st) {
        if (gen != _gen) return;
        AppLog.w('bridge: ${brokers[i]} failed', e, st);
      }
      failures++;
      if (_st != JamBridgeStatus.retrying && failures >= brokers.length) {
        _set(JamBridgeStatus.unreachable);
      }
      final c = Completer<void>();
      _wait = Timer(
        kJamBridgeWaits[(failures - 1).clamp(0, kJamBridgeWaits.length - 1)],
        c.complete,
      );
      await c.future;
      i = (i + 1) % brokers.length;
    }
  }
}
