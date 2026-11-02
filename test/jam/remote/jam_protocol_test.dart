import 'dart:convert';
import 'dart:io' show ZLibCodec;
import 'dart:math';
import 'dart:typed_data';

import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/jam/remote/broker_entry.dart';
import 'package:codecore/services/jam/remote/jam_crypto.dart';
import 'package:codecore/services/jam/remote/jam_protocol.dart';
import 'package:crypto/crypto.dart' as hash;
import 'package:flutter_test/flutter_test.dart';

String toHex(List<int> b) =>
    b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
String sha(List<int> b) => hash.sha256.convert(b).toString();

/// Deterministic randomness: every call continues a counter from [base].
Uint8List Function(int) fixedRandom(int base) {
  var c = base;
  return (n) => Uint8List.fromList(List.generate(n, (_) => c++ & 0xff));
}

JamState stateOf(List<JamItem> items, {int current = 0}) => JamState(
  version: 3,
  items: items,
  currentIndex: current,
  hostDeviceId: 'host',
  outputDeviceId: 'host',
);

JamItem item(int id, String title, {String? artist, String? album}) => JamItem(
  id: id,
  ownerDeviceId: 'host',
  title: title,
  artist: artist,
  album: album,
  ext: 'mp3',
);

Map<String, Object?> acceptBody(JamState s, JamProtocol p) => {
  'host': 'host',
  'name': 'Host',
  'state': p.fitState(s),
  'brokers': <Object?>[],
  'ak': b64u(Uint8List(32)),
  't': 1,
};

