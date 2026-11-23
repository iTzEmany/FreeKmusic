import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/share/discovery.dart';
import 'package:codecore/services/share/lan_client.dart';
import 'package:codecore/services/share/lan_server.dart';
import 'package:codecore/services/share/offers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

Map<String, Object?> offerBody({
  String id = 'offer-1',
  String token = 'tok-12345678',
  List<Object?>? items,
}) =>
    {
      'offerId': id,
      'fromId': 'dev-a',
      'fromName': 'Phone A',
      'port': 4000,
      'token': token,
      'items': items ??
          [
            {'id': 1, 'title': 'Song', 'artist': 'Band', 'album': 'Alb',
             'sizeBytes': 1000, 'ext': 'mp3'},
          ],
    };

/// Sends one loopback datagram, retrying while `send` returns 0 (would block:
/// on Windows a second send right after the first is otherwise dropped).
Future<void> sendDatagram(RawDatagramSocket s, List<int> data, int port) async {
  for (var i = 0; i < 100; i++) {
    if (s.send(data, InternetAddress.loopbackIPv4, port) > 0) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('datagram to port $port could not be sent');
}

void main() {
  group('isLocalNetworkAddress', () {
    test('private yes, public no', () {
      for (final a in ['10.0.0.5', '172.16.1.1', '172.31.9.9', '192.168.1.20',
          '169.254.3.3', 'fd12::1']) {
        expect(isLocalNetworkAddress(a), true, reason: a);
      }
      for (final a in ['8.8.8.8', '172.32.0.1', '172.15.0.1', '1.1.1.1',
          'garbage', '2001:4860:4860::8888']) {
        expect(isLocalNetworkAddress(a), false, reason: a);
      }
      expect(isLocalNetworkAddress('127.0.0.1'), false);
      expect(isLocalNetworkAddress('127.0.0.1', allowLoopback: true), true);
    });
  });

  group('offer routes', () {
    late OfferService receiver;
    late Handler handler;
    var ip = '192.168.1.50';
    var now = DateTime(2026, 1, 1, 12);
    final seen = <IncomingOffer>[];

    setUp(() {
      ip = '192.168.1.50';
      now = DateTime(2026, 1, 1, 12);
      seen.clear();
      receiver = OfferService(
          deviceId: 'dev-b', deviceName: 'PC B', now: () => now)
        ..onIncoming = seen.add;
      final root = receiver.buildRouter(clientIp: (_) => ip);
      handler = root.call;
    });

    Future<Response> post(String path, Object body, {String? token}) =>
        Future.value(handler(Request('POST', Uri.parse('http://x$path'),
            body: jsonEncode(body),
            headers: {'X-Token': ?token})));

    test('valid offer is pending and surfaced', () async {
      final r = await post('/', offerBody());
      expect(r.statusCode, 202);
      expect(seen.single.fromHost, '192.168.1.50');
      expect(seen.single.status, OfferStatus.pending);
    });

    test('public address refused', () async {
      ip = '8.8.8.8';
      expect((await post('/', offerBody())).statusCode, 403);
      expect(seen, isEmpty);
    });

    test('non-audio, malformed and oversized offers are rejected', () async {
      final exe = offerBody(items: [
        {'id': 1, 'title': 'x', 'sizeBytes': 5, 'ext': 'exe'}
      ]);
      expect((await post('/', exe)).statusCode, 400);
      expect((await post('/', {'offerId': 'a'})).statusCode, 400);
      final big = offerBody(items: [
        for (var i = 0; i < maxOfferItems + 1; i++)
          {'id': i, 'title': 't', 'sizeBytes': 1, 'ext': 'mp3'}
      ]);
      expect((await post('/', big)).statusCode, 400);
      expect(seen, isEmpty);
    });

    test('duplicates and flooding are limited', () async {
      expect((await post('/', offerBody(id: 'a'))).statusCode, 202);
      expect((await post('/', offerBody(id: 'a'))).statusCode, 409);
      for (var i = 0; i < 4; i++) {
        await post('/', offerBody(id: 'o$i'));
      }
      expect((await post('/', offerBody(id: 'late'))).statusCode, 429);
    });

    test('sender cancel needs the token', () async {
      await post('/', offerBody());
      expect((await post('/offer-1/cancel', {}, token: 'wrong-token')).statusCode,
          401);
      expect((await post('/offer-1/cancel', {}, token: 'tok-12345678')).statusCode,
          200);
      expect(receiver.incoming['offer-1']!.status, OfferStatus.cancelled);
    });

    test('pending offers expire', () async {
      await post('/', offerBody());
      now = now.add(const Duration(minutes: 11));
      receiver.expire();
      expect(receiver.incoming['offer-1']!.status, OfferStatus.expired);
    });
  });

  group('end to end over loopback', () {
    late Directory tmp;
    late OfferNode senderNode, receiverNode;
    late OfferService sender, receiver;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('offer');
      // Loopback is only allowed explicitly, in tests.
      sender = OfferService(
          deviceId: 'a', deviceName: 'Sender', allowLoopback: true);
      receiver = OfferService(
          deviceId: 'b', deviceName: 'Receiver', allowLoopback: true);
      senderNode = OfferNode(sender, allowLoopback: true);
      receiverNode = OfferNode(receiver, allowLoopback: true);
      await senderNode.start();
      await receiverNode.start();
    });
    tearDown(() async {
      await senderNode.stop();
      await receiverNode.stop();
      tmp.deleteSync(recursive: true);
    });

    ShareEntry entry(int id, String name, List<int> bytes) {
      final f = File(p.join(tmp.path, name))..writeAsBytesSync(bytes);
      return ShareEntry(
          id: id,
          path: f.path,
          title: 'Song $id',
          artist: 'Band',
          sizeBytes: bytes.length,
          durationMs: 1000,
          ext: 'mp3');
    }

    test('offer -> pending -> accept -> files arrive', () async {
      final client = LanClient();
      final e1 = entry(1, 'one.mp3', List.generate(500, (i) => i % 251));
      final offer = sender.createOutgoing(
          toId: 'b', toName: 'Receiver', entries: [e1]);

      await client.sendOffer('127.0.0.1', receiverNode.port!,
          sender.offerPayload(offer, senderNode.port!));
      final inc = receiver.incoming[offer.offerId]!;
      expect(inc.status, OfferStatus.pending);
      expect(offer.status, OfferStatus.pending);

      // Files are not served before acceptance.
      var blocked = false;
      try {
        await client
            .downloadOfferItem('127.0.0.1', senderNode.port!, offer.offerId,
                inc.token, inc.items.single, Directory(p.join(tmp.path, 'x')))
            .drain<void>();
      } on LanException {
        blocked = true;
      }
      expect(blocked, true);

      await client.offerAction('127.0.0.1', senderNode.port!, offer.offerId,
          'accept', inc.token);
      expect(offer.status, OfferStatus.accepted);

      String? saved;
      await for (final ev in client.downloadOfferItem('127.0.0.1',
          senderNode.port!, offer.offerId, inc.token, inc.items.single,
          Directory(p.join(tmp.path, 'in')))) {
        saved = ev.path ?? saved;
      }
      expect(File(saved!).readAsBytesSync(), File(e1.path).readAsBytesSync());
      await client.offerAction('127.0.0.1', senderNode.port!, offer.offerId,
          'done', inc.token);
      expect(offer.status, OfferStatus.done);
    });

    test('a mixed offer carries the stream in `streams`, not in items', () async {
      final e1 = entry(1, 'one.mp3', [1, 2, 3]);
      const s = ShareEntry(
          id: 2, path: '', streamKey: 'youtube:abcdefghijk', title: 'Live', artist: 'Band', sizeBytes: 0, durationMs: 5000, ext: '');
      final offer = sender.createOutgoing(toId: 'b', toName: 'R', entries: [e1, s]);
      final payload = sender.offerPayload(offer, senderNode.port!);
      // What an older receiver reads: items with files only, the extra field is ignored.
      expect((payload['items'] as List).length, 1);
      await LanClient().sendOffer('127.0.0.1', receiverNode.port!, payload);
      final inc = receiver.incoming[offer.offerId]!;
      expect(inc.items.single.id, 1);
      expect(inc.streams.single.key, 'youtube:abcdefghijk');
      expect(inc.streams.single.durationMs, 5000);
    });

    test('an offer without `streams` (older sender) parses as before', () async {
      final offer = sender.createOutgoing(toId: 'b', toName: 'R', entries: [entry(1, 'one.mp3', [1])]);
      final payload = sender.offerPayload(offer, senderNode.port!);
      expect(payload.containsKey('streams'), false);
      await LanClient().sendOffer('127.0.0.1', receiverNode.port!, payload);
      expect(receiver.incoming[offer.offerId]!.streams, isEmpty);
    });

    test('decline leaves the sender informed and files locked', () async {
      final client = LanClient();
      final e1 = entry(1, 'one.mp3', [1, 2, 3]);
      final offer =
          sender.createOutgoing(toId: 'b', toName: 'R', entries: [e1]);
      await client.sendOffer('127.0.0.1', receiverNode.port!,
          sender.offerPayload(offer, senderNode.port!));
      final inc = receiver.incoming[offer.offerId]!;
      await client.offerAction('127.0.0.1', senderNode.port!, offer.offerId,
          'decline', inc.token);
      expect(offer.status, OfferStatus.declined);
      expect(
          () => client
              .offerAction('127.0.0.1', senderNode.port!, offer.offerId,
                  'accept', inc.token),
          throwsA(isA<LanException>()));
    });
  });

  /// Polls [done] every few ms, failing after 5 s (no fixed sleep).
  Future<void> until(bool Function() done) async {
    final end = DateTime.now().add(const Duration(seconds: 5));
    while (!done()) {
      if (DateTime.now().isAfter(end)) fail('condition not met within 5 s');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test('two devices discover each other; their own id, no magic and junk are ignored', () async {
    final a = LanDiscovery(
      deviceId: 'a',
      deviceName: 'Alpha',
      port: 45901,
      interval: const Duration(milliseconds: 100),
      allowLoopback: true,
      targets: [(address: InternetAddress.loopbackIPv4, port: 45902)],
    );
    final b = LanDiscovery(
      deviceId: 'b',
      deviceName: 'Beta',
      port: 45902,
      interval: const Duration(milliseconds: 100),
      allowLoopback: true,
      targets: [(address: InternetAddress.loopbackIPv4, port: 45901)],
    );
    addTearDown(() async {
      await a.dispose();
      await b.dispose();
    });
    await a.start(1111);
    // Queued on a's socket before b's first beacon, so a reads them first.
    final s = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(s.close);
    for (final junk in [
      '{"m":"CODECORE/1","id":"a","name":"Me","port":9}', // its own id
      '{"m":"nope","id":"y","name":"Y","port":9}', // no magic
      'not json',
    ]) {
      await sendDatagram(s, utf8.encode(junk), 45901);
    }
    await b.start(2222);
    await until(() => a.current.isNotEmpty && b.current.isNotEmpty);
    expect(a.current.map((p) => p.id), ['b']);
    expect(a.current.single.port, 2222);
    expect(b.current.map((p) => p.name), ['Alpha']);
  });

  test('beacons from outside the local network are ignored', () async {
    // The same beacon goes to a device that refuses loopback (non-local here)
    // and to one that accepts it: once the second has it, the first has had
    // the same time to read it.
    final strict = LanDiscovery(
        deviceId: 'a', deviceName: 'Alpha', port: 45903, targets: const []);
    final open = LanDiscovery(
        deviceId: 'b', deviceName: 'Beta', port: 45904, allowLoopback: true, targets: const []);
    addTearDown(() async {
      await strict.dispose();
      await open.dispose();
    });
    await strict.start(1);
    await open.start(1);
    final s = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(s.close);
    final beacon = utf8.encode('{"m":"CODECORE/1","id":"x","name":"X","port":9}');
    await sendDatagram(s, beacon, 45903);
    await sendDatagram(s, beacon, 45904);
    await until(() => open.current.isNotEmpty);
    expect(strict.current, isEmpty);
  });

  test('a failed send does not kill discovery: it binds again and still finds peers',
      () async {
    // An IPv6 target on the IPv4 socket: the SDK reports the failure
    // asynchronously and closes the socket.
    final aTargets = [(address: InternetAddress.loopbackIPv6, port: 45906)];
    final a = LanDiscovery(
      deviceId: 'a',
      deviceName: 'Alpha',
      port: 45905,
      interval: const Duration(milliseconds: 50),
      allowLoopback: true,
      targets: aTargets,
    );
    final b = LanDiscovery(
      deviceId: 'b',
      deviceName: 'Beta',
      port: 45906,
      interval: const Duration(milliseconds: 50),
      allowLoopback: true,
      targets: [(address: InternetAddress.loopbackIPv4, port: 45905)],
    );
    addTearDown(() async {
      await a.dispose();
      await b.dispose();
    });
    await a.start(1111);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    aTargets.clear();
    await b.start(2222);
    await until(() => a.current.isNotEmpty);
    expect(a.current.single.id, 'b');
  });
}
