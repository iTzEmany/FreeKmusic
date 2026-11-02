import 'dart:convert';
import 'dart:typed_data';

import 'package:codecore/services/jam/remote/jam_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';

Uint8List hex(String s) => Uint8List.fromList([
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
]);

String toHex(List<int> b) =>
    b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

void main() {
  late Uint8List nonce;
  late SodiumJamCrypto c;

  setUpAll(() async {
    c = await SodiumJamCrypto.create(random: (n) => n == 24 ? nonce : _seq(n));
  });

  test('HKDF-SHA-256: RFC 5869 A.1 PRK, A.3 OKM', () {
    final ikm = Uint8List.fromList(List.filled(22, 0x0b));
    // RFC 5869 A.1 (rfc-editor.org/rfc/rfc5869): salt 0x00..0x0c -> PRK
    final prk = c.hkdfExtract(
      salt: hex('000102030405060708090a0b0c'),
      ikm: ikm,
    );
    expect(
      toHex(prk.bytes),
      '077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5',
    );
    // RFC 5869 A.3: empty salt and info (A.1 info 0xf0.. is not a valid String context)
    final prk3 = c.hkdfExtract(ikm: ikm);
    expect(
      toHex(prk3.bytes),
      '19ef24a32c717b167f33a91d6f648bdf96596776afdb6377ac434c1c293ccb04',
    );
    final okm = c.hkdfExpand(prk: prk3, context: '', outLen: 42);
    expect(
      toHex(okm.bytes),
      '8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d9d201395faa4b61a96c8',
    );
  });

  group('XChaCha20-Poly1305', () {
    // draft-irtf-cfrg-xchacha-03 A.3.1
    final pt = hex(
      '4c616469657320616e642047656e746c656d656e206f662074686520636c617373206f66202739393a204966204920636f756c64206f6666657220796f75206f6e6c79206f6e652074697020666f7220746865206675747572652c2073756e73637265656e20776f756c642062652069742e',
    );
    final aad = hex('50515253c0c1c2c3c4c5c6c7');
    final keyHex =
        '808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f';
    const ivHex = '404142434445464748494a4b4c4d4e4f5051525354555657';
    final ct = hex(
      'bd6d179d3e83d43b9576579493c0e939572a1700252bfaccbed2902c21396cbb731c7f1b0b4aa6440bf3a82f4eda7e39ae64c6708c54c216cb96b72e1213b4522f8c9ba40db5d945b11b69b982c1bb9e3f3fac2bc369488f76b2383565d3fff921f9664c97637da9768812f615c68b13b52e'
      'c0875924c1c7987947deafd8780acf49',
    );

    test('encrypt gives nonce || ciphertext || tag', () {
      nonce = hex(ivHex);
      final out = c.aeadEncrypt(
        key: JamKey(hex(keyHex)),
        message: pt,
        additionalData: aad,
      );
      expect(toHex(out), toHex([...nonce, ...ct]));
    });

    test('decrypt, and a flipped tag is rejected', () {
      final key = JamKey(hex(keyHex));
      final input = Uint8List.fromList([...hex(ivHex), ...ct]);
      expect(
        c.aeadDecrypt(key: key, nonceAndCipher: input, additionalData: aad),
        pt,
      );
      input[input.length - 1] ^= 1;
      expect(
        c.aeadDecrypt(key: key, nonceAndCipher: input, additionalData: aad),
        isNull,
      );
    });
  });

  test('kx: libsodium test/default/kx.exp', () {
    // seeds as in libsodium kx.c: client 0..31, server = same seed incremented (byte 0 + 1)
    final seed = Uint8List.fromList(List.generate(32, (i) => i));
    final seed2 = Uint8List.fromList(seed)..[0] = 1;
    final k = SodiumJamCrypto.create(random: (_) => Uint8List.fromList(seed));
    return Future.wait([
      k,
      SodiumJamCrypto.create(random: (_) => Uint8List.fromList(seed2)),
    ]).then((l) {
      final client = l[0].kxKeyPair();
      final server = l[1].kxKeyPair();
      expect(
        toHex(client.publicKey),
        '0e0216223f147143d32615a91189c288c1728cba3cc5f9f621b1026e03d83129',
      );
      final cs = c.kxClientSessionKeys(
        clientPublicKey: client.publicKey,
        clientSecretKey: client.secretKey,
        serverPublicKey: server.publicKey,
      );
      final ss = c.kxServerSessionKeys(
        serverPublicKey: server.publicKey,
        serverSecretKey: server.secretKey,
        clientPublicKey: client.publicKey,
      );
      expect(
        toHex(ss!.rx.bytes),
        '62c8f4fa81800abd0577d99918d129b65deb789af8c8351f391feb0cbf238604',
      );
      expect(
        toHex(ss.tx.bytes),
        '749519c68059bce69f7cfcc7b387a3de1a1e8237d110991323bf62870115731a',
      );
      expect(
        toHex(cs!.rx.bytes),
        '749519c68059bce69f7cfcc7b387a3de1a1e8237d110991323bf62870115731a',
      );
      expect(
        toHex(cs.tx.bytes),
        '62c8f4fa81800abd0577d99918d129b65deb789af8c8351f391feb0cbf238604',
      );
    });
  });

  test('auth: libsodium test/default/auth.exp (HMAC-SHA-512-256)', () {
    // key "Jefe" zero-padded to 32 B, message from RFC 4231 case 2, as in auth.c
    final key = JamKey(Uint8List(32)..setAll(0, utf8.encode('Jefe')));
    final msg = Uint8List.fromList(utf8.encode('what do ya want for nothing?'));
    final tag = c.mac(key: key, message: msg);
    expect(
      toHex(tag),
      '164b7a7bfcf819e2e395fbe73b56e0a387bd64222e831fd610270cd7ea250554',
    );
    expect(c.macVerify(key: key, message: msg, tag: tag), isTrue);
    expect(c.macVerify(key: key, message: msg, tag: Uint8List(32)), isFalse);
  });

  test('pad/unpad round trip to a 256 B block', () {
    final data = Uint8List.fromList(utf8.encode('{"id":"x"}'));
    final padded = c.pad(data, 256);
    expect(padded.length, 256);
    expect(c.unpad(padded, 256), data);
  });

  test('kx: an all-zero (low-order) peer key gives null on both sides', () {
    final kp = c.kxKeyPair();
    final zero = Uint8List(32);
    expect(
      c.kxClientSessionKeys(
        clientPublicKey: kp.publicKey,
        clientSecretKey: kp.secretKey,
        serverPublicKey: zero,
      ),
      isNull,
    );
    expect(
      c.kxServerSessionKeys(
        serverPublicKey: kp.publicKey,
        serverSecretKey: kp.secretKey,
        clientPublicKey: zero,
      ),
      isNull,
    );
  });

  test('unpad on invalid padding gives null', () {
    expect(c.unpad(Uint8List(256), 256), isNull);
  });

  test('macVerify with a short tag is false', () {
    final key = JamKey(Uint8List(32));
    expect(
      c.macVerify(key: key, message: Uint8List(1), tag: Uint8List(5)),
      isFalse,
    );
  });

  test('aeadDecrypt: wrong AD or too-short input gives null', () {
    final key = JamKey(Uint8List(32));
    final sealed = c.aeadEncrypt(
      key: key,
      message: Uint8List.fromList([1, 2, 3]),
      additionalData: Uint8List.fromList([9]),
    );
    expect(
      c.aeadDecrypt(
        key: key,
        nonceAndCipher: sealed,
        additionalData: Uint8List.fromList([8]),
      ),
      isNull,
    );
    expect(c.aeadDecrypt(key: key, nonceAndCipher: Uint8List(39)), isNull);
  });

  test('pwhash in the isolate equals Argon2id computed in place', () async {
    final salt = Uint8List.fromList(utf8.encode('codecore-jam-c1!'));
    final sodium = await SodiumSumoInit.init();
    final direct = sodium.crypto.pwhash.callStr(
      outLen: 64,
      password: 'ABCD2345',
      salt: salt,
      opsLimit: sodium.crypto.pwhash.opsLimitInteractive,
      memLimit: sodium.crypto.pwhash.memLimitInteractive,
      alg: CryptoPwhashAlgorithm.argon2id13,
    );
    final expected = direct.runUnlockedSync((b) => Uint8List.fromList(b));
    final a = await c.pwhash(password: 'ABCD2345', salt: salt, outLen: 64);
    expect(a.length, 64);
    expect(a.bytes, expected);
    final other = await c.pwhash(password: 'ABCD2346', salt: salt, outLen: 64);
    expect(other.bytes, isNot(expected));
  });
}

Uint8List _seq(int n) => Uint8List.fromList(List.generate(n, (i) => i));
