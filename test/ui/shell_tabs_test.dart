import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/shell/bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

// Characterization of phase 87: today a dock tab keeps its state when another
// tab is shown. These flip in phase 89.4 (D-392). Scroll and search retention
// are pinned in app_shell_test.dart ('leaving a tab and coming back keeps its
// scroll offset', 'the Search tab keeps its query across tab switches') and
// also flip in 89.4.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)));
  // Tabs sit in a TickerMode: a few pumps after each tap.
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Finder _bar(String label) => find
    .descendant(of: find.byType(ShellDock), matching: find.text(label))
    .hitTestable();

Future<Harness> _open(WidgetTester tester, {int tracks = 40}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create(tester, tracks: tracks);
  await h.pump(tester, const AppShell());
  await _settle(tester);
  return h;
}

Future<void> _roundTrip(WidgetTester tester, String tab) async {
  await tester.tap(_bar('Home'));
  await _settle(tester);
  await tester.tap(_bar(tab));
  await _settle(tester);
}

void main() {
  testWidgets('a page pushed inside a tab is still there after another tab',
      (t) async {
    final h = await _open(t, tracks: 4);
    await t.tap(_bar('Libreria'));
    await _settle(t);
    await t.tap(find.text('Tutti i brani'));
    await _settle(t);
    expect(find.byType(AllTracksScreen), findsOneWidget);
    await _roundTrip(t, 'Libreria');
    expect(find.byType(AllTracksScreen), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('the selected Library block is kept after another tab', (t) async {
    final h = await _open(t, tracks: 4);
    await t.tap(_bar('Libreria'));
    await _settle(t);
    await t.tap(find.text('Album').first);
    await _settle(t);
    expect(find.text('2 album'), findsOneWidget);
    await _roundTrip(t, 'Libreria');
    expect(find.text('2 album'), findsOneWidget);
    await h.dispose(t);
  });
}
