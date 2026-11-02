import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

/// A secret key held as plain bytes, so the interface does not leak the crypto
/// library's types (D-272). [dispose] zeroes it; after that any use of [bytes]
/// throws [StateError].
class JamKey {
  /// Copies [bytes].
  JamKey(Uint8List bytes) : _bytes = Uint8List.fromList(bytes);

  /// Takes ownership of [bytes] (no copy): the caller must not keep or reuse it.
  JamKey.adopt(this._bytes);

  final Uint8List _bytes;
  bool _disposed = false;

  Uint8List get bytes {
    if (_disposed) throw StateError('JamKey used after dispose');
    return _bytes;
  }

  bool get isDisposed => _disposed;

  int get length => _bytes.length;

  void dispose() {
    _disposed = true;
    _bytes.fillRange(0, _bytes.length, 0);
  }
}

class JamKeyPair {
  const JamKeyPair(this.publicKey, this.secretKey);

  final Uint8List publicKey;
  final JamKey secretKey;

  void dispose() => secretKey.dispose();
}

/// Key-exchange result: [rx] decrypts what the peer sends, [tx] encrypts.
class JamSessionKeys {
  const JamSessionKeys(this.rx, this.tx);

  final JamKey rx, tx;

  void dispose() {
    rx.dispose();
    tx.dispose();
  }
}

/// Only the libsodium primitives the remote Jam protocol needs (D-250, D-252).
abstract interface class JamCrypto {
  Uint8List randomBytes(int length);

  JamKeyPair kxKeyPair();

  /// Null for a low-order or invalid peer public key.
  JamSessionKeys? kxClientSessionKeys({
    required Uint8List clientPublicKey,
    required JamKey clientSecretKey,
    required Uint8List serverPublicKey,
  });

  /// Null for a low-order or invalid peer public key.
  JamSessionKeys? kxServerSessionKeys({
    required Uint8List serverPublicKey,
    required JamKey serverSecretKey,
    required Uint8List clientPublicKey,
  });

  JamKey hkdfExtract({Uint8List? salt, required Uint8List ikm});
  JamKey hkdfExpand({
    required JamKey prk,
    required String context,
    required int outLen,
  });

  /// Returns `nonce(24) || ciphertext || tag(16)`; the nonce comes from [randomBytes].
  Uint8List aeadEncrypt({
    required JamKey key,
    required Uint8List message,
    Uint8List? additionalData,
  });

  /// Null when authentication fails or the input is too short.
  Uint8List? aeadDecrypt({
    required JamKey key,
    required Uint8List nonceAndCipher,
    Uint8List? additionalData,
  });

  /// HMAC-SHA-512-256, 32 B tag.
  Uint8List mac({required JamKey key, required Uint8List message});
  bool macVerify({
    required JamKey key,
    required Uint8List message,
    required Uint8List tag,
  });

  Uint8List genericHash(Uint8List message, {required int outLen});

  /// Argon2id (interactive limits) raw output, computed in a separate isolate.
  Future<JamKey> pwhash({
    required String password,
    required Uint8List salt,
    required int outLen,
  });

  Uint8List pad(Uint8List data, int blockSize);

  /// Null when the padding is invalid.
  Uint8List? unpad(Uint8List data, int blockSize);
}

class SodiumJamCrypto implements JamCrypto {
  SodiumJamCrypto._(this._s, Uint8List Function(int)? random)
    : _random = random ?? _s.randombytes.buf;

  /// [random] replaces `randombytes.buf` (nonces and key seeds) in tests.
  static Future<SodiumJamCrypto> create({
    Uint8List Function(int)? random,
  }) async => SodiumJamCrypto._(await SodiumSumoInit.init(), random);

  final SodiumSumo _s;
  final Uint8List Function(int) _random;

  CryptoSumo get _c => _s.crypto;

  @override
  Uint8List randomBytes(int length) => _random(length);

  /// Copies [key] into libsodium memory for one call, then wipes that copy.
  T _with<T>(JamKey key, T Function(SecureKey) use) {
    final k = _s.secureCopy(key.bytes);
    try {
      return use(k);
    } finally {
      k.dispose();
    }
  }

  /// Moves a libsodium key into a [JamKey] and wipes the original.
  JamKey _take(SecureKey k) {
    try {
      return k.runUnlockedSync(JamKey.new);
    } finally {
      k.dispose();
    }
  }

  @override
  JamKeyPair kxKeyPair() {
    final raw = _random(_c.kx.seedBytes);
    final seed = _s.secureCopy(raw);
    raw.fillRange(0, raw.length, 0);
    try {
      final kp = _c.kx.seedKeyPair(seed);
      return JamKeyPair(kp.publicKey, _take(kp.secretKey));
    } finally {
      seed.dispose();
    }
  }

