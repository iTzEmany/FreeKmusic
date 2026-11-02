import 'dart:async';
import 'dart:typed_data';

import 'package:codecore/services/jam/jam_guest.dart' show JamJoinOutcome;
import 'package:codecore/services/jam/jam_guest_link.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/jam/remote/broker_entry.dart';
import 'package:codecore/services/jam/remote/jam_crypto.dart';
import 'package:codecore/services/jam/remote/jam_invite.dart';
import 'package:codecore/services/jam/remote/jam_protocol.dart';
import 'package:codecore/services/jam/remote/remote_jam_guest.dart';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const a = BrokerEntry(host: 'a.net', port: 8883);
const b = BrokerEntry(host: 'b.net', port: 8883);
const hostMs = 10 * 30000 + 5000;

JamState stateV(int v, {bool ended = false}) => JamState(
  version: v,
  hostDeviceId: 'host',
  outputDeviceId: 'host',
  ended: ended,
);

Future<void> pump() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeNet net;
  late FakeMqttLink hostLink;
  late JamProtocol hostP, guestP;
  late JamHostSecrets secrets;
  late DateTime clock;
  late RemoteJamGuest guest;
  JamChannel? ch; // host side of the pair
  late List<JamMessage> inbox;
  var lostCount = 0;
  late List<FakeMqttLink> guestLinks;

  setUp(() async {
    net = FakeNet([a, b]);
    hostLink = FakeMqttLink(net);
    await hostLink.connect(a);
    hostP = JamProtocol(await SodiumJamCrypto.create());
    guestP = JamProtocol(await SodiumJamCrypto.create());
    secrets = hostP.newHostSecrets();
    clock = DateTime(2026, 1, 1);
    ch = null;
    inbox = [];
    lostCount = 0;
    guestLinks = [];
    guest = RemoteJamGuest(
      protocol: guestP,
      linkFactory: () {
        final l = FakeMqttLink(net);
        guestLinks.add(l);
        return l;
      },
      brokers: const [a],
      now: () => clock,
      leaveGrace: Duration.zero,
    );
    guest.lost.listen((_) => lostCount++);
  });
  tearDown(() => guest.dispose());

  JamInvite qr() => JamInvite(
    jamId: secrets.jamId,
    hpk: secrets.hpk,
    token: hostP.token(secrets, hostMs),
    brokers: const [a, b],
  );

  Future<JamJoinOutcome> join(JamInvite i) =>
      guest.join(i, ownDeviceId: 'dev-1', ownName: 'Anna');

  /// Opens the guest's request found on any broker.
  JamHostRequest? hostTakesRequest({JamKey? kc}) {
    for (final br in net.brokers.values) {
      for (final e in br.log) {
        if (e.topic != JamProtocol.requestTopic(secrets.jamId)) continue;
        final r = hostP.openRequest(e.bytes, secrets, hostMs: hostMs, kc: kc);
        if (r != null) {
          ch = r.channel;
          return r;
        }
      }
    }
    return null;
  }

  void hostSend(int type, Object? body) =>
      hostLink.publish(ch!.sendTopic, ch!.seal(type, body)!);

  /// Everything new the guest published for the host.
  void hostPull() {
    for (final br in net.brokers.values) {
      for (final e in br.log) {
        if (e.topic != ch!.recvTopic) continue;
        final m = ch!.open(e.bytes); // already seen ones fail the counter
        if (m != null) inbox.add(m);
      }
    }
  }

  Map<String, Object?> acceptBody(JamState s) => {
    'host': 'host',
    'name': 'Host',
    'state': hostP.fitState(s)!,
    'brokers': <Object?>[],
    'ak': b64u(Uint8List(32)),
    't': 1,
  };

  Future<void> joined() async {
    final f = join(qr());
    await pump();
    hostTakesRequest();
    hostSend(JamMsg.accept, acceptBody(stateV(1)));
    expect(await f, JamJoinOutcome.accepted);
  }

  /// Moves the clock until [f] completes (the timers run on tick()).
  Future<T> settle<T>(Future<T> f, {int step = 5}) async {
    var done = false;
    unawaited(f.whenComplete(() => done = true));
    for (var i = 0; i < 100 && !done; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      clock = clock.add(Duration(seconds: step));
      guest.tick();
    }
    return f;
  }

  test(
    'QR: the request reaches the host and ACCEPT brings the state',
    () async {
      final f = join(qr());
      await pump();
      final r = hostTakesRequest()!;
      expect((r.id, r.name, r.viaCode), ('dev-1', 'Anna', false));
      hostSend(JamMsg.accept, acceptBody(stateV(4)));
      expect(await f, JamJoinOutcome.accepted);
      expect(guest.state!.version, 4);
      expect(guest.files, isNull);
    },
  );

  test('code: found on the retained CODE, request proved with KC', () async {
    final keys = await hostP.deriveCode('ABCD2345');
    hostLink.publish(
      JamProtocol.codeTopic(keys.topicId),
      hostP.sealCode(
        keys.kc,
        JamCodeInfo(
          jamId: secrets.jamId,
          hpk: secrets.hpk,
          expMs: clock.millisecondsSinceEpoch + 120000,
          brokers: const [a],
          gone: false,
        ),
      ),
      retain: true,
    );
    final f = join(JamInvite.fromCode('abcd-2345')!);
    for (var i = 0; i < 50 && hostTakesRequest(kc: keys.kc) == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(ch, isNotNull);
    hostSend(JamMsg.accept, acceptBody(stateV(1)));
    expect(await f, JamJoinOutcome.accepted);
  });

  test('code with no CODE on the broker: invalid after 4 s', () async {
    expect(
      await settle(join(JamInvite.fromCode('ABCD2345')!), step: 5),
      JamJoinOutcome.codeInvalid,
    );
  });

  for (final gone in [true, false]) {
    test('code ${gone ? 'gone' : 'past its exp'}: expired', () async {
      final keys = await hostP.deriveCode('ABCD2345');
      hostLink.publish(
        JamProtocol.codeTopic(keys.topicId),
        hostP.sealCode(
          keys.kc,
          JamCodeInfo(
            jamId: secrets.jamId,
            hpk: secrets.hpk,
            expMs: clock.millisecondsSinceEpoch + (gone ? 120000 : -180000),
            brokers: const [a],
            gone: gone,
          ),
        ),
        retain: true,
      );
      expect(
        await join(JamInvite.fromCode('ABCD2345')!),
        JamJoinOutcome.codeExpired,
      );
    });
  }

  test('a code only 60 s past its exp (skewed clock) still works', () async {
    final keys = await hostP.deriveCode('ABCD2345');
    hostLink.publish(
      JamProtocol.codeTopic(keys.topicId),
      hostP.sealCode(
        keys.kc,
        JamCodeInfo(
          jamId: secrets.jamId,
          hpk: secrets.hpk,
          expMs: clock.millisecondsSinceEpoch - 60000,
          brokers: const [a],
          gone: false,
        ),
      ),
      retain: true,
    );
    final f = join(JamInvite.fromCode('ABCD2345')!);
    for (var i = 0; i < 50 && hostTakesRequest(kc: keys.kc) == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(ch, isNotNull);
    hostSend(JamMsg.accept, acceptBody(stateV(1)));
    expect(await f, JamJoinOutcome.accepted);
  });

  for (final why in ['busy', 'declined']) {
    test('NO $why ends the join', () async {
      final f = join(qr());
      await pump();
      hostTakesRequest();
      hostSend(JamMsg.no, {'why': why});
      expect(
        await f,
        why == 'busy' ? JamJoinOutcome.busy : JamJoinOutcome.declined,
      );
    });
  }

  test('no answer in 60 s: expired', () async {
    final f = join(qr());
    await pump();
    clock = clock.add(const Duration(seconds: 61));
    guest.tick();
    await pump();
    clock = clock.add(const Duration(seconds: 2));
    guest.tick();
    expect(await f, JamJoinOutcome.expired);
  });

  test('dispose during the wait for the host: cancelled', () async {
    final f = join(qr());
    await pump();
    await guest.dispose();
    expect(await f, JamJoinOutcome.cancelled);
  });

  test('dispose during the code derivation: cancelled, no bridge', () async {
    final f = join(JamInvite.fromCode('ABCD2345')!);
    await guest.dispose();
    expect(await f, JamJoinOutcome.cancelled);
    expect(net.brokers.values.every((b) => b.log.isEmpty), isTrue);
    expect(guestLinks.length <= 1, isTrue); // at most the CODE lookup link
  });

  test('a failing derivation stops the timer', () {
    fakeAsync((t) {
      final g = RemoteJamGuest(
        protocol: JamProtocol(_BrokenCrypto()),
        linkFactory: () => FakeMqttLink(net),
        now: () => clock,
      );
      Object? error;
      g
          .join(JamInvite.fromCode('ABCD2345')!, ownDeviceId: 'd', ownName: 'n')
          .catchError((Object e) {
            error = e;
            return JamJoinOutcome.unreachable;
          });
      t.flushMicrotasks();
      expect(error, isNotNull);
      expect(t.periodicTimerCount, 0);
    });
  });

  test('cancelJoin ends the wait', () async {
    final f = join(qr());
    await pump();
    guest.cancelJoin();
    expect(await f, JamJoinOutcome.cancelled);
  });

  test('send: CMD goes out and RESULT answers it', () async {
    await joined();
    final f = guest.send(const JamCommand.play());
    await pump();
    hostPull();
    final cmd = inbox.singleWhere((m) => m.type == JamMsg.cmd);
    expect(cmd.command!.type, JamCommandType.play);
    hostSend(JamMsg.state, {'state': hostP.fitState(stateV(2))});
    hostSend(JamMsg.result, {'req': cmd.body['req'], 'v': 2});
    final r = await f;
    expect(r.state!.version, 2); // STATE came first: the result carries it
  });

  test('send: RESULT with an error maps to JamError', () async {
    await joined();
    final f = guest.send(const JamCommand.play());
    await pump();
    hostPull();
    hostSend(JamMsg.result, {
      'req': inbox.last.body['req'],
      'err': 'forbidden',
    });
    expect((await f).error, JamError.forbidden);
  });

  test('send: no RESULT in 10 s gives notFound', () async {
    await joined();
    final f = guest.send(const JamCommand.play());
    await pump();
    clock = clock.add(const Duration(seconds: 11));
    guest.tick();
    expect((await f).error, JamError.notFound);
  });

  test('an older STATE is ignored', () async {
    await joined();
    hostSend(JamMsg.state, {'state': hostP.fitState(stateV(7))});
    hostSend(JamMsg.state, {'state': hostP.fitState(stateV(3))});
    await pump();
    expect(guest.state!.version, 7);
  });

  test(
    '45 s of silence: SYNC and hostSilent, a host message clears it',
    () async {
      await joined();
      final links = <JamLinkState>[];
      guest.links.listen(links.add);
      clock = clock.add(const Duration(seconds: 46));
      guest.tick();
      await pump();
      hostPull();
      expect(inbox.any((m) => m.type == JamMsg.sync), isTrue);
      expect(guest.link, JamLinkState.hostSilent);
      hostSend(JamMsg.ping, {'v': 1, 't': 1});
      await pump();
      expect(guest.link, JamLinkState.ok);
      expect(links, [JamLinkState.hostSilent, JamLinkState.ok]);
    },
  );

  test(
    'broker lost: reconnecting, then SYNC on the next broker, same keys',
    () async {
      await joined();
      net[a].goDown();
      await pump();
      expect(guest.link, JamLinkState.reconnecting);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await pump();
      expect(guest.link, JamLinkState.ok);
      hostPull();
      expect(inbox.any((m) => m.type == JamMsg.sync), isTrue);
      expect(lostCount, 0);
    },
  );

  test(
    'a SYNC nobody answers in 5 s moves the bridge to the next broker',
    () async {
      await joined();
      clock = clock.add(const Duration(seconds: 46));
      guest.tick(); // SYNC
      await pump();
      clock = clock.add(const Duration(seconds: 6));
      guest.tick();
      await pump();
      expect(guestLinks.last.connectAttempts, [a, b]);
      hostPull();
      expect(inbox.where((m) => m.type == JamMsg.sync).length, 2);
    },
  );

  test('BYE: the Jam is lost', () async {
    await joined();
    hostSend(JamMsg.bye, {'why': 'removed'});
    await pump();
    expect(lostCount, 1);
  });

  test('STATE with ended closes the link without lost', () async {
    await joined();
    hostSend(JamMsg.state, {'state': hostP.fitState(stateV(2, ended: true))});
    await pump();
    expect(guest.state!.ended, isTrue);
    expect((await guest.send(const JamCommand.play())).error, JamError.ended);
    expect(lostCount, 0);
  });

  test('10 minutes without the host: lost', () async {
    await joined();
    clock = clock.add(const Duration(minutes: 11));
    guest.tick();
    await pump();
    expect(lostCount, 1);
  });

  test('time probe: TIME is answered with the host clock', () async {
    await joined();
    final f = guest.probeHostTime(() => 1000);
    await pump();
    hostPull();
    final t = inbox.lastWhere((m) => m.type == JamMsg.gTime);
    hostSend(JamMsg.time, {'t0': t.body['t0'], 't': 5000});
    expect((await f)!.hostMs, 5000);
  });

  test('two probes with the same t0 are both completed', () async {
    await joined();
    final f1 = guest.probeHostTime(() => 1000);
    final f2 = guest.probeHostTime(() => 1000);
    await pump();
    hostPull();
    final t = inbox.lastWhere((m) => m.type == JamMsg.gTime);
    hostSend(JamMsg.time, {'t0': t.body['t0'], 't': 5000});
    expect((await f1)!.hostMs, 5000);
    expect((await f2)!.hostMs, 5000);
  });

  test('dispose completes pending probes', () async {
    await joined();
    final f = guest.probeHostTime(() => 1000);
    await pump();
    await guest.dispose();
    expect(await f, isNull);
  });

  test('leave publishes LEAVE', () async {
    await joined();
    await guest.leave();
    hostPull();
    expect(inbox.any((m) => m.type == JamMsg.leave), isTrue);
  });
}

/// Any call fails: only the Argon2id derivation is reached in its test.
class _BrokenCrypto implements JamCrypto {
  @override
  dynamic noSuchMethod(Invocation i) => throw StateError('broken crypto');
}
