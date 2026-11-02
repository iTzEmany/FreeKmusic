import 'dart:convert';
import 'dart:typed_data';

import 'package:codecore/services/jam/jam_host.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/jam/remote/broker_entry.dart';
import 'package:codecore/services/jam/remote/jam_beacon.dart';
import 'package:codecore/services/jam/remote/jam_bridge.dart';
import 'package:codecore/services/jam/remote/jam_bridge_host.dart';
import 'package:codecore/services/jam/remote/jam_crypto.dart';
import 'package:codecore/services/jam/remote/jam_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const entry = BrokerEntry(host: 'a.net', port: 8883);

/// Real crypto that counts decryptions and remembers keys, and can fail Argon2.
class TestCrypto implements JamCrypto {
  TestCrypto(this.i);
  final JamCrypto i;
  int decrypts = 0;
  bool failPwhash = false;
  JamKey? lastDecryptKey, lastMacKey;

  @override
  Uint8List? aeadDecrypt({
    required JamKey key,
    required Uint8List nonceAndCipher,
    Uint8List? additionalData,
  }) {
    decrypts++;
    lastDecryptKey = key;
    return i.aeadDecrypt(
      key: key,
      nonceAndCipher: nonceAndCipher,
      additionalData: additionalData,
    );
  }

  @override
  Uint8List mac({required JamKey key, required Uint8List message}) {
    lastMacKey = key;
    return i.mac(key: key, message: message);
  }

  @override
  Future<JamKey> pwhash({
    required String password,
    required Uint8List salt,
    required int outLen,
  }) async {
    if (failPwhash) throw StateError('pwhash down');
    return i.pwhash(password: password, salt: salt, outLen: outLen);
  }

  @override
  Uint8List randomBytes(int length) => i.randomBytes(length);
  @override
  JamKeyPair kxKeyPair() => i.kxKeyPair();
  @override
  JamSessionKeys? kxClientSessionKeys({
    required Uint8List clientPublicKey,
    required JamKey clientSecretKey,
    required Uint8List serverPublicKey,
  }) => i.kxClientSessionKeys(
    clientPublicKey: clientPublicKey,
    clientSecretKey: clientSecretKey,
    serverPublicKey: serverPublicKey,
  );
  @override
  JamSessionKeys? kxServerSessionKeys({
    required Uint8List serverPublicKey,
    required JamKey serverSecretKey,
    required Uint8List clientPublicKey,
  }) => i.kxServerSessionKeys(
    serverPublicKey: serverPublicKey,
    serverSecretKey: serverSecretKey,
    clientPublicKey: clientPublicKey,
  );
  @override
  JamKey hkdfExtract({Uint8List? salt, required Uint8List ikm}) =>
      i.hkdfExtract(salt: salt, ikm: ikm);
  @override
  JamKey hkdfExpand({
    required JamKey prk,
    required String context,
    required int outLen,
  }) => i.hkdfExpand(prk: prk, context: context, outLen: outLen);
  @override
  Uint8List aeadEncrypt({
    required JamKey key,
    required Uint8List message,
    Uint8List? additionalData,
  }) => i.aeadEncrypt(
    key: key,
    message: message,
    additionalData: additionalData,
  );
  @override
  bool macVerify({
    required JamKey key,
    required Uint8List message,
    required Uint8List tag,
  }) => i.macVerify(key: key, message: message, tag: tag);
  @override
  Uint8List genericHash(Uint8List message, {required int outLen}) =>
      i.genericHash(message, outLen: outLen);
  @override
  Uint8List pad(Uint8List data, int blockSize) => i.pad(data, blockSize);
  @override
  Uint8List? unpad(Uint8List data, int blockSize) => i.unpad(data, blockSize);
}

/// A remote guest driven by hand with the real protocol.
class Guest {
  Guest(this.id, this.req, this.ch, this.link);
  final String id;
  final JamGuestRequest req;
  final JamChannel ch;
  final FakeMqttLink link;
  final inbox = <JamMessage>[];

  void listen() {
    link.messages.listen((m) {
      if (m.topic != ch.recvTopic) return;
      final x = ch.open(m.payload);
      if (x != null) inbox.add(x);
    });
    link.subscribe(ch.recvTopic);
  }

  void send(int type, Map<String, Object?> body) =>
      link.publish(ch.sendTopic, ch.seal(type, body)!);

  Iterable<JamMessage> of(int type) => inbox.where((m) => m.type == type);
}

