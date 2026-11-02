import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../../../core/app_log.dart';
import 'broker_entry.dart';

/// A message that came back from the broker.
typedef MqttIncoming = ({String topic, Uint8List payload});

/// The small slice of MQTT the remote Jam needs. Faked in tests.
abstract class MqttLink {
  /// Throws when the broker cannot be reached or refuses (bad certificate included).
  Future<void> connect(BrokerEntry broker);
  void subscribe(String topic);
  void unsubscribe(String topic);
  void publish(String topic, Uint8List bytes, {bool retain = false});

  /// Broadcast, owned by the link: it survives reconnections.
  Stream<MqttIncoming> get messages;

  /// Fires when an established connection is lost (not on our own `disconnect`).
  Stream<void> get onDisconnected;
  bool get connected;
  void disconnect();
}

/// Random 20-character client id, new at every connection (R-133).
String randomClientId([Random? rng]) {
  final r = rng ?? Random.secure();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return String.fromCharCodes([
    for (var i = 0; i < 20; i++) chars.codeUnitAt(r.nextInt(chars.length)),
  ]);
}

class MqttClientLink implements MqttLink {
  MqttClientLink({this.timeout = const Duration(seconds: 8)});

  final Duration timeout;
  MqttServerClient? _c;
  StreamSubscription<void>? _updates;
  final _msgs = StreamController<MqttIncoming>.broadcast();
  final _disc = StreamController<void>.broadcast();

  @override
  Future<void> connect(BrokerEntry b) async {
    _updates?.cancel();
    _c?.disconnect();
    final id = randomClientId();
    final c =
        MqttServerClient.withPort(b.host, id, b.port, maxConnectionAttempts: 1)
          ..secure = b.tls
          ..securityContext = SecurityContext
              .defaultContext // R-129: onBadCertificate stays null
          ..keepAlivePeriod = 30
          ..disconnectOnNoResponsePeriod =
              10 // a silently dead socket fires onDisconnected
          ..autoReconnect = false
          ..logging(on: false)
          ..setProtocolV311()
          ..connectionTimeout = timeout.inMilliseconds ~/ 2
          ..connectTimeoutPeriod = timeout.inMilliseconds ~/ 2
          ..connectionMessage = MqttConnectMessage()
              .withClientIdentifier(id)
              .startClean();
    _c = c;
    c.onDisconnected = () {
      if (identical(c, _c) &&
          c.connectionStatus?.disconnectionOrigin ==
              MqttDisconnectionOrigin.unsolicited) {
        _disc.add(null);
      }
    };
    // The socket's `done` error is never listened to by mqtt_client: catch it in a guarded zone.
    final done = Completer<MqttClientConnectionStatus?>();
    runZonedGuarded(
      () => c.connect().then(done.complete, onError: done.completeError),
      (e, st) => AppLog.w('mqtt socket', e, st),
    );
    try {
      final st = await done.future.timeout(timeout); // safety net
      if (st?.state != MqttConnectionState.connected) {
        throw StateError('MQTT refused: ${st?.returnCode}');
      }
      _updates = c.updates!.expand((l) => l).listen((m) {
        final p = (m.payload as MqttPublishMessage).payload.message;
        _msgs.add((topic: m.topic, payload: Uint8List.fromList(p)));
      });
    } on Object {
      c.disconnect();
      rethrow;
    }
  }

  @override
  void subscribe(String topic) {
    if (topic.contains('#') || topic.contains('+')) {
      throw ArgumentError.value(topic, 'topic', 'wildcards are not allowed');
    }
    _c!.subscribe(topic, MqttQos.atLeastOnce);
  }

  @override
  void unsubscribe(String topic) => _c?.unsubscribe(topic);

  @override
  void publish(String topic, Uint8List bytes, {bool retain = false}) {
    final b = MqttClientPayloadBuilder();
    b.payload!.addAll(bytes);
    _c!.publishMessage(topic, MqttQos.atLeastOnce, b.payload!, retain: retain);
  }

  @override
  Stream<MqttIncoming> get messages => _msgs.stream;

  @override
  Stream<void> get onDisconnected => _disc.stream;

  @override
  bool get connected =>
      _c?.connectionStatus?.state == MqttConnectionState.connected;

  @override
  void disconnect() {
    _updates?.cancel();
    _c?.disconnect();
  }
}
