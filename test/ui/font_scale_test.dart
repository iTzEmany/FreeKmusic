import 'package:codecore/app.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  // The smallest choice and a scale above the largest one (1.15): the scale
  // is applied linearly, so the values in between add nothing.
  for (final scale in [0.9, 1.5]) {
    testWidgets('app builds without errors at text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester, tracks: 3);
      await tester.pumpWidget(ProviderScope(
          overrides: h.overrides, child: const CodecoreApp()));
      await tester.pump(const Duration(milliseconds: 200));
      final container =
          ProviderScope.containerOf(tester.element(find.byType(CodecoreApp)));
      container
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(fontScale: scale));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Libreria'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Tutti i brani'));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 400));
      // The list query needs a second round of real I/O since the 83 provider changes.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.text('Song 0'), findsOneWidget);
      await h.dispose(tester);
    });
  }

  test('the app text scaler is equal when rebuilt with the same values', () {
    // An unequal scaler on every rebuild relayouts every Text (Pallino schede 3 % → 12 %).
    const a = AppTextScaler(TextScaler.noScaling, 1.15);
    expect(a, const AppTextScaler(TextScaler.noScaling, 1.15));
    expect(a.clamp(maxScaleFactor: 2), const AppTextScaler(TextScaler.noScaling, 1.15).clamp(maxScaleFactor: 2));
    expect(a == const AppTextScaler(TextScaler.noScaling, 1.0), isFalse);
  });
}