void main() {
  late TestCrypto crypto;
  late JamProtocol protocol, guestProtocol;
  late DateTime clock;
  late List<String> drops;
  late FakeNet net;
  late JamHost host;
  late JamBridge bridge;
  late JamBridgeHost bh;
  late JamQr qr;

  setUp(() async {
    final base = await SodiumJamCrypto.create();
    crypto = TestCrypto(base);
    clock = DateTime.fromMillisecondsSinceEpoch(1000000 * 30000 + 5000);
    drops = [];
    final log = JamDropLog(now: () => clock, sink: drops.add);
    protocol = JamProtocol(crypto, drops: log);
    guestProtocol = JamProtocol(base, drops: log);
    net = FakeNet([entry]);
    host = JamHost(deviceId: 'host', deviceName: 'Host', now: () => clock);
    bridge = JamBridge(FakeMqttLink(net), [entry], waits: const [Duration(milliseconds: 5)]);
    bh = JamBridgeHost(
      protocol: protocol,
      host: host,
      bridge: bridge,
      now: () => clock,
      stopGrace: Duration.zero,
    )..start();
    await pumpEventQueue();
    qr = guestProtocol.decodeQr(bh.currentQr()!)!;
  });

  tearDown(() async {
    await bh.dispose();
    host.dispose();
  });

  Future<Guest> guest(String id, {Uint8List? proof, String? name}) async {
    final link = FakeMqttLink(net);
    await link.connect(entry);
    final r = guestProtocol.buildRequest(
      jamId: qr.jamId,
      hpk: qr.hpk,
      proof: proof ?? qr.token,
      id: id,
      name: name ?? 'Name $id',
    )!;
    final g = Guest(id, r, r.channel, link)..listen();
    link.publish(JamProtocol.requestTopic(qr.jamId), r.bytes);
    await pumpEventQueue();
    return g;
  }

  /// Joins and gets accepted.
  Future<Guest> joined(String id) async {
    final g = await guest(id);
    host.accept(host.requests.values.firstWhere((r) => r.fromId == id).id);
    await pumpEventQueue();
    return g;
  }

  test('beacon: announces at start, renews with each 30 s window, stops with the bridge', () async {
    final beacon = FakeJamBeacon();
    final b2 = JamBridge(FakeMqttLink(net), [entry], waits: const [Duration(milliseconds: 5)]);
    final h2 = JamBridgeHost(
      protocol: protocol,
      host: host,
      bridge: b2,
      now: () => clock,
      beacon: beacon,
      stopGrace: Duration.zero,
    )..start();
    await pumpEventQueue();
    final first = beacon.advertising!;
    expect(first.length, 26);
    final adv = guestProtocol.decodeAdvert(first)!;
    expect(adv.jamId, h2.jamId);
    expect(adv.broker, 0xFF, reason: 'a.net is not one of the default brokers');
    h2.tick(); // same window: nothing changes
    expect(beacon.advertising, same(first));
    clock = clock.add(const Duration(seconds: 30));
    h2.tick();
    await pumpEventQueue();
    expect(beacon.advertising, isNot(first));
    expect(guestProtocol.decodeAdvert(beacon.advertising!)!.jamId, adv.jamId);
    await h2.dispose();
    expect(beacon.advertising, isNull);
  });

  test('start: LOBBY retained and /r subscribed', () {
    final lobby = net[entry].retained[JamProtocol.lobbyTopic(qr.jamId)]!;
    expect(lobby, protocol.lobby(qr.hpk));
    expect(bridge.broker, entry);
  });

  test('request then accept: ACCEPT with state and brokers', () async {
    final g = await guest('dev-1');
    expect(host.requests.values.single.remote, isTrue);
    expect(g.inbox, isEmpty);
    host.accept(host.requests.values.single.id);
    await pumpEventQueue();
    final a = g.of(JamMsg.accept).single;
    expect(a.body['host'], 'host');
    expect(a.state!.participants.map((p) => p.id), contains('dev-1'));
    expect(a.brokers, [entry]);
    expect(host.memberIds, ['dev-1']);
  });

  test('busy answers NO busy; decline answers NO declined', () async {
    final a = await guest('a');
    final b = await guest('b');
    expect(b.of(JamMsg.no).single.body['why'], 'busy');
    host.decline(host.requests.values.firstWhere((r) => r.fromId == 'a').id);
    await pumpEventQueue();
    expect(a.of(JamMsg.no).single.body['why'], 'declined');
  });

  test('decryption attempts are capped at 10 a second, not messages', () async {
    // No code: 2 attempts each, so 5 requests fit. g0 pending, g1..g4 busy.
    final gs = [for (var i = 0; i < 6; i++) await guest('g$i')];
    expect(gs.sublist(1, 5).every((g) => g.of(JamMsg.no).isNotEmpty), isTrue);
    expect(gs[5].inbox, isEmpty);
    expect(drops.join(), contains('rate=1'));
  });

  test('with two codes alive, AEAD attempts stay within 10 a second', () async {
    await bh.startCode();
    clock = clock.add(const Duration(seconds: 1));
    await bh.startCode(); // the first one is now the previous code
    crypto.decrypts = 0;
    for (var i = 0; i < 30; i++) {
      await guest('g$i', proof: Uint8List(6));
    }
    expect(crypto.decrypts, lessThanOrEqualTo(10));
    expect(crypto.decrypts, greaterThan(0));
  });

  test('a code older than 2 minutes opens nothing, even if renewal fails', () async {
    await bh.startCode();
    final keys = await guestProtocol.deriveCode(bh.code!.replaceAll('-', ''));
    crypto.failPwhash = true;
    clock = clock.add(const Duration(minutes: 5));
    bh.tick();
    await pumpEventQueue();
    final g = await guest('dev-1', proof: keys.kc.bytes);
    expect(host.requests, isEmpty);
    expect(g.inbox, isEmpty);
  });

  test('malformed junk does not use the decryption budget', () async {
    final junk = Uint8List(10);
    final l = FakeMqttLink(net);
    await l.connect(entry);
    for (var i = 0; i < 20; i++) {
      l.publish(JamProtocol.requestTopic(qr.jamId), junk);
    }
    await pumpEventQueue();
    final g = await guest('a');
    expect(host.requests.length, 1);
    expect(g.inbox, isEmpty);
    expect(drops.join(), isNot(contains('rate')));
  });

  test('a repeated Gpk is dropped', () async {
    final g = await guest('a');
    host.decline(host.requests.values.single.id);
    await pumpEventQueue();
    g.link.publish(JamProtocol.requestTopic(qr.jamId), g.req.bytes);
    await pumpEventQueue();
    expect(g.of(JamMsg.no).length, 1);
    expect(host.requests.values.where((r) => r.status.name == 'pending'), isEmpty);
    expect(drops.join(), contains('replay'));
  });

  test('a request with the wrong proof is dropped', () async {
    final g = await guest('a', proof: Uint8List(6));
    expect(host.requests, isEmpty);
    expect(g.inbox, isEmpty);
    expect(drops.join(), contains('auth'));
  });

  test('CMD is applied as the pair id and answered with RESULT', () async {
    final g = await joined('dev-1');
    final v = host.state!.version;
    g.send(JamMsg.cmd, {'req': 'r1', 'cmd': const JamCommand.volume(0.5).toJson()});
    await pumpEventQueue();
    final ok = g.of(JamMsg.result).first.body;
    expect(ok['req'], 'r1');
    expect(ok['v'], greaterThan(v));
    // A remote may not choose an output: proves `from` is the remote member.
    g.send(JamMsg.cmd, {
      'req': 'r2',
      'cmd': const JamCommand.setOutput('dev-1').toJson(),
    });
    await pumpEventQueue();
    expect(g.of(JamMsg.result).last.body, {'req': 'r2', 'err': 'forbidden'});
  });

  test('the new STATE goes out before the RESULT of a CMD', () async {
    final g = await joined('dev-1');
    g.send(JamMsg.cmd, {'req': 'r', 'cmd': const JamCommand.volume(0.5).toJson()});
    await pumpEventQueue();
    final i = g.inbox.lastIndexWhere((m) => m.type == JamMsg.result);
    expect(g.inbox[i - 1].type, JamMsg.state);
    expect(g.inbox[i - 1].state!.version, g.inbox[i].body['v']);
  });

  test('a new version is pushed as STATE to every remote', () async {
    final g = await joined('dev-1');
    host.apply(const JamCommand.volume(0.3));
    await pumpEventQueue();
    expect(g.of(JamMsg.state).last.state!.version, host.state!.version);
  });

  test('SYNC with an old version gets STATE, a current one a PING', () async {
    final g = await joined('dev-1');
    final n = g.of(JamMsg.state).length;
    g.send(JamMsg.sync, {'v': host.state!.version});
    await pumpEventQueue();
    expect(g.of(JamMsg.state).length, n);
    expect(g.of(JamMsg.ping).single.body['v'], host.state!.version);
    g.send(JamMsg.sync, {'v': 0});
    await pumpEventQueue();
    expect(g.of(JamMsg.state).length, n + 1);
  });

  test('TIME answers with the host clock', () async {
    final g = await joined('dev-1');
    g.send(JamMsg.gTime, {'t0': 7});
    await pumpEventQueue();
    expect(g.of(JamMsg.time).single.body['t0'], 7);
    expect(g.of(JamMsg.time).single.body['t'], clock.millisecondsSinceEpoch);
  });

  test('LEAVE removes the member and throws its keys away', () async {
    final g = await joined('dev-1');
    g.send(JamMsg.gPing, {});
    await pumpEventQueue();
    final key = crypto.lastDecryptKey!;
    expect(key.isDisposed, isFalse);
    g.send(JamMsg.leave, {});
    await pumpEventQueue();
    expect(host.memberIds, isEmpty);
    expect(key.isDisposed, isTrue);
  });

  test('a silent guest is reachable again after a valid message', () async {
    final g = await joined('dev-1');
    clock = clock.add(const Duration(seconds: 61));
    expect(host.unreachableIds(), ['dev-1']);
    g.send(JamMsg.gPing, {});
    await pumpEventQueue();
    expect(host.unreachableIds(), isEmpty);
  });

  test('a new member gets no second STATE of the same version', () async {
    final g1 = await joined('dev-1');
    final g2 = await joined('dev-2');
    expect(g2.of(JamMsg.state), isEmpty); // the ACCEPT carried it
    expect(g1.of(JamMsg.state), hasLength(1));
  });

  test('a removed member gets BYE and its channel is dead', () async {
    final g = await joined('dev-1');
    g.send(JamMsg.gPing, {});
    await pumpEventQueue();
    final key = crypto.lastDecryptKey!;
    host.removeMember('dev-1');
    await pumpEventQueue();
    expect(key.isDisposed, isTrue);
    expect(g.of(JamMsg.bye).single.body['why'], 'removed');
    expect(net[entry].log.last.topic, g.ch.recvTopic);
    final before = host.state!.version;
    g.send(JamMsg.cmd, {'req': 'x', 'cmd': const JamCommand.volume(0.1).toJson()});
    await pumpEventQueue();
    expect(host.state!.version, before);
    expect(g.of(JamMsg.result), isEmpty);
  });

  test('10 minutes of silence remove a remote guest', () async {
    final g = await joined('dev-1');
    clock = clock.add(const Duration(minutes: 10, seconds: 1));
    host.dropStale(const Duration(seconds: 75));
    await pumpEventQueue();
    expect(g.of(JamMsg.bye), hasLength(1));
  });

  test('an unanswered request expires at 60 s with no reply', () async {
    final g = await guest('dev-1');
    clock = clock.add(const Duration(seconds: 61));
    bh.tick();
    host.expire();
    await pumpEventQueue();
    expect(host.requests.values.single.status, JamRequestStatus.expired);
    expect(g.inbox, isEmpty);
  });

  test('PING every 30 s', () async {
    final g = await joined('dev-1');
    clock = clock.add(const Duration(seconds: 29));
    bh.tick();
    await pumpEventQueue();
    expect(g.of(JamMsg.ping), isEmpty);
    clock = clock.add(const Duration(seconds: 1));
    bh.tick();
    await pumpEventQueue();
    expect(g.of(JamMsg.ping).single.body['v'], host.state!.version);
  });

  test('code: CODE opens with the code, is renewed at 2 min, joins', () async {
    await bh.startCode();
    final text = bh.code!.replaceAll('-', '');
    final keys = await guestProtocol.deriveCode(text);
    final topic = JamProtocol.codeTopic(keys.topicId);
    final info = guestProtocol.openCode(
      net[entry].retained[topic]!,
      keys.kc,
      nowMs: clock.millisecondsSinceEpoch,
    )!;
    expect(info.jamId, qr.jamId);
    expect(info.gone, isFalse);
    expect(
      info.expMs,
      clock.millisecondsSinceEpoch + const Duration(minutes: 2).inMilliseconds,
    );
    final g = await guest('dev-1', proof: keys.kc.bytes);
    expect(host.requests.values.single.fromId, 'dev-1');
    expect(g.inbox, isEmpty);

    clock = clock.add(const Duration(minutes: 2));
    bh.tick();
    await bh.codeChanges.first;
    expect(bh.code!.replaceAll('-', ''), isNot(text));
    final old = guestProtocol.openCode(
      net[entry].retained[topic]!,
      keys.kc,
      nowMs: clock.millisecondsSinceEpoch,
    )!;
    expect(old.gone, isTrue); // the old one says «gone», it is not erased
    // The old code still opens a request for 10 s after the renewal.
    await guest('dev-2', proof: keys.kc.bytes);
    expect(host.requests.values.where((r) => r.fromId == 'dev-2'), hasLength(1));
    clock = clock.add(const Duration(seconds: 11));
    bh.tick();
    final late = await guest('dev-3', proof: keys.kc.bytes);
    expect(host.requests.values.where((r) => r.fromId == 'dev-3'), isEmpty);
    expect(late.inbox, isEmpty);
    await bh.stop();
    expect(net[entry].retained[topic], isEmpty);
  });

  test('stopCode publishes gone', () async {
    await bh.startCode();
    final keys = await guestProtocol.deriveCode(bh.code!.replaceAll('-', ''));
    bh.stopCode();
    final info = guestProtocol.openCode(
      net[entry].retained[JamProtocol.codeTopic(keys.topicId)]!,
      keys.kc,
      nowMs: clock.millisecondsSinceEpoch,
    )!;
    expect(info.gone, isTrue);
    expect(bh.code, isNull);
  });

  test('stop: final STATE, retained cleared, keys thrown away', () async {
    final g = await joined('dev-1');
    await bh.startCode();
    final codeTopics = net[entry].retained.keys.where((t) => t.startsWith('ccj1/c/'));
    host.endSession();
    await bh.stop();
    await pumpEventQueue();
    expect(g.of(JamMsg.state).last.state!.ended, isTrue);
    expect(net[entry].retained[JamProtocol.lobbyTopic(qr.jamId)], isEmpty);
    for (final t in codeTopics) {
      expect(net[entry].retained[t], isEmpty);
    }
    expect(bh.running, isFalse);
    expect(crypto.lastMacKey!.isDisposed, isTrue); // the token key of the secrets
    expect(bh.currentQr(), isNull);
    expect(bridge.status, JamBridgeStatus.connecting);
  });

  test('a member replaced by a LAN guest of the same id gets BYE', () async {
    final g = await joined('dev-1');
    host.addMember(id: 'dev-1', name: 'Lan', host: '10.0.0.5', port: 4000);
    await pumpEventQueue();
    expect(g.of(JamMsg.bye).single.body['why'], 'removed');
    expect(host.memberIds, ['dev-1']);
  });

  test('an ACCEPT lost while the bridge is down is sent on return', () async {
    final g = await guest('dev-1');
    final b = net[entry];
    b.goDown();
    await pumpEventQueue();
    host.accept(host.requests.values.single.id);
    await pumpEventQueue();
    b.comeBack();
    await g.link.connect(entry);
    g.link.subscribe(g.ch.recvTopic);
    expect(g.inbox, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await pumpEventQueue();
    expect(g.inbox.first.type, JamMsg.accept);
    expect(g.of(JamMsg.accept), hasLength(1));
  });

  test('broker drops and returns: LOBBY and STATE are published again', () async {
    final g = await joined('dev-1');
    final b = net[entry];
    b.retained.clear();
    final n = b.log.where((m) => m.topic == g.ch.recvTopic).length;
    b.goDown();
    b.comeBack();
    await pumpEventQueue();
    expect(b.retained[JamProtocol.lobbyTopic(qr.jamId)], protocol.lobby(qr.hpk));
    expect(b.log.where((m) => m.topic == g.ch.recvTopic).length, n + 1);
  });

  test('the broker log holds no name, title or device id in clear', () async {
    final g = await joined('dev-anna');
    host.apply(const JamCommand.add(JamItem(
      id: 1,
      ownerDeviceId: 'host',
      title: 'TitoloSegreto',
      ext: 'mp3',
    )));
    g.send(JamMsg.cmd, {'req': 'r', 'cmd': const JamCommand.volume(0.4).toJson()});
    await pumpEventQueue();
    host.removeMember('dev-anna');
    await pumpEventQueue();
    final all = net[entry].log.map((m) => latin1.decode(m.bytes)).join('\n');
    for (final s in ['dev-anna', 'Name dev-anna', 'TitoloSegreto', 'Host']) {
      expect(all.contains(s), isFalse, reason: s);
    }
  });
}
