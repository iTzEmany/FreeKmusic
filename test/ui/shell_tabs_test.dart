import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/data/repositories/track_repository.dart' show SortOption;
import 'package:codecore/providers/nav_providers.dart';
import 'package:codecore/ui/theme/custom_theme.dart';
import 'package:codecore/ui/screens/settings/theme_editor_screen.dart';
import 'package:codecore/ui/screens/home/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/screens/library/library_screen.dart';
import 'package:codecore/ui/screens/memory/memory_screen.dart';
import 'package:codecore/ui/screens/search/search_screen.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/shell/bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

// Phase 89.4 (D-392): leaving a dock tab sends it back to its first state.
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
  testWidgets('a page pushed inside a tab is gone after another tab',
      (t) async {
    final h = await _open(t, tracks: 4);
    await t.tap(_bar('Libreria'));
    await _settle(t);
    await t.tap(find.text('Tutti i brani'));
    await _settle(t);
    expect(find.byType(AllTracksScreen), findsOneWidget);
    await _roundTrip(t, 'Libreria');
    expect(find.byType(AllTracksScreen), findsNothing);
    await h.dispose(t);
  });

  testWidgets('the selected Library block is back to Tutti after another tab', (t) async {
    final h = await _open(t, tracks: 4);
    await t.tap(_bar('Libreria'));
    await _settle(t);
    await t.tap(find.text('Album').first);
    await _settle(t);
    expect(find.text('2 album'), findsOneWidget);
    await _roundTrip(t, 'Libreria');
    expect(find.text('2 album'), findsNothing);
    await h.dispose(t);
  });

  testWidgets('only the tab you leave is reset', (t) async {
    final h = await _open(t, tracks: 4);
    final c = ProviderScope.containerOf(t.element(find.byType(AppShell)));
    NavigatorState nav(NavTab tab) =>
        c.read(tabNavigatorKeysProvider)[tab.index].currentState!;
    nav(NavTab.memory).push(
        MaterialPageRoute<void>(builder: (_) => const Text('Marker')));
    await t.tap(_bar('Libreria'));
    await _settle(t);
    await t.tap(find.text('Tutti i brani'));
    await _settle(t);
    await t.tap(_bar('Home')); // leaves Library only
    await _settle(t);
    expect(nav(NavTab.library).canPop(), isFalse);
    expect(nav(NavTab.memory).canPop(), isTrue);
    await h.dispose(t);
  });

  testWidgets('selecting the active tab still pops to its root', (t) async {
    final h = await _open(t, tracks: 4);
    await t.tap(_bar('Libreria'));
    await _settle(t);
    await t.tap(find.text('Tutti i brani'));
    await _settle(t);
    await t.tap(_bar('Libreria'));
    await _settle(t);
    expect(find.byType(AllTracksScreen), findsNothing);
    await h.dispose(t);
  });

  testWidgets('a dirty theme editor survives a tab switch', (t) async {
    final h = await _open(t, tracks: 4);
    final c = ProviderScope.containerOf(t.element(find.byType(AppShell)));
    c.read(tabNavigatorKeysProvider)[NavTab.home.index].currentState!.push(
        MaterialPageRoute<void>(
            builder: (_) => const ThemeEditorScreen(
                initial: CustomTheme(id: 'sea', name: 'Mare'))));
    await _settle(t);
    await t.enterText(find.byType(TextField).first, 'Mare edit');
    await t.pump();
    await t.tap(_bar('Libreria'));
    await _settle(t);
    await t.tap(_bar('Home'));
    await _settle(t);
    expect(find.byType(ThemeEditorScreen), findsOneWidget);
    expect(find.text('Mare edit'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('leaving Library keeps the Favorites sort, resets All tracks',
      (t) async {
    final h = await _open(t, tracks: 4);
    final c = ProviderScope.containerOf(t.element(find.byType(AppShell)));
    for (final fav in [true, false]) {
      c.read(trackQueryProvider(fav).notifier)
          .update((q) => q.copyWith(sort: SortOption.title));
    }
    await t.tap(_bar('Libreria'));
    await _settle(t);
    await t.tap(_bar('Home'));
    await _settle(t);
    expect(c.read(trackQueryProvider(true)).sort, SortOption.title);
    expect(c.read(trackQueryProvider(false)).sort, SortOption.defaultOrder);
    await h.dispose(t);
  });

  // Pinned because 89.4 rebuilds the shell: hidden tabs must not tick.
  testWidgets('only the shown tab has its tickers on', (t) async {
    final h = await _open(t, tracks: 4);
    bool ticking(Type page) => TickerMode.valuesOf(
        t.element(find.byType(page, skipOffstage: false))).enabled;
    expect(ticking(HomeScreen), isTrue);
    for (final p in [SearchScreen, LibraryScreen, MemoryScreen]) {
      expect(ticking(p), isFalse, reason: '$p hidden');
    }
    await t.tap(_bar('Libreria'));
    await _settle(t);
    expect(ticking(LibraryScreen), isTrue);
    expect(ticking(HomeScreen), isFalse);
    await h.dispose(t);
  });
}
