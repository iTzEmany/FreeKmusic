// Opt-in: the real public brokers (R-129, D-328, D-383).
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

  for (final b in kDefaultJamBrokers) {
    test('$b echoes a message', () async {
      expect(await testBroker(MqttClientLink(), b), isTrue);
    }, skip: skip, timeout: timeout);
  }
}
