import 'package:codecore/services/jam/remote/broker_entry.dart';
import 'package:codecore/services/jam/remote/mqtt_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a broker needs a host without spaces and a port from 1 to 65535', () {
    bool ok(String h, int p) => BrokerEntry(host: h, port: p).isValid;
    expect(ok('broker.emqx.io', 8883), isTrue);
    expect(ok('', 8883), isFalse);
    expect(ok('a b', 8883), isFalse);
    expect(ok('h', 0), isFalse);
    expect(ok('h', 1), isTrue);
    for (final bad in [
      'http://h',
      'h:1883',
      'h/x',
      'a\u00a0b',
      'a\u200bb',
      'a\u200cb',
      'a\u200db',
      'a\ufeffb',
      'a\tb',
      'a\u3000b',
    ]) {
      expect(ok(bad, 8883), isFalse, reason: bad);
    }
    expect(ok('h', 65536), isFalse);
    expect(ok('h', 65535), isTrue);
  });

  test('the list survives JSON, drops invalid entries and falls back to the defaults', () {
    const mine = [
      BrokerEntry(host: 'x.org', port: 1883, tls: false),
      BrokerEntry(host: 'y.org', port: 8883),
    ];
    expect(decodeBrokers(encodeBrokers(mine)), mine);
    expect(
      decodeBrokers(
        '[{"host":"","port":1,"tls":true},{"host":"y.org","port":8883}]',
      ),
      [mine[1]],
    );
    expect(decodeBrokers(null), kDefaultJamBrokers);
    expect(decodeBrokers('not json'), kDefaultJamBrokers);
    expect(kDefaultJamBrokers.map((b) => '$b'), ['broker.emqx.io:8883']);
    expect(kDefaultJamBrokers.every((b) => b.tls), isTrue);
  });

  test('hosts that differ only in case are duplicates', () {
    expect(
      decodeBrokers('[{"host":"X.org","port":1},{"host":"x.org","port":1}]'),
      [const BrokerEntry(host: 'X.org', port: 1)],
    );
  });

  test('the client id has 20 characters and changes every time', () {
    expect(randomClientId().length, 20);
    expect(randomClientId(), isNot(randomClientId()));
  });

  test('one bad entry drops only itself, duplicates go, nothing valid gives the defaults', () {
    const raw =
        '[{"host":"a.org","port":1883,"tls":false},5,{"host":"b.org","port":8883.0},'
        '{"host":"a.org","port":1883,"tls":false},{"host":"c.org","port":0}]';
    expect(decodeBrokers(raw), [
      const BrokerEntry(host: 'a.org', port: 1883, tls: false),
    ]);
    expect(decodeBrokers('[]'), kDefaultJamBrokers);
    expect(decodeBrokers('[{"host":"","port":1}]'), kDefaultJamBrokers);
  });
}
