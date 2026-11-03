import 'dart:typed_data';

import 'package:codecore/services/jam/remote/broker_entry.dart';
import 'package:codecore/services/jam/remote/jam_crypto.dart';
import 'package:codecore/services/jam/remote/jam_invite.dart';
import 'package:codecore/services/jam/remote/jam_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a QR gives back the invite it was made from', () async {
    final p = JamProtocol(await SodiumJamCrypto.create());
    final qr = JamQr(
      jamId: Uint8List.fromList([1, 2, 3, 4, 5, 6]),
      token: Uint8List.fromList([6, 5, 4, 3, 2, 1]),
      hpk: Uint8List.fromList(List.generate(32, (i) => i)),
      friendLabel: Uint8List(4),
      brokers: const [BrokerEntry(host: 'a.net', port: 8883)],
    );
    final i = JamInvite.fromQr(p.encodeQr(qr), p)!;
    expect(i.jamId, qr.jamId);
    expect(i.token, qr.token);
    expect(i.hpk, qr.hpk);
    expect(i.brokers, qr.brokers);
    expect(i.code, isNull);
    expect(JamInvite.fromQr('CCJ1:xx', p), isNull);
  });

  test('an announcement gives the default broker by index, none for 0xFF', () {
    JamAdvert adv(int broker) => JamAdvert(
      jamId: Uint8List(6),
      token: Uint8List(6),
      fingerprint: Uint8List(8),
      friendLabel: Uint8List(4),
      broker: broker,
    );
    expect(JamInvite.fromAdvert(adv(0)).brokers, [kDefaultJamBrokers.first]);
    expect(JamInvite.fromAdvert(adv(0xFF)).brokers, isEmpty);
    expect(JamInvite.fromAdvert(adv(0)).fingerprint, hasLength(8));
    // Out of the list (a longer list on another version): custom broker, no RangeError.
    expect(JamInvite.fromAdvert(adv(kDefaultJamBrokers.length)).brokers, isEmpty);
    expect(JamInvite.fromAdvert(adv(254)).brokers, isEmpty);
  });

  test(
    'a code is normalized, a malformed one is refused before any network',
    () {
      expect(JamInvite.fromCode('abcd-2o3l')!.code, 'ABCD2031');
      expect(JamInvite.fromCode('ABCD'), isNull);
      expect(JamInvite.fromCode('ABCD-234U'), isNull);
    },
  );
}
