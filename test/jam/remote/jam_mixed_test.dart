import 'dart:convert';

import 'package:codecore/services/jam/jam_guest.dart' show JamJoinOutcome;
import 'package:codecore/services/jam/jam_host.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/jam/remote/broker_entry.dart';
import 'package:codecore/services/jam/remote/jam_bridge.dart';
import 'package:codecore/services/jam/remote/jam_bridge_host.dart';
import 'package:codecore/services/jam/remote/jam_crypto.dart';
import 'package:codecore/services/jam/remote/jam_invite.dart';
import 'package:codecore/services/jam/remote/jam_protocol.dart';
import 'package:codecore/services/jam/remote/remote_jam_guest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

import 'fakes.dart';

const brokerA = BrokerEntry(host: 'a.net', port: 8883);
const brokerB = BrokerEntry(host: 'b.net', port: 8883);

/// Host + LAN guest + remote guests on a FakeBroker, all on one fake clock.
void main() {
  late JamProtocol protocol;
  late DateTime clock;
  late FakeNet net;
  late FakeMqttLink hostLink;
  late JamHost host;
  late JamBridgeHost bh;
  late List<RemoteJamGuest> guests;

  Future<void> pump() async {
    for (var i = 0; i < 5; i++) {
      await pumpEventQueue();
    }
  }

  setUp(() async {
    final crypto = await SodiumJamCrypto.create();
    clock = DateTime.fromMillisecondsSinceEpoch(1000000 * 30000 + 5000);
    protocol = JamProtocol(crypto);
    net = FakeNet([brokerA, brokerB]);
    hostLink = FakeMqttLink(net);
    host = JamHost(
      deviceId: 'host-dev-id',
      deviceName: 'HostPCname',
      now: () => clock,
    );
    bh = JamBridgeHost(
      protocol: protocol,
      host: host,
      bridge: JamBridge(hostLink, [brokerA, brokerB]),
      now: () => clock,
      stopGrace: Duration.zero,
    )..start();
    guests = [];
    await pump();
  });

  tearDown(() async {
    for (final g in guests) {
      await g.dispose();
    }
    await bh.dispose();
    host.dispose();
  });

  RemoteJamGuest newGuest() {
    final g = RemoteJamGuest(
      protocol: protocol,
      linkFactory: () => FakeMqttLink(net),
      brokers: const [brokerA, brokerB],
      now: () => clock,
    );
    guests.add(g);
    return g;
  }

  /// Ticks guest and host on a clock moving [step] until [f] completes.
  Future<T> drive<T>(
    Future<T> f,
    RemoteJamGuest g, {
    Duration step = const Duration(seconds: 1),
  }) async {
    var done = false;
    f.whenComplete(() => done = true).ignore();
    for (var i = 0; i < 400 && !done; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      clock = clock.add(step);
      g.tick();
      bh.tick();
    }
    return f;
  }

  Future<JamJoinOutcome> joinQr(
    RemoteJamGuest g,
    String id, {
    bool accept = true,
  }) async {
    final f = g.join(
      JamInvite.fromQr(bh.currentQr()!, protocol)!,
      ownDeviceId: id,
      ownName: 'Name $id',
    );
    await pump();
    if (accept) {
      host.accept(host.requests.values.firstWhere((r) => r.fromId == id).id);
      await pump();
    }
    return f;
  }

  Future<RemoteJamGuest> joined(String id) async {
    final g = newGuest();
    expect(await joinQr(g, id), JamJoinOutcome.accepted);
    return g;
  }

  /// A LAN guest through the real router.
  Future<void> lanJoin(String id) async {
    final res = await host
        .buildRouter(clientIp: (_) => '192.168.1.50')
        .call(
          Request(
            'POST',
            Uri.parse('http://x/request'),
            body: jsonEncode({
              'fromId': id,
              'fromName': 'Lan $id',
              'port': 4000,
              'token': 'token-12345',
            }),
          ),
        );
    expect(res.statusCode, 202);
    host.accept(host.requests.values.firstWhere((r) => r.fromId == id).id);
    await pump();
  }

  JamItem track(String owner, String title) =>
      JamItem(id: 0, ownerDeviceId: owner, title: title, ext: 'mp3');

  test('LAN and remote guests see the same queue and version', () async {
    await lanJoin('lan-1');
    final g = await joined('rem-1');
    host.apply(JamCommand.add(track('host-dev-id', 'Uno')));
    await pump();
    expect(host.memberIds, ['lan-1', 'rem-1']);
    expect(g.state!.version, host.state!.version);
    expect(g.state!.items.map((i) => i.title), ['Uno']);
    expect(g.state!.participants.length, 3);
  });

  test('the sixth participant is refused', () async {
    await lanJoin('lan-1');
    for (var i = 0; i < 3; i++) {
      await joined('rem-$i');
    }
    expect(host.memberIds.length, 4);
    final late = newGuest();
    expect(await joinQr(late, 'rem-late', accept: false), JamJoinOutcome.busy);
    expect(host.memberIds.length, 4);
  });

  test('offerSpeaker and setOutput from or to a remote are forbidden', () async {
    final g = await joined('rem-1');
    expect(
      (await g.send(const JamCommand.offerSpeaker())).error,
      JamError.forbidden,
    );
    expect(
      (await g.send(const JamCommand.setOutput('rem-1'))).error,
      JamError.forbidden,
    );
    expect(
      host.apply(const JamCommand.setOutput('rem-1')).error,
      JamError.forbidden,
    );
  });

  test('LEAVE removes the guest and its own items', () async {
    final g = await joined('rem-1');
    final add = await g.send(JamCommand.add(track('rem-1', 'Mio')));
    expect(add.isOk, isTrue);
    expect(host.state!.items.length, 1);
    await g.leave();
    await pump();
    expect(host.memberIds, isEmpty);
    expect(host.state!.items, isEmpty);
  });

  test('a removed guest is told, and its keys no longer work', () async {
    final g = await joined('rem-1');
    final subs = hostLink.subscribed.length;
    var lost = false;
    g.lost.listen((_) => lost = true);
    host.removeMember('rem-1');
    await pump();
    expect(lost, isTrue);
    expect(hostLink.subscribed.length, subs - 1);
    expect((await g.send(const JamCommand.pause())).error, JamError.ended);
    expect(host.memberIds, isEmpty);
  });

  test('broker down: the guest follows on the reserve without rejoining', () async {
    final g = await joined('rem-1');
    net[brokerA].goDown();
    host.apply(JamCommand.add(track('host-dev-id', 'Durante')));
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await pump();
    expect(g.state!.version, host.state!.version);
    expect(g.state!.items.map((i) => i.title), ['Durante']);
    expect(host.memberIds, ['rem-1']);
  });

  test('an unanswered request vanishes at 60 s on both sides', () async {
    final g = newGuest();
    final f = g.join(
      JamInvite.fromQr(bh.currentQr()!, protocol)!,
      ownDeviceId: 'rem-1',
      ownName: 'Name',
    );
    await pump();
    expect(host.requests, isNotEmpty);
    expect(
      await drive(f, g, step: const Duration(seconds: 5)),
      JamJoinOutcome.expired,
    );
    expect(host.requests.values.every((r) => r.status != JamRequestStatus.pending),
        isTrue);
    expect(host.memberIds, isEmpty);
  });

  test('a wrong code is codeInvalid', () async {
    await bh.startCode();
    final g = newGuest();
    final f = g.join(
      JamInvite.fromCode('ZZZZ-ZZZZ')!,
      ownDeviceId: 'rem-1',
      ownName: 'Name',
    );
    expect(await drive(f, g), JamJoinOutcome.codeInvalid);
  });

  test('an expired code is codeExpired', () async {
    await bh.startCode();
    final code = bh.code!;
    clock = clock.add(const Duration(minutes: 5)); // past exp plus the guest slack
    final g = newGuest();
    final f = g.join(
      JamInvite.fromCode(code)!,
      ownDeviceId: 'rem-1',
      ownName: 'Name',
    );
    expect(await drive(f, g), JamJoinOutcome.codeExpired);
  });

  test('a good code joins', () async {
    await bh.startCode();
    final g = newGuest();
    final f = g.join(
      JamInvite.fromCode(bh.code!)!,
      ownDeviceId: 'rem-1',
      ownName: 'Name',
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await pump();
    host.accept(host.requests.values.single.id);
    expect(await drive(f, g), JamJoinOutcome.accepted);
  });

  test('the broker log holds no name, title or device id in clear', () async {
    final g = await joined('anna-device-id');
    host.apply(JamCommand.add(track('host-dev-id', 'TitoloSegretoXY')));
    await pump();
    await g.send(JamCommand.add(track('anna-device-id', 'BranoDiAnnaZZ')));
    host.removeMember('anna-device-id');
    await pump();
    final log = [
      for (final b in net.brokers.values) ...b.log,
    ].map((m) => latin1.decode(m.bytes)).join('\n');
    for (final s in [
      'anna-device-id',
      'Name anna-device-id',
      'TitoloSegretoXY',
      'BranoDiAnnaZZ',
      'HostPCname',
      'host-dev-id',
    ]) {
      expect(log.contains(s), isFalse, reason: s);
    }
  });
}


