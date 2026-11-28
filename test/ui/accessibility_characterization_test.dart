// System accessibility flags and large text: the flags are followed (D-14),
// the text scale is capped at 2.0 (D-31), car mode stays usable at 200 %.
import 'package:codecore/app.dart';
import 'package:codecore/core/platform.dart' show debugIsDesktopOverride;
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/ui/screens/car/car_mode_screen.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void _phone(WidgetTester tester, {double scale = 1}) {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  // Desktop ignores the text size (157a): these cases are the phone ones.
  debugIsDesktopOverride = false;
  addTearDown(() {
    debugIsDesktopOverride = null;
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

Future<Harness> _playing(WidgetTester tester) async {
  final h = await Harness.create(tester, tracks: 3);
  final ids = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!
      .map((t) => t.id)
      .toList();
  await tester.runAsync(() => h.handler.playQueue(ids, 0));
  return h;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('D-14: the system flags are followed (animations off, 1.3 x 1.5 = 1.95)', (tester) async {
    _phone(tester, scale: 1.3);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = await Harness.create(tester, tracks: 1);
    await tester.pumpWidget(
        ProviderScope(overrides: h.overrides, child: const CodecoreApp()));
    await tester.pump(const Duration(milliseconds: 600));
    final ctx = tester.element(find.byType(AppShell));
    final c = ProviderScope.containerOf(ctx);
    expect(c.read(settingsProvider).reducedMotion, isFalse);
    expect(MediaQuery.of(ctx).disableAnimations, isTrue);
    expect(MediaQuery.of(ctx).textScaler.scale(10), closeTo(13, 1e-6));
    c.read(settingsProvider.notifier).update((s) => s.copyWith(fontScale: 1.5));
    await tester.pump();
    expect(MediaQuery.of(ctx).textScaler.scale(10), closeTo(19.5, 1e-6));
    await h.dispose(tester);
  });

  testWidgets('system 1,5 x app 1,5 is capped at 2,0 (D-31)', (tester) async {
    _phone(tester, scale: 1.5);
    final h = await Harness.create(tester, tracks: 1);
    await tester.pumpWidget(
        ProviderScope(overrides: h.overrides, child: const CodecoreApp()));
    await tester.pump(const Duration(milliseconds: 600));
    final ctx = tester.element(find.byType(AppShell));
    ProviderScope.containerOf(ctx)
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(fontScale: 1.5));
    await tester.pump();
    expect(MediaQuery.of(ctx).textScaler.scale(10), closeTo(20, 1e-6));
    await h.dispose(tester);
  });

  testWidgets('car mode at 200 %: no overflow, controls stay big', (tester) async {
    _phone(tester, scale: 2.0);
    final h = await _playing(tester);
    await h.pump(tester, const CarModeScreen());
    await _settle(tester);
    expect(tester.takeException(), isNull);
    for (final tip in ['Brano precedente', 'Brano successivo', 'Pausa']) {
      final box = tester.getSize(
          find.ancestor(of: find.byTooltip(tip), matching: find.byType(SizedBox)).first);
      expect(box.shortestSide, greaterThanOrEqualTo(96), reason: tip);
    }
    await h.dispose(tester);
  });
}
