import 'dart:async';
import 'dart:typed_data';

import 'package:codecore/data/settings/jam_secret_store.dart';
import 'package:codecore/providers/jam_broker_providers.dart';
import 'package:codecore/providers/jam_gate_providers.dart';
import 'package:codecore/providers/jam_nearby_providers.dart';
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/share_hub.dart';
import 'package:codecore/services/jam/remote/jam_beacon.dart';
import 'package:codecore/services/jam/remote/jam_crypto.dart';
import 'package:codecore/services/jam/remote/jam_invite.dart';
import 'package:codecore/services/jam/remote/jam_protocol.dart';
import 'package:codecore/services/share/discovery.dart';
import 'package:codecore/ui/screens/devices/devices_sheet.dart';
import 'package:codecore/ui/screens/jam/ble_permission.dart';
import 'package:codecore/ui/screens/jam/speaker_notices.dart';
import 'package:codecore/ui/screens/settings/jam_remote_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

class _Hub extends ShareHubNotifier {
  @override
  ShareHubState build() => const ShareHubState(active: true);
  void setPeers(List<Peer> p) => state = state.copyWith(peers: p);
  @override
  Future<void> enter() async {}
  @override
  Future<void> leave() async {}
}

class _SlowBeacon extends FakeJamBeacon {
  final gate = Completer<void>();
  int stops = 0;
  @override
  Future<bool> startScan() async {
    await gate.future;
    return super.startScan();
  }

  @override
  Future<void> stopScan() async {
    stops++;
    await super.stopScan();
  }
}

class _Jam extends JamController {
  final requested = <JamInvite?>[];
  @override
  JamUiState build() => const JamUiState();
  @override
  Future<void> requestRemote(JamInvite? invite) async => requested.add(invite);
  void set(JamUiState s) => state = s;
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump();
  }
}

