import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/activity_providers.dart';
import 'package:codecore/providers/memory_providers.dart';
import 'package:codecore/providers/nav_providers.dart';
import 'package:codecore/providers/ui_providers.dart';
import 'package:codecore/providers/user_activity_provider.dart';
import 'package:codecore/services/memory/app_data.dart';
import 'package:codecore/ui/screens/home/home_screen.dart';
import 'package:codecore/ui/screens/library/album_detail_screen.dart';
import 'package:codecore/ui/widgets/cc_sheet.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_screen.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/shell/bottom_bar.dart';
import 'package:codecore/ui/shell/desktop_player_bar.dart';
import 'package:codecore/ui/shell/desktop_sidebar.dart';
import 'package:codecore/ui/shell/side_panel.dart';
import 'package:codecore/ui/widgets/mini_player.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:codecore/ui/widgets/quality_tag.dart';
import 'package:codecore/ui/widgets/ring_progress.dart';
import 'package:codecore/ui/widgets/speed_button.dart';
import 'package:codecore/ui/widgets/selection_bar.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300)); // dock switch: 450 ms
}

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(AppShell)));

Finder _dockField() => find.descendant(
    of: find.byType(ShellDock), matching: find.byType(TextField));

// Hit-testable: while searching, hidden tabs hold the dock's height.
Finder _bar(String label) => find
    .descendant(of: find.byType(ShellDock), matching: find.text(label))
    .hitTestable();

Future<void> _openTabSheet(WidgetTester t) async {
  showCcSheet<void>(
    context: t.element(find.byType(HomeScreen)),
    builder: (_) => const ListTile(autofocus: true, title: Text('TAB SHEET')),
  );
  await t.pump(const Duration(milliseconds: 400));
  expect(find.text('TAB SHEET'), findsOneWidget);
}

