import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/ui/screens/search/search_screen.dart';
import 'package:codecore/ui/shell/bottom_bar.dart';
import 'package:codecore/ui/widgets/segmented_blocks.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_youtube.dart';
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

Future<void> _genre(Harness h, String genre, int n, int i) => h.db
    .into(h.db.tracks)
    .insert(
      TracksCompanion.insert(
        path: '/m/$genre$n$i.mp3',
        title: '$genre $n$i',
        albumKey: 'a|b',
        format: 'mp3',
        sizeBytes: 1,
        mtimeMs: 1,
        addedAt: i,
        genre: Value(genre),
      ),
    );

void main() {
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

  testWidgets('genres are listed by number of tracks, most first', (
    tester,
  ) async {
    _size(tester, const Size(400, 900));
    final h = await Harness.create(tester);
    await _genre(h, 'Jazz', 1, 0);
    for (var i = 0; i < 2; i++) {
      await _genre(h, 'Pop', 2, i);
    }
    for (var i = 0; i < 3; i++) {
      await _genre(h, 'Rock', 3, i);
    }
    await h.pump(tester, const SearchScreen());
    await _settle(tester);
    final rock = tester.getTopLeft(find.byKey(const ValueKey('genre-Rock')));
    final pop = tester.getTopLeft(find.byKey(const ValueKey('genre-Pop')));
    final jazz = tester.getTopLeft(find.byKey(const ValueKey('genre-Jazz')));
    expect(find.text('3 brani'), findsOneWidget);
    expect(find.text('1 brano'), findsOneWidget);
    expect(rock.dx, lessThan(pop.dx));
    expect(pop.dx, lessThan(jazz.dx));
    expect(rock.dy, jazz.dy, reason: 'three columns share the first row');
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
}
