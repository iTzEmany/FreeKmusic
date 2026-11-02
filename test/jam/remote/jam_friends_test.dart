import 'dart:typed_data';

import 'package:codecore/data/settings/jam_secret_store.dart';
import 'package:codecore/services/jam/jam_host.dart';
import 'package:codecore/services/jam/remote/broker_entry.dart';
import 'package:codecore/services/jam/remote/jam_bridge.dart';
import 'package:codecore/services/jam/remote/jam_bridge_host.dart';
import 'package:codecore/services/jam/remote/jam_crypto.dart';
import 'package:codecore/services/jam/remote/jam_friends.dart';
import 'package:codecore/services/jam/remote/jam_invite.dart';
import 'package:codecore/services/jam/remote/jam_protocol.dart';
import 'package:codecore/services/jam/remote/remote_jam_guest.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const entry = BrokerEntry(host: 'a.net', port: 8883);

Future<void> _pump() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late JamCrypto crypto;
  late JamProtocol hostP, guestP;
  late FakeNet net;
  late DateTime clock;
  late JamHost host;
  late JamBridgeHost bh;
  late JamBridge bridge;
  late MemoryJamSecretStore hostStore, guestStore;
  late JamFriends hostFriends, guestFriends;
  late List<RemoteJamGuest> guests;
  late List<String> asked, auto;
  var autoOn = false;
  late Future<Object?> lastJoin;

  setUp(() async {
    crypto = await SodiumJamCrypto.create();
    hostP = JamProtocol(crypto);
    guestP = JamProtocol(crypto);
    net = FakeNet([entry]);
    clock = DateTime.fromMillisecondsSinceEpoch(1000000 * 30000 + 5000);
    guests = [];
    asked = [];
    auto = [];
    autoOn = false;
    hostStore = MemoryJamSecretStore();
    guestStore = MemoryJamSecretStore();
    hostFriends = JamFriends(hostStore);
    guestFriends = JamFriends(guestStore);
    await Future.wait([hostFriends.ready, guestFriends.ready]);
    host = JamHost(deviceId: 'host', deviceName: 'Host', now: () => clock)
      ..onRequest = (r) {
        asked.add(r.fromId);
      }
      ..onAutoAccept = (r) {
        auto.add(r.fromId);
      };
    bridge = JamBridge(FakeMqttLink(net), [entry], waits: const [Duration(milliseconds: 5)]);
    bh = JamBridgeHost(
      protocol: hostP,
      host: host,
      bridge: bridge,
      now: () => clock,
      friends: hostFriends,
      autoAcceptFriends: () => autoOn,
      stopGrace: Duration.zero,
    )..start();
    await _pump();
  });

  tearDown(() async {
    for (final g in guests) {
      await g.dispose();
    }
    await bh.dispose();
    host.dispose();
    hostFriends.dispose();
    guestFriends.dispose();
  });

  /// Starts a join (not awaited) with the host's current QR; [at] moves the guest's clock.
  Future<void> join(String id, {Duration at = Duration.zero, JamFriends? friends}) async {
    final g = RemoteJamGuest(
      protocol: guestP,
      linkFactory: () => FakeMqttLink(net),
      brokers: const [entry],
      now: () => clock.add(at),
      friends: friends ?? guestFriends,
      leaveGrace: Duration.zero,
      bridgeWaits: const [Duration(milliseconds: 5)],
    );
    guests.add(g);
    final invite = JamInvite.fromQr(bh.currentQr()!, guestP)!;
    lastJoin = g.join(invite, ownDeviceId: id, ownName: 'Declared $id');
    await _pump();
  }

  /// Both sides already hold the same pair key, as after an earlier Jam.
  Future<void> befriend() async {
    final fkp = crypto.randomBytes(32);
    await hostFriends.save('guest-1', 'Anna', guestFriends.announceKey, fkp);
    await guestFriends.save('host', 'Host', hostFriends.announceKey, fkp);
  }

  test('first accepted join: both sides save each other', () async {
    await join('guest-1');
    expect(host.requests.values.single.friend, isFalse);
    host.accept(host.requests.values.single.id);
    await lastJoin;
    await _pump();
    final h = hostFriends.byId('guest-1')!, g = guestFriends.byId('host')!;
    expect(h.ak, guestFriends.announceKey);
    expect(g.ak, hostFriends.announceKey);
    expect(h.fkp, g.fkp);
    expect(h.name, 'Declared guest-1');
    expect(g.name, 'Host');
    // Persisted in the secret store, not elsewhere.
    expect(hostStore.data.keys, containsAll([jamFriendsKey, jamAnnounceKeyKey]));
  });

  test('a saved friend is recognised even in another window, with its saved name', () async {
    await befriend();
    await join('guest-1', at: const Duration(seconds: 40)); // next 30 s window
    final r = host.requests.values.single;
    expect(r.friend, isTrue);
    expect(r.fromName, 'Anna');
  });

  test('a stranger, or a friend with the wrong pair key, is not marked', () async {
    final stranger = JamFriends(MemoryJamSecretStore());
    await stranger.ready;
    await join('guest-2', friends: stranger);
    expect(host.requests.values.single.friend, isFalse);
    host.decline(host.requests.values.single.id);

    // Knows the host's AK but not the pair key: the proof does not verify.
    await hostFriends.save('guest-1', 'Anna', guestFriends.announceKey, crypto.randomBytes(32));
    await guestFriends.save('host', 'Host', hostFriends.announceKey, crypto.randomBytes(32));
    clock = clock.add(const Duration(minutes: 2)); // out of the rate window of the gate, if any
    await join('guest-1');
    expect(host.requests.values.last.friend, isFalse);
  });

  test('a removed friend no longer recognises the host: AK is rotated', () async {
    await befriend();
    final label = bh.friendLabel();
    expect(guestFriends.match(guestP, label, clock.millisecondsSinceEpoch), isNotNull);
    await hostFriends.remove('guest-1');
    expect(hostFriends.byId('guest-1'), isNull);
    expect(guestFriends.match(guestP, bh.friendLabel(), clock.millisecondsSinceEpoch), isNull);
    expect(guestFriends.match(guestP, Uint8List(4), clock.millisecondsSinceEpoch), isNull);
  });

  test('auto-accept on: a friend skips the sheet; off: the sheet is asked', () async {
    await befriend();
    autoOn = true;
    await join('guest-1');
    expect(auto, ['guest-1']);
    expect(asked, isEmpty);
    host.decline(host.requests.values.single.id);

    autoOn = false;
    clock = clock.add(const Duration(minutes: 2));
    await join('guest-1');
    expect(asked, ['guest-1']);
    expect(auto, ['guest-1']);
  });

  test('auto-accept never skips the sheet for a stranger', () async {
    autoOn = true;
    await join('guest-9');
    expect(auto, isEmpty);
    expect(asked, ['guest-9']);
  });

  test('the list and AK survive a restart', () async {
    await befriend();
    final again = JamFriends(hostStore);
    await again.ready;
    expect(again.announceKey, hostFriends.announceKey);
    expect(again.byId('guest-1')!.name, 'Anna');
    again.dispose();
  });
}

