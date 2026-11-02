// Opt-in: the real public brokers (R-129, D-258).
//   CODECORE_LIVE=1 flutter test test/live/jam_broker_live_test.dart
import 'dart:io';

import 'package:codecore/providers/jam_broker_providers.dart';
import 'package:codecore/services/jam/remote/broker_entry.dart';
import 'package:codecore/services/jam/remote/mqtt_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final live = Platform.environment['CODECORE_LIVE'] == '1';
  final skip = live ? false : 'set CODECORE_LIVE=1';
  const timeout = Timeout(Duration(minutes: 1));

  test('broker.emqx.io:8883 echoes a message', () async {
    expect(await testBroker(MqttClientLink(), kDefaultJamBrokers[0]), isTrue);
  }, skip: skip, timeout: timeout);

  test('test.mosquitto.org:8886 echoes a message', () async {
    expect(await testBroker(MqttClientLink(), const BrokerEntry(host: 'test.mosquitto.org', port: 8886)), isTrue);
  }, skip: skip, timeout: timeout);

  test('test.mosquitto.org:8883 is refused for its certificate', () async {
    const b = BrokerEntry(host: 'test.mosquitto.org', port: 8883);
    expect(await testBroker(MqttClientLink(), b), isFalse);
  }, skip: skip, timeout: timeout);
}
