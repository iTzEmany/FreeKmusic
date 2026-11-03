import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/share/discovery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> until(bool Function() done) async {
    final end = DateTime.now().add(const Duration(seconds: 5));
    while (!done()) {
      if (DateTime.now().isAfter(end)) fail('condition not met within 5 s');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test('jam name in the beacon reaches Peer.jamName and goes away with it', () async {
    LanDiscovery mk(String id, int port, int to) => LanDiscovery(
          deviceId: id,
          deviceName: id,
          port: port,
          interval: const Duration(milliseconds: 50),
          allowLoopback: true,
          targets: [(address: InternetAddress.loopbackIPv4, port: to)],
        );
    final a = mk('a', 45911, 45912), b = mk('b', 45912, 45911);
    addTearDown(() async {
      await a.dispose();
      await b.dispose();
    });
    await a.start(1111);
    await b.start(2222);
    await until(() => b.current.isNotEmpty);
    expect(b.current.single.jamName, isNull);
    a.speakerJamName = 'Cassa';
    await until(() => b.current.single.jamName == 'Cassa');
    expect(b.current.single.jamRid, isNull);
    a.speakerJamRid = 'AbCdEfGh';
    await until(() => b.current.single.jamRid == 'AbCdEfGh');
    a.speakerJamName = null;
    await until(() => b.current.single.jamName == null);
    expect(b.current.single.jamRid, isNull);
  });

  test('malformed jam field is ignored, unknown fields too', () async {
    final d = LanDiscovery(
        deviceId: 'd',
        deviceName: 'D',
        port: 45913,
        interval: const Duration(seconds: 5),
        allowLoopback: true,
        targets: const []);
    addTearDown(d.dispose);
    await d.start(1);
    final s = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(s.close);
    Future<void> send(String id, Object? jam) async {
      final m = {'m': discoveryMagic, 'id': id, 'name': id, 'port': 9, 'x': 1, 'jam': jam};
      s.send(utf8.encode(jsonEncode(m)), InternetAddress.loopbackIPv4, 45913);
    }

    await send('p1', 'text');
    await send('p2', {'name': 5});
    await send('p3', {'name': 'Ok', 'other': true});
    await until(() => d.current.length == 3);
    String? jn(String id) => d.current.firstWhere((p) => p.id == id).jamName;
    expect(jn('p1'), isNull);
    expect(jn('p2'), isNull);
    expect(jn('p3'), 'Ok');
  });
}
