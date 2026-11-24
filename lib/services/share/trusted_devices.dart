import 'dart:convert';

import '../../core/app_log.dart';

/// A device the user paired with: it may send tracks without a PIN, and its
/// identity (the certificate fingerprint) is checked on every connection.
class TrustedDevice {
  const TrustedDevice({
    required this.id,
    required this.name,
    required this.fingerprint,
    required this.pairedAt,
    this.autoAccept = false,
    this.mine = false,
  });

  /// The other device's `deviceId`.
  final String id;
  final String name;

  /// SHA-256 of its certificate, as the user saw it when pairing.
  final String fingerprint;

  /// Epoch ms.
  final int pairedAt;

  /// Receive from it without asking (off unless the user turns it on).
  final bool autoAccept;

  /// One of the user's own devices (D-668): deletions travel only between these.
  final bool mine;

  TrustedDevice copyWith({String? name, String? fingerprint, bool? autoAccept, bool? mine}) =>
      TrustedDevice(
        id: id,
        name: name ?? this.name,
        fingerprint: fingerprint ?? this.fingerprint,
        pairedAt: pairedAt,
        autoAccept: autoAccept ?? this.autoAccept,
        mine: mine ?? this.mine,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'fingerprint': fingerprint,
        'pairedAt': pairedAt,
        'autoAccept': autoAccept,
        'mine': mine,
      };

  static TrustedDevice? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], fp = j['fingerprint'];
    if (id is! String || id.isEmpty || fp is! String || fp.isEmpty) return null;
    return TrustedDevice(
      id: id,
      name: '${j['name'] ?? id}',
      fingerprint: fp,
      pairedAt: (j['pairedAt'] as num?)?.toInt() ?? 0,
      autoAccept: j['autoAccept'] == true,
      mine: j['mine'] == true,
    );
  }
}

/// A fingerprint written however it was shown (`A1F3-09BC-…`, lower case,
/// with spaces) reduced to what identifies it: upper-case hex digits.
String normalizeFingerprint(String fp) =>
    fp.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');

/// [fp] as the user reads it aloud: upper-case, in groups of four digits, cut
/// after [groups] groups (`A1F3-09BC-77D2-4E10`).
String formatFingerprint(String fp, {int groups = 4}) {
  final hex = normalizeFingerprint(fp);
  final end = hex.length < groups * 4 ? hex.length : groups * 4;
  return [
    for (var i = 0; i < end; i += 4) hex.substring(i, i + 4 > end ? end : i + 4),
  ].join('-');
}

/// The devices the user trusts. Immutable: every change returns a new list.
class TrustedDevices {
  TrustedDevices([Iterable<TrustedDevice> devices = const []])
      : _byId = {for (final d in devices) d.id: d};

  final Map<String, TrustedDevice> _byId;

  List<TrustedDevice> get all => _byId.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  bool get isEmpty => _byId.isEmpty;

  TrustedDevice? byId(String id) => _byId[id];

  /// Trusts [device]; pairing again with the same id replaces the old entry
  /// (new fingerprint, new date) but keeps what the user chose for it.
  TrustedDevices add(TrustedDevice device) {
    final old = _byId[device.id];
    return TrustedDevices([
      for (final d in _byId.values)
        if (d.id != device.id) d,
      old == null ? device : device.copyWith(autoAccept: old.autoAccept, mine: old.mine),
    ]);
  }

  TrustedDevices revoke(String id) =>
      TrustedDevices([for (final d in _byId.values) if (d.id != id) d]);

  TrustedDevices setAutoAccept(String id, bool value) => TrustedDevices([
        for (final d in _byId.values) d.id == id ? d.copyWith(autoAccept: value) : d,
      ]);

  TrustedDevices setMine(String id, bool value) => TrustedDevices([
        for (final d in _byId.values) d.id == id ? d.copyWith(mine: value) : d,
      ]);

  /// True only for a known device presenting the fingerprint saved for it. The
  /// same id with another fingerprint is NOT trusted: it is a different
  /// identity (reinstalled, or someone pretending).
  bool matches(String id, String fingerprint) {
    final d = _byId[id];
    return d != null &&
        normalizeFingerprint(d.fingerprint) == normalizeFingerprint(fingerprint);
  }

  /// The device that owns [fingerprint], whatever id it announces now.
  TrustedDevice? byFingerprint(String fingerprint) {
    final want = normalizeFingerprint(fingerprint);
    if (want.isEmpty) return null;
    for (final d in _byId.values) {
      if (normalizeFingerprint(d.fingerprint) == want) return d;
    }
    return null;
  }

  String encode() => jsonEncode([for (final d in _byId.values) d.toJson()]);

  /// Reads what [encode] wrote; anything unreadable gives an empty list (and
  /// is logged): a damaged setting must not take the app down, and nothing is
  /// trusted by guesswork.
  static TrustedDevices decode(String? raw) {
    if (raw == null || raw.isEmpty) return TrustedDevices();
    try {
      final j = jsonDecode(raw);
      if (j is! List) return TrustedDevices();
      return TrustedDevices([for (final e in j) ?TrustedDevice.fromJson(e)]);
    } on FormatException catch (e) {
      AppLog.w('trusted devices unreadable, starting empty', e);
      return TrustedDevices();
    }
  }
}
