import 'dart:convert';
import 'dart:io' show ZLibCodec, ZLibDecoder;
import 'dart:isolate';
import 'dart:typed_data';

import '../../../core/app_log.dart';
import '../jam_models.dart';
import 'broker_entry.dart';
import 'jam_crypto.dart';

/// Remote Jam wire protocol, pure (no I/O). Formulas, labels and sizes follow
/// `docs/feature-jam-distanza.md` §Protocollo di sicurezza to the letter: a change
/// is a new decision (K-JD-03).
abstract final class JamWire {
  static const version = 1;
  static const tLobby = 1, tRequest = 2, tCode = 3;
  static const maxEnvelope = 65536, maxRequest = 2048, maxCode = 2048;
  static const lobbyLength = 34;
  static const maxInflated = 512 * 1024;

  /// Brokers in a QR, a CODE or an ACCEPT: encoders cut to it, decoders refuse more.
  static const maxBrokers = 4;

  /// Compressed state above this is shrunk (titles cut, played items dropped).
  static const stateBudget = 60 * 1024;
  static const windowMs = 30000;
  static const padBlock = 256;
  static const codeAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const codeSalt = 'codecore-jam-c1!';
}

/// Message types inside a session envelope.
abstract final class JamMsg {
  static const accept = 0x10, state = 0x11, result = 0x12, ping = 0x13;
  static const no = 0x14, bye = 0x15, time = 0x16;
  static const cmd = 0x20, gPing = 0x21, sync = 0x22, leave = 0x23;
  static const friend = 0x24, gTime = 0x25;
  static const h2g = {accept, state, result, ping, no, bye, time};
  static const g2h = {cmd, gPing, sync, leave, friend, gTime};
}

/// Counts dropped messages by reason and writes one line per minute (R-134).
/// The first drop writes at once; later ones accumulate until a drop arrives a
/// minute after the last line (shortcut: no timer, so counts of a quiet end
/// stay unwritten).
class JamDropLog {
  JamDropLog({DateTime Function()? now, void Function(String)? sink})
    : _now = now ?? DateTime.now,
      _sink = sink ?? AppLog.w;

  final DateTime Function() _now;
  final void Function(String) _sink;
  final _counts = <String, int>{};
  DateTime? _last;

  void drop(String reason) {
    _counts[reason] = (_counts[reason] ?? 0) + 1;
    final now = _now();
    final last = _last;
    if (last != null && now.difference(last) < const Duration(minutes: 1)) {
      return;
    }
    _last = now;
    _sink(
      'jam bridge dropped: ${_counts.entries.map((e) => '${e.key}=${e.value}').join(' ')}',
    );
    _counts.clear();
  }
}

String b64u(List<int> b) => base64Url.encode(b).replaceAll('=', '');

Uint8List? unb64u(Object? s) {
  if (s is! String) return null;
  try {
    return base64Url.decode(base64Url.normalize(s));
  } on FormatException {
    return null;
  }
}

/// Everything a host creates when the bridge turns on (one per switch-on).
class JamHostSecrets {
  JamHostSecrets._(this._s, this.hk, this.jamId, this.kt);

  final JamKey _s;
  final JamKeyPair hk;
  final Uint8List jamId;
  final JamKey kt;

  /// `Gpk` already used for a request in this switch-on (R-132).
  final seenGpk = <String>{};

  Uint8List get hpk => hk.publicKey;

  /// After this, [JamProtocol.token] / `openRequest` throw [StateError].
  void dispose() {
    _s.dispose();
    hk.dispose();
    kt.dispose();
  }
}

/// Keys of one host-guest pair. [tp] names the pair's two channels.
class JamPairKeys {
  JamPairKeys(this.kReq, this.kG2h, this.kH2g, this.fkp, this.tp);

  final JamKey kReq, kG2h, kH2g, fkp;
  final Uint8List tp;

  void dispose() {
    for (final k in [kReq, kG2h, kH2g, fkp]) {
      k.dispose();
    }
  }
}

/// A message that passed every check. [state] / [command] are set for the
/// types that carry them.
class JamMessage {
  const JamMessage(
    this.type,
    this.body, {
    this.state,
    this.command,
    this.brokers = const [],
  });

  final int type;
  final Map<String, Object?> body;
  final JamState? state;
  final JamCommand? command;

  /// Validated brokers of an ACCEPT, empty for the other types.
  final List<BrokerEntry> brokers;
}

class JamHostRequest {
  const JamHostRequest({
    required this.id,
    required this.name,
    required this.gpk,
    required this.channel,
    required this.viaCode,
    this.friendProof,
  });

