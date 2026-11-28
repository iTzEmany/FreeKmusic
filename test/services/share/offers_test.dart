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

    test('an offer of streams alone (items: []) is accepted; hostile stream entries are dropped', () async {
      const good = {'key': 'youtube:abcdefghijk', 'title': 'Live', 'durationMs': 5000};
      final r = await post('/', {
        ...offerBody(items: []),
        'streams': [
          good,
          {'key': 'youtube:../../x', 'title': 'Evil'},
          {'key': 'youtube:abcdefghijk&x=1', 'title': 'Evil'},
          {'key': 'youtube:bbbbbbbbbbb', 'title': ''},
          5,
        ],
      });
      expect(r.statusCode, 202);
      expect(seen.single.items, isEmpty);
      expect(seen.single.streams.map((s) => s.key), ['youtube:abcdefghijk']);
      // Nothing valid and no files: nothing to offer.
      expect((await post('/', {...offerBody(id: 'o2', items: []), 'streams': [5, 'x']})).statusCode, 400);
    });

    test('items and streams together stay within maxOfferItems', () async {
      Map<String, Object?> body(int items, int streams) => {
            ...offerBody(items: [
              for (var i = 0; i < items; i++) {'id': i, 'title': 't', 'sizeBytes': 1, 'ext': 'mp3'},
            ]),
            'streams': [
              for (var i = 0; i < streams; i++) {'key': 'soundcloud:$i', 'title': 't'},
            ],
          };
      expect((await post('/', body(maxOfferItems - 1, 1))).statusCode, 202);
      expect((await post('/', {...body(maxOfferItems - 1, 2), 'offerId': 'o2'})).statusCode, 400);
    });

    group('playlist field (D-760)', () {
      const pl = {
        'key': 'k1', 'name': 'Mix', 'part': 1, 'parts': 1,
        'order': [{'stream': 'youtube:abcdefghijk'}, {'item': 1}],
      };
      Map<String, Object?> body(Object? playlist) => {
            ...offerBody(),
            'playlist': playlist is Map ? {...playlist, 'shadow': [{'key': 'youtube:abcdefghijk', 'title': 'Live'}]} : playlist,
          };

      test('a valid playlist is read with its order and the shadow mark', () async {
        expect((await post('/', body(pl))).statusCode, 202);
        final p = seen.single.playlist!;
        expect((p.key, p.name, p.part, p.parts), ('k1', 'Mix', 1, 1));
        expect(p.order, [(item: null, stream: 'youtube:abcdefghijk'), (item: 1, stream: null)]);
        expect(seen.single.streams.single.shadow, true);
      });

      test('a missing or damaged field is no playlist and the offer stays valid', () async {
        final bad = <Object?>[
          null,
          5,
          {...pl, 'name': 'x' * 201},
          {...pl, 'name': ''},
          {...pl, 'key': 7},
          {...pl, 'part': 2},
          {...pl, 'part': 0},
          {...pl, 'parts': 'x'},
          {...pl, 'order': 'x'},
        ];
        for (var i = 0; i < bad.length; i++) {
          ip = '192.168.1.${100 + i}'; // the flood limits are per address and per pending offer
          final r = await post('/', {...body(bad[i]), 'offerId': 'o$i'});
          expect(r.statusCode, 202, reason: '${bad[i]}');
          seen.last.status = OfferStatus.cancelled;
        }
        expect(seen.length, bad.length);
        expect(seen.every((o) => o.playlist == null), true);
      });

      test('unknown order elements and dangling refs are skipped, the playlist stays', () async {
        final r = await post('/', body({
          ...pl,
          'order': [
            {'item': 99},
            {'stream': 'youtube:bbbbbbbbbbb'},
            {'item': 1, 'stream': 'youtube:abcdefghijk'},
            5,
            {'future': 1},
            {'item': 1},
          ],
        }));
        expect(r.statusCode, 202);
        expect(seen.single.playlist!.order, [(item: 1, stream: null)]);
      });

      test('a malformed shadow entry is skipped; a stream-only playlist of shadow rows is valid', () async {
        final r = await post('/', {
          ...offerBody(items: []),
          'playlist': {
            ...pl,
            'order': [{'stream': 'youtube:abcdefghijk'}],
            'shadow': [{'key': 'nope', 'title': 'x'}, 5, {'key': 'youtube:abcdefghijk', 'title': 'Live'}],
          },
        });
        expect(r.statusCode, 202);
        expect(seen.single.playlist!.shadow.map((s) => s.key), ['youtube:abcdefghijk']);
        expect(seen.single.streams.single.shadow, true);
      });

      test('shadow rows: a key also in streams[] is deduped, uncited rows are dropped, items+streams+shadow stay within 500', () async {
        String k(int i) => 'youtube:${i.toString().padLeft(11, 'a')}';
        Map<String, Object?> row(String key) => {'key': key, 'title': 't'};
        final r = await post('/', {
          ...offerBody(items: []),
          'streams': [row(k(1))],
          'playlist': {
            ...pl,
            'order': [{'stream': k(1)}, {'stream': k(2)}],
            'shadow': [row(k(1)), row(k(2)), row(k(3))],
          },
        });
        expect(r.statusCode, 202);
        expect(seen.single.playlist!.shadow.map((s) => s.key), [k(2)]);
        expect(seen.single.streams.map((s) => (s.key, s.shadow)), [(k(1), false), (k(2), true)]);
        ip = '192.168.1.61';
        final none = await post('/', {
          ...offerBody(id: 'o2'),
          'playlist': {...pl, 'order': [{'item': 1}], 'shadow': [row(k(3))]},
        });
        expect(none.statusCode, 202);
        expect(seen.last.playlist!.shadow, isEmpty);
        ip = '192.168.1.62';
        final over = await post('/', {
          ...offerBody(id: 'o3', items: []),
          'streams': [row(k(900))],
          'playlist': {
            ...pl,
            'order': [for (var i = 0; i < 500; i++) {'stream': k(i)}],
            'shadow': [for (var i = 0; i < 700; i++) row(k(i))],
          },
        });
        expect(over.statusCode, 400);
      });

      test('splitParts cuts in runs of 500, in order', () {
        final parts = splitParts([for (var i = 0; i < 1200; i++) i]);
        expect(parts.map((e) => e.length), [500, 500, 200]);
        expect(parts.expand((e) => e).toList(), [for (var i = 0; i < 1200; i++) i]);
      });

      test('createOutgoing -> offerPayload -> POST round trip; no playlist, no field', () async {
        const e1 = ShareEntry(id: 1, path: '/a.mp3', title: 'One', sizeBytes: 1, durationMs: 0, ext: 'mp3');
        const e2 = ShareEntry(
            id: 2, path: '', streamKey: 'youtube:abcdefghijk', title: 'Live', sizeBytes: 0, durationMs: 0, ext: '', shadow: true);
        final sender = OfferService(deviceId: 'dev-a', deviceName: 'A');
        final plain = sender.offerPayload(sender.createOutgoing(toId: 'b', toName: 'B', entries: [e1, e2]), 4000);
        expect(plain.containsKey('playlist'), false);
        final offer = sender.createOutgoing(
            toId: 'b', toName: 'B', entries: [e2, e1], playlist: (key: 'k9', name: 'Mix', part: 1, parts: 1));
        final payload = jsonDecode(jsonEncode(sender.offerPayload(offer, 4000))) as Map<String, Object?>;
        expect(payload['playlist'], {
          'key': 'k9', 'name': 'Mix', 'part': 1, 'parts': 1,
          'order': [{'stream': 'youtube:abcdefghijk'}, {'item': 1}],
          'shadow': [
            {'key': 'youtube:abcdefghijk', 'title': 'Live', 'artist': null, 'album': null, 'durationMs': 0},
          ],
        });
        expect(payload.containsKey('streams'), false);
        expect((payload['playlist']! as Map)['shadow'], [
          {'key': 'youtube:abcdefghijk', 'title': 'Live', 'artist': null, 'album': null, 'durationMs': 0},
        ]);
        expect((await post('/', payload)).statusCode, 202);
        expect(seen.single.playlist!.order.length, 2);
      });

      test('tryParse boundaries: parts 1000/1001, key 64/65, order 500/501, name 200/201, shadow flag never read from streams[]', () {
        Map<String, Object?> raw({String key = 'k', int parts = 1, int refs = 1, String name = 'n'}) => {
              'key': key, 'name': name, 'part': 1, 'parts': parts,
              'order': [for (var i = 0; i < refs; i++) {'item': i}],
            };
        OfferPlaylist? parse(Map<String, Object?> m) =>
            OfferPlaylist.tryParse(m, itemIds: {for (var i = 0; i < 600; i++) i}, streamKeys: {});
        expect(parse(raw(parts: 1000)), isNotNull);
        expect(parse(raw(parts: 1001)), isNull);
        expect(parse(raw(key: 'k' * 64)), isNotNull);
        expect(parse(raw(key: 'k' * 65)), isNull);
        expect(parse(raw(refs: 500)), isNotNull);
        expect(parse(raw(refs: 501)), isNull);
        expect(parse(raw(name: 'n' * 200)), isNotNull);
        expect(parse(raw(name: 'n' * 201)), isNull);
        expect(StreamOffer.tryParse({'key': 'youtube:abcdefghijk', 'title': 't', 'shadow': true})!.shadow, false);
      });

      test('invisible and bidi characters are stripped from the name; a name of only those is no playlist', () {
        OfferPlaylist? parse(String n) => OfferPlaylist.tryParse(
            {'key': 'k', 'name': n, 'part': 1, 'parts': 1, 'order': [{'item': 1}]}, itemIds: {1}, streamKeys: {});
        expect(parse('\u202Eab\u200B\u0000c')!.name, 'abc');
        expect(parse('\u200B\u200B'), isNull);
      });

      test('a "shadow": true in streams[] is ignored; shadow rows without a valid playlist do not exist', () async {
        final r = await post('/', {
          ...body({...pl, 'part': 9}),
          'streams': [{'key': 'youtube:bbbbbbbbbbb', 'title': 'Saved', 'shadow': true}],
        });
        expect(r.statusCode, 202);
        expect(seen.single.playlist, isNull);
        expect(seen.single.streams.map((s) => (s.key, s.shadow)), [('youtube:bbbbbbbbbbb', false)]);
        ip = '192.168.1.60';
        final none = await post('/', {...offerBody(id: 'o2', items: []), 'playlist': {...pl, 'part': 9, 'shadow': [{'key': 'youtube:abcdefghijk', 'title': 'L'}]}});
        expect(none.statusCode, 400);
      });

      test('over the limits, only the next part of a group already being received gets in', () async {
        receiver.acceptsPart = (id, host, fp, key, part, parts) => key == 'k1' && part > 1 && id == 'dev-a';
        final codes = <int>[];
        for (var i = 1; i <= 8; i++) {
          codes.add((await post('/', {...body({...pl, 'part': i, 'parts': 8}), 'offerId': 'p$i'})).statusCode);
        }
        expect(codes, [for (var i = 0; i < 8; i++) 202]);
        // The same flood with another key is limited as always.
        final other = await post('/', {...body({...pl, 'key': 'other', 'part': 2, 'parts': 8}), 'offerId': 'x'});
        expect(other.statusCode, 429);
      });

      test('the sender keeps the parts of an accepted group alive while the first one is busy', () async {
        var t = DateTime(2026, 1, 1, 12);
        final sender = OfferService(deviceId: 's', deviceName: 'S', now: () => t);
        const e = ShareEntry(id: 1, path: '/a.mp3', title: 'One', sizeBytes: 1, durationMs: 0, ext: 'mp3');
        OutgoingOffer mk(int part) => sender.createOutgoing(
            toId: 'b', toName: 'B', entries: [e], playlist: (key: 'k', name: 'Mix', part: part, parts: 2));
        final a = mk(1), b = mk(2);
        final h = sender.buildRouter(clientIp: (_) => '192.168.1.5').call;
        t = t.add(const Duration(minutes: 9));
        final r = await h(Request('POST', Uri.parse('http://x/${a.offerId}/accept'), headers: {'X-Token': a.token}));
        expect(r.statusCode, 200);
        t = t.add(const Duration(minutes: 9)); // 18 minutes after creation, 9 after the answer
        sender.expire();
        expect((a.status, b.status), (OfferStatus.accepted, OfferStatus.pending));
        t = t.add(const Duration(minutes: 2));
        sender.expire();
        expect((a.status, b.status), (OfferStatus.expired, OfferStatus.expired));
      });
    });

    test('StreamOffer.tryParse clips text, keeps a sane duration only', () {
      final o = StreamOffer.tryParse({'key': 'youtube:abcdefghijk', 'title': 'x' * 500, 'artist': 'a' * 500, 'durationMs': 3600000})!;
      expect((o.title.length, o.artist!.length, o.durationMs), (200, 200, 3600000));
      for (final d in [-1, 24 * 3600 * 1000 + 1, 1e30, 'x']) {
        expect(StreamOffer.tryParse({'key': 'youtube:abcdefghijk', 'title': 't', 'durationMs': d})!.durationMs, 0, reason: '$d');
      }
      expect(StreamOffer.tryParse({'key': 'youtube:abcdefghijk', 'title': 't', 'durationMs': 24 * 3600 * 1000})!.durationMs, 24 * 3600 * 1000);
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
