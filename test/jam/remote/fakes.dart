import 'dart:async';
import 'dart:typed_data';

import 'package:codecore/services/jam/remote/broker_entry.dart';
import 'package:codecore/services/jam/remote/mqtt_link.dart';

/// An in-memory MQTT broker: retain, a byte log of everything published, and it
/// can go down (dropping every link) and come back.
class FakeBroker {
  FakeBroker(this.entry);
  final BrokerEntry entry;
  bool up = true;
  final retained = <String, Uint8List>{};

  /// Every publish seen, in order; later tests scan it for plaintext.
  final log = <({String topic, Uint8List bytes, bool retain})>[];
  final _links = <FakeMqttLink>{};

  void goDown() {
    up = false;
    for (final l in [..._links]) {
      l.dropped();
    }
  }

  void comeBack() => up = true;

  void _publish(String topic, Uint8List bytes, bool retain) {
    log.add((topic: topic, bytes: bytes, retain: retain));
    if (retain) retained[topic] = bytes;
    for (final l in _links) {
      if (l.subscribed.contains(topic)) l._deliver(topic, bytes);
    }
  }
}

/// Several fake brokers by address, shared by the links of one test.
class FakeNet {
  FakeNet(Iterable<BrokerEntry> entries)
    : brokers = {for (final e in entries) e: FakeBroker(e)};
  final Map<BrokerEntry, FakeBroker> brokers;
  FakeBroker operator [](BrokerEntry e) => brokers[e]!;
}

class FakeMqttLink implements MqttLink {
  FakeMqttLink(this.net);
  final FakeNet net;
  final subscribed = <String>{};
  final connectAttempts = <BrokerEntry>[];
  final _msgs = StreamController<MqttIncoming>.broadcast();
  final _disc = StreamController<void>.broadcast();
  FakeBroker? _b;

  /// When set before a connect, that connect completes only after it resolves.
  Future<void>? hold;

  /// The next this-many connects fail (a timeout), whatever the broker.
  int failNext = 0;

  @override
  Future<void> connect(BrokerEntry broker) async {
    _b?._links.remove(this);
    _b = null;
    connectAttempts.add(broker);
    if (failNext > 0) {
      failNext--;
      throw StateError('timeout: $broker');
    }
    final h = hold;
    final b = net.brokers[broker];
    if (b == null || !b.up) throw StateError('unreachable: $broker');
    _b = b;
    subscribed.clear(); // a fresh session: subscriptions are lost
    b._links.add(this);
    if (h != null) await h;
  }

  @override
  void subscribe(String topic) {
    if (_b == null) throw StateError('not connected');
    subscribed.add(topic);
    final r = _b?.retained[topic];
    if (r != null) _deliver(topic, r);
  }

  @override
  void unsubscribe(String topic) => subscribed.remove(topic);

  @override
  void publish(String topic, Uint8List bytes, {bool retain = false}) =>
      (_b ?? (throw StateError('not connected')))._publish(
        topic,
        Uint8List.fromList(bytes),
        retain,
      );

  @override
  Stream<MqttIncoming> get messages => _msgs.stream;
  @override
  Stream<void> get onDisconnected => _disc.stream;
  @override
  bool get connected => _b != null;

  @override
  void disconnect() {
    _b?._links.remove(this);
    _b = null;
  }

  void dropped() {
    disconnect();
    subscribed.clear();
    _disc.add(null);
  }

  void _deliver(String topic, Uint8List bytes) =>
      scheduleMicrotask(() => _msgs.add((topic: topic, payload: bytes)));
}
