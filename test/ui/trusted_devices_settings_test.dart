import 'package:codecore/data/db/tables.dart' show TombstoneKind;
import 'package:codecore/providers/share_hub.dart';
import 'package:codecore/services/backup/user_data.dart';
import 'package:codecore/services/share/collection_sync.dart';
import 'package:codecore/services/share/playlist_sync.dart';
import 'package:codecore/services/share/settings_sync.dart';
import 'package:codecore/services/share/trusted_devices.dart';
import 'package:codecore/ui/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(500, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _Hub extends ShareHubNotifier {
  static final applied = <bool>[];
  static final settings = <Set<String>>[];

  @override
  ShareHubState build() => const ShareHubState();

  @override
  Future<SyncPlan> planPlaylistSync(TrustedDevice device) async => SyncPlan(
        const [],
        CollectionPlan(
          deletes: [TombstoneData(kind: TombstoneKind.favoriteAlbum, key: 'a|b', deletedAt: 5)],
          settings: const [SettingChange('theme', 'dark', 'light'), SettingChange('autoLyrics', true, false)],
        ),
      );

  @override
  Future<int> applyPlaylistSync(SyncPlan plan, {bool collections = false}) async {
    applied.add(collections);
    return 0;
  }

  @override
  void applySettingsSync(SyncPlan plan, Set<String> keys) => settings.add(keys);
}

Future<void> _pairOne(WidgetTester tester, Harness h, {required bool mine}) async {
  final devices = TrustedDevices([
    TrustedDevice(id: 'pc', name: 'PC di Marco', fingerprint: 'a1f309bc77d24e10ffee0011', pairedAt: 1, mine: mine),
  ]);
  await tester.runAsync(() => h.store.writeTrustedDevicesRaw(devices.encode()));
  await h.pump(tester, const Scaffold(body: SettingsScreen(initial: SettingsPage.network)),
      extraOverrides: [shareHubProvider.overrideWith(_Hub.new)]);
  await tester.ensureVisible(find.text('PC di Marco'));
  await tester.tap(find.text('PC di Marco'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no paired device: the section is not shown', (tester) async {
    _tall(tester);
    final h = await Harness.create(tester);
    await h.pump(tester, const Scaffold(body: SettingsScreen(initial: SettingsPage.network)));
    expect(find.text('Rete locale'), findsNothing, reason: 'one group: no title');
    expect(find.text('Dispositivi fidati'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('a paired device: fingerprint, accept automatically, revoke with confirmation', (tester) async {
    _tall(tester);
    final h = await Harness.create(tester);
    final devices = TrustedDevices([
      const TrustedDevice(
          id: 'pc', name: 'PC di Marco', fingerprint: 'a1f309bc77d24e10ffee0011', pairedAt: 1700000000000),
    ]);
    await tester.runAsync(() => h.store.writeTrustedDevicesRaw(devices.encode()));
    await h.pump(tester, const Scaffold(body: SettingsScreen(initial: SettingsPage.network)));

    expect(find.text('Dispositivi fidati'), findsOneWidget);
    expect(find.text('PC di Marco'), findsOneWidget);
    expect(find.text('Impronta A1F3-09BC-77D2-4E10'), findsOneWidget);

    await tester.ensureVisible(find.text('PC di Marco'));
    await tester.tap(find.text('PC di Marco'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Abbinato il'), findsOneWidget);
    await tester.tap(find.text('Accetta automaticamente'));
    await tester.pumpAndSettle();
    expect(TrustedDevices.decode(h.store.readTrustedDevicesRaw()).byId('pc')!.autoAccept, isTrue);

    await tester.tap(find.text('Mio dispositivo'));
    await tester.pumpAndSettle();
    expect(TrustedDevices.decode(h.store.readTrustedDevicesRaw()).byId('pc')!.mine, isTrue);

    await tester.ensureVisible(find.text('Revoca'));
    await tester.tap(find.text('Revoca'));
    await tester.pumpAndSettle();
    expect(find.text('Revocare «PC di Marco»?'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(find.text('PC di Marco'), findsOneWidget, reason: 'cancelling keeps the device');

    await tester.tap(find.text('Revoca'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Revoca')));
    await tester.pumpAndSettle();
    expect(find.text('PC di Marco'), findsNothing);
    expect(find.text('Dispositivi fidati'), findsNothing);
    expect(TrustedDevices.decode(h.store.readTrustedDevicesRaw()).isEmpty, isTrue);
    await h.dispose(tester);
  });

  testWidgets('a device that is not mine: only «Sincronizza playlist», no «Sincronizza ora»', (tester) async {
    _tall(tester);
    final h = await Harness.create(tester);
    await _pairOne(tester, h, mine: false);
    expect(find.text('Sincronizza ora'), findsNothing);
    expect(find.text('Sincronizza playlist'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('own device: removals and settings are applied only after the confirm, only the ticked settings',
      (tester) async {
    _tall(tester);
    _Hub.applied.clear();
    _Hub.settings.clear();
    final h = await Harness.create(tester);
    await _pairOne(tester, h, mine: true);
    await tester.tap(find.text('Sincronizza ora'));
    await tester.pumpAndSettle();
    expect(_Hub.applied, isEmpty, reason: 'nothing before the confirm');
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(_Hub.applied, isEmpty);

    await tester.tap(find.text('Sincronizza ora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tema'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Applica e togli 1 elemento'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // the snackbar, before it times out
    expect(_Hub.applied, [true]);
    expect(_Hub.settings, [
      {'theme'},
    ]);
    expect(find.text('Sincronizzato: 1 elemento'), findsNothing, reason: '1 removal + 1 setting = 2');
    expect(find.text('Sincronizzati: 2 elementi'), findsOneWidget);
    await h.dispose(tester);
  });
}
