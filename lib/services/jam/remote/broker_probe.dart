import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;

import '../../../core/app_log.dart';
import 'broker_entry.dart';
import 'mqtt_link.dart';

/// Connects, subscribes and publishes on a random channel, waits for the message
/// to come back (5 s), disconnects. True = ok (the reason goes to the log).
Future<bool> testBroker(
  MqttLink link,
  BrokerEntry b, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final r = Random.secure();
  final topic = 'ccj1/t/${randomClientId(r)}';
  final payload = Uint8List.fromList([
    for (var i = 0; i < 8; i++) r.nextInt(256),
  ]);
  try {
    await link.connect(b);
    final back = link.messages
        .firstWhere((m) => m.topic == topic && listEquals(m.payload, payload))
        .timeout(timeout);
    back.ignore();
    link.subscribe(topic);
    link.publish(topic, payload);
    await back;
    return true;
  } on Object catch (e, st) {
    AppLog.w('broker test failed: $b', e, st);
    return false;
  } finally {
    // Not inside the stream callback that woke us: the client cannot close its subscriptions there.
    await Future<void>.delayed(Duration.zero);
    link.disconnect();
  }
}
