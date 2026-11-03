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
  'state': p.fitState(s)!,
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

    test('exact edges: window w is valid until the end of window w+1', () {
      const w10 = 10 * 30000;
      final old = request(ms: w10);
      expect(
        host.openRequest(old.bytes, secrets, hostMs: 12 * 30000 - 1),
        isNotNull,
      );
      final late = request(ms: w10);
      expect(host.openRequest(late.bytes, secrets, hostMs: 12 * 30000), isNull);
    });

    test('a token of a future window is refused', () {
      final g = request(ms: 11 * 30000); // host is still in window 10
      expect(host.openRequest(g.bytes, secrets, hostMs: t0), isNull);
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

    test('an intermediary request with its own Gpk and a wrong key: auth', () {
      final g = request(proof: Uint8List(6)); // fresh Gpk, not the token
      expect(host.openRequest(g.bytes, secrets, hostMs: t0), isNull);
      expect(lines.single, contains('auth=1'));
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

    test('a wrong schema does not consume the counter', () {
      final (h, g) = pair();
      final bad = _forge(
        h.keys.kH2g,
        JamMsg.ping,
        1,
        'h2g',
        '{"v":"x"}',
        hostCrypto,
      );
      expect(g.open(bad), isNull);
      final ok = _forge(
        h.keys.kH2g,
        JamMsg.ping,
        1,
        'h2g',
        '{"v":1,"t":2}',
        hostCrypto,
      );
      expect(g.open(ok), isNotNull);
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

  test('matchFriendLabel accepts the windows w-1, w, w+1 of the guest clock and no other', () {
    final ak = Uint8List.fromList(List.generate(32, (i) => i + 1));
    final fp = host.fingerprint(secrets.hpk);
    final label = host.friendLabelAt(ak, t0, fp);
    for (final d in [-1, 0, 1]) {
      expect(guest.matchFriendLabel([ak], label, t0 + d * 30000, fp), 0, reason: 'w${d >= 0 ? '+' : ''}$d');
    }
    for (final d in [-2, 2]) {
      expect(guest.matchFriendLabel([ak], label, t0 + d * 30000, fp), isNull, reason: 'w$d');
    }
  });

  test('advertAt: window token and label change, two Jams of a host share nothing (R-133)', () {
    final ak = Uint8List.fromList(List.generate(32, (i) => i));
    final other = host.newHostSecrets();
    final a = host.advertAt(secrets, t0, ak: ak, broker: 0);
    expect(a.length, 26);
    final d = guest.decodeAdvert(a)!;
    expect(d.jamId, secrets.jamId);
    expect(d.token, host.token(secrets, t0));
    expect(d.fingerprint, host.fingerprint(secrets.hpk));
    expect(guest.matchFriendLabel([ak], d.friendLabel, t0, d.fingerprint), 0);
    expect(guest.matchFriendLabel([ak], d.friendLabel, t0, other.hpk.sublist(0, 8)), isNull); // bound to the Jam
    expect(d.broker, 0);
    // The next window: another token and label.
    final n = guest.decodeAdvert(host.advertAt(secrets, t0 + 30000, ak: ak, broker: 0xFF))!;
    expect(n.token, isNot(d.token));
    expect(n.friendLabel, isNot(d.friendLabel));
    expect(n.broker, 0xFF);
    // A second Jam of the same host, two windows later: no part in common.
    final o = guest.decodeAdvert(host.advertAt(other, t0 + 60000, ak: ak, broker: 0))!;
    expect(o.jamId, isNot(d.jamId));
    expect(o.token, isNot(d.token));
    expect(o.fingerprint, isNot(d.fingerprint));
    expect(o.friendLabel, isNot(d.friendLabel));
  });

  test('code is normalized and Crockford-safe', () {
    expect(JamProtocol.normalizeCode(' abcd-23o1 '), 'ABCD2301');
    expect(JamProtocol.normalizeCode('abcd 23il'), 'ABCD2311');
    expect(JamProtocol.normalizeCode('ABCD234'), isNull, reason: 'length');
    expect(JamProtocol.normalizeCode('ABCD234U'), isNull, reason: 'U');
    expect(JamProtocol.normalizeCode('ABCD234!'), isNull);
    for (final u in ['ıııı-ıııı', 'ßßßß', 'ſſſſ']) {
      expect(JamProtocol.normalizeCode(u), isNull, reason: u);
    }
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
    final opened = guest.openCode(sealed, guestKeys.kc, nowMs: 50)!;
    expect(opened.hpk, secrets.hpk);
    expect(opened.jamId, secrets.jamId);
    expect(opened.expMs, 99);
    expect(opened.brokers, info.brokers);
    final wrong = await guest.deriveCode('ABCD2346');
    expect(guest.openCode(sealed, wrong.kc, nowMs: 50), isNull);
    expect(guest.openCode(sealed, guestKeys.kc, nowMs: 98), isNotNull);
    clock = clock.add(const Duration(minutes: 2));
    expect(guest.openCode(sealed, guestKeys.kc, nowMs: 99), isNull);
    expect(lines.last, contains('expired=1'));

    final g = guest.buildRequest(
      jamId: opened.jamId,
      hpk: opened.hpk,
      proof: guestKeys.kc.bytes,
      id: 'd',
      name: 'n',
    )!;
    final r = host.openRequest(g.bytes, secrets, hostMs: t0, kc: hostKeys.kc)!;
    expect(r.viaCode, isTrue);
    guestKeys.dispose();
    expect(() => guestKeys.kc.bytes, throwsStateError);
  });

  test('lobby: 34 B, cleared lobby is not a drop', () {
    final l = host.lobby(secrets.hpk);
    expect(l.length, JamWire.lobbyLength);
    final fp = host.fingerprint(secrets.hpk);
    expect(guest.parseLobby(l, fpH: fp), secrets.hpk);
    expect(guest.parseLobby(Uint8List(0), fpH: fp), isNull);
    expect(lines, isEmpty);
    expect(guest.parseLobby(Uint8List(33), fpH: fp), isNull);
    expect(lines, hasLength(1));
  });

  test('LOBBY with a replaced Hpk is refused', () {
    final fake = host.lobby(host.newHostSecrets().hpk);
    expect(guest.parseLobby(fake, fpH: host.fingerprint(secrets.hpk)), isNull);
    expect(lines.single, contains('hpk=1'));
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
        'state': host.fitState(stateOf(bigItems()))!,
      });
      expect(sealed, isNotNull);
      expect(sealed!.length, lessThan(64 * 1024));
      final got = g.open(sealed)!;
      expect(got.state!.items, hasLength(200));
      expect(got.state!.items.first.title.length, 64);
    });

    test('packed in an isolate (K-JD-09) opens to the same state', () async {
      final (h, g) = pair();
      final st = stateOf(bigItems(), current: 5);
      final bytes = (await packStateOffThread(st))!;
      expect(bytes, packState(st), reason: 'same bytes in and out of the isolate');
      final got = g.open(h.sealPacked(JamMsg.state, bytes)!)!;
      final plain = g.open(h.seal(JamMsg.state, {'state': host.fitState(st)!})!)!;
      expect(got.state!.toJson(), plain.state!.toJson());
      expect(got.state!.items, hasLength(200));
    });

    test('a state over the budget even cut packs to null', () {
      final rnd = Random(3);
      String t() => String.fromCharCodes(List.generate(64, (_) => 33 + rnd.nextInt(90)));
      final heavy = [
        for (var i = 0; i < 1200; i++)
          item(i + 1, t(), artist: t(), album: t()),
      ];
      expect(packState(stateOf(heavy)), isNull);
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
      final j = host.fitState(s)!;
      expect((j['items'] as List).length, 50);
      expect(j['current'], 0);
      expect(
        ZLibCodec().encode(utf8.encode(jsonEncode({'state': j}))).length,
        lessThanOrEqualTo(JamWire.stateBudget),
      );
    });

    test(
      'still too big with nothing to drop: null, never an oversized state',
      () {
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
        expect(host.fitState(stateOf(heavy)), isNull);
      },
    );

    test('a small state is left untouched', () {
      final s = stateOf([item(1, 'x' * 150)]);
      expect(host.fitState(s)!['items'], s.toJson()['items']);
    });
  });

  test('QR cuts to 4 brokers and skips a host over 255 bytes', () {
    final qr = JamQr(
      jamId: secrets.jamId,
      token: host.token(secrets, t0),
      hpk: secrets.hpk,
      friendLabel: Uint8List(4),
      brokers: [
        BrokerEntry(host: '${'a' * 256}.org', port: 1),
        for (var i = 0; i < 5; i++) BrokerEntry(host: 'b$i.org', port: 8883),
      ],
    );
    final back = guest.decodeQr(host.encodeQr(qr))!;
    expect(back.brokers.map((b) => b.host), [
      for (var i = 0; i < 4; i++) 'b$i.org',
    ]);
    expect(JamProtocol.brokersJson(qr.brokers), hasLength(JamWire.maxBrokers));
  });

  test('ACCEPT brokers are validated and typed', () {
    final (h, g) = pair();
    Map<String, Object?> body(Object brokers) => {
      ...acceptBody(stateOf([item(1, 'x')]), host),
      'brokers': brokers,
    };
    final ok = g.open(
      h.seal(
        JamMsg.accept,
        body([
          {'host': 'b.example', 'port': 8883, 'tls': true},
        ]),
      )!,
    )!;
    expect(ok.brokers, const [BrokerEntry(host: 'b.example', port: 8883)]);
    for (final bad in [
      [
        {'host': 'a b', 'port': 1},
      ],
      [
        {'host': 'x', 'port': 'y'},
      ],
      [
        for (var i = 0; i < 5; i++) {'host': 'b$i', 'port': 1},
      ],
    ]) {
      expect(g.open(h.seal(JamMsg.accept, body(bad))!), isNull);
    }
    expect(
      g.open(h.seal(JamMsg.accept, {...body([]), 'host': ''})!),
      isNull,
      reason: 'empty host name',
    );
  });

  test('after dispose, keys, channels and host secrets throw StateError', () {
    final (h, g) = pair();
    final ok = h.seal(JamMsg.ping, {'v': 1, 't': 1})!;
    g.dispose();
    expect(() => g.open(ok), throwsStateError);
    expect(() => g.seal(JamMsg.leave, {}), throwsStateError);
    expect(() => g.keys.kG2h.bytes, throwsStateError);
    final req = request();
    secrets.dispose();
    expect(() => host.token(secrets, t0), throwsStateError);
    expect(
      () => host.openRequest(req.bytes, secrets, hostMs: t0),
      throwsStateError,
    );
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
