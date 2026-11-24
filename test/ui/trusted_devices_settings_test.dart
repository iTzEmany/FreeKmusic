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
}
