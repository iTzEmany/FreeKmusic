import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/data/repositories/library_entries.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/ui/screens/library/library_screen.dart';
import 'package:codecore/ui/screens/library/library_results.dart' show LibraryResults;
import 'package:codecore/ui/screens/library/library_shortcuts.dart';
import 'package:codecore/ui/screens/library/library_island.dart';
import 'package:codecore/ui/screens/library/library_toolbar.dart';
import 'package:codecore/providers/ui_providers.dart' show librarySearchRequestProvider;
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/settings_providers.dart' show settingsProvider;
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/widgets/cc_search_field.dart';
import 'package:codecore/ui/widgets/skeleton.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:codecore/ui/widgets/segmented_blocks.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';

import 'package:codecore/providers/selection_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../support/app_harness.dart';
import '../support/search_input.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('the sort button label is not truncated at 360 dp, for every criterion and language',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    for (final locale in AppLocalizations.supportedLocales) {
      for (final s in LibrarySort.values) {
        await h.pump(
          tester,
          Scaffold(
            body: LibraryToolbar(
              countLabel: '2.120 elementi',
              sort: s,
              ascending: false,
              grid: false,
              onSort: (_, _) {},
              onToggleGrid: () {},
            ),
          ),
          locale: locale,
        );
        expect(tester.takeException(), isNull, reason: '$locale/$s');
        final label = find.descendant(of: find.byType(InkWell), matching: find.byType(Text));
        final p = tester.renderObject<RenderParagraph>(label);
        expect(p.didExceedMaxLines, isFalse, reason: '$locale/$s');
      }
    }
    await h.dispose(tester);
  });

  Future<Harness> open(
    WidgetTester tester, {
    double width = 400,
    int tracks = 4,
  }) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: tracks);
    if (width >= 840) {
      await h.pump(tester, const LibraryScreen());
    } else {
      await h.pump(tester, const AppShell());
      await tester.tap(find.text('Libreria'));
    }
    await _settle(tester);
    return h;
  }

  testWidgets('blocks filter the list and the count follows', (t) async {
    final h = await open(t);
    expect(find.text('Tutto'), findsOneWidget);
    expect(find.text('Album 0'), findsOneWidget);
    await t.tap(find.text('Album').first);
    await _settle(t);
    expect(find.text('2 album'), findsOneWidget);
    expect(find.text('Artist'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    await t.tap(find.text('Tutto'));
    await _settle(t);
    expect(find.text('Album 0'), findsOneWidget);
    await t.tap(find.byIcon(Icons.grid_view_rounded));
    await _settle(t);
    expect(find.text('Album 0'), findsOneWidget);
    expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);
    expect(t.takeException(), isNull);
    await h.dispose(t);
  });

  testWidgets('first load shows skeleton rows, not a spinner', (t) async {
    final h = await open(t);
    await t.pumpWidget(const SizedBox());
    await h.pump(
      t,
      const LibraryScreen(),
      extraOverrides: [
        playlistsProvider.overrideWith(
          (_) => Completer<List<PlaylistSummary>>().future.asStream(),
        ),
      ],
    );
    expect(find.byType(Skeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await h.dispose(t);
  });

  testWidgets('the lens opens a focused search with grouped results; Back closes it', (t) async {
    final sem = t.ensureSemantics();
    final h = await open(t, width: 900);
    expect(find.bySemanticsLabel(RegExp('^Ordina per')), findsOneWidget);
    final tabs = t.getTopLeft(find.byType(SegmentedBlocks<LibraryKind?>));
    await t.tap(find.byIcon(Icons.search_rounded));
    await _settle(t);
    expect(find.byType(CcSearchField), findsOneWidget);
    expect(t.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, isTrue);
    // The field sits in the title row, where the title was; nothing else of it answers.
    expect(find.text('Libreria').hitTestable(), findsNothing);
    expect(find.bySemanticsLabel('Libreria'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Cerca, disattivato|disabled')), findsNothing);
    expect(t.getRect(find.byType(TextField)).bottom, lessThanOrEqualTo(tabs.dy));
    // The sort row is closed, the tabs stay where they were and answer.
    expect(find.text('Recenti').hitTestable(), findsNothing);
    expect(
      find.ancestor(
        of: find.byType(LibraryToolbar),
        matching: find.byWidgetPredicate((w) => w is ExcludeSemantics && w.excluding),
      ),
      findsOneWidget,
    );
    expect(t.getTopLeft(find.byType(SegmentedBlocks<LibraryKind?>)), tabs);
    expect(find.text('Playlist').hitTestable(), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Song');
    await t.pump(const Duration(milliseconds: 300));
    await indexReady(t);
    await _settle(t);
    expect(find.text('Brani'), findsOneWidget);
    expect(find.text('Song 0'), findsOneWidget);
    // The results start under the island, not behind it.
    expect(
      t.getTopLeft(find.text('Brani')).dy,
      greaterThanOrEqualTo(t.getRect(find.byType(LibraryIsland)).bottom),
    );
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(find.byType(CcSearchField), findsNothing);
    expect(find.text('Libreria').hitTestable(), findsOneWidget);
    expect(find.text('Recenti').hitTestable(), findsOneWidget);
    sem.dispose();
    await h.dispose(t);
  });

  testWidgets('a tab filters the search results, and the tabs stay while searching', (t) async {
    final h = await open(t, width: 900);
    await t.tap(find.byIcon(Icons.search_rounded));
    await _settle(t);
    await t.enterText(find.byType(TextField), 'Album');
    await t.pump(const Duration(milliseconds: 300));
    await indexReady(t);
    await _settle(t);
    Finder inResults(String s) =>
        find.descendant(of: find.byType(LibraryResults), matching: find.text(s));
    expect(inResults('Brani'), findsOneWidget);
    await t.tap(find.descendant(of: find.byType(SegmentedBlocks<LibraryKind?>), matching: find.text('Album')));
    await _settle(t);
    expect(inResults('Brani'), findsNothing);
    expect(inResults('Song 0'), findsNothing);
    expect(inResults('Album 0'), findsOneWidget);
    await t.tap(find.text('Artisti'));
    await _settle(t);
    expect(inResults('Album 0'), findsNothing);
    await t.tap(find.text('Tutto'));
    await _settle(t);
    expect(inResults('Brani'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('Ctrl+F opens the search focused', (t) async {
    final h = await open(t, width: 900);
    ProviderScope.containerOf(
      t.element(find.byType(LibraryScreen)),
    ).read(librarySearchRequestProvider.notifier).request();
    await _settle(t);
    expect(find.byType(CcSearchField), findsOneWidget);
    expect(t.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, isTrue);
    await h.dispose(t);
  });

  testWidgets('Back first clears a selection in the results, then closes', (t) async {
    final h = await open(t, width: 900);
    await t.tap(find.byIcon(Icons.search_rounded));
    await _settle(t);
    await t.enterText(find.byType(TextField), 'Song');
    await t.pump(const Duration(milliseconds: 300));
    await indexReady(t);
    await _settle(t);
    final c = ProviderScope.containerOf(t.element(find.byType(LibraryScreen)));
    final key = SelectionKey.search.key;
    c.listen(selectionProvider(key), (_, _) {});
    c.read(selectionProvider(key).notifier).toggle(1);
    await t.pump();
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(c.read(selectionProvider(key)).active, isFalse);
    expect(find.byType(CcSearchField), findsOneWidget);
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(find.byType(CcSearchField), findsNothing);
    await h.dispose(t);
  });

  Future<void> manyPlaylists(Harness h, WidgetTester t) async {
    final repo = PlaylistRepository(h.db);
    for (var i = 0; i < 15; i++) {
      await repo.create('Playlist ${i.toString().padLeft(2, '0')}');
    }
  }

  double offset(WidgetTester t) =>
      t.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

  // Drags in the lower part of the list, away from the island.
  Future<void> scrollBy(WidgetTester t, double dy) async {
    await t.dragFrom(const Offset(450, 560), Offset(0, -dy));
    await _settle(t);
  }

  testWidgets('opening and closing the search keeps the scroll', (t) async {
    final h = await open(t, width: 900);
    await manyPlaylists(h, t);
    t.view.physicalSize = const Size(900, 600);
    await _settle(t);
    await scrollBy(t, 150);
    final before = offset(t);
    expect(before, greaterThan(0));
    // The title row is out: the lens (and the field) come back with the search.
    ProviderScope.containerOf(
      t.element(find.byType(LibraryScreen)),
    ).read(librarySearchRequestProvider.notifier).request();
    await _settle(t);
    expect(find.byType(CcSearchField).hitTestable(), findsOneWidget);
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(offset(t), before);
    await h.dispose(t);
  });

  testWidgets('the island gives up the title, then the sort row, 1:1 with the scroll; the tabs stay', (t) async {
    final h = await open(t, width: 900);
    await manyPlaylists(h, t);
    t.view.physicalSize = const Size(900, 600);
    await _settle(t);
    final island = find.byType(LibraryIsland);
    final tabs = find.byType(SegmentedBlocks<LibraryKind?>);
    final full = t.getRect(island).height;
    final tabsTop = t.getTopLeft(tabs).dy;
    expect(find.text('Libreria').hitTestable(), findsOneWidget);
    expect(find.text('Recenti').hitTestable(), findsOneWidget);

    await scrollBy(t, 60);
    final s1 = offset(t);
    expect(s1, inInclusiveRange(32, 56));
    // Title first: the tabs rise by the scroll, the sort row has not started.
    expect(tabsTop - t.getTopLeft(tabs).dy, closeTo(s1, 0.5));
    expect(full - t.getRect(island).height, closeTo(s1, 0.5));
    expect(find.text('Libreria').hitTestable(), findsNothing);
    expect(find.text('Recenti').hitTestable(), findsOneWidget);

    await scrollBy(t, 300);
    // Both gone, the tabs 56 up and still on screen and tappable.
    expect(full - t.getRect(island).height, closeTo(104, 0.5));
    expect(tabsTop - t.getTopLeft(tabs).dy, closeTo(56, 0.5));
    expect(find.text('Recenti').hitTestable(), findsNothing);
    expect(find.text('Playlist').hitTestable(), findsOneWidget);

    // Back up by a little: the sort row returns first, the title waits.
    await scrollBy(t, -70);
    expect(full - t.getRect(island).height, inInclusiveRange(28, 56));
    expect(find.text('Recenti').hitTestable(), findsOneWidget);
    expect(find.text('Libreria').hitTestable(), findsNothing);

    await scrollBy(t, -2000);
    expect(offset(t), 0);
    expect(t.getRect(island).height, closeTo(full, 0.5));
    expect(find.text('Libreria').hitTestable(), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('a fling still running when the search opens does not retract the field', (t) async {
    final h = await open(t, width: 900);
    await manyPlaylists(h, t);
    t.view.physicalSize = const Size(900, 600);
    await _settle(t);
    await t.fling(find.byType(Scrollable).first, const Offset(0, -400), 3000);
    await t.pump(const Duration(milliseconds: 50));
    ProviderScope.containerOf(
      t.element(find.byType(LibraryScreen)),
    ).read(librarySearchRequestProvider.notifier).request();
    await _settle(t);
    final isl = t.getRect(find.byType(LibraryIsland));
    final field = t.getRect(find.byType(TextField));
    expect(field.top, greaterThanOrEqualTo(isl.top));
    expect(field.height, greaterThan(40));
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    expect(t.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, isTrue);
    await h.dispose(t);
  });

  testWidgets('a tab shows every match of its kind and keeps hidden tracks out of the selection', (t) async {
    final h = await open(t, width: 900, tracks: 4);
    await manyPlaylists(h, t);
    await t.tap(find.byIcon(Icons.search_rounded));
    await _settle(t);
    await t.enterText(find.byType(TextField), 'Playlist');
    await t.pump(const Duration(milliseconds: 300));
    await indexReady(t);
    await _settle(t);
    await t.tap(find.descendant(of: find.byType(SegmentedBlocks<LibraryKind?>), matching: find.text('Playlist')));
    await _settle(t);
    // 15 playlists, no «Mostra tutti»: the preview would stop at 12.
    final results = find.byType(LibraryResults);
    expect(find.descendant(of: results, matching: find.text('Playlist 14')), findsOneWidget);
    expect(find.descendant(of: results, matching: find.text('Mostra tutti')), findsNothing);
    final c = ProviderScope.containerOf(t.element(find.byType(LibraryScreen)));
    final key = SelectionKey.search.key;
    c.listen(selectionProvider(key), (_, _) {});
    c.read(selectionProvider(key).notifier).toggle(1);
    await t.tap(find.descendant(of: find.byType(SegmentedBlocks<LibraryKind?>), matching: find.text('Tutto')));
    await _settle(t);
    expect(c.read(selectionProvider(key)).active, isFalse);
    c.read(selectionProvider(key).notifier).toggle(1);
    await t.tap(find.descendant(of: find.byType(SegmentedBlocks<LibraryKind?>), matching: find.text('Album')));
    await _settle(t);
    expect(c.read(selectionProvider(key)).active, isFalse);
    await h.dispose(t);
  });

  testWidgets('a scroll past the top (bounce) leaves the island whole', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final h = await open(t, width: 900);
      await manyPlaylists(h, t);
      t.view.physicalSize = const Size(900, 600);
      await _settle(t);
      final island = find.byType(LibraryIsland);
      final full = t.getRect(island).height;
      await scrollBy(t, 50);
      expect(full - t.getRect(island).height, closeTo(offset(t), 0.5));
      await scrollBy(t, -400);
      expect(t.takeException(), isNull);
      expect(t.getRect(island).height, closeTo(full, 0.5));
      await h.dispose(t);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('changing the tab and coming back never leaves rows scrolled under a whole island', (t) async {
    final h = await open(t, width: 900);
    await manyPlaylists(h, t);
    t.view.physicalSize = const Size(900, 600);
    await _settle(t);
    final island = find.byType(LibraryIsland);
    final full = t.getRect(island).height;
    await scrollBy(t, 142);
    expect(offset(t), greaterThan(100));
    Finder tab(String s) =>
        find.descendant(of: find.byType(SegmentedBlocks<LibraryKind?>), matching: find.text(s));
    await t.tap(tab('Playlist'));
    await _settle(t);
    await t.tap(tab('Tutto'));
    await _settle(t);
    // Either at the top with a whole island, or the island follows the offset.
    expect(full - t.getRect(island).height, closeTo(offset(t).clamp(0, 104), 0.5));
    expect(
      t.getTopLeft(find.text('Playlist 00')).dy,
      greaterThanOrEqualTo(t.getRect(island).bottom),
    );
    await h.dispose(t);
  });

  Future<void> insertThe(Harness h) => h.db.into(h.db.tracks).insert(
    TracksCompanion.insert(
      path: '/m/the.mp3',
      title: 'The Track',
      albumKey: 'the artist|the album',
      format: 'mp3',
      sizeBytes: 1,
      mtimeMs: 1,
      addedAt: 9,
      artist: const Value('The Artist'),
      album: const Value('The Album'),
    ),
  );

  testWidgets('in the Album tab, search does not show the other kinds', (t) async {
    final h = await open(t, width: 900);
    await insertThe(h);
    await PlaylistRepository(h.db).create('The List');
    await t.tap(find.byIcon(Icons.search_rounded));
    await _settle(t);
    await t.enterText(find.byType(TextField), 'the');
    await t.pump(const Duration(milliseconds: 300));
    await indexReady(t);
    await _settle(t);
    Finder inResults(String s) =>
        find.descendant(of: find.byType(LibraryResults), matching: find.text(s));
    for (final s in ['Brani', 'The Track', 'Artisti', 'The Artist', 'Playlist', 'The List']) {
      expect(inResults(s), findsWidgets, reason: s);
    }
    await t.tap(find.descendant(of: find.byType(SegmentedBlocks<LibraryKind?>), matching: find.text('Album')));
    await _settle(t);
    expect(inResults('The Album'), findsWidgets);
    // «The Artist» stays: it is the album's subtitle.
    for (final s in ['Brani', 'The Track', 'Artisti', 'Playlist', 'The List']) {
      expect(inResults(s), findsNothing, reason: s);
    }
    await h.dispose(t);
  });

  testWidgets('in the Album tab, Ctrl+A selects no hidden track', (t) async {
    final h = await open(t, width: 900, tracks: 4);
    await t.tap(find.byIcon(Icons.search_rounded));
    await _settle(t);
    await t.enterText(find.byType(TextField), 'Album');
    await t.pump(const Duration(milliseconds: 300));
    await indexReady(t);
    await _settle(t);
    final c = ProviderScope.containerOf(t.element(find.byType(LibraryScreen)));
    final key = SelectionKey.search.key;
    c.listen(selectionProvider(key), (_, _) {});
    Future<void> ctrlA() async {
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyA);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pump();
    }
    // All tabs: the shown tracks are selected.
    c.read(selectionProvider(key).notifier).toggle(1);
    await t.pump();
    await ctrlA();
    expect(c.read(selectionProvider(key)).count, greaterThan(1));
    await t.tap(find.descendant(of: find.byType(SegmentedBlocks<LibraryKind?>), matching: find.text('Album')));
    await _settle(t);
    c.read(selectionProvider(key).notifier).toggle(1);
    await t.pump();
    await ctrlA();
    expect(c.read(selectionProvider(key)).active, isFalse);
    await h.dispose(t);
  });

  testWidgets('at text scale 2.0 the title, the field and the sort row are whole', (t) async {
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final h = await open(t, width: 900);
    expect(t.takeException(), isNull);
    final isl = t.getRect(find.byType(LibraryIsland));
    for (final f in [find.text('Libreria'), find.text('Recenti'), find.text('Tutto')]) {
      final r = t.getRect(f);
      expect(r.top, greaterThanOrEqualTo(isl.top));
      expect(r.bottom, lessThanOrEqualTo(isl.bottom));
      expect(f.hitTestable(), findsOneWidget);
    }
    await t.tap(find.byIcon(Icons.search_rounded));
    await _settle(t);
    final field = t.getRect(find.byType(TextField));
    expect(field.top, greaterThanOrEqualTo(isl.top));
    expect(field.bottom, lessThanOrEqualTo(t.getTopLeft(find.byType(SegmentedBlocks<LibraryKind?>)).dy));
    expect(t.takeException(), isNull);
    await h.dispose(t);
  });

  testWidgets('the activity log and the lens are in the title row; every target is 48 dp', (t) async {
    final h = await open(t, width: 900);
    final title = t.getCenter(find.text('Libreria')).dy;
    // Registro is always there, between the title and the lens, next to the running-tasks pill.
    final log = find.byTooltip('Registro');
    expect(log, findsOneWidget);
    expect(t.getCenter(log).dx, lessThan(t.getCenter(find.byIcon(Icons.search_rounded)).dx));
    for (final f in [log, find.byIcon(Icons.search_rounded), find.byTooltip('Altre azioni')]) {
      expect((t.getCenter(f).dy - title).abs(), lessThan(1));
    }
    final isl = t.getRect(find.byType(LibraryIsland));
    expect(isl.left, 8);
    expect(t.getRect(log).bottom, lessThan(t.getTopLeft(find.byType(SegmentedBlocks<LibraryKind?>)).dy));
    for (final f in [
      find.descendant(of: find.byType(LibraryIsland), matching: find.byType(IconButton)),
      find.ancestor(of: find.text('Recenti'), matching: find.byType(InkWell)),
      find.ancestor(of: find.text('Playlist'), matching: find.byType(InkWell)),
    ]) {
      for (final e in f.evaluate()) {
        final r = t.getRect(find.byWidget(e.widget));
        expect(r.height, greaterThanOrEqualTo(48 - 0.01), reason: '${e.widget}');
        expect(r.width, greaterThanOrEqualTo(48 - 0.01), reason: '${e.widget}');
      }
    }
    await h.dispose(t);
  });

  Future<void> openSearch(WidgetTester t) async {
    await t.tap(find.byIcon(Icons.search_rounded));
    await _settle(t);
  }

  Future<void> type(WidgetTester t, String text, {bool wait = true}) async {
    await t.enterText(find.byType(TextField), text);
    if (!wait) return;
    await t.pump(const Duration(milliseconds: 300));
    await indexReady(t);
    await _settle(t);
  }

  testWidgets('search trims the text; only spaces show nothing', (t) async {
    final h = await open(t, width: 900);
    await openSearch(t);
    await type(t, '  Song  ');
    expect(find.text('Song 0'), findsOneWidget);
    await type(t, '     ');
    expect(find.text('Brani'), findsNothing);
    await h.dispose(t);
  });

  testWidgets('typing again inside the debounce searches only the last text', (t) async {
    final h = await open(t, width: 900);
    await openSearch(t);
    await type(t, 'Song 0', wait: false);
    await t.pump(const Duration(milliseconds: 100));
    await type(t, 'Song 1');
    Finder row(String s) =>
        find.descendant(of: find.byType(LibraryResults), matching: find.text(s));
    expect(row('Song 1'), findsOneWidget);
    expect(row('Song 0'), findsNothing);
    await h.dispose(t);
  });

  testWidgets('closing before the debounce leaves no old text or results', (t) async {
    final h = await open(t, width: 900);
    await openSearch(t);
    await type(t, 'Song', wait: false);
    await t.binding.handlePopRoute();
    await _settle(t);
    await openSearch(t);
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(find.text('Brani'), findsNothing);
    expect(find.text('Song 0'), findsNothing);
    await h.dispose(t);
  });

  testWidgets('Esc closes the search and it reopens empty', (t) async {
    final h = await open(t, width: 900);
    await openSearch(t);
    await type(t, 'Song');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(t);
    expect(find.byType(CcSearchField), findsNothing);
    await openSearch(t);
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    await h.dispose(t);
  });

  testWidgets('with reduced motion the search opens at once', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = await open(t, width: 900);
    await t.tap(find.byIcon(Icons.search_rounded));
    await t.pump();
    await t.pump();
    expect(find.byType(CcSearchField), findsOneWidget);
    expect(find.text('Libreria').hitTestable(), findsNothing);
    await h.dispose(t);
  });

  testWidgets('sort sheet names last played and date added', (t) async {
    final h = await open(t);
    await t.tap(find.text('Recenti'));
    await t.pumpAndSettle();
    expect(find.text('Aggiunti di recente'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('sort menu switches to A–Z', (t) async {
    final h = await open(t);
    await t.tap(find.text('Recenti'));
    await t.pumpAndSettle();
    await t.tap(find.text('Titolo A–Z').last);
    await t.pumpAndSettle();
    await _settle(t);
    expect(find.text('Titolo'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('sort sheet: track count not on the artists tab; «Più ascoltati» is saved descending', (t) async {
    final h = await open(t);
    await t.tap(find.text('Recenti'));
    await t.pumpAndSettle();
    expect(find.text('Numero di brani'), findsOneWidget);
    await t.tap(find.text('Più ascoltati'));
    await t.pumpAndSettle();
    final s = ProviderScope.containerOf(t.element(find.byType(LibraryScreen))).read(settingsProvider);
    expect((s.librarySort, s.librarySortAscending), ('plays', false));
    await t.tap(find.text('Artisti').first);
    await _settle(t);
    await t.tap(find.text('Più ascoltati'));
    await t.pumpAndSettle();
    expect(find.text('Numero di brani'), findsNothing);
    await h.dispose(t);
  });

  testWidgets('a saved track-count order shown as A–Z on Artisti is not overwritten by flipping it', (t) async {
    final h = await open(t);
    final c = ProviderScope.containerOf(t.element(find.byType(LibraryScreen)));
    c.read(settingsProvider.notifier).update((s) => s.copyWith(librarySort: 'trackCount', librarySortAscending: true));
    await _settle(t);
    await t.tap(find.text('Artisti').first);
    await _settle(t);
    await t.tap(find.text('Titolo'));
    await t.pumpAndSettle();
    await t.tap(find.text('Decrescente'));
    await t.pumpAndSettle();
    final s = c.read(settingsProvider);
    expect((s.librarySort, s.librarySortAscending), ('trackCount', true));
    await h.dispose(t);
  });

  testWidgets('shortcuts only in Tutto, in spec order', (t) async {
    final h = await open(t);
    final fav = t.getRect(find.text('Preferiti'));
    final all = t.getRect(find.text('Tutti i brani'));
    expect(all.left > fav.left || all.top > fav.top, isTrue);
    await t.tap(find.text('Album').first);
    await _settle(t);
    expect(find.text('Preferiti'), findsNothing);
    await h.dispose(t);
  });

  Rect block(WidgetTester t, String label) => t.getRect(
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
  );

  testWidgets(
    'phone: shortcuts are 2 columns, the odd last one is full width',
    (t) async {
      final h = await open(t, width: 360);
      final fav = block(t, 'Preferiti');
      final all = block(t, 'Tutti i brani');
      final last = block(t, 'Statistiche');
      expect(all.top, fav.top);
      expect(all.left, greaterThan(fav.right));
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      // 7 blocks here: the seventh spans both columns.
      expect(last.left, fav.left);
      expect(last.right, all.right);
      await h.dispose(t);
    },
  );

  testWidgets('desktop: all shortcuts on one row', (t) async {
    final h = await open(t, width: 1600);
    final fav = block(t, 'Preferiti');
    final last = block(t, 'Statistiche');
    expect(last.top, fav.top);
    expect(last.left, greaterThan(fav.right));
    await h.dispose(t);
  });

  testWidgets('desktop, German: shortcuts stay on one row without overflow', (
    t,
  ) async {
    t.view.physicalSize = const Size(1280, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t, tracks: 4);
    await h.pump(t, const LibraryScreen(), locale: const Locale('de'));
    await _settle(t);
    final tops = {
      for (final e
          in find
              .descendant(
                of: find.byType(LibraryShortcuts),
                matching: find.byType(InkWell),
              )
              .evaluate())
        t.getRect(find.byWidget(e.widget)).top,
    };
    expect(tops.length, 1);
    expect(t.takeException(), isNull);
    await h.dispose(t);
  });

  testWidgets('shortcuts with icons keep the old grid on a wide screen', (
    t,
  ) async {
    t.view.physicalSize = const Size(1200, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t);
    await h.pump(
      t,
      Scaffold(
        body: LibraryShortcuts(
          items: [
            for (var i = 0; i < 5; i++)
              LibraryShortcut(label: 'S$i', icon: Icons.star, onTap: () {}),
          ],
        ),
      ),
    );
    // 4 per row, the fifth wraps to a second row.
    expect(t.getRect(find.text('S3')).top, t.getRect(find.text('S0')).top);
    expect(
      t.getRect(find.text('S4')).top,
      greaterThan(t.getRect(find.text('S0')).top),
    );
    await h.dispose(t);
  });

  testWidgets('filters never scroll sideways', (t) async {
    final h = await open(t);
    expect(
      find.descendant(
        of: find.byType(SegmentedBlocks<LibraryKind?>),
        matching: find.byWidgetPredicate(
          (w) => w is ListView && w.scrollDirection == Axis.horizontal,
        ),
      ),
      findsNothing,
    );
    await h.dispose(t);
  });

  testWidgets('with zero podcasts, radios and tags the three shortcuts show', (
    t,
  ) async {
    final h = await open(t);
    expect(find.text('Preferiti'), findsOneWidget);
    expect(find.text('Tutti i brani'), findsOneWidget);
    expect(find.text('Podcast'), findsOneWidget);
    expect(find.text('Radio'), findsOneWidget);
    expect(find.text('Etichette'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('A–Z headers follow leadingLetter', (t) async {
    final h = await open(t, tracks: 0);
    var i = 0;
    for (final album in ['Abba', 'Ägypten', '1999', 'Beta']) {
      await h.db
          .into(h.db.tracks)
          .insert(
            TracksCompanion.insert(
              path: '/m/x${i++}.mp3',
              title: 'T$i',
              albumKey: 'a|$album',
              format: 'mp3',
              sizeBytes: 1,
              mtimeMs: 1,
              addedAt: i,
              artist: const Value('Zed'),
              album: Value(album),
            ),
          );
    }
    await _settle(t);
    expect(find.text('A'), findsNothing);
    await t.tap(find.text('Recenti'));
    await t.pumpAndSettle();
    await t.tap(find.text('Titolo A–Z').last);
    await t.pumpAndSettle();
    await _settle(t);
    // Headers only: covers may also show an initial.
    Finder header(String x) => find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data == x &&
          w.style?.color == CcColors.notte.accentSoft,
    );
    for (final x in ['A', 'B', '#', 'Z']) {
      expect(header(x), findsOneWidget, reason: x);
    }
    await h.dispose(t);
  });

  testWidgets(
    'every tab and sort keeps its order, also after Tutto→Playlist→Tutto',
    (t) async {
      final h = await open(t, tracks: 0);
      final rows = [
        ('Mina', 'Zeta', 5000),
        ('Zed', 'Alfa', null),
        ('Bea', 'Beta', null),
      ];
      for (final (i, (artist, album, played)) in rows.indexed) {
        await h.db
            .into(h.db.tracks)
            .insert(
              TracksCompanion.insert(
                path: '/m/o$i.mp3',
                title: 'T$i',
                albumKey: '$artist|$album',
                format: 'mp3',
                sizeBytes: 1,
                mtimeMs: 1,
                addedAt: i,
                artist: Value(artist),
                album: Value(album),
                lastPlayedAt: Value(played),
              ),
            );
      }
      final playlists = PlaylistRepository(h.db);
      await playlists.create('Playlist B');
      await playlists.create('Playlist A');
      await _settle(t);

      List<String> order(List<String> names) {
        final seen =
            [
              for (final n in names)
                if (find.text(n).evaluate().isNotEmpty) n,
            ]..sort(
              (a, b) => t
                  .getTopLeft(find.text(a))
                  .dy
                  .compareTo(t.getTopLeft(find.text(b)).dy),
            );
        return seen;
      }

      const everything = [
        'Mina',
        'Zeta',
        'Alfa',
        'Bea',
        'Beta',
        'Playlist A',
        'Playlist B',
        'Zed',
      ];
      // Recent: the played ones first (the artist and the album, same moment, A–Z), then the rest A–Z.
      const recentAll = [
        'Mina',
        'Zeta',
        'Alfa',
        'Bea',
        'Beta',
        'Playlist A',
        'Playlist B',
        'Zed',
      ];
      expect(order(everything), recentAll);

      Future<void> tab(String label) async {
        await t.tap(find.text(label).first);
        await _settle(t);
      }

      await tab('Playlist');
      expect(order(everything), ['Playlist A', 'Playlist B']);
      await tab('Album');
      expect(order(everything), ['Zeta', 'Alfa', 'Beta']);
      await tab('Artisti');
      expect(order(everything), ['Mina', 'Bea', 'Zed']);
      await tab('Tutto');
      expect(order(everything), recentAll);

      await t.tap(find.text('Recenti'));
      await t.pumpAndSettle();
      await t.tap(find.text('Titolo A–Z').last);
      await t.pumpAndSettle();
      await _settle(t);
      const alphaAll = [
        'Alfa',
        'Bea',
        'Beta',
        'Mina',
        'Playlist A',
        'Playlist B',
        'Zed',
        'Zeta',
      ];
      expect(order(everything), alphaAll);
      await tab('Playlist');
      expect(order(everything), ['Playlist A', 'Playlist B']);
      await tab('Album');
      expect(order(everything), ['Alfa', 'Beta', 'Zeta']);
      await tab('Artisti');
      expect(order(everything), ['Bea', 'Mina', 'Zed']);
      await tab('Tutto');
      expect(order(everything), alphaAll);
      await h.dispose(t);
    },
  );

  testWidgets('desktop: content reaches the same right edge as the header', (
    t,
  ) async {
    final h = await open(t, width: 1600);
    final r = t.getRect(find.byType(SegmentedBlocks<LibraryKind?>));
    final menu = t.getRect(find.byTooltip('Altre azioni'));
    expect(r.right, greaterThanOrEqualTo(menu.right - 2 * CcDims.margin));
    await h.dispose(t);
  });
}