  final String id, name;
  final Uint8List gpk;
  final Uint8List? friendProof;
  final JamChannel channel;
  final bool viaCode;
}

class JamGuestRequest {
  const JamGuestRequest(this.bytes, this.channel);

  final Uint8List bytes;
  final JamChannel channel;
}

class JamCodeInfo {
  const JamCodeInfo({
    required this.jamId,
    required this.hpk,
    required this.expMs,
    required this.brokers,
    required this.gone,
  });

  final Uint8List jamId, hpk;
  final int expMs;
  final List<BrokerEntry> brokers;
  final bool gone;
}

class JamCodeKeys {
  const JamCodeKeys(this.topicId, this.kc);

  final Uint8List topicId;
  final JamKey kc;

  void dispose() => kc.dispose();
}

class JamQr {
  const JamQr({
    required this.jamId,
    required this.token,
    required this.hpk,
    required this.friendLabel,
    required this.brokers,
  });

  final Uint8List jamId, token, hpk, friendLabel;
  final List<BrokerEntry> brokers;
}

class JamAdvert {
  const JamAdvert({
    required this.jamId,
    required this.token,
    required this.fingerprint,
    required this.friendLabel,
    required this.broker,
  });

  final Uint8List jamId, token, fingerprint, friendLabel;

  /// Index into `kDefaultJamBrokers`, `0xFF` = custom broker.
  final int broker;
}

/// One direction pair of a host-guest session: counters, keys, envelopes.
class JamChannel {
  JamChannel._(this._p, this.keys, {required bool host})
    : _host = host,
      _sendKey = host ? keys.kH2g : keys.kG2h,
      _recvKey = host ? keys.kG2h : keys.kH2g;

  final JamProtocol _p;
  final JamPairKeys keys;
  final bool _host;
  final JamKey _sendKey, _recvKey;
  int _sent = 0, _received = 0;

  String get _sendDir => _host ? 'h2g' : 'g2h';
  String get _recvDir => _host ? 'g2h' : 'h2g';

  /// Topic this side publishes to / listens on.
  String get sendTopic => JamProtocol.pairTopic(keys.tp, toGuest: _host);
  String get recvTopic => JamProtocol.pairTopic(keys.tp, toGuest: !_host);

  /// After this, [seal] and [open] throw [StateError].
  void dispose() => keys.dispose();

  void _live() {
    if (keys.kReq.isDisposed) throw StateError('JamChannel used after dispose');
  }

  /// Null when the envelope would pass [JamWire.maxEnvelope]; the counter is
  /// then not consumed.
  Uint8List? seal(int type, Object? body) {
    _live();
    return _finishSeal(type, _pack(body));
  }

  /// Runs strictly after the earlier [sealStateAsync] / [sealAsync] calls, so
  /// counters and the order of publishes follow the order of the calls.
  Future<T> _serial<T>(Future<T> Function() f) {
    _queued++;
    final r = _tail.then((_) => f());
    _tail = r.then((_) {}, onError: (_) {}).whenComplete(() => _queued--);
    return r;
  }

  Future<void> _tail = Future.value();
  int _queued = 0;

  /// True while an async seal is in flight: a sync [seal] now would
  /// overtake it, so the caller must use [sealAsync] to keep the order.
  bool get busy => _queued > 0;

  /// [seal] queued behind the async calls in flight. [publish] runs right
  /// after sealing, in the same queue slot: counter order = publish order.
  /// False when the envelope would be too big.
  Future<bool> sealAsync(
    int type,
    Object? body,
    void Function(Uint8List) publish,
  ) => _serial(() async {
    _live();
    return _emit(_finishSeal(type, _pack(body)), publish);
  });

  bool _emit(Uint8List? b, void Function(Uint8List) publish) {
    if (b == null) return false;
    publish(b);
    return true;
  }

  /// [seal] of a STATE with [JamProtocol.fitState] applied: the JSON, the
  /// size fitting and the compression (the slow part, K-JD-09) run in an
  /// isolate; false when the state does not fit. Throws [StateError] when the
  /// channel was disposed meanwhile. See [sealAsync] for [publish].
  Future<bool> sealStateAsync(
    JamState st,
    void Function(Uint8List) publish,
  ) => _serial(() async {
    _live();
    // shortcut: a short list is packed inline (the isolate costs more than it saves).
    final packed = st.items.length < _isolateItems
        ? _packState(st)
        : await _packStateInIsolate(st);
    _live();
    return _emit(
      packed == null ? null : _finishSeal(JamMsg.state, packed),
      publish,
    );
  });

