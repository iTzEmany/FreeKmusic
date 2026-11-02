import 'dart:typed_data';

import 'broker_entry.dart';
import 'jam_protocol.dart';

/// What a guest needs to enter a remote Jam: a QR (everything but the code) or
/// a typed code (the rest comes from the retained CODE message).
class JamInvite {
  const JamInvite({
    this.jamId,
    this.hpk,
    this.token,
    this.brokers = const [],
    this.code,
  });

  /// Null for a code: the CODE message tells it.
  final Uint8List? jamId, hpk, token;
  final List<BrokerEntry> brokers;

  /// Normalized 8-character code.
  final String? code;

  /// Null for anything that is not a well-formed QR.
  static JamInvite? fromQr(String text, JamProtocol protocol) {
    final q = protocol.decodeQr(text);
    return q == null
        ? null
        : JamInvite(
            jamId: q.jamId,
            hpk: q.hpk,
            token: q.token,
            brokers: q.brokers,
          );
  }

  /// Null when the code is malformed ("Codice non valido", no network).
  static JamInvite? fromCode(String input) {
    final c = JamProtocol.normalizeCode(input);
    return c == null ? null : JamInvite(code: c);
  }
}