  JamSessionKeys _takeSession(SessionKeys k) =>
      JamSessionKeys(_take(k.rx), _take(k.tx));

  @override
  JamSessionKeys? kxClientSessionKeys({
    required Uint8List clientPublicKey,
    required JamKey clientSecretKey,
    required Uint8List serverPublicKey,
  }) {
    try {
      return _with(
        clientSecretKey,
        (sk) => _takeSession(
          _c.kx.clientSessionKeys(
            clientPublicKey: clientPublicKey,
            clientSecretKey: sk,
            serverPublicKey: serverPublicKey,
          ),
        ),
      );
    } on SodiumException {
      return null; // low-order peer key: the caller counts it as a drop
    }
  }

  @override
  JamSessionKeys? kxServerSessionKeys({
    required Uint8List serverPublicKey,
    required JamKey serverSecretKey,
    required Uint8List clientPublicKey,
  }) {
    try {
      return _with(
        serverSecretKey,
        (sk) => _takeSession(
          _c.kx.serverSessionKeys(
            serverPublicKey: serverPublicKey,
            serverSecretKey: sk,
            clientPublicKey: clientPublicKey,
          ),
        ),
      );
    } on SodiumException {
      return null; // low-order peer key: the caller counts it as a drop
    }
  }

  @override
  JamKey hkdfExtract({Uint8List? salt, required Uint8List ikm}) =>
      _take(_c.kdfHkdfSha256.extract(salt: salt, ikm: ikm));

  @override
  JamKey hkdfExpand({
    required JamKey prk,
    required String context,
    required int outLen,
  }) => _with(
    prk,
    (k) => _take(
      _c.kdfHkdfSha256.expand(masterKey: k, context: context, outLen: outLen),
    ),
  );

  @override
  Uint8List aeadEncrypt({
    required JamKey key,
    required Uint8List message,
    Uint8List? additionalData,
  }) {
    final aead = _c.aeadXChaCha20Poly1305IETF;
    final nonce = _random(aead.nonceBytes);
    final ct = _with(
      key,
      (k) => aead.encrypt(
        message: message,
        nonce: nonce,
        key: k,
        additionalData: additionalData,
      ),
    );
    return Uint8List.fromList([...nonce, ...ct]);
  }

  @override
  Uint8List? aeadDecrypt({
    required JamKey key,
    required Uint8List nonceAndCipher,
    Uint8List? additionalData,
  }) {
    final aead = _c.aeadXChaCha20Poly1305IETF;
    if (nonceAndCipher.length < aead.nonceBytes + aead.aBytes) return null;
    try {
      return _with(
        key,
        (k) => aead.decrypt(
          cipherText: Uint8List.sublistView(nonceAndCipher, aead.nonceBytes),
          nonce: Uint8List.sublistView(nonceAndCipher, 0, aead.nonceBytes),
          key: k,
          additionalData: additionalData,
        ),
      );
    } on SodiumException {
      return null; // forged or corrupted message: the caller drops and counts it
    }
  }

  @override
  Uint8List mac({required JamKey key, required Uint8List message}) =>
      _with(key, (k) => _c.auth(message: message, key: k));

  @override
  bool macVerify({
    required JamKey key,
    required Uint8List message,
    required Uint8List tag,
  }) =>
      tag.length == _c.auth.bytes &&
      _with(key, (k) => _c.auth.verify(tag: tag, message: message, key: k));

  @override
  Uint8List genericHash(Uint8List message, {required int outLen}) =>
      _c.genericHash(message: message, outLen: outLen);

  @override
  Future<JamKey> pwhash({
    required String password,
    required Uint8List salt,
    required int outLen,
  }) async {
    final s = _s; // capture the sodium instance, not `this` (holds _random)
    final raw = await s.runIsolated(
      (keys, pairs) => s.crypto.pwhash.callStr(
        outLen: outLen,
        password: password,
        salt: salt,
        opsLimit: s.crypto.pwhash.opsLimitInteractive,
        memLimit: s.crypto.pwhash.memLimitInteractive,
        alg: CryptoPwhashAlgorithm.argon2id13,
      ),
    );
    return _take(raw);
  }

  @override
  Uint8List pad(Uint8List data, int blockSize) => _s.pad(data, blockSize);

  @override
  Uint8List? unpad(Uint8List data, int blockSize) {
    try {
      return _s.unpad(data, blockSize);
    } on SodiumException {
      return null; // invalid padding: the caller drops the message
    }
  }
}
