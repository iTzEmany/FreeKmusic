import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:codecore/providers/nav_providers.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/shell/desktop_sidebar.dart';
import 'package:codecore/ui/shell/side_panel.dart';
import 'package:codecore/ui/widgets/album_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void _size(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

SidePanelNotifier _panel(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppShell)))
        .read(sidePanelProvider.notifier);

void main() {
  test('the album grid keeps cells of at least 168 px', () {
    expect(albumGridColumns(360), 2);
    expect(albumGridColumns(840), 4);
    expect(albumGridColumns(1200), 7);
    expect(albumGridColumns(1600), 9);
    expect(albumGridColumns(100), 2, reason: 'never fewer than two');
    for (final w in [360.0, 600.0, 840.0, 1000.0, 1280.0, 1600.0, 2400.0]) {
      final cell = (w - 16) / albumGridColumns(w);
      expect(cell, greaterThanOrEqualTo(w < 2 * 168 + 16 ? 0 : 168), reason: 'width $w');
    }
  });

  testWidgets('at 1280 px the panel starts closed and opens 360 px wide', (tester) async {
    _size(tester, 1280, 800);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, const AppShell());
    await _settle(tester);
    await tester.runAsync(() => h.handler.playQueue([1, 2, 3, 4], 0));
    await _settle(tester);
    expect(find.byType(SidePanelView), findsNothing, reason: 'closed by default');
    _panel(tester).toggle(SidePanel.queue);
    await _settle(tester);
    expect(find.byType(SidePanelView), findsOneWidget);
    expect(tester.getSize(find.byType(SidePanelView)).width, 360);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('at 1600×1000 everything fits, with the panel open', (tester) async {
    _size(tester, 1600, 1000);
    final h = await Harness.create(tester, tracks: 12);
    await tester.runAsync(() => h.handler.playQueue([1, 2, 3, 4, 5], 1));
    await h.pump(tester, const AppShell());
    await _settle(tester);
    _panel(tester).toggle(SidePanel.queue);
    await _settle(tester);
    expect(find.byType(SidePanelView), findsOneWidget);
    expect(find.byType(DesktopSidebar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('below 1200 px the panel is 320 px wide', (tester) async {
    _size(tester, 1100, 800);
    final h = await Harness.create(tester, tracks: 4);
    await tester.runAsync(() => h.handler.playQueue([1, 2, 3, 4], 0));
    await h.pump(tester, const AppShell());
    await _settle(tester);
    expect(find.byType(SidePanelView), findsNothing);
    _panel(tester).toggle(SidePanel.queue);
    await _settle(tester);
    expect(tester.getSize(find.byType(SidePanelView)).width, 320);
    await h.dispose(tester);
  });

  testWidgets('a vertical hinge over the sidebar pushes the whole layout past it', (tester) async {
    _size(tester, 1280, 800);
    tester.view.displayFeatures = [
      const DisplayFeature(
        bounds: Rect.fromLTWH(100, 0, 24, 800),
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.unknown,
      ),
    ];
    addTearDown(tester.view.resetDisplayFeatures);
    final h = await Harness.create(tester, tracks: 2);
    await h.pump(tester, const AppShell());
    await _settle(tester);
    expect(tester.getTopLeft(find.byType(DesktopSidebar)).dx, 124);
    await h.dispose(tester);
  });

  testWidgets('a hinge in the middle leaves the sidebar where it is', (tester) async {
    _size(tester, 1280, 800);
    tester.view.displayFeatures = [
      const DisplayFeature(
        bounds: Rect.fromLTWH(630, 0, 20, 800),
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.unknown,
      ),
    ];
    addTearDown(tester.view.resetDisplayFeatures);
    final h = await Harness.create(tester, tracks: 2);
    await h.pump(tester, const AppShell());
    await _settle(tester);
    expect(tester.getTopLeft(find.byType(DesktopSidebar)).dx, 0);
    await h.dispose(tester);
  });

  // The narrowest window of each sidebar width: 840 (collapsed sidebar, the
  // narrowest bar) and 1000 (full sidebar, the narrowest content).
  for (final w in [840.0, 1000.0]) {
    testWidgets('the player bar fits at ${w.round()} px (the volume slider gives way)', (tester) async {
      _size(tester, w, 800);
      final h = await Harness.create(tester, tracks: 4);
      await tester.runAsync(() => h.handler.playQueue([1, 2, 3, 4], 0));
      await h.pump(tester, const AppShell());
      await _settle(tester);
      expect(tester.takeException(), isNull);
      await h.dispose(tester);
    });
  }
}

