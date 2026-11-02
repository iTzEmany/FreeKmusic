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

  test(
    'a code is normalized, a malformed one is refused before any network',
    () {
      expect(JamInvite.fromCode('abcd-2o3l')!.code, 'ABCD2031');
      expect(JamInvite.fromCode('ABCD'), isNull);
      expect(JamInvite.fromCode('ABCD-234U'), isNull);
    },
  );
}