void main() {
  late SodiumJamCrypto hostCrypto, guestCrypto;
  late DateTime clock;
  late List<String> lines;
  late JamProtocol host, guest;
  late JamHostSecrets secrets;
  const t0 = 10 * 30000 + 5000; // host clock, inside window 10

  setUp(() async {
    // Same streams for every test: the pinned vector depends on them.
    hostCrypto = await SodiumJamCrypto.create(random: fixedRandom(0));
    guestCrypto = await SodiumJamCrypto.create(random: fixedRandom(0x80));
    clock = DateTime(2026, 1, 1);
    lines = [];
    final log = JamDropLog(now: () => clock, sink: lines.add);
    host = JamProtocol(hostCrypto, drops: log);
    guest = JamProtocol(guestCrypto, drops: log);
    secrets = host.newHostSecrets();
  });

  JamGuestRequest request({Uint8List? hpk, int? ms, Uint8List? proof}) =>
      guest.buildRequest(
        jamId: secrets.jamId,
        hpk: hpk ?? secrets.hpk,
        proof: proof ?? host.token(secrets, ms ?? t0),
        id: 'dev-1',
        name: 'Anna',
      )!;

  // Pair of channels as after a successful request.
  (JamChannel, JamChannel) pair() {
    final g = request();
    final r = host.openRequest(g.bytes, secrets, hostMs: t0)!;
    return (r.channel, g.channel);
  }

  test('full exchange with fixed randomness: pinned vector', () {
    final token = host.token(secrets, t0);
    final g = request();
    final r = host.openRequest(g.bytes, secrets, hostMs: t0)!;
    expect(r.id, 'dev-1');
    expect(r.name, 'Anna');
    expect(r.viaCode, isFalse);
    expect(g.channel.keys.tp, r.channel.keys.tp);
    expect(g.channel.keys.fkp.bytes, r.channel.keys.fkp.bytes);

    final accept = r.channel.seal(
      JamMsg.accept,
      acceptBody(stateOf([item(1, 'Song')]), host),
    )!;
    final got = g.channel.open(accept)!;
    expect(got.type, JamMsg.accept);
    expect(got.state!.items.single.title, 'Song');

    final cmd = g.channel.seal(JamMsg.cmd, {
      'req': 'r1',
      'cmd': const JamCommand.play().toJson(),
    })!;
    final back = r.channel.open(cmd)!;
    expect(back.command!.type, JamCommandType.play);

    expect(toHex(secrets.jamId), kVector['jamId']);
    expect(toHex(token), kVector['token']);
    expect(toHex(r.channel.keys.tp), kVector['tp']);
    expect(sha(g.bytes), kVector['request']);
    expect(sha(accept), kVector['accept']);
    expect(sha(cmd), kVector['cmd']);
  });

  group('token window', () {
    test('accepted in its window and the next one, not two windows later', () {
      final g = request(ms: t0); // window 10
      expect(
        host.openRequest(g.bytes, secrets, hostMs: t0 + 30000),
        isNotNull,
        reason: 'window 11: T_(w-1)',
      );
      final h2 = host.newHostSecrets();
      final g2 = guest.buildRequest(
        jamId: h2.jamId,
        hpk: h2.hpk,
        proof: host.token(h2, t0),
        id: 'd',
        name: 'n',
      )!;
      expect(host.openRequest(g2.bytes, h2, hostMs: t0 + 60000), isNull);
    });

    test('a token of another host does not open the request', () {
      final other = host.newHostSecrets();
      final g = request(proof: host.token(other, t0));
      expect(host.openRequest(g.bytes, secrets, hostMs: t0), isNull);
    });
  });

  group('man in the middle', () {
    test('Hpk replaced: the host cannot open the request', () {
      final mitm = host.newHostSecrets();
      final g = request(hpk: mitm.hpk);
      expect(host.openRequest(g.bytes, secrets, hostMs: t0), isNull);
      expect(host.fingerprint(mitm.hpk), isNot(host.fingerprint(secrets.hpk)));
    });

    test('Gpk replaced: the host cannot open the request', () {
      final g = request();
      final forged = Uint8List.fromList(g.bytes)
        ..setAll(
          2,
          guest
              .buildRequest(
                jamId: secrets.jamId,
                hpk: secrets.hpk,
                proof: Uint8List(6),
                id: 'x',
                name: 'y',
              )!
              .bytes
              .sublist(2, 34),
        );
      expect(host.openRequest(forged, secrets, hostMs: t0), isNull);
    });

    test('a reply sealed by someone without the pair keys is refused', () {
      final (_, guestSide) = pair();
      final (strangerHost, _) = pair();
      final fake = strangerHost.seal(
        JamMsg.accept,
        acceptBody(stateOf([item(1, 'x')]), host),
      )!;
      expect(guestSide.open(fake), isNull);
    });
  });

  group('receive checks', () {
    test('repeated request: the second is dropped', () {
      final g = request();
      expect(host.openRequest(g.bytes, secrets, hostMs: t0), isNotNull);
      expect(host.openRequest(g.bytes, secrets, hostMs: t0), isNull);
      expect(lines.single, contains('replay=1'));
    });

    test('repeated envelope, old counter, wrong key, bad JSON: one log', () {
      final (h, g) = pair();
      final first = h.seal(JamMsg.ping, {'v': 1, 't': 1})!;
      final second = h.seal(JamMsg.ping, {'v': 2, 't': 2})!;
      expect(g.open(second), isNotNull);
      expect(g.open(second), isNull, reason: 'repeated');
      expect(g.open(first), isNull, reason: 'older counter');

      final (otherHost, _) = pair();
      expect(g.open(otherHost.seal(JamMsg.ping, {'v': 1, 't': 1})!), isNull);

      final bad = _forge(
        h.keys.kH2g,
        JamMsg.ping,
        9,
        'h2g',
        '{"v":',
        hostCrypto,
      );
      expect(g.open(bad), isNull, reason: 'malformed JSON');
      final wrongShape = _forge(
        h.keys.kH2g,
        JamMsg.ping,
        10,
        'h2g',
        '{"v":"x"}',
        hostCrypto,
      );
      expect(g.open(wrongShape), isNull, reason: 'schema');

      expect(lines, hasLength(1), reason: 'one line per minute');
      clock = clock.add(const Duration(seconds: 61));
      expect(g.open(first), isNull);
      expect(lines, hasLength(2));
      expect(lines.last, contains('counter=2'));
    });

    test('size, version and direction are checked before decrypting', () {
      final (h, g) = pair();
      final ok = h.seal(JamMsg.ping, {'v': 1, 't': 1})!;
      void dropAndWait(Uint8List bytes) {
        expect(g.open(bytes), isNull);
        clock = clock.add(const Duration(minutes: 2));
      }

      dropAndWait(Uint8List(JamWire.maxEnvelope + 1));
      dropAndWait(Uint8List.fromList(ok)..[0] = 2);
      // A g2h type arriving at the guest.
      dropAndWait(Uint8List.fromList(ok)..[1] = JamMsg.cmd);
      expect(lines, hasLength(3));
      expect(lines[0], contains('size=1'));
      expect(lines[1], contains('version=1'));
      expect(lines[2], contains('type=1'));
      expect(g.open(ok), isNotNull, reason: 'untouched envelope still opens');
    });

    test('the sender cannot read its own direction back', () {
      final (h, _) = pair();
      expect(h.open(h.seal(JamMsg.ping, {'v': 1, 't': 1})!), isNull);
    });
  });

  test('QR round trip, and malformed QR text is refused', () {
    final qr = JamQr(
      jamId: secrets.jamId,
      token: host.token(secrets, t0),
      hpk: secrets.hpk,
      friendLabel: Uint8List.fromList([1, 2, 3, 4]),
      brokers: const [
        BrokerEntry(host: 'broker.emqx.io', port: 8883),
        BrokerEntry(host: 'mqtt.example.org', port: 1883, tls: false),
      ],
    );
    final text = host.encodeQr(qr);
    expect(text, startsWith('CCJ1:'));
    final back = guest.decodeQr(text)!;
    expect(back.jamId, qr.jamId);
    expect(back.token, qr.token);
    expect(back.hpk, qr.hpk);
    expect(back.friendLabel, qr.friendLabel);
    expect(back.brokers, qr.brokers);
    expect(guest.decodeQr('${text}AA'), isNull, reason: 'trailing bytes');
    expect(guest.decodeQr(text.substring(0, text.length - 4)), isNull);
    expect(guest.decodeQr(text.replaceFirst('CCJ1:', 'CCJ2:')), isNull);
    expect(guest.decodeQr('CCJ1:@@@'), isNull);
  });

  test('announcement is 26 B and round trips', () {
    final a = JamAdvert(
      jamId: secrets.jamId,
      token: host.token(secrets, t0),
      fingerprint: host.fingerprint(secrets.hpk),
      friendLabel: Uint8List(4),
      broker: 0xFF,
    );
    final bytes = host.encodeAdvert(a);
    expect(bytes.length, 26);
    final back = guest.decodeAdvert(bytes)!;
    expect(back.fingerprint, a.fingerprint);
    expect(back.broker, 0xFF);
    expect(guest.decodeAdvert(Uint8List(25)), isNull);
  });

  test('code is normalized and Crockford-safe', () {
    expect(JamProtocol.normalizeCode(' abcd-23o1 '), 'ABCD2301');
    expect(JamProtocol.normalizeCode('abcd 23il'), 'ABCD2311');
    expect(JamProtocol.normalizeCode('ABCD234'), isNull, reason: 'length');
    expect(JamProtocol.normalizeCode('ABCD234U'), isNull, reason: 'U');
    expect(JamProtocol.normalizeCode('ABCD234!'), isNull);
    final c = host.generateCode();
    expect(JamProtocol.normalizeCode(c), c);
    expect(JamProtocol.formatCode('ABCD2345'), 'ABCD-2345');
  });

  test('entry by code: same keys on both sides, CODE sealed with KC', () async {
    final hostKeys = await host.deriveCode('ABCD2345');
    final guestKeys = await guest.deriveCode('ABCD2345');
    expect(hostKeys.topicId.length, 16);
    expect(hostKeys.kc.length, 32);
    expect(guestKeys.topicId, hostKeys.topicId);
    expect(guestKeys.kc.bytes, hostKeys.kc.bytes);
    expect(JamProtocol.codeTopic(hostKeys.topicId), startsWith('ccj1/c/'));

    final info = JamCodeInfo(
      jamId: secrets.jamId,
      hpk: secrets.hpk,
      expMs: 99,
      brokers: const [BrokerEntry(host: 'b.example', port: 8883)],
      gone: false,
    );
    final sealed = host.sealCode(hostKeys.kc, info);
    final opened = guest.openCode(sealed, guestKeys.kc)!;
    expect(opened.hpk, secrets.hpk);
    expect(opened.jamId, secrets.jamId);
    expect(opened.expMs, 99);
    expect(opened.brokers, info.brokers);
    final wrong = await guest.deriveCode('ABCD2346');
    expect(guest.openCode(sealed, wrong.kc), isNull);

    final g = guest.buildRequest(
      jamId: opened.jamId,
      hpk: opened.hpk,
      proof: guestKeys.kc.bytes,
      id: 'd',
      name: 'n',
    )!;
    final r = host.openRequest(g.bytes, secrets, hostMs: t0, kc: hostKeys.kc)!;
    expect(r.viaCode, isTrue);
  });

  test('lobby: 34 B, cleared lobby is not a drop', () {
    final l = host.lobby(secrets.hpk);
    expect(l.length, JamWire.lobbyLength);
    expect(guest.parseLobby(l), secrets.hpk);
    expect(guest.parseLobby(Uint8List(0)), isNull);
    expect(lines, isEmpty);
    expect(guest.parseLobby(Uint8List(33)), isNull);
    expect(lines, hasLength(1));
  });

  test('friend proof is checked with the saved pair key', () {
    final (h, g) = pair();
    final gpk = Uint8List(32)..fillRange(0, 32, 7);
    final proof = guest.friendProof(g.keys.fkp, secrets.jamId, gpk);
    expect(
      host.friendProofValid(h.keys.fkp, secrets.jamId, gpk, proof),
      isTrue,
    );
    expect(
      host.friendProofValid(JamKey(Uint8List(32)), secrets.jamId, gpk, proof),
      isFalse,
    );
  });

  group('state size (RNF-14)', () {
    List<JamItem> bigItems() {
      final rnd = Random(7);
      String text() =>
          String.fromCharCodes(List.generate(200, (_) => 33 + rnd.nextInt(90)));
      return [
        for (var i = 0; i < 200; i++)
          item(i + 1, text(), artist: text(), album: text()),
      ];
    }

    test('200 items with long texts stay under 64 KB and still parse', () {
      final (h, g) = pair();
      final sealed = h.seal(JamMsg.state, {
        'state': host.fitState(stateOf(bigItems())),
      });
      expect(sealed, isNotNull);
      expect(sealed!.length, lessThan(64 * 1024));
      final got = g.open(sealed)!;
      expect(got.state!.items, hasLength(200));
      expect(got.state!.items.first.title.length, 64);
    });

    test('too big even cut: played items go, current is recomputed', () {
      final rnd = Random(9);
      const abc =
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';
      String id() => String.fromCharCodes(
        List.generate(64, (_) => abc.codeUnitAt(rnd.nextInt(64))),
      );
      final heavy = [
        for (final it in bigItems())
          JamItem(
            id: it.id,
            ownerDeviceId: id(),
            title: it.title,
            artist: it.artist,
            album: it.album,
            ext: 'mp3',
            ref: 'yt:youtube:${id()}',
            videoId: id(),
            partKey: id(),
          ),
      ];
      final s = stateOf(heavy, current: 150);
      final j = host.fitState(s);
      expect((j['items'] as List).length, 50);
      expect(j['current'], 0);
    });

    test('a small state is left untouched', () {
      final s = stateOf([item(1, 'x' * 150)]);
      expect(host.fitState(s)['items'], s.toJson()['items']);
    });
  });

  test('a decompression bomb is dropped, not inflated', () {
    final (h, g) = pair();
    final bomb = _forge(
      h.keys.kH2g,
      JamMsg.ping,
      5,
      'h2g',
      '{"v":1,"t":1,"pad":"${'a' * (2 * 1024 * 1024)}"}',
      hostCrypto,
      compress: true,
    );
    expect(g.open(bomb), isNull);
    expect(lines.single, contains('inflate=1'));
  });
}