  Uint8List? _finishSeal(int type, Uint8List plain) {
    final ctr = _sent + 1;
    final sealed = _p.crypto.aeadEncrypt(
      key: _sendKey,
      message: _p.crypto.pad(plain, JamWire.padBlock),
      additionalData: _ad(type, ctr, _sendDir),
    );
    final out = Uint8List.fromList([..._header(type, ctr), ...sealed]);
    if (out.length > JamWire.maxEnvelope) return null;
    _sent = ctr;
    return out;
  }

  /// Receive order (R-132): size, version and type, AEAD, counter, schema.
  JamMessage? open(Uint8List bytes) {
    _live();
    final drops = _p.drops;
    if (bytes.length > JamWire.maxEnvelope || bytes.length < 10 + 24 + 16) {
      drops.drop('size');
      return null;
    }
    final allowed = _host ? JamMsg.g2h : JamMsg.h2g;
    if (bytes[0] != JamWire.version) {
      drops.drop('version');
      return null;
    }
    final type = bytes[1];
    if (!allowed.contains(type)) {
      drops.drop('type');
      return null;
    }
    final ctr = ByteData.sublistView(bytes).getUint64(2);
    final plain = _p.crypto.aeadDecrypt(
      key: _recvKey,
      nonceAndCipher: Uint8List.sublistView(bytes, 10),
      additionalData: _ad(type, ctr, _recvDir),
    );
    if (plain == null) {
      drops.drop('auth');
      return null;
    }
    if (ctr <= _received) {
      drops.drop('counter');
      return null;
    }
    final msg = _p._parseBody(plain, type);
    if (msg == null) return null;
    _received = ctr;
    return msg;
  }

  Uint8List _ad(int type, int ctr, String dir) => Uint8List.fromList([
    ...ascii.encode('ccj1'),
    JamWire.version,
    type,
    ..._u64(ctr),
    ...ascii.encode(dir),
  ]);

  Uint8List _header(int type, int ctr) =>
      Uint8List.fromList([JamWire.version, type, ..._u64(ctr)]);
}

Uint8List _u64(int v) => (ByteData(8)..setUint64(0, v)).buffer.asUint8List();

Uint8List _cat(List<List<int>> parts) =>
    Uint8List.fromList([for (final p in parts) ...p]);

class JamProtocol {
  JamProtocol(this.crypto, {JamDropLog? drops}) : drops = drops ?? JamDropLog();

  final JamCrypto crypto;
  final JamDropLog drops;

  // ---- derivations -------------------------------------------------------

  JamHostSecrets newHostSecrets() {
    final s = JamKey.adopt(crypto.randomBytes(32));
    final hk = crypto.kxKeyPair();
    final prk = crypto.hkdfExtract(ikm: s.bytes);
    final jamId = crypto.hkdfExpand(
      prk: prk,
      context: 'ccj1 jam-id',
      outLen: 32,
    );
    final kt = crypto.hkdfExpand(prk: prk, context: 'ccj1 token', outLen: 32);
    prk.dispose();
    final id = Uint8List.fromList(jamId.bytes.sublist(0, 6));
    jamId.dispose();
    return JamHostSecrets._(s, hk, id, kt);
  }

  static int windowOf(int hostMs) => hostMs ~/ JamWire.windowMs;

  Uint8List _tag(JamKey key, String label, List<int> data, int len) =>
      Uint8List.fromList(
        crypto
            .mac(key: key, message: _cat([ascii.encode(label), data]))
            .sublist(0, len),
      );

  /// `T_w` (6 B) of the window holding [hostMs].
  Uint8List token(JamHostSecrets h, int hostMs) =>
      _tag(h.kt, 'ccj1-tok', _u64(windowOf(hostMs)), 6);

  /// `T_w` and `T_(w-1)`: at most 60 s of validity (R-139).
  List<Uint8List> acceptedTokens(JamHostSecrets h, int hostMs) => [
    for (final w in [windowOf(hostMs), windowOf(hostMs) - 1])
      _tag(h.kt, 'ccj1-tok', _u64(w), 6),
  ];

  /// 4 B label of the friends' announcement for window [w], bound to the Jam
  /// by its fingerprint [fpH]: a label copied into another Jam matches nothing.
  Uint8List friendLabel(JamKey ak, int w, Uint8List fpH) =>
      _tag(ak, 'ccj1-ft', _cat([_u64(w), fpH]), 4);

  /// The label to announce at [ms] (host clock) for the announce key [ak] and the Jam [fpH].
  Uint8List friendLabelAt(Uint8List ak, int ms, Uint8List fpH) {
    final k = JamKey(ak);
    try {
      return friendLabel(k, windowOf(ms), fpH);
    } finally {
      k.dispose();
    }
  }

