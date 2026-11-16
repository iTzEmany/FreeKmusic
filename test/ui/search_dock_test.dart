import 'package:codecore/providers/nav_providers.dart';
import 'package:codecore/providers/ui_providers.dart';
import 'package:codecore/ui/screens/search/search_screen.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/shell/bottom_bar.dart';
import 'package:codecore/ui/widgets/mini_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester t) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  for (var i = 0; i < 3; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

/// A phone with a track playing, so the dock has its three layers.
Future<Harness> _shell(WidgetTester t) async {
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final h = await Harness.create(t, tracks: 2);
  final rows = await t.runAsync(() => h.db.select(h.db.tracks).get());
  await t.runAsync(() => h.handler.playQueue([rows!.first.id], 0));
  await h.pump(t, const AppShell());
  await _settle(t);
  return h;
}

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(AppShell)));

// The bar is the page's: on a phone too, no longer the dock's.
Finder _field() => find.descendant(
    of: find.byType(SearchScreen), matching: find.byType(TextField));

Finder _tab(String label) => find
    .descendant(of: find.byType(ShellDock), matching: find.text(label))
    .hitTestable()
    .last;

Future<void> _keyboard(WidgetTester t, double height) async {
  t.view.viewInsets = FakeViewPadding(bottom: height);
  await _settle(t);
}

void main() {
  testWidgets('keyboard up on Search: the dock steps aside, the bar stays in view', (t) async {
    final h = await _shell(t);
    final semantics = t.ensureSemantics();
    await t.tap(_tab('Cerca'));
    await _settle(t);
    await _keyboard(t, 300);
    expect(_field(), findsOneWidget);
    expect(find.byType(MiniPlayer), findsNothing);
    expect(find.text('Home').hitTestable(), findsNothing);
    expect(find.bySemanticsLabel('Home'), findsNothing);
    expect(t.getRect(_field()).bottom, lessThanOrEqualTo(800 - 300));
    semantics.dispose();
    await h.dispose(t);
  });

  testWidgets('keyboard up: Tab never lands on the hidden tabs', (t) async {
    final h = await _shell(t);
    await t.tap(_tab('Cerca'));
    await _settle(t);
    await _keyboard(t, 300);
    for (var i = 0; i < 6; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      final focus = FocusManager.instance.primaryFocus?.context;
      expect(focus?.findAncestorWidgetOfExactType<DockLayers>(), isNull);
    }
    await h.dispose(t);
  });

  testWidgets('keyboard down: the dock has no text field, mini player above the tabs; Cerca has the dot',
      (t) async {
    final h = await _shell(t);
    await t.tap(_tab('Cerca'));
    await _settle(t);
    await _keyboard(t, 300);
    await _keyboard(t, 0);
    expect(find.descendant(of: find.byType(ShellDock), matching: find.byType(TextField)), findsNothing);
    final player = t.getRect(find.byType(MiniPlayer));
    final tabs = t.getRect(_tab('Home'));
    expect(player.bottom, lessThanOrEqualTo(tabs.top));
    final dot = t.getCenter(find.byKey(const ValueKey('tab-dot'))).dx;
    double away(String tab) => (t.getCenter(_tab(tab)).dx - dot).abs();
    expect(away('Cerca'), lessThan(away('Home')));
    expect(away('Cerca'), lessThan(away('Libreria')));
    await h.dispose(t);
  });

  testWidgets('the bar is there from the start and stays while the grid scrolls', (t) async {
    final h = await _shell(t);
    await t.tap(_tab('Cerca'));
    await _settle(t);
    final before = t.getTopLeft(_field());
    await t.drag(find.byKey(const ValueKey('genre-pop')), const Offset(0, -400));
    await _settle(t);
    expect(t.getTopLeft(_field()), before);
    await h.dispose(t);
  });

  testWidgets('the dock button opens Search and focuses the field, again on a second tap',
      (t) async {
    final h = await _shell(t);
    final c = _container(t);
    expect(c.read(searchFocusProvider).hasFocus, isFalse);
    await t.tap(_tab('Cerca'));
    await _settle(t);
    expect(c.read(navIndexProvider), NavTab.search.index);
    expect(c.read(searchFocusProvider).hasFocus, isTrue);
    expect(t.testTextInput.isVisible, isTrue);
    c.read(searchFocusProvider).unfocus();
    await _settle(t);
    await t.tap(_tab('Cerca'));
    await _settle(t);
    expect(c.read(searchFocusProvider).hasFocus, isTrue);
    await h.dispose(t);
  });

  testWidgets('Back with the keyboard up only hides it', (t) async {
    final h = await _shell(t);
    final c = _container(t);
    await t.tap(_tab('Cerca'));
    await _settle(t);
    await _keyboard(t, 300);
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(c.read(navIndexProvider), NavTab.search.index);
    expect(c.read(searchFocusProvider).hasFocus, isFalse);
    await h.dispose(t);
  });

  testWidgets('the keyboard moving rebuilds neither the dock nor the mini player',
      (t) async {
    final h = await _shell(t);
    await t.tap(_tab('Cerca'));
    await _settle(t);
    var docks = 0, players = 0, frames = 0;
    debugOnRebuildDirtyWidget = (e, _) {
      if (e.widget.runtimeType.toString() == '_DockFrame') frames++;
      if (e.widget is ShellDock) docks++;
      if (e.widget is MiniPlayer) players++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    for (var i = 1; i <= 10; i++) {
      t.view.viewInsets = FakeViewPadding(bottom: 30.0 * i);
      await t.pump(const Duration(milliseconds: 16));
    }
    debugOnRebuildDirtyWidget = null;
    expect(frames, greaterThan(0), reason: 'the probe sees the frame follow');
    expect(docks, lessThanOrEqualTo(1));
    expect(players, lessThanOrEqualTo(1));
    await h.dispose(t);
  });
}