/// An envelope with valid AEAD but a hand-made body.
Uint8List _forge(
  JamKey key,
  int type,
  int ctr,
  String dir,
  String body,
  JamCrypto c, {
  bool compress = false,
}) {
  List<int> raw = utf8.encode(body);
  if (compress) raw = ZLibCodec().encode(raw);
  final plain = Uint8List.fromList([compress ? 1 : 0, ...raw]);
  final ctrBytes = (ByteData(8)..setUint64(0, ctr)).buffer.asUint8List();
  final ad = Uint8List.fromList([
    ...ascii.encode('ccj1'),
    1,
    type,
    ...ctrBytes,
    ...ascii.encode(dir),
  ]);
  final sealed = c.aeadEncrypt(
    key: key,
    message: c.pad(plain, 256),
    additionalData: ad,
  );
  return Uint8List.fromList([1, type, ...ctrBytes, ...sealed]);
}

/// Pinned from this implementation: a change here must be a deliberate
/// protocol decision (K-JD-03).
const kVector = <String, String>{
  'jamId': '4130ec736c81',
  'token': '7d786b853383',
  'tp': '707acfc765f68af4053ee7ca23c8ffc5',
  'request': '5747295ca6553045ad16f8034c9376f90cdb38c61f0a4f9389d6d34cc024c3ad',
  'accept': 'b6aa2bb8a3a1cc7214ac9d1987b5e1641c727606a0fe31225c93e056e3e66ab2',
  'cmd': '165cc721a4af4955eea8f2b5d5dc97296c128b73db1dde7adcaef41942c61537',
};
