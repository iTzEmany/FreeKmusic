import 'package:codecore/services/online/credits.dart' show creditNameKey;
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/ui/screens/library/search_section_screen.dart';
import 'package:codecore/ui/widgets/empty_state.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/results_host.dart';
import '../support/search_input.dart';

Future<void> _settle(WidgetTester tester) async {
  await indexReady(tester);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Five single-track albums "Disc 0".."Disc 4" by "Band 0".."Band 4"; the
/// first two are favourites.
Future<void> _insertDiscs(Harness h) async {
  for (var i = 0; i < 5; i++) {
    await h.db
        .into(h.db.tracks)
        .insert(
          TracksCompanion.insert(
            path: '/m/d$i.mp3',
            title: 'Tune $i',
            albumKey: 'band $i|disc $i',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: i,
            artist: Value('Band $i'),
            album: Value('Disc $i'),
            isFavorite: Value(i < 2),
          ),
        );
  }
}

void main() {
  testWidgets('typing shows library sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, const ResultsHost());
    await _settle(tester);
    typeSearch(tester, 'Song 1');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    expect(find.text('Brani'), findsOneWidget);
    // Plain words still search as text (no operator involved).
    Finder row(String title) =>
        find.descendant(of: find.byType(TrackRow), matching: find.text(title));
    expect(row('Song 1'), findsOneWidget);
    expect(row('Song 0'), findsNothing);
    // Typing did not switch to YouTube mode.
    expect(find.text('Cerca un brano o incolla un link'), findsNothing);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('search without matches says so', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 2);
    await h.pump(tester, const ResultsHost());
    typeSearch(tester, 'zzzz');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    expect(find.text('Nessun risultato in libreria'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('results are rows: no main card, no Tutti under the limits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, const ResultsHost());
    await _settle(tester);
    typeSearch(tester, 'Album');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    expect(find.text('Risultato principale'), findsNothing);
    expect(find.text('Album 0'), findsOneWidget);
    expect(find.text('Album 1'), findsOneWidget);
    expect(
      find.text('Playlist'),
      findsNothing,
      reason: 'empty section vanishes',
    );
    expect(find.text('Tutti'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.horizontal,
      ),
      findsNothing,
    );
    await h.dispose(tester);
  });

  testWidgets('section screen lists every match for the query', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(
      tester,
      const SearchSectionScreen(
        text: 'album',
        kind: SearchSectionKind.albums,
      ),
    );
    await _settle(tester);
    expect(find.text('Album 0'), findsOneWidget);
    expect(find.text('Album 1'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('Tutti appears above the limit and opens the full list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 0);
    await _insertDiscs(h);
    await h.pump(tester, const ResultsHost());
    await _settle(tester);
    typeSearch(tester, 'Disc');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    expect(find.text('Disc 4'), findsNothing, reason: 'only three are shown');
    expect(find.text('Tutti'), findsWidgets);
    await tester.tap(find.text('Tutti').first);
    await tester.pumpAndSettle();
    expect(find.byType(SearchSectionScreen), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      expect(find.text('Disc $i'), findsOneWidget);
    }
    await h.dispose(tester);
  });

  testWidgets('section screen without matches shows the empty state', (
    tester,
  ) async {
    final h = await Harness.create(tester, tracks: 2);
    await h.pump(
      tester,
      const SearchSectionScreen(
        text: 'zzzz',
        kind: SearchSectionKind.albums,
      ),
    );
    await _settle(tester);
    expect(find.byType(EmptyState), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('result rows grow with 150 % text instead of overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(
      tester,
      const MediaQuery(
        data: MediaQueryData(
          size: Size(360, 800),
          textScaler: TextScaler.linear(1.5),
        ),
        child: SearchSectionScreen(
          text: 'Album',
          kind: SearchSectionKind.albums,
        ),
      ),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Album 0'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets(
    'section screen keeps only the plain words of an operator query',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester, tracks: 0);
      await _insertDiscs(h);
      await h.pump(
        tester,
        const SearchSectionScreen(
          text: 'Disc artista:"Band 3"',
          kind: SearchSectionKind.albums,
        ),
      );
      await _settle(tester);
      // The operator is not matched against album names: the plain word rules.
      for (var i = 0; i < 5; i++) {
        expect(find.text('Disc $i'), findsOneWidget);
      }
      await h.dispose(tester);
    },
  );

  testWidgets('section screen with only an operator has no rows', (
    tester,
  ) async {
    final h = await Harness.create(tester, tracks: 0);
    await _insertDiscs(h);
    await h.pump(
      tester,
      const SearchSectionScreen(
        text: 'artista:"Band 3"',
        kind: SearchSectionKind.albums,
      ),
    );
    await _settle(tester);
    expect(find.byType(EmptyState), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('search: a credited track shows under «Nei crediti», once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 1);
    final id = await h.db.select(h.db.tracks).map((t) => t.id).getSingle();
    await h.db.into(h.db.trackCredits).insert(TrackCreditsCompanion.insert(
      trackId: id,
      name: 'Pharrell Williams',
      nameKey: creditNameKey('Pharrell Williams'),
      role: 'producer',
      source: 'deezer',
    ));
    await h.pump(tester, const ResultsHost());
    await _settle(tester);
    typeSearch(tester, 'Song');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    expect(find.text('Nei crediti'), findsNothing);
    typeSearch(tester, 'Pharrell');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    expect(find.text('Nei crediti'), findsOneWidget);
    expect(find.text('Song 0'), findsOneWidget);
    await h.dispose(tester);
  });
}