  /// Index of the first key in [aks] whose label for `w-1`, `w` or `w+1` of
  /// [nowMs] (the guest's clock) for the Jam [fpH] equals [label]; null for a stranger.
  int? matchFriendLabel(List<Uint8List> aks, Uint8List label, int nowMs, Uint8List fpH) {
    if (label.length != 4) return null;
    final w = windowOf(nowMs);
    for (var i = 0; i < aks.length; i++) {
      final k = JamKey(aks[i]);
      try {
        for (final d in [0, -1, 1]) {
          final l = friendLabel(k, w + d, fpH);
          if (l[0] == label[0] && l[1] == label[1] && l[2] == label[2] && l[3] == label[3]) {
            return i;
          }
        }
      } finally {
        k.dispose();
      }
    }
    return null;
  }

  Uint8List fingerprint(Uint8List hpk) =>
      Uint8List.fromList(crypto.genericHash(hpk, outLen: 16).sublist(0, 8));

  Uint8List friendProof(JamKey fkp, Uint8List jamId, Uint8List gpk) =>
      _tag(fkp, 'ccj1-fp', _cat([jamId, gpk]), 32);

  bool friendProofValid(
    JamKey savedFkp,
    Uint8List jamId,
    Uint8List gpk,
    Uint8List proof,
  ) => crypto.macVerify(
    key: savedFkp,
    message: _cat([ascii.encode('ccj1-fp'), jamId, gpk]),
    tag: proof,
  );

  // ---- topics ------------------------------------------------------------

  static String lobbyTopic(Uint8List jamId) => 'ccj1/${b64u(jamId)}/l';
  static String requestTopic(Uint8List jamId) => 'ccj1/${b64u(jamId)}/r';
  static String codeTopic(Uint8List topicId) => 'ccj1/c/${b64u(topicId)}';
  static String pairTopic(Uint8List tp, {required bool toGuest}) =>
      'ccj1/${b64u(tp)}/${toGuest ? 'h' : 'g'}';

  // ---- code (D-257) ------------------------------------------------------

  /// 8 Crockford base32 characters = 40 random bits.
  String generateCode() {
    final r = crypto.randomBytes(8);
    return String.fromCharCodes([
      for (final b in r) JamWire.codeAlphabet.codeUnitAt(b & 31),
    ]);
  }

  static String formatCode(String code) =>
      '${code.substring(0, 4)}-${code.substring(4)}';