void main() {
  late SodiumJamCrypto crypto;
  late JamProtocol p;
  late FakeJamBeacon beacon;
  late _Hub hub;
  late _Jam jam;
  var now = DateTime.utc(2026, 1, 1);
  final ak = Uint8List.fromList(List.generate(32, (i) => i));

  setUpAll(() async => crypto = await SodiumJamCrypto.create());

  setUp(() {
    p = JamProtocol(crypto);
    beacon = FakeJamBeacon();
    hub = _Hub();
    jam = _Jam();
    now = DateTime.utc(2026, 1, 1);
  });

  /// A packet from a new Jam of a host whose announce key is [hostAk].
  (Uint8List, JamHostSecrets) packet({Uint8List? hostAk}) {
    final s = p.newHostSecrets();
    return (p.advertAt(s, now.millisecondsSinceEpoch, ak: hostAk ?? ak, broker: 0), s);
  }

  Future<Harness> open(WidgetTester t, Widget child, {List<Override> extra = const [], bool ble = false}) async {
    final h = await Harness.create(t);
    await h.pump(t, child, extraOverrides: [
      jamBeaconProvider.overrideWithValue(beacon),
      if (!ble) jamBleAvailableProvider.overrideWithValue(true),
      jamCryptoProvider.overrideWith((_) => crypto),
      jamSecretStoreProvider.overrideWithValue(MemoryJamSecretStore()),
      jamNearbyNowProvider.overrideWithValue(() => now),
      shareHubProvider.overrideWith(() => hub),
      jamProvider.overrideWith(() => jam),
      ...extra,
    ]);
    // Scan starts after a few microtasks.
    await settle(t);
    return h;
  }

  const banner = Scaffold(body: JamInviteBanner());

  testWidgets('an announcement shows the banner; a tap asks with the newest token', (t) async {
    final h = await open(t, banner);
    expect(beacon.scanning, isTrue);
    final (bytes, s) = packet();
    beacon.hear(bytes);
    await settle(t);
    expect(find.text('Unisciti a una Jam qui vicino'), findsOneWidget);
    await t.tap(find.text('Unisciti a una Jam qui vicino'));
    await settle(t);
    expect(jam.requested.single!.jamId, s.jamId);
    expect(jam.requested.single!.fingerprint, p.fingerprint(s.hpk));
    await t.pumpAndSettle();
    await h.dispose(t);
  });

  testWidgets('X hides the banner for that Jam, the row in Dispositivi stays', (t) async {
    final h = await open(
      t,
      Builder(builder: (c) => Column(children: [const JamInviteBanner(), TextButton(onPressed: () => DevicesSheet.show(c), child: const Text('open'))])),
    );
    beacon.hear(packet().$1);
    await settle(t);
    await t.tap(find.byTooltip('Nascondi'));
    await settle(t);
    expect(find.textContaining('Unisciti'), findsNothing);
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Unisciti a una Jam qui vicino'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('a friend is named and listed before a stranger', (t) async {
    final h = await open(t, banner);
    final friends = ProviderScope.containerOf(t.element(find.byType(JamInviteBanner))).read(jamFriendsProvider);
    await t.runAsync(() => friends.save('f1', 'Ale', ak, Uint8List(32)));
    beacon.hear(packet(hostAk: Uint8List(32)).$1, -40); // a stranger, closer
    beacon.hear(packet().$1, -80);
    await settle(t);
    final c = ProviderScope.containerOf(t.element(find.byType(JamInviteBanner)));
    expect(c.read(jamNearbyProvider).map((e) => e.friendName), ['Ale', null]);
    expect(find.text('Unisciti alla Jam di Ale'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('in the background the scanner stops and the list empties; back, it scans again', (t) async {
    final h = await open(t, banner);
    beacon.hear(packet().$1);
    await settle(t);
    expect(find.textContaining('Unisciti'), findsOneWidget);
    for (final st in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      t.binding.handleAppLifecycleStateChanged(st);
    }
    await settle(t);
    expect(beacon.scanning, isFalse);
    expect(ProviderScope.containerOf(t.element(find.byType(JamInviteBanner))).read(jamNearbyProvider), isEmpty);
    for (final st in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      t.binding.handleAppLifecycleStateChanged(st);
    }
    await settle(t);
    expect(beacon.scanning, isTrue);
    await h.dispose(t);
  });

  testWidgets('a Jam that ended with the Jam screen closed does not hold the search back', (t) async {
    final h = await open(t, banner);
    expect(beacon.scanning, isTrue);
    jam.set(const JamUiState(phase: JamPhase.active));
    await settle(t);
    expect(beacon.scanning, isFalse, reason: 'a Jam going on: no search');
    jam.set(const JamUiState(phase: JamPhase.ended));
    await settle(t);
    expect(beacon.scanning, isTrue);
    await h.dispose(t);
  });

  testWidgets('inactive (a dialog on top) keeps the scan going', (t) async {
    final h = await open(t, banner);
    beacon.hear(packet().$1);
    await settle(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await settle(t);
    expect(beacon.scanning, isTrue);
    expect(find.textContaining('Unisciti'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('a scan lost natively is no longer active and starts again at the next refresh', (t) async {
    final h = await open(t, banner);
    beacon.hear(packet().$1);
    await settle(t);
    beacon.fail(JamBeaconKind.scan);
    await settle(t);
    final c = ProviderScope.containerOf(t.element(find.byType(JamInviteBanner)));
    expect(c.read(jamNearbyProvider), isEmpty);
    // Still believing it ran, a refresh would do nothing: it must scan again.
    c.read(jamNearbyProvider.notifier).refresh();
    await settle(t);
    expect(beacon.scanning, isTrue);
    await h.dispose(t);
  });

  testWidgets('a forgotten friend loses the name at the next packet', (t) async {
    final h = await open(t, banner);
    final c = ProviderScope.containerOf(t.element(find.byType(JamInviteBanner)));
    final friends = c.read(jamFriendsProvider);
    await t.runAsync(() => friends.save('f1', 'Ale', ak, Uint8List(32)));
    final (bytes, _) = packet();
    beacon.hear(bytes);
    await settle(t);
    expect(c.read(jamNearbyProvider).single.friendName, 'Ale');
    await t.runAsync(() => friends.remove('f1'));
    beacon.hear(bytes);
    await settle(t);
    expect(c.read(jamNearbyProvider).single.friendName, isNull);
    await h.dispose(t);
  });

  testWidgets('no scan with the setting off or without the permission', (t) async {
    beacon.perms = const JamBeaconPermissions();
    final h = await open(t, banner);
    expect(beacon.scanning, isFalse);
    await h.dispose(t);
  });

  testWidgets('an entry lives to the end of the window after the one it was heard in', (t) async {
    final h = await open(t, banner);
    now = DateTime.utc(2026, 1, 1, 0, 0, 29); // last second of window w
    beacon.hear(packet().$1);
    await settle(t);
    now = DateTime.utc(2026, 1, 1, 0, 0, 59); // still w+1
    await t.pump(const Duration(seconds: 10));
    expect(find.textContaining('Unisciti'), findsOneWidget);
    now = DateTime.utc(2026, 1, 1, 0, 1, 0); // w+2: the host refuses the token
    await t.pump(const Duration(seconds: 10));
    expect(find.textContaining('Unisciti'), findsNothing);
    await h.dispose(t);
  });

  testWidgets('a tap on an entry whose token ran out since the last prune asks nothing', (t) async {
    final h = await open(t, banner);
    beacon.hear(packet().$1);
    await settle(t);
    now = now.add(const Duration(seconds: 61)); // the 10 s prune has not fired yet
    await t.tap(find.text('Unisciti a una Jam qui vicino'));
    await settle(t);
    expect(jam.requested, isEmpty);
    await h.dispose(t);
  });

  testWidgets('a dismissed Jam that expired and is announced again shows the banner again', (t) async {
    final h = await open(t, banner);
    final (bytes, _) = packet();
    beacon.hear(bytes);
    await settle(t);
    await t.tap(find.byTooltip('Nascondi'));
    await settle(t);
    now = now.add(const Duration(seconds: 70));
    await t.pump(const Duration(seconds: 10));
    final c = ProviderScope.containerOf(t.element(find.byType(JamInviteBanner)));
    expect(c.read(jamNearbyProvider), isEmpty);
    beacon.hear(bytes); // the same Jam id again
    await settle(t);
    expect(find.textContaining('Unisciti'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('a scan that starts after the container is gone is stopped again', (t) async {
    final slow = _SlowBeacon();
    beacon = slow;
    final h = await open(t, banner);
    await h.dispose(t);
    slow.gate.complete();
    await t.pump();
    await t.pump();
    expect(slow.scanning, isFalse);
    expect(slow.stops, greaterThan(0));
  });

  testWidgets('the same Jam id from the LAN leaves only the LAN row', (t) async {
    final h = await open(t, banner);
    final (bytes, s) = packet();
    beacon.hear(bytes);
    await settle(t);
    hub.setPeers([
      Peer(id: 'h1', name: 'Tel', host: '10.0.0.5', port: 8000, platform: 'android', jamName: 'Cucina', jamRid: b64u(s.jamId)),
    ]);
    await settle(t);
    expect(find.text('Unisciti alla Jam di Cucina'), findsOneWidget);
    expect(find.text('Unisciti a una Jam qui vicino'), findsNothing);
    final c = ProviderScope.containerOf(t.element(find.byType(JamInviteBanner)));
    expect(c.read(jamNearbyVisibleProvider), isEmpty);
    await h.dispose(t);
  });

  group('permission sheets', () {
    Future<Harness> sheet(WidgetTester t, {required bool legacy, bool locationOff = false, bool grant = true}) async {
      beacon
        ..perms = const JamBeaconPermissions()
        ..caps = JamBeaconCapabilities(bluetoothOn: true, scan: true, advertise: true, needsLocation: legacy, locationOff: locationOff)
        ..grantOnRequest = grant ? const JamBeaconPermissions(scan: true, advertise: true) : const JamBeaconPermissions();
      return open(
        t,
        Scaffold(body: Consumer(builder: (c, ref, _) => TextButton(onPressed: () => askBlePermission(c, ref), child: const Text('ask')))),
      );
    }

    testWidgets('Android 12+: the Nearby devices line, then the request', (t) async {
      final h = await sheet(t, legacy: false);
      await t.tap(find.text('ask'));
      await t.pumpAndSettle();
      expect(find.textContaining('Dispositivi vicini'), findsOneWidget);
      await t.tap(find.text('Consenti'));
      await t.pumpAndSettle();
      expect(beacon.requests, 1);
      final c = ProviderScope.containerOf(t.element(find.text('ask')));
      expect(c.read(jamNearbyScanProvider), isTrue);
      expect(beacon.scanning, isTrue);
      await h.dispose(t);
    });

    testWidgets('Android <= 11: the location line; location off says so', (t) async {
      final h = await sheet(t, legacy: true, locationOff: true);
      await t.tap(find.text('ask'));
      await t.pumpAndSettle();
      expect(find.textContaining('non legge dove sei'), findsOneWidget);
      expect(find.textContaining('Dispositivi vicini'), findsNothing);
      await t.tap(find.text('Consenti'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600)); // not settle: the snackbar ring animates until it closes
      expect(find.textContaining('Accendi la posizione'), findsOneWidget);
      await h.dispose(t);
    });

    testWidgets('Dispositivi with the location off says so inside the sheet, at each opening', (t) async {
      beacon
        ..perms = const JamBeaconPermissions(scan: true, advertise: true)
        ..caps = const JamBeaconCapabilities(bluetoothOn: true, scan: true, advertise: true, needsLocation: true, locationOff: true);
      final h = await open(
        t,
        Builder(builder: (c) => TextButton(onPressed: () => DevicesSheet.show(c), child: const Text('open'))),
      );
      final inSheet = find.descendant(of: find.byType(DevicesSheet), matching: find.textContaining('Accendi la posizione'));
      for (var i = 0; i < 2; i++) {
        await t.tap(find.text('open'));
        await t.pumpAndSettle();
        expect(inSheet, findsOneWidget, reason: 'opening ${i + 1}');
        await t.tapAt(const Offset(5, 5)); // the barrier closes the sheet
        await t.pumpAndSettle();
      }
      await h.dispose(t);
    });

    testWidgets('location off is not mentioned when the search is off', (t) async {
      final h = await sheet(t, legacy: true, locationOff: true);
      final c = ProviderScope.containerOf(t.element(find.text('ask')));
      c.read(jamNearbyScanProvider.notifier).set(false);
      beacon.perms = const JamBeaconPermissions(scan: true, advertise: true);
      await t.tap(find.text('ask'));
      await t.pumpAndSettle();
      expect(find.textContaining('Accendi la posizione'), findsNothing);
      await h.dispose(t);
    });

    testWidgets('the widget going away during the sheet does not throw', (t) async {
      final h = await sheet(t, legacy: false);
      await t.tap(find.text('ask'));
      await t.pumpAndSettle();
      // Replace the tree while the sheet is open, then answer.
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await h.dispose(t);
    });

    testWidgets('refusal turns the scan off, is not asked again, and the switch brings it back', (t) async {
      final h = await sheet(t, legacy: false, grant: false);
      final c = ProviderScope.containerOf(t.element(find.text('ask')));
      await t.tap(find.text('ask'));
      await t.pumpAndSettle();
      await t.tap(find.text('Non ora'));
      await t.pumpAndSettle();
      expect(beacon.requests, 0);
      expect(c.read(jamNearbyScanProvider), isFalse);
      expect(h.store.readJamNearbyScan(), isFalse);
      expect(beacon.scanning, isFalse);
      // Asked once: no second sheet.
      await t.tap(find.text('ask'));
      await t.pumpAndSettle();
      expect(find.text('Consenti'), findsNothing);
      await h.dispose(t);
    });

    testWidgets('the settings hide the search switch where there is no Bluetooth beacon', (t) async {
      final h = await open(t, const JamRemoteSettings(), ble: true, extra: [jamBleAvailableProvider.overrideWithValue(false)]);
      expect(find.text('Cerca Jam vicine'), findsNothing);
      await h.dispose(t);
    });

    testWidgets('the settings switch turns it off, and on again asks with the sheet', (t) async {
      beacon
        ..perms = const JamBeaconPermissions()
        ..grantOnRequest = const JamBeaconPermissions(scan: true, advertise: true);
      final h = await open(t, const JamRemoteSettings());
      final c = ProviderScope.containerOf(t.element(find.byType(JamRemoteSettings)));
      await t.tap(find.text('Cerca Jam vicine'));
      await settle(t);
      expect(c.read(jamNearbyScanProvider), isFalse);
      await t.tap(find.text('Cerca Jam vicine'));
      await t.pumpAndSettle();
      await t.tap(find.text('Consenti'));
      await t.pumpAndSettle();
      expect(c.read(jamNearbyScanProvider), isTrue);
      expect(beacon.scanning, isTrue);
      await h.dispose(t);
    });
  });
}
