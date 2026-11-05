import 'dart:convert';

import '../../../core/app_log.dart';

/// One MQTT broker the remote Jam can use (R-122).
class BrokerEntry {
  const BrokerEntry({required this.host, required this.port, this.tls = true});

  final String host;
  final int port;
  final bool tls;

  /// A bare host name (no scheme, port, path, whitespace or invisible
  /// characters), port 1..65535.
  bool get isValid =>
      host.isNotEmpty &&
      !host.contains(
        RegExp(
          r'[\s:/\x00-\x1f\x7f-\x9f\u200b-\u200f\u2028\u2029\u2060\ufeff]',
        ),
      ) &&
      port >= 1 &&
      port <= 65535;

  /// Same broker, host compared ignoring case.
  bool sameAs(BrokerEntry o) =>
      o.host.toLowerCase() == host.toLowerCase() &&
      o.port == port &&
      o.tls == tls;

  Map<String, Object> toJson() => {'host': host, 'port': port, 'tls': tls};

  @override
  bool operator ==(Object other) =>
      other is BrokerEntry &&
      other.host == host &&
      other.port == port &&
      other.tls == tls;

  @override
  int get hashCode => Object.hash(host, port, tls);

  @override
  String toString() => '$host:$port';
}

/// Append only: the BLE announcement (phase 72) carries an index into this list.
/// Mosquitto 8886 was dropped before that index was used (D-328).
/// HiveMQ appended 2026-11-05, TLS cert verified for broker.hivemq.com (D-383).
const kDefaultJamBrokers = [
  BrokerEntry(host: 'broker.emqx.io', port: 8883),
  BrokerEntry(host: 'broker.hivemq.com', port: 8883),
];

String encodeBrokers(List<BrokerEntry> l) =>
    jsonEncode([for (final b in l) b.toJson()]);

/// Reads `[{host, port, tls}]`. A broken entry drops only itself, duplicates go;
/// null, broken text or nothing valid gives the defaults (D-270).
List<BrokerEntry> decodeBrokers(String? raw) {
  if (raw == null) return kDefaultJamBrokers;
  final out = <BrokerEntry>[];
  try {
    for (final e in jsonDecode(raw) as List) {
      try {
        final b = BrokerEntry(
          host: ((e as Map)['host'] as String).trim(),
          port: e['port'] as int,
          tls: e['tls'] as bool? ?? true,
        );
        if (b.isValid && !out.any((o) => o.sameAs(b))) out.add(b);
      } on Object catch (err, st) {
        AppLog.w('jamBrokers: entry dropped', err, st);
      }
    }
  } on Object catch (e, st) {
    AppLog.w('jamBrokers unreadable', e, st);
  }
  return out.isEmpty ? kDefaultJamBrokers : out;
}