  /// Null when the length or a character is wrong ("Codice non valido").
  static String? normalizeCode(String input) {
    // Before toUpperCase: it maps some Unicode letters (ı, ß, ſ) into the alphabet.
    if (RegExp(r'[^A-Za-z0-9\s-]').hasMatch(input)) return null;
    final c = input
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]'), '')
        .replaceAll('O', '0')
        .replaceAll(RegExp('[IL]'), '1');
    if (c.length != 8) return null;
    for (final u in c.codeUnits) {
      if (!JamWire.codeAlphabet.codeUnits.contains(u)) return null;
    }
    return c;
  }

  /// Argon2id in an isolate; [code] must already be normalized.
  Future<JamCodeKeys> deriveCode(String code) async {
    final x = await crypto.pwhash(
      password: code,
      salt: Uint8List.fromList(ascii.encode(JamWire.codeSalt)),
      outLen: 64,
    );
    final keys = JamCodeKeys(
      x.bytes.sublist(0, 16),
      JamKey.adopt(x.bytes.sublist(32, 64)), // sublist copies: x is wiped next
    );
    x.dispose();
    return keys;
  }

  // ---- QR and announcement ----------------------------------------------

  /// At most [JamWire.maxBrokers] brokers; one whose host does not fit the
  /// 1-byte length is skipped, not cut.
  String encodeQr(JamQr q) {
    final brokers = [
      for (final b in q.brokers)
        if (utf8.encode(b.host).length <= 255) b,
    ].take(JamWire.maxBrokers).toList();
    final out = BytesBuilder()
      ..addByte(JamWire.version)
      ..add(q.jamId)
      ..add(q.token)
      ..add(q.hpk)
      ..add(q.friendLabel)
      ..addByte(brokers.length);
    for (final b in brokers) {
      final host = utf8.encode(b.host);
      out
        ..addByte(b.tls ? 1 : 0)
        ..add((ByteData(2)..setUint16(0, b.port)).buffer.asUint8List())
        ..addByte(host.length)
        ..add(host);
    }
    return 'CCJ1:${b64u(out.toBytes())}';
  }

  /// Null for anything that is not a well-formed QR.
  JamQr? decodeQr(String text) {
    if (!text.startsWith('CCJ1:')) return null;
    final b = unb64u(text.substring(5));
    if (b == null || b.length < 50 || b[0] != JamWire.version) return null;
    final n = b[49];
    if (n < 1 || n > JamWire.maxBrokers) return null;
    final brokers = <BrokerEntry>[];
    var i = 50;
    for (var k = 0; k < n; k++) {
      if (i + 4 > b.length) return null;
      final tls = b[i];
      final port = ByteData.sublistView(b).getUint16(i + 1);
      final len = b[i + 3];
      i += 4;
      if (tls > 1 || i + len > b.length) return null;
      final String host;
      try {
        host = utf8.decode(b.sublist(i, i + len));
      } on FormatException {
        return null;
      }
      i += len;
      final e = BrokerEntry(host: host, port: port, tls: tls == 1);
      if (!e.isValid) return null;
      brokers.add(e);
    }
    if (i != b.length) return null;
    return JamQr(
      jamId: b.sublist(1, 7),
      token: b.sublist(7, 13),
      hpk: b.sublist(13, 45),
      friendLabel: b.sublist(45, 49),
      brokers: brokers,
    );
  }

  /// 26 B Bluetooth service data.
  Uint8List encodeAdvert(JamAdvert a) => _cat([
    [JamWire.version],
    a.jamId,
    a.token,
    a.fingerprint,
    a.friendLabel,
    [a.broker],
  ]);

  /// The announcement of [s] for the window of [hostMs]: this window's token
  /// and `fpH`, the friends' label of [ak] and the broker index (`0xFF` = custom).
  /// Nothing in it outlives the switch-on, bar the label of [ak] (R-133, R-136).
  Uint8List advertAt(
    JamHostSecrets s,
    int hostMs, {
    required Uint8List ak,
    required int broker,
  }) => encodeAdvert(
    JamAdvert(
      jamId: s.jamId,
      token: token(s, hostMs),
      fingerprint: fingerprint(s.hpk),
      friendLabel: friendLabelAt(ak, hostMs, fingerprint(s.hpk)),
      broker: broker,
    ),
  );

  JamAdvert? decodeAdvert(Uint8List b) {
    if (b.length != 26 || b[0] != JamWire.version) return null;
    return JamAdvert(
      jamId: b.sublist(1, 7),
      token: b.sublist(7, 13),
      fingerprint: b.sublist(13, 21),
      friendLabel: b.sublist(21, 25),
      broker: b[25],
    );
  }

  // ---- lobby and code messages -------------------------------------------

  Uint8List lobby(Uint8List hpk) => _cat([
    [JamWire.version, JamWire.tLobby],
    hpk,
  ]);

  /// `Hpk`, or null for a cleared lobby (empty payload, not a drop), a bad one,
  /// or one whose fingerprint is not [fpH] (the Hpk the guest was told about).
  Uint8List? parseLobby(Uint8List bytes, {required Uint8List fpH}) {
    if (bytes.isEmpty) return null;
    if (bytes.length != JamWire.lobbyLength) {
      drops.drop('size');
      return null;
    }
    if (bytes[0] != JamWire.version) {
      drops.drop('version');
      return null;
    }
    if (bytes[1] != JamWire.tLobby) {
      drops.drop('type');
      return null;
    }
    final hpk = bytes.sublist(2);
    final fp = fingerprint(hpk);
    var diff = fp.length ^ fpH.length; // constant time over the fingerprint
    for (var i = 0; i < fp.length && i < fpH.length; i++) {
      diff |= fp[i] ^ fpH[i];
    }
    if (diff != 0) {
      drops.drop('hpk');
      return null;
    }
    return hpk;
  }

  /// Wire form of the brokers of a CODE or an ACCEPT, cut to [JamWire.maxBrokers].
  static List<Map<String, Object>> brokersJson(List<BrokerEntry> l) => [
    for (final b in l.take(JamWire.maxBrokers)) b.toJson(),
  ];

  /// Null when [raw] is not a list of at most [JamWire.maxBrokers] valid entries.
  static List<BrokerEntry>? _parseBrokers(Object? raw) {
    if (raw is! List || raw.length > JamWire.maxBrokers) return null;
    final out = <BrokerEntry>[];
    for (final r in raw) {
      if (r is! Map || r['host'] is! String || r['port'] is! int) return null;
      final b = BrokerEntry(
        host: r['host'] as String,
        port: r['port'] as int,
        tls: r['tls'] is bool ? r['tls'] as bool : true,
      );
      if (!b.isValid) return null;
      out.add(b);
    }
    return out;
  }

  Uint8List sealCode(JamKey kc, JamCodeInfo c) {
    final json = jsonEncode({
      'jam': b64u(c.jamId),
      'hpk': b64u(c.hpk),
      'exp': c.expMs,
      'brokers': brokersJson(c.brokers),
      'gone': c.gone,
    });
    return _cat([
      [JamWire.version, JamWire.tCode],
      crypto.aeadEncrypt(
        key: kc,
        message: crypto.pad(
          Uint8List.fromList(utf8.encode(json)),
          JamWire.padBlock,
        ),
        additionalData: _cat([
          ascii.encode('ccj1'),
          [JamWire.version, JamWire.tCode],
        ]),
      ),
    ]);
  }

  /// Null (and a drop) too when the code expired: `exp <= nowMs`.
  JamCodeInfo? openCode(Uint8List bytes, JamKey kc, {required int nowMs}) {
    if (bytes.length > JamWire.maxCode || bytes.length < 2 + 24 + 16) {
      drops.drop('size');
      return null;
    }
    if (bytes[0] != JamWire.version) {
      drops.drop('version');
      return null;
    }
    if (bytes[1] != JamWire.tCode) {
      drops.drop('type');
      return null;
    }
    final plain = crypto.aeadDecrypt(
      key: kc,
      nonceAndCipher: Uint8List.sublistView(bytes, 2),
      additionalData: _cat([
        ascii.encode('ccj1'),
        [JamWire.version, JamWire.tCode],
      ]),
    );
    if (plain == null) {
      drops.drop('auth');
      return null;
    }
    final j = _unpadJson(plain);
    if (j is Map) {
      final jam = unb64u(j['jam']), hpk = unb64u(j['hpk']);
      final exp = j['exp'], gone = j['gone'];
      final brokers = _parseBrokers(j['brokers']);
      if (jam?.length == 6 &&
          hpk?.length == 32 &&
          exp is int &&
          gone is bool &&
          brokers != null) {
        if (exp <= nowMs) {
          drops.drop('expired');
          return null;
        }
        return JamCodeInfo(
          jamId: jam!,
          hpk: hpk!,
          expMs: exp,
          brokers: brokers,
          gone: gone,
        );
      }
    }
    drops.drop('schema');
    return null;
  }

  // ---- request (guest -> host) -------------------------------------------

  /// [proof] is `T_w` (Bluetooth, QR) or `KC` (code). Null when [hpk] is not a
  /// usable key. `Gsk` is wiped here; the keys of the pair live in the channel.
  JamGuestRequest? buildRequest({
    required Uint8List jamId,
    required Uint8List hpk,
    required Uint8List proof,
    required String id,
    required String name,
    Uint8List? friendProof,
    JamKey? friendKey,
  }) {
    final gk = crypto.kxKeyPair();
    final session = crypto.kxClientSessionKeys(
      clientPublicKey: gk.publicKey,
      clientSecretKey: gk.secretKey,
      serverPublicKey: hpk,
    );
    gk.dispose();
    if (session == null) return null;
    final ikm = _cat([session.tx.bytes, session.rx.bytes]);
    session.dispose();
    final keys = _pairKeys(ikm, proof);
    ikm.fillRange(0, ikm.length, 0);
    // [friendKey] is the saved `FKp` of the host recognised from its label.
    final fp =
        friendProof ??
        (friendKey == null ? null : this.friendProof(friendKey, jamId, gk.publicKey));
    final json = jsonEncode({
      'id': id,
      'name': name,
      if (fp != null) 'fp': b64u(fp),
    });
    final sealed = crypto.aeadEncrypt(
      key: keys.kReq,
      message: crypto.pad(
        Uint8List.fromList(utf8.encode(json)),
        JamWire.padBlock,
      ),
      additionalData: _requestAd(jamId, gk.publicKey),
    );
    final bytes = _cat([
      [JamWire.version, JamWire.tRequest],
      gk.publicKey,
      sealed,
    ]);
    return JamGuestRequest(bytes, JamChannel._(this, keys, host: false));
  }

  /// Tries `T_w`, `T_(w-1)` and (if given) the code's [kc]: three attempts at most.
  JamHostRequest? openRequest(
    Uint8List bytes,
    JamHostSecrets h, {
    required int hostMs,
    JamKey? kc,
  }) {
    if (bytes.length > JamWire.maxRequest || bytes.length < 2 + 32 + 24 + 16) {
      drops.drop('size');
      return null;
    }
    if (bytes[0] != JamWire.version) {
      drops.drop('version');
      return null;
    }
    if (bytes[1] != JamWire.tRequest) {
      drops.drop('type');
      return null;
    }
    final gpk = Uint8List.fromList(bytes.sublist(2, 34));
    final session = crypto.kxServerSessionKeys(
      serverPublicKey: h.hpk,
      serverSecretKey: h.hk.secretKey,
      clientPublicKey: gpk,
    );
    if (session == null) {
      drops.drop('kx');
      return null;
    }
    final ikm = _cat([session.rx.bytes, session.tx.bytes]);
    session.dispose();
    try {
      return _openWithProofs(bytes, h, gpk, ikm, hostMs, kc);
    } finally {
      ikm.fillRange(0, ikm.length, 0);
    }
  }

  JamHostRequest? _openWithProofs(
    Uint8List bytes,
    JamHostSecrets h,
    Uint8List gpk,
    Uint8List ikm,
    int hostMs,
    JamKey? kc,
  ) {
    final proofs = [
      ...acceptedTokens(h, hostMs).map((t) => (t, false)),
      if (kc != null) (kc.bytes, true),
    ];
    final ad = _requestAd(h.jamId, gpk);
    final sealed = Uint8List.sublistView(bytes, 34);
    for (final (p, viaCode) in proofs) {
      final keys = _pairKeys(ikm, p);
      final plain = crypto.aeadDecrypt(
        key: keys.kReq,
        nonceAndCipher: sealed,
        additionalData: ad,
      );
      if (plain == null) {
        keys.dispose();
        continue;
      }
      final g = b64u(gpk);
      if (h.seenGpk.contains(g)) {
        keys.dispose();
        drops.drop('replay');
        return null;
      }
      final j = _unpadJson(plain);
      final id = j is Map ? j['id'] : null, name = j is Map ? j['name'] : null;
      final fpRaw = j is Map ? j['fp'] : null;
      final fp = fpRaw == null ? null : unb64u(fpRaw);
      if (id is String &&
          id.isNotEmpty &&
          id.length <= 64 &&
          name is String &&
          name.length <= 60 &&
          (fpRaw == null || fp?.length == 32)) {
        h.seenGpk.add(g);
        return JamHostRequest(
          id: id,
          name: name,
          gpk: gpk,
          friendProof: fp,
          viaCode: viaCode,
          channel: JamChannel._(this, keys, host: true),
        );
      }
      keys.dispose();
      drops.drop('schema');
      return null;
    }
    drops.drop('auth');
    return null;
  }

  Uint8List _requestAd(Uint8List jamId, Uint8List gpk) => _cat([
    ascii.encode('ccj1'),
    [JamWire.version, JamWire.tRequest],
    jamId,
    gpk,
  ]);

  JamPairKeys _pairKeys(Uint8List ikm, Uint8List proof) {
    final prk = crypto.hkdfExtract(salt: proof, ikm: ikm);
    JamKey ex(String label) =>
        crypto.hkdfExpand(prk: prk, context: 'ccj1 $label', outLen: 32);
    final topic = ex('topic');
    final keys = JamPairKeys(
      ex('req'),
      ex('g2h'),
      ex('h2g'),
      ex('friend'),
      topic.bytes.sublist(0, 16),
    );
    topic.dispose();
    prk.dispose();
    return keys;
  }

  // ---- body: unpad, inflate, JSON, schema --------------------------------

  Object? _unpadJson(Uint8List padded) {
    final plain = crypto.unpad(padded, JamWire.padBlock);
    if (plain == null) return null;
    try {
      return jsonDecode(utf8.decode(plain));
    } on FormatException {
      return null;
    }
  }

  JamMessage? _parseBody(Uint8List padded, int type) {
    final plain = crypto.unpad(padded, JamWire.padBlock);
    if (plain == null || plain.isEmpty) {
      drops.drop('padding');
      return null;
    }
    var raw = Uint8List.sublistView(plain, 1);
    if (plain[0] & 1 == 1) {
      final inflated = _inflate(raw);
      if (inflated == null) {
        drops.drop('inflate');
        return null;
      }
      raw = inflated;
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(raw));
    } on FormatException {
      drops.drop('json');
      return null;
    }
    final msg = json is Map<String, Object?> ? _schema(type, json) : null;
    if (msg == null) drops.drop('schema');
    return msg;
  }

  /// Zlib inflate that stops at [JamWire.maxInflated]; null when over or invalid.
  Uint8List? _inflate(Uint8List z) {
    final out = BytesBuilder();
    try {
      final conv = ZLibDecoder().startChunkedConversion(_CapSink(out));
      conv.add(z);
      conv.close();
    } on _TooBig {
      return null;
    } on Exception {
      return null; // bad zlib data: the caller drops and counts it
    }
    return out.toBytes();
  }

  JamMessage? _schema(int type, Map<String, Object?> b) {
    bool str(String k, int max, {int min = 0}) =>
        b[k] is String &&
        (b[k] as String).length >= min &&
        (b[k] as String).length <= max;
    bool integer(String k) => b[k] is int;
    bool key(String k) => unb64u(b[k])?.length == 32;
    switch (type) {
      case JamMsg.accept:
        final s = JamState.tryParse(b['state']);
        final brokers = _parseBrokers(b['brokers']);
        return s != null &&
                str('host', 64, min: 1) &&
                str('name', 60) &&
                key('ak') &&
                integer('t') &&
                brokers != null
            ? JamMessage(type, b, state: s, brokers: brokers)
            : null;
      case JamMsg.state:
        final s = JamState.tryParse(b['state']);
        return s == null ? null : JamMessage(type, b, state: s);
      case JamMsg.result:
        return str('req', 64, min: 1) &&
                (integer('v') || str('err', 60, min: 1))
            ? JamMessage(type, b)
            : null;
      case JamMsg.ping:
        return integer('v') && integer('t') ? JamMessage(type, b) : null;
      case JamMsg.no:
        return b['why'] == 'busy' || b['why'] == 'declined'
            ? JamMessage(type, b)
            : null;
      case JamMsg.bye:
        return b['why'] == 'removed' || b['why'] == 'ended'
            ? JamMessage(type, b)
            : null;
      case JamMsg.time:
        return integer('t0') && integer('t') ? JamMessage(type, b) : null;
      case JamMsg.cmd:
        final c = JamCommand.tryParse(b['cmd']);
        return c != null && str('req', 64, min: 1)
            ? JamMessage(type, b, command: c)
            : null;
      case JamMsg.sync:
        return integer('v') ? JamMessage(type, b) : null;
      case JamMsg.gPing:
      case JamMsg.leave:
        return JamMessage(type, b);
      case JamMsg.friend:
        return key('ak') ? JamMessage(type, b) : null;
      case JamMsg.gTime:
        return integer('t0') ? JamMessage(type, b) : null;
    }
    return null;
  }

  // ---- state size (RNF-14) ------------------------------------------------

  /// The state as JSON that fits an envelope: if it is over the budget once
  /// compressed, titles, artists and albums are cut to 64 characters, and if
  /// that is not enough the already played items go (`current` recomputed).
  /// Null when it still does not fit: the caller must not send that state.
  Map<String, Object?>? fitState(JamState s) => _fitState(s);
}