void main() {
  testWidgets('Esc closes a sheet opened inside a tab', (t) async {
    _phone(t);
    final h = await Harness.create(t);
    await h.pump(t, const AppShell());
    await _openTabSheet(t);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('TAB SHEET'), findsNothing);
    await h.dispose(t);
  });

  testWidgets('wide: a tab sheet blocks the queue panel behind it', (t) async {
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t, tracks: 3);
    final rows = await t.runAsync(() => h.db.select(h.db.tracks).get());
    await t.runAsync(() => h.handler.playQueue([for (final r in rows!) r.id], 0));
    await h.pump(t, const AppShell());
    await _settle(t);
    await _openTabSheet(t);
    final row = find.descendant(
      of: find.byType(SidePanelView),
      matching: find.byType(TrackRow),
    );
    await t.tapAt(t.getCenter(row.last), buttons: kSecondaryButton);
    await t.pump(const Duration(milliseconds: 400));
    // The barrier eats the click: at most the tab sheet, never a second one.
    expect(find.byType(BottomSheet).evaluate().length, lessThan(2));
    await h.dispose(t);
  });

  testWidgets('a spinner in a hidden tab does not tick; in the shown tab it does',
      (t) async {
    _phone(t);
    final h = await Harness.create(t, tracks: 2);
    await h.pump(t, const AppShell(), extraOverrides: [
      activityProvider.overrideWithValue(const ActivityState([
        ActivityItem(kind: ActivityKind.scan, key: 'scan', name: null),
      ], [])),
    ]);
    await _settle(t);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));
    await t.tap(_bar('Memoria'));
    await _settle(t);
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
    await t.tap(_bar('Home'));
    await _settle(t);
    expect(SchedulerBinding.instance.transientCallbackCount, greaterThan(0));
    await h.dispose(t);
  });

  testWidgets('no track: dock holds only the tabs', (t) async {
    _phone(t);
    final h = await Harness.create(t, tracks: 2);
    await h.pump(t, const AppShell());
    await _settle(t);
    expect(find.byType(ShellDock), findsOneWidget);
    expect(find.byType(MiniPlayer), findsNothing);
    expect(_bar('Home'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('no track: the dot stays inside the dock mid-hop', (t) async {
    _phone(t);
    final h = await Harness.create(t, tracks: 2);
    await h.pump(t, const AppShell());
    await _settle(t);
    await t.tap(_bar('Libreria'));
    await t.pump();
    await t.pump(CcMotion.page ~/ 2);
    final dock = t.getRect(find.descendant(
        of: find.byType(ShellDock), matching: find.byType(Material)).first);
    final dot = t.getRect(find.byKey(const ValueKey('tab-dot')));
    expect(dot.top, greaterThanOrEqualTo(dock.top));
    await t.pump(CcMotion.page);
    await h.dispose(t);
  });

  testWidgets('reduced motion: the dot is at its tab after one frame',
      (t) async {
    _phone(t);
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = await Harness.create(t, tracks: 2);
    await h.pump(t, const AppShell());
    await _settle(t);
    await t.tap(_bar('Libreria'));
    await t.pump();
    final icon = find.descendant(
        of: find.ancestor(of: _bar('Libreria'), matching: find.byType(InkWell)),
        matching: find.byType(Icon));
    final dot = t.getCenter(find.byKey(const ValueKey('tab-dot')));
    expect((dot - t.getTopRight(icon)).distance, lessThan(16));
    await h.dispose(t);
  });

  testWidgets('the selected tab is marked by the dot and in semantics',
      (t) async {
    _phone(t);
    final h = await Harness.create(t, tracks: 2);
    await h.pump(t, const AppShell());
    await t.tap(_bar('Libreria'));
    await _settle(t);
    await t.pump(CcMotion.page); // the hop is still on its way after _settle
    final tab = find.ancestor(of: _bar('Libreria'), matching: find.byType(InkWell));
    expect(
      t.getSemantics(tab.first),
      isSemantics(
          label: 'Libreria\nLibreria', isSelected: true, isButton: true),
    );
    final corner = t.getTopRight(
        find.descendant(of: tab, matching: find.byType(Icon)));
    final dot = t.getCenter(find.byKey(const ValueKey('tab-dot')));
    expect((dot - corner).distance, lessThan(16));
    await h.dispose(t);
  });

  testWidgets('narrow: four labelled tabs, home first', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester);
    await h.pump(tester, const AppShell());
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Cerca'), findsWidgets);
    expect(find.text('Libreria'), findsWidgets);
    expect(find.text('Memoria'), findsWidgets);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    await h.dispose(tester);
  });

  final memoryOverrides = [
    appDataUsageProvider.overrideWith(
      (_) async => [const AppDataItem(AppDataKind.covers, 2 * 1024 * 1024, detailBytes: 512)],
    ),
    musicDiskSpaceProvider.overrideWith((_) async => null),
  ];

  testWidgets('Memoria tab opens the storage page', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 3);
    await h.pump(tester, const AppShell(), extraOverrides: memoryOverrides);
    // Nothing is measured until the tab is shown.
    expect(find.text('Formati'), findsNothing);
    await tester.tap(find.text('Memoria'));
    await _settle(tester);
    expect(find.text('Formati'), findsOneWidget);
    expect(find.text('3 B'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Copertine'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Copertine'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('sidebar has a Memoria entry that opens the same page', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await h.pump(tester, const AppShell(), extraOverrides: memoryOverrides);
    await tester.tap(find.descendant(
        of: find.byType(DesktopSidebar), matching: find.text('Memoria')));
    await _settle(tester);
    expect(find.text('Formati'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('library tab: empty state with add folder', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester);
    await h.pump(tester, const AppShell());
    await tester.tap(find.text('Libreria'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Aggiungi la tua cartella musicale'), findsWidgets);
    await h.dispose(tester);
  });

  testWidgets('wide: sidebar and player bar, no rail, no mini-player',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 2);
    final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
    await tester.runAsync(() => h.handler.playQueue([rows!.first.id], 0));
    await h.pump(tester, const AppShell());
    await _settle(tester);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(MiniPlayer), findsNothing);
    expect(find.byType(DesktopSidebar), findsOneWidget);
    expect(find.byType(DesktopPlayerBar), findsOneWidget);
    expect(find.text('La tua libreria'), findsOneWidget);
    expect(find.text('Preferiti'), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(DesktopPlayerBar),
        matching: find.byType(RingProgress),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('sidebar-dot')), findsOneWidget);
    // From 1200 px the queue opens by itself in the right-hand panel; its
    // button closes it and opens it again.
    expect(find.byType(SidePanelView), findsOneWidget);
    await tester.tap(find.byIcon(Icons.queue_music_rounded).last);
    await _settle(tester);
    expect(find.byType(SidePanelView), findsNothing);
    await tester.tap(find.byIcon(Icons.queue_music_rounded).last);
    await _settle(tester);
    expect(find.byType(SidePanelView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('opening an album keeps mini-player and bar; back closes it',
      (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, const AppShell());
    await tester.tap(find.text('Libreria'));
    await _settle(tester);
    await tester.tap(find.text('Tutti i brani'));
    await _settle(tester);
    await tester.tap(find.text('Song 0').first);
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await _settle(tester);
    // Library lists the albums directly: open the first one.
    await tester.tap(find.text('Album 0').first);
    await _settle(tester);
    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(find.text('Libreria'), findsWidgets); // bottom bar still there
    // Android back: the album page goes first, back on the Library.
    await tester.binding.handlePopRoute();
    await _settle(tester);
    await _settle(tester);
    expect(find.byType(AlbumDetailScreen), findsNothing);
    expect(find.text('Album 0'), findsWidgets);
    await h.dispose(tester);
  });

  testWidgets(
      'tracks listed in Library; tap plays and shows the mini-player: '
      'favourite, devices sheet, no nearby devices', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 3);
    await h.pump(tester, const AppShell());
    await tester.tap(find.text('Libreria'));
    await _settle(tester);
    await tester.tap(find.text('Tutti i brani'));
    await _settle(tester);
    expect(find.text('Song 0'), findsWidgets);
    await tester.tap(find.text('Song 1').first);
    await _settle(tester);
    expect(h.handler.currentTrack?.title, 'Song 1');
    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsWidgets);
    expect(find.byIcon(Icons.devices_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.devices_rounded));
    await _settle(tester);
    expect(find.text('Dispositivi'), findsWidgets);
    expect(find.text('Rendi visibile questo dispositivo'), findsOneWidget);
    expect(find.text('Collegamento manuale (IP e PIN)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('Enter on the focused mini player opens the player', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 2);
    final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
    await tester.runAsync(() => h.handler.playQueue([rows!.first.id], 0));
    await h.pump(tester, const AppShell());
    await _settle(tester);
    // The InkWell's own Focus sits right above its MouseRegion.
    final probe = find.descendant(
        of: find.descendant(of: find.byType(MiniPlayer), matching: find.byType(InkWell)),
        matching: find.byType(MouseRegion));
    Focus.of(tester.element(probe.first)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('system back in selection mode ends the selection and keeps the page',
      (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 3);
    await h.pump(tester, const AppShell());
    await tester.tap(find.text('Libreria'));
    await _settle(tester);
    await tester.tap(find.text('Tutti i brani'));
    await _settle(tester);
    await tester.longPress(find.text('Song 0').first);
    await _settle(tester);
    expect(find.byType(SelectionBar), findsOneWidget);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byType(SelectionBar), findsNothing);
    expect(find.byType(AllTracksScreen), findsOneWidget); // still on the page
    // A second back leaves the page.
    await tester.binding.handlePopRoute();
    await _settle(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(AllTracksScreen), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('the mini-player label is title and artist, with no progress value', (tester) async {
    _phone(tester);
    final handle = tester.ensureSemantics();
    final h = await Harness.create(tester, tracks: 3);
    await h.pump(tester, const AppShell());
    await tester.tap(find.text('Libreria'));
    await _settle(tester);
    await tester.tap(find.text('Tutti i brani'));
    await _settle(tester);
    await tester.tap(find.text('Song 1').first);
    await _settle(tester);
    h.backend.posC.add(const Duration(seconds: 30));
    h.backend.durC.add(const Duration(seconds: 60));
    await _settle(tester);
    final node = tester.getSemantics(
        find.descendant(of: find.byType(MiniPlayer), matching: find.text('Song 1')));
    expect(node.label, contains('Song 1')); // prefixed by «In riproduzione» (40)
    expect(node.value, isEmpty, reason: 'the progress bar value would lead the spoken label');
    handle.dispose();
    await h.dispose(tester);
  });

  testWidgets('Ctrl+F goes to the Search tab', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await h.pump(tester, const AppShell());
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    expect(container.read(navIndexProvider), NavTab.search.index);
    expect(container.read(searchFocusProvider).hasFocus, isTrue);
    await h.dispose(tester);
  });

  test('without YouTube Ctrl+F always targets the Library', () {
    expect(ctrlFTargetsLibrary(youtube: false, tab: NavTab.home.index), isTrue);
    expect(ctrlFTargetsLibrary(youtube: true, tab: NavTab.home.index), isFalse);
    expect(ctrlFTargetsLibrary(youtube: true, tab: NavTab.library.index), isTrue);
  });

  testWidgets('Ctrl+F on the Library opens its own focused search', (t) async {
    t.view.physicalSize = const Size(1200, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t);
    await h.pump(t, const AppShell());
    _container(t).read(navIndexProvider.notifier).set(NavTab.library.index);
    await _settle(t);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyF);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(t);
    expect(_container(t).read(navIndexProvider), NavTab.library.index);
    expect(find.byKey(const ValueKey('library-search-bar')), findsOneWidget);
    expect(_container(t).read(searchFocusProvider).hasFocus, isFalse);
    await h.dispose(t);
  });

  testWidgets('Alt+Left goes back from a page opened in the tab', (t) async {
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t, tracks: 4);
    await h.pump(t, const AppShell());
    await t.tap(find.text('La tua libreria'));
    await _settle(t);
    await t.tap(find.text('Tutti i brani'));
    await _settle(t);
    expect(find.byType(AllTracksScreen), findsOneWidget);
    await t.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await _settle(t);
    expect(find.byType(AllTracksScreen), findsNothing);
    await h.dispose(t);
  });

  testWidgets('Ctrl+F in a narrow window opens the dock field with focus',
      (t) async {
    _phone(t);
    final h = await Harness.create(t, tracks: 2);
    await h.pump(t, const AppShell());
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyF);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(t);
    expect(_dockField(), findsOneWidget);
    expect(_container(t).read(searchFocusProvider).hasFocus, isTrue);
    await h.dispose(t);
  });

  testWidgets('leaving Search by another route closes the dock field',
      (t) async {
    _phone(t);
    final h = await Harness.create(t, tracks: 2);
    await h.pump(t, const AppShell());
    await t.tap(_bar('Cerca'));
    await _settle(t);
    _container(t).read(navIndexProvider.notifier).set(NavTab.library.index);
    await _settle(t);
    expect(_container(t).read(searchBarProvider), isFalse);
    expect(_bar('Home'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('reopening Cerca during the fade-out does not throw', (t) async {
    _phone(t);
    final h = await Harness.create(t, tracks: 2);
    await h.pump(t, const AppShell());
    await t.tap(_bar('Cerca'));
    await _settle(t);
    await t.binding.handlePopRoute();
    await t.pump(const Duration(milliseconds: 100));
    // The fading field's hint is also «Cerca»: take the tab label.
    await t.tap(_bar('Cerca').last);
    await _settle(t);
    expect(t.takeException(), isNull);
    expect(_dockField(), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('sidebar «La tua libreria» closes a page left open in that tab',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await h.pump(tester, const AppShell());
    await tester.tap(find.text('La tua libreria'));
    await _settle(tester);
    await tester.tap(find.descendant(
        of: find.byType(DesktopSidebar), matching: find.text('Preferiti')));
    await _settle(tester);
    expect(find.text('Nessun preferito, per ora'), findsOneWidget);
    await tester.tap(find.text('Home').first);
    await _settle(tester);
    await tester.tap(find.text('La tua libreria'));
    await _settle(tester);
    await _settle(tester);
    await _settle(tester);
    expect(find.text('Nessun preferito, per ora'), findsNothing);
    expect(find.text('Aggiungi la tua cartella musicale'), findsWidgets);
    await h.dispose(tester);
  });

  testWidgets('phone: leaving a tab and coming back restores its open page',
      (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, const AppShell());
    await tester.tap(_bar('Libreria'));
    await _settle(tester);
    await tester.tap(find.text('Tutti i brani'));
    await _settle(tester);
    expect(find.byType(AllTracksScreen), findsOneWidget);
    await tester.tap(_bar('Home'));
    await _settle(tester);
    await tester.tap(_bar('Libreria'));
    await _settle(tester);
    expect(find.byType(AllTracksScreen), findsOneWidget);
    // Tapping the already-selected tab goes back to its root.
    await tester.tap(_bar('Libreria'));
    await _settle(tester);
    await _settle(tester);
    expect(find.byType(AllTracksScreen), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('phone: leaving a tab and coming back keeps its scroll offset',
      (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 40);
    await h.pump(tester, const AppShell());
    await tester.tap(_bar('Libreria'));
    await _settle(tester);
    await tester.tap(find.text('Tutti i brani'));
    await _settle(tester);
    final list = find.descendant(
        of: find.byType(AllTracksScreen),
        matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axis == Axis.vertical));
    await _settle(tester);
    await _settle(tester);
    tester.state<ScrollableState>(list.first).position.jumpTo(600);
    await tester.pump();
    double offset() => tester.state<ScrollableState>(list.first).position.pixels;
    final before = offset();
    expect(before, greaterThan(0));
    await tester.tap(_bar('Home'));
    await _settle(tester);
    await tester.tap(_bar('Libreria'));
    await _settle(tester);
    expect(offset(), before);
    await h.dispose(tester);
  });

  testWidgets('phone: a root page keeps its scroll offset across tab switches',
      (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 40);
    // Enough albums for the Library list to scroll past one screen.
    for (var i = 0; i < 30; i++) {
      await h.db.into(h.db.tracks).insert(TracksCompanion.insert(
            path: '/m/x$i.mp3',
            title: 'Extra $i',
            albumKey: 'other|album $i',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 100 + i,
            artist: const Value('Other'),
            album: Value('Extra album $i'),
          ));
    }
    await h.pump(tester, const AppShell());
    await tester.tap(_bar('Libreria'));
    await _settle(tester);
    final list = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axis == Axis.vertical);
    await tester.drag(list.first, const Offset(0, -500));
    await _settle(tester);
    double offset() => tester.state<ScrollableState>(list.first).position.pixels;
    final before = offset();
    expect(before, greaterThan(0));
    await tester.tap(_bar('Cerca'));
    await _settle(tester);
    await tester.binding.handlePopRoute(); // closes the field, tabs return
    await _settle(tester);
    await tester.tap(_bar('Memoria'));
    await _settle(tester);
    await tester.tap(_bar('Libreria'));
    await _settle(tester);
    expect(offset(), before);
    await h.dispose(tester);
  });

  testWidgets('phone: the Search tab keeps its query across tab switches',
      (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, const AppShell());
    await tester.tap(_bar('Cerca'));
    await _settle(tester);
    await tester.enterText(_dockField(), 'Song 2');
    await _settle(tester);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    await tester.tap(_bar('Home'));
    await _settle(tester);
    await tester.tap(_bar('Cerca'));
    await _settle(tester);
    expect(tester.widget<TextField>(_dockField()).controller!.text, 'Song 2');
    await h.dispose(tester);
  });

  testWidgets('phone: the query survives closing the keyboard by hand and switching tab',
      (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, const AppShell());
    await tester.tap(_bar('Cerca'));
    await _settle(tester);
    await tester.enterText(_dockField(), 'Song 2');
    await _settle(tester);
    final c = _container(tester);
    c.read(searchFocusProvider).unfocus(); // keyboard dismissed, not Back
    await _settle(tester);
    // Phase 60: the field stays, the tabs are visible with the keyboard down.
    expect(c.read(searchBarProvider), isTrue);
    expect(_bar('Home'), findsOneWidget);
    c.read(navIndexProvider.notifier).set(NavTab.home.index);
    await _settle(tester);
    await tester.tap(_bar('Cerca'));
    await _settle(tester);
    expect(tester.widget<TextField>(_dockField()).controller!.text, 'Song 2');
    await h.dispose(tester);
  });

  testWidgets('✕ clears the text and stays on Search', (t) async {
    _phone(t);
    final h = await Harness.create(t, tracks: 2);
    await h.pump(t, const AppShell());
    await t.tap(_bar('Libreria'));
    await _settle(t);
    await t.tap(_bar('Cerca'));
    await _settle(t);
    await t.enterText(_dockField(), 'Song');
    await _settle(t);
    await t.tap(find.byTooltip('Cancella ricerca'));
    await _settle(t);
    final c = _container(t);
    expect(c.read(navIndexProvider), NavTab.search.index);
    expect(c.read(searchControllerProvider).text, isEmpty);
    expect(c.read(searchBarProvider), isTrue);
    expect(c.read(searchFocusProvider).hasFocus, isTrue); // keyboard stays
    expect(_dockField(), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('✕ is always there, inert while empty and unfocused', (t) async {
    _phone(t);
    final h = await Harness.create(t, tracks: 2);
    await h.pump(t, const AppShell());
    await t.tap(_bar('Cerca'));
    await _settle(t);
    final x = find.byTooltip('Cancella ricerca');
    final btn = find.ancestor(of: x, matching: find.byType(IconButton));
    expect(t.widget<IconButton>(btn).onPressed, isNull);
    await t.enterText(_dockField(), 'Song');
    await t.pump();
    await t.tap(x);
    await t.pump();
    expect(find.byTooltip('Chiudi tastiera'), findsOneWidget);
    expect(_container(t).read(searchControllerProvider).text, isEmpty);
    await h.dispose(t);
  });

  testWidgets('Back with the keyboard down leaves Search like the other tabs',
      (t) async {
    _phone(t);
    final h = await Harness.create(t, tracks: 4);
    await h.pump(t, const AppShell());
    await t.tap(_bar('Cerca'));
    await _settle(t);
    await t.enterText(_dockField(), 'Song 2');
    await _settle(t);
    await t.binding.handlePopRoute();
    await _settle(t);
    final c = _container(t);
    expect(c.read(navIndexProvider), NavTab.home.index);
    expect(c.read(searchBarProvider), isFalse);
    // Cerca again reopens the field with the kept text.
    await t.tap(_bar('Cerca'));
    await _settle(t);
    expect(c.read(searchControllerProvider).text, 'Song 2');
    await h.dispose(t);
  });

  testWidgets('a page opened from Search brings the tabs back', (t) async {
    _phone(t);
    final h = await Harness.create(t, tracks: 2);
    await h.pump(t, const AppShell());
    await t.tap(_bar('Cerca'));
    await _settle(t);
    final c = _container(t);
    c.read(tabNavigatorKeysProvider)[NavTab.search.index].currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('Pushed page')));
    await _settle(t);
    expect(c.read(searchBarProvider), isFalse);
    expect(_bar('Home'), findsOneWidget);
    // Back pops the page, Search stays.
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(find.text('Pushed page'), findsNothing);
    expect(c.read(navIndexProvider), NavTab.search.index);
    await h.dispose(t);
  });

  testWidgets('back from a page opened in Search: the field returns, no keyboard',
      (t) async {
    _phone(t);
    final h = await Harness.create(t, tracks: 2);
    await h.pump(t, const AppShell());
    await t.tap(_bar('Cerca'));
    await _settle(t);
    await t.enterText(_dockField(), 'Song');
    await _settle(t);
    final c = _container(t);
    c.read(tabNavigatorKeysProvider)[NavTab.search.index].currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('Pushed page')));
    await _settle(t);
    expect(_dockField(), findsNothing);
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(c.read(navIndexProvider), NavTab.search.index);
    expect(_dockField(), findsOneWidget);
    expect(c.read(searchControllerProvider).text, 'Song');
    expect(c.read(searchFocusProvider).hasFocus, isFalse);
    await h.dispose(t);
  });

  testWidgets('keyboard lifts only the search field', (t) async {
    _phone(t);
    final h = await Harness.create(t, tracks: 2);
    final rows = await t.runAsync(() => h.db.select(h.db.tracks).get());
    await t.runAsync(() => h.handler.playQueue([rows!.first.id], 0));
    await h.pump(t, const AppShell());
    await _settle(t);
    expect(find.byType(MiniPlayer), findsOneWidget);
    await t.tap(_bar('Cerca'));
    await _settle(t);
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    await _settle(t);
    expect(t.getRect(_dockField()).bottom, lessThanOrEqualTo(800 - 300));
    expect(find.byType(MiniPlayer), findsNothing);
    expect(_bar('Home'), findsNothing);
    await h.dispose(t);
  });

  testWidgets('sidebar: leaving a tab keeps the page open in it',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await h.pump(tester, const AppShell());
    await tester.tap(find.text('La tua libreria'));
    await _settle(tester);
    await tester.tap(find.descendant(
        of: find.byType(DesktopSidebar), matching: find.text('Preferiti')));
    await _settle(tester);
    expect(find.text('Nessun preferito, per ora'), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(DesktopSidebar), matching: find.text('Cerca')));
    await _settle(tester);
    // The Library navigator still holds the page: leaving a tab never pops it.
    final container =
        ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    final nav = container
        .read(tabNavigatorKeysProvider)[NavTab.library.index]
        .currentState!;
    expect(nav.canPop(), isTrue);
    await h.dispose(tester);
  });

  testWidgets('desktop bar: the seek slider is centred between its slots',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 2);
    final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
    await tester.runAsync(() => h.handler.playQueue([rows!.first.id], 0));
    await h.pump(tester, const AppShell());
    await _settle(tester);
    Finder inBar(Finder f) =>
        find.descendant(of: find.byType(DesktopPlayerBar), matching: f);
    final left = tester.getCenter(inBar(find.byType(QualityTag))).dx;
    final right = tester.getCenter(inBar(find.byType(SpeedButton))).dx;
    final slider = tester.getCenter(inBar(find.byType(Slider)).first).dx;
    expect(slider, closeTo((left + right) / 2, 1));
    await h.dispose(tester);
  });

  testWidgets('typing in the search touches the user activity', (t) async {
    _phone(t);
    final h = await Harness.create(t, tracks: 2);
    await h.pump(t, const AppShell());
    await t.tap(_bar('Cerca'));
    await _settle(t);
    final activity = _container(t).read(userActivityProvider);
    expect(activity.lastActivityAt, isNull);
    await t.enterText(_dockField(), 'abc');
    await t.pump();
    expect(activity.lastActivityAt, isNotNull);
    await h.dispose(t);
  });
}
