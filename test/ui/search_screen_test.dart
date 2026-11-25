import 'dart:async';

import 'package:codecore/services/online/youtube_service.dart' show YtResult;
import 'package:codecore/providers/online_collection_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/services/online/chart_genres.dart';
import 'package:codecore/ui/screens/online/online_playlist_screen.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/providers/ytm_catalog_providers.dart';
import 'package:codecore/ui/screens/search/search_screen.dart';
import 'package:codecore/ui/shell/bottom_bar.dart';
import 'package:codecore/ui/theme/palette.dart' show chartGenreColors, contrastRatio;
import 'package:codecore/ui/widgets/segmented_blocks.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_youtube.dart';
import '../support/fake_ytm.dart';
import '../support/search_input.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Answers only once [gate] opens, so the search stays under way.
class _SlowYoutube extends FakeYoutube {
  final gate = Completer<void>();

  @override
  Future<List<YtResult>> searchSongs(String query, {int limit = 5}) async {
    await gate.future;
    return super.searchSongs(query, limit: limit);
  }
}

void main() {
  testWidgets('wide: the genre chips use 13 px text with at least 4.5:1 on their colour', (tester) async {
    _size(tester, const Size(1440, 900));
    final h = await Harness.create(tester, tracks: 1);
    await h.pump(tester, const SearchScreen());
    await _settle(tester);
    final popColor = chartGenreColors['pop']!;
    final text = tester.widget<Text>(find.descendant(of: find.byKey(const ValueKey('genre-pop')), matching: find.byType(Text)).first);
    expect(text.style!.fontSize, 13);
    expect(contrastRatio(text.style!.color!, popColor), greaterThanOrEqualTo(4.5));
    await h.dispose(tester);
  });

  testWidgets('typing shows no library result and asks nothing online', (
    tester,
  ) async {
    _size(tester, const Size(400, 900));
    final h = await Harness.create(tester, tracks: 4);
    final svc = FakeYoutube();
    await h.pump(
      tester,
      const SearchScreen(),
      extraOverrides: [youtubeServiceProvider.overrideWithValue(svc)],
    );
    typeSearch(tester, 'Song 1');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    expect(find.byType(TrackRow), findsNothing);
    expect(find.text('Brani'), findsNothing);
    expect(find.byType(SegmentedBlocks<bool>), findsNothing);
    expect(find.byType(FilterChip), findsNothing);
    expect(svc.calls, isEmpty, reason: 'online runs on submit only');
    await h.dispose(tester);
  });

  testWidgets('typing, waiting and Enter ask the catalog once', (tester) async {
    _size(tester, const Size(400, 900));
    final h = await Harness.create(tester, tracks: 2);
    final svc = FakeYoutube();
    await h.pump(
      tester,
      const SearchScreen(),
      extraOverrides: [
        youtubeServiceProvider.overrideWithValue(svc),
        ytmCatalogProvider.overrideWithValue(FakeCatalog((_) async => null)),
      ],
    );
    typeSearch(tester, 'oasis');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    expect(svc.calls, isEmpty);
    submitSearch(tester);
    await _settle(tester);
    expect(svc.calls.where((c) => c.startsWith('music:')), hasLength(1));
    expect(svc.calls.where((c) => c.startsWith('youtube:')), hasLength(1));
    await h.dispose(tester);
  });

  testWidgets('Enter again while the same search is coming is not a second search', (
    tester,
  ) async {
    _size(tester, const Size(400, 900));
    final h = await Harness.create(tester, tracks: 2);
    final svc = _SlowYoutube();
    await h.pump(
      tester,
      const SearchScreen(),
      extraOverrides: [
        youtubeServiceProvider.overrideWithValue(svc),
        ytmCatalogProvider.overrideWithValue(FakeCatalog((_) async => null)),
      ],
    );
    typeSearch(tester, 'oasis');
    submitSearch(tester);
    await _settle(tester);
    submitSearch(tester);
    await _settle(tester);
    svc.gate.complete();
    await _settle(tester);
    expect(svc.calls.where((c) => c.startsWith('music:')), hasLength(1));
    expect(svc.calls.where((c) => c.startsWith('youtube:')), hasLength(1));
    await h.dispose(tester);
  });

  testWidgets('empty Search shows the 12 macro-genre tiles, each with a TalkBack label', (
    tester,
  ) async {
    _size(tester, const Size(400, 900));
    final h = await Harness.create(tester);
    final semantics = tester.ensureSemantics();
    await h.pump(tester, const SearchScreen());
    await _settle(tester);
    final tiles = find.byWidgetPredicate(
      (w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('genre-'),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('genre-country')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(tiles, findsNWidgets(12));
    for (final label in ['Pop', 'Rap e Hip-hop', 'Dance ed Elettronica', 'Italiana', 'Country']) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    semantics.dispose();
    await h.dispose(tester);
  });

  testWidgets('a macro-genre tile opens its Top 20 page', (tester) async {
    _size(tester, const Size(400, 900));
    final h = await Harness.create(tester);
    await h.pump(
      tester,
      const SearchScreen(),
      // The read never ends: only the page and its source are looked at.
      extraOverrides: [
        onlineCollectionProvider.overrideWith((ref, r) => Completer<CollectionPage>().future),
      ],
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('genre-rock')));
    await _settle(tester);
    expect(tester.widget<OnlinePlaylistScreen>(find.byType(OnlinePlaylistScreen)).source,
        OnlineCollectionRef.chart(chartGenres.firstWhere((g) => g.id == 'rock')));
    await h.dispose(tester);
  });

  testWidgets('the ✕ of a recent search names the query', (tester) async {
    _size(tester, const Size(400, 900));
    final h = await Harness.create(tester);
    await h.pump(tester, const SearchScreen());
    ProviderScope.containerOf(tester.element(find.byType(SearchScreen)))
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(recentSearches: ['queen']));
    await _settle(tester);
    expect(find.text('Ricerche recenti'), findsOneWidget);
    expect(find.byTooltip('Rimuovi «queen» dalle ricerche recenti'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('desktop: ✕ clears the field and the page stays on Search', (
    tester,
  ) async {
    _size(tester, const Size(1400, 900));
    final h = await Harness.create(tester, tracks: 2);
    await h.pump(tester, const SearchScreen());
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'Song');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    expect(find.byTooltip('Cancella ricerca'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancella ricerca'));
    await _settle(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.byTooltip('Cancella ricerca'), findsNothing);
    expect(find.byType(SearchScreen), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the dock has no Search tab when YouTube is off (D-358)', (
    tester,
  ) async {
    _size(tester, const Size(400, 800));
    final h = await Harness.create(tester);
    final picked = <int>[];
    for (final show in [true, false]) {
      await h.pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: ShellDock(
            showSearch: show,
            items: const [
              BottomBarItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
              BottomBarItem(Icons.search_rounded, Icons.search_rounded, 'Cerca'),
              BottomBarItem(
                Icons.library_music_outlined,
                Icons.library_music_rounded,
                'Libreria',
              ),
            ],
            selected: 0,
            onSelect: picked.add,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Cerca'), show ? findsOneWidget : findsNothing);
    }
    await tester.tap(find.text('Libreria'));
    expect(picked, [2], reason: 'the index is the tab, not the position');
    await h.dispose(tester);
  });

  for (final online in [false, true]) {
    testWidgets('no overflow at text scale 2.0 ${online ? 'with online results' : 'idle'}', (
      tester,
    ) async {
      _size(tester, const Size(400, 900));
      final h = await Harness.create(tester, tracks: 4);
      await h.pump(
        tester,
        const SearchScreen(),
        textScale: 2,
        extraOverrides: [
          youtubeServiceProvider.overrideWithValue(FakeYoutube()),
          ytmCatalogProvider.overrideWithValue(FakeCatalog((_) async => null)),
        ],
      );
      ProviderScope.containerOf(tester.element(find.byType(SearchScreen)))
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(recentSearches: ['queen', 'a rather long recent search']));
      if (online) {
        typeSearch(tester, 'daft punk');
        submitSearch(tester);
      }
      await _settle(tester);
      await _settle(tester);
      final ex = tester.takeException();
      if (ex != null) fail(ex is FlutterError ? ex.toStringDeep() : '$ex');
      await h.dispose(tester);
    });
  }
}
