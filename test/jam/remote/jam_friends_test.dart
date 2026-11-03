import 'dart:async';
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
  FutureOr<void> Function(JamRequest)? autoHandler;
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
    autoHandler = (r) => host.accept(r.id);
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
        return autoHandler?.call(r);
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
    final fpH = hostP.decodeAdvert(bh.advert()!)!.fingerprint;
    expect(guestFriends.match(guestP, label, clock.millisecondsSinceEpoch, fpH), isNotNull);
    await hostFriends.remove('guest-1');
    expect(hostFriends.byId('guest-1'), isNull);
    expect(guestFriends.match(guestP, bh.friendLabel(), clock.millisecondsSinceEpoch, fpH), isNull);
    expect(guestFriends.match(guestP, Uint8List(4), clock.millisecondsSinceEpoch, fpH), isNull);
  });

  test('auto-accept on: a friend skips the sheet; off: the sheet is asked', () async {
    await befriend();
    autoOn = true;
    await join('guest-1');
    expect(auto, ['guest-1']);
    expect(asked, isEmpty);
    expect(host.requests.values.single.status, JamRequestStatus.accepted);

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

  test('an impostor with the id and name of a friend changes nothing and is not a friend', () async {
    await befriend();
    final before = hostFriends.byId('guest-1')!;
    autoOn = true;
    final stranger = JamFriends(MemoryJamSecretStore());
    await stranger.ready;
    await join('guest-1', friends: stranger); // no proof
    final r = host.requests.values.single;
    expect(r.friend, isFalse);
    expect(r.fromName, 'Declared guest-1'); // not the saved «Anna»
    expect(auto, isEmpty);
    expect(asked, ['guest-1']);
    host.accept(r.id);
    await lastJoin;
    await _pump();
    final after = hostFriends.byId('guest-1')!;
    expect(after.name, 'Anna');
    expect(after.ak, before.ak);
    expect(after.fkp, before.fkp);
  });

  test('a friend with the proof still updates its entry after a Jam', () async {
    await befriend();
    final before = hostFriends.byId('guest-1')!;
    await join('guest-1');
    host.accept(host.requests.values.single.id);
    await lastJoin;
    await _pump();
    // Updated with the new pair key (D-236); both sides hold the same one.
    expect(hostFriends.byId('guest-1')!.fkp, guestFriends.byId('host')!.fkp);
    expect(hostFriends.byId('guest-1')!.fkp, isNot(before.fkp));
  });

  test('an ACCEPT naming a saved friend that the label did not announce leaves the entry alone', () async {
    final oldAk = crypto.randomBytes(32), oldFkp = crypto.randomBytes(32);
    await guestFriends.save('host', 'Old host', oldAk, oldFkp); // not this host's AK: no recognition
    await join('guest-1');
    host.accept(host.requests.values.single.id);
    await lastJoin;
    await _pump();
    final g = guestFriends.byId('host')!;
    expect(g.name, 'Old host');
    expect(g.ak, oldAk);
    expect(g.fkp, oldFkp);
    expect(hostFriends.byId('guest-1'), isNull); // no FRIEND was sent
  });

  test('auto-accept without a handler, or one that throws or leaves it pending: the sheet is asked', () async {
    await befriend();
    autoOn = true;
    host.onAutoAccept = null;
    await join('guest-1');
    expect(asked, ['guest-1']);
    host.decline(host.requests.values.single.id);

    clock = clock.add(const Duration(minutes: 2));
    host.onAutoAccept = (r) => throw StateError('no controller');
    await join('guest-1');
    await _pump();
    expect(asked, ['guest-1', 'guest-1']);
    host.decline(host.requests.values.last.id);

    clock = clock.add(const Duration(minutes: 2));
    host.onAutoAccept = (r) async {}; // starts nothing
    await join('guest-1');
    await _pump();
    expect(asked.length, 3);
  });

  test('a friend goes before a stranger who holds the only slot (R-144)', () async {
    await befriend();
    final stranger = JamFriends(MemoryJamSecretStore());
    await stranger.ready;
    await join('guest-9', friends: stranger);
    final first = host.requests.values.single;
    expect(first.status, JamRequestStatus.pending);
    clock = clock.add(const Duration(seconds: 1));
    await join('guest-1');
    expect(first.status, JamRequestStatus.expired);
    final mine = host.requests.values.where((q) => q.status == JamRequestStatus.pending).single;
    expect(mine.fromId, 'guest-1');
    expect(mine.friend, isTrue);
    // A stranger does not take it back from a friend.
    await join('guest-8', friends: stranger);
    expect(host.requests.values.where((q) => q.fromId == 'guest-8'), isEmpty);
  });

  test('the label of A copied into the announcement of another Jam is not recognised', () async {
    await befriend();
    final a = hostP.decodeAdvert(bh.advert()!)!;
    final other = hostP.newHostSecrets();
    final otherFp = hostP.fingerprint(other.hpk);
    final now = clock.millisecondsSinceEpoch;
    expect(guestFriends.match(guestP, a.friendLabel, now, a.fingerprint), isNotNull);
    expect(guestFriends.match(guestP, a.friendLabel, now, otherFp), isNull);
    other.dispose();
  });

  test('a removed friend does not come back with a late FRIEND', () async {
    await join('guest-1'); // first Jam: the guest is new
    host.accept(host.requests.values.single.id);
    await lastJoin;
    await _pump();
    expect(hostFriends.byId('guest-1'), isNotNull);
    host.removeMember('guest-1');
    await _pump();

    // Second Jam: recognised with proof, then the user removes the friend mid-session.
    clock = clock.add(const Duration(minutes: 2));
    await join('guest-1');
    expect(host.requests.values.last.friend, isTrue);
    await hostFriends.remove('guest-1');
    host.accept(host.requests.values.last.id);
    await lastJoin;
    await _pump(); // the guest's FRIEND arrives after the removal
    expect(hostFriends.byId('guest-1'), isNull);
  });

  test('save and remove wait for the stored list to load', () async {
    final store = MemoryJamSecretStore();
    final first = JamFriends(store);
    await first.save('a', 'A', crypto.randomBytes(32), crypto.randomBytes(32));
    final again = JamFriends(store); // still loading
    await again.save('b', 'B', crypto.randomBytes(32), crypto.randomBytes(32));
    final third = JamFriends(store);
    await third.ready;
    expect(third.all.map((f) => f.id), unorderedEquals(['a', 'b']));
    final loading = JamFriends(store);
    await loading.remove('a'); // before the load: must not be lost
    expect(loading.byId('a'), isNull);
    expect(loading.byId('b'), isNotNull);
    for (final f in [first, again, third, loading]) {
      f.dispose();
    }
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

