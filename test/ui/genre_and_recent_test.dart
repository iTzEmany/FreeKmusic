import 'dart:ui' show Tristate;

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/ui/screens/radio/radio_labels.dart';
import 'package:codecore/ui/screens/radio/radio_sections.dart';
import 'package:codecore/ui/screens/search/genre_screen.dart';
import 'package:codecore/ui/screens/search/search_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/search_input.dart';

Future<void> _settle(WidgetTester tester) async {
  await indexReady(tester);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

List<String> _recents(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(SearchScreen)),
).read(settingsProvider).recentSearches;

void main() {
  testWidgets('Radio: every genre chip keeps its key genre-<tag> and reports its tag', (
    tester,
  ) async {
    _desktop(tester);
    final h = await Harness.create(tester);
    String? picked;
    await h.pump(
      tester,
      Scaffold(
        body: CustomScrollView(
          slivers: [
            GenresSection(selected: 'jazz', onSelect: (t) => picked = t),
          ],
        ),
      ),
    );
    for (final tag in kRadioGenreTags) {
      expect(find.byKey(ValueKey('genre-$tag')), findsOneWidget, reason: tag);
    }
    expect(
      tester.getSemantics(find.byKey(const ValueKey('genre-jazz'))).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('genre-pop'))).flagsCollection.isSelected,
      Tristate.isFalse,
    );
    await tester.tap(find.byKey(ValueKey('genre-${kRadioGenreTags.first}')));
    expect(picked, kRadioGenreTags.first);
    await h.dispose(tester);
  });

  testWidgets('Cerca: a genre of the library opens its page', (tester) async {
    _desktop(tester);
    final h = await Harness.create(tester);
    await h.db.into(h.db.tracks).insert(
      TracksCompanion.insert(
        path: '/m/g.mp3',
        title: 'Rocker',
        albumKey: 'a|b',
        format: 'mp3',
        sizeBytes: 1,
        mtimeMs: 1,
        addedAt: 1,
        genre: const Value('Rock'),
      ),
    );
    await h.pump(tester, const SearchScreen());
    await _settle(tester);
    await tester.tap(find.text('Rock'));
    await _settle(tester);
    expect(find.byType(GenreScreen), findsOneWidget);
    expect(tester.widget<GenreScreen>(find.byType(GenreScreen)).genre, 'Rock');
    await h.dispose(tester);
  });

  testWidgets('Cerca: submitting remembers the text, newest first, once per spelling', (
    tester,
  ) async {
    _desktop(tester);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, const SearchScreen());
    await _settle(tester);
    for (final q in ['Song 1', 'Song 2', 'song 1']) {
      typeSearch(tester, q);
      submitSearch(tester);
      await _settle(tester);
    }
    expect(_recents(tester), ['song 1', 'Song 2']);
    await h.dispose(tester);
  });

  testWidgets('Cerca: a recent search refills the field, its ✕ removes it', (
    tester,
  ) async {
    _desktop(tester);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, const SearchScreen());
    await _settle(tester);
    ProviderScope.containerOf(tester.element(find.byType(SearchScreen)))
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(recentSearches: ['Song 3', 'Song 1']));
    await _settle(tester);
    await tester.tap(find.byTooltip('Rimuovi dalle ricerche recenti').first);
    await _settle(tester);
    expect(_recents(tester), ['Song 1']);
    expect(find.text('Song 3'), findsNothing);
    await tester.tap(find.text('Song 1'));
    await _settle(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Song 1',
    );
    expect(find.text('Ricerche recenti'), findsNothing, reason: 'results replace them');
    await h.dispose(tester);
  });
}