/// Flag byte (1 = zlib) followed by the JSON of [body], compressed when that
/// pays; top level so that it can run in an isolate.
Uint8List _pack(Object? body) {
  var raw = Uint8List.fromList(utf8.encode(jsonEncode(body)));
  var flag = 0;
  if (raw.length > 256) {
    final z = Uint8List.fromList(ZLibCodec().encode(raw));
    if (z.length < raw.length) {
      raw = z;
      flag = 1;
    }
  }
  return Uint8List(raw.length + 1)
    ..[0] = flag
    ..setAll(1, raw);
}

// The closures live at top level: inside a method they would capture `this`
// (keys, sodium) and could not be sent to the isolate.
const _isolateItems = 40;

Uint8List? _packState(JamState st) {
  final j = _fitState(st);
  return j == null ? null : _pack({'state': j});
}

Future<Uint8List?> _packStateInIsolate(JamState st) =>
    Isolate.run(() => _packState(st));

Map<String, Object?>? _fitState(JamState s) {
  final j = s.toJson();
  if (_fits(j)) return j;
  final items = (j['items'] as List).cast<Map<String, Object?>>();
  for (final it in items) {
    for (final k in const ['title', 'artist', 'album']) {
      final v = it[k];
      if (v is String && v.length > 64) it[k] = v.substring(0, 64);
    }
  }
  if (_fits(j)) return j;
  final cur = j['current'] as int;
  if (cur > 0) {
    items.removeRange(0, cur);
    j['current'] = 0;
  }
  return _fits(j) ? j : null;
}

bool _fits(Map<String, Object?> j) =>
    ZLibCodec().encode(utf8.encode(jsonEncode({'state': j}))).length <=
    JamWire.stateBudget;

class _TooBig implements Exception {}

class _CapSink implements Sink<List<int>> {
  _CapSink(this._out);

  final BytesBuilder _out;

  @override
  void add(List<int> chunk) {
    _out.add(chunk);
    if (_out.length > JamWire.maxInflated) throw _TooBig();
  }

  @override
  void close() {}
}
