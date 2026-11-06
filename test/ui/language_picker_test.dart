import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/ui/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('the language list offers French and Portuguese, and the choice is applied', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await h.pump(tester, const Scaffold(body: SettingsScreen(initial: SettingsPage.appearance)));
    // The list is lazy: scroll until the language row is built.
    await tester.scrollUntilVisible(find.text('Italiano'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Italiano'));
    await tester.pumpAndSettle();
    for (final name in ['English', 'Deutsch', 'Español', 'Français', 'Português']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
    expect(container.read(settingsProvider).language, 'fr');
    await h.dispose(tester);
  });
}
