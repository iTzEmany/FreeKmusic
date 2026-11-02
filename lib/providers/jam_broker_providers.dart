import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../services/jam/remote/broker_entry.dart';
import '../services/jam/remote/mqtt_link.dart';
import 'settings_providers.dart';

export '../services/jam/remote/broker_probe.dart' show testBroker;

/// The brokers of the remote Jam, saved on every change (R-122).
class JamBrokersNotifier extends Notifier<List<BrokerEntry>> {
  @override
  List<BrokerEntry> build() => decodeBrokers(ref.read(settingsStoreProvider).readJamBrokersRaw());

  void _set(List<BrokerEntry> next, {bool reset = false}) {
    state = next;
    ref
        .read(settingsStoreProvider)
        .writeJamBrokersRaw(reset ? null : encodeBrokers(next))
        .catchError((Object e, StackTrace st) {
      AppLog.w('could not save the brokers', e, st);
    });
  }

  /// False when [b] is invalid or already there.
  bool add(BrokerEntry b) {
    if (!b.isValid || state.any(b.sameAs)) return false;
    _set([...state, b]);
    return true;
  }

  /// The last broker stays (D-270).
  void remove(BrokerEntry b) {
    if (state.length > 1) _set([...state]..remove(b));
  }

  void move(int from, int to) {
    final l = [...state];
    l.insert(to > from ? to - 1 : to, l.removeAt(from));
    _set(l);
  }

  void restore() => _set(kDefaultJamBrokers, reset: true);
}

final jamBrokersProvider =
    NotifierProvider<JamBrokersNotifier, List<BrokerEntry>>(JamBrokersNotifier.new);

/// Makes the MQTT link; tests override it with a fake.
final mqttLinkFactoryProvider = Provider<MqttLink Function()>((_) => MqttClientLink.new);
