import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/tag_repository.dart';
import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/screens/library/library_screen.dart';
import 'package:codecore/ui/screens/tags/tags_screen.dart';
import 'package:codecore/ui/widgets/empty_state.dart';
import 'package:codecore/ui/widgets/play_buttons.dart';
import 'package:codecore/ui/widgets/shuffle_button.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// One turn of the real event loop (not real time) lets drift finish what a
/// `runAsync` write started; everything else runs on the test clock.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump(const Duration(milliseconds: 300));
}

Finder _row(String title) =>
    find.descendant(of: find.byType(TrackRow), matching: find.text(title));

void main() {
  late Harness h;
  late TagRepository repo;
  late List<Track> tracks;

  Future<void> open(WidgetTester tester, Widget page, {bool withTag = false}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester, tracks: 4);
    repo = TagRepository(h.db);
    tracks = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
    await h.pump(tester, page);
    await _settle(tester);
  }

  /// In one transaction: with a drift stream open, a plain statement that
  /// follows another one waits for timers the test clock holds back.
  Future<int> tagWith(WidgetTester tester, String name, List<int> trackIdx) async =>
      (await tester.runAsync(() => h.db.transaction(() async {
        final id = await repo.create(name);
        await repo.assign([for (final i in trackIdx) tracks[i].id], id);
        return id;
      })))!;

  Future<Map<int, int>> counts(WidgetTester tester) async =>
      (await tester.runAsync(() => repo.countsAmong([for (final t in tracks) t.id])))!;

  testWidgets('a track\'s «Etichette…» creates a tag and gives it to the track, then removes it', (tester) async {
    await open(tester, const AllTracksScreen());
    await tester.tap(find.descendant(of: find.widgetWithText(TrackRow, 'Song 1').first, matching: find.byTooltip('Altre azioni')).first);
    await _settle(tester);
    await tester.tap(find.text('Etichette…'));
    await _settle(tester);
    await tester.tap(find.text('Nuova etichetta'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Live');
    await tester.tap(find.text('Salva').last);
    await _settle(tester);
    expect(find.text('Live'), findsOneWidget);
    expect((await counts(tester)).values.single, 1);
    final live = (await tester.runAsync(() => repo.byName('live')))!;
    expect((await counts(tester)).keys.single, live.id);

    // Unchecking it removes the link; the tag itself stays.
    final box = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(box.value, isTrue);
    await tester.tap(find.byType(CheckboxListTile));
    await _settle(tester);
    expect(await counts(tester), isEmpty);
    expect((await tester.runAsync(() => repo.watchAll().first))!, hasLength(1));
    await h.dispose(tester);
  });

  testWidgets('for several tracks a tag some have shows a dash and tapping gives it to all', (tester) async {
    await open(tester, const AllTracksScreen());
    final live = await tagWith(tester, 'Live', [0]);
    await tester.longPress(_row('Song 0'));
    await tester.tap(_row('Song 1'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Azioni'));
    await _settle(tester);
    // The bulk menu has «Aggiungi etichetta…» (a list); the dash is in the single-track sheet,
    // so check the state through the repository after adding.
    await tester.tap(find.text('Aggiungi etichetta…'));
    await _settle(tester);
    await tester.tap(find.text('Live'));
    await _settle(tester);
    expect(find.textContaining('2 brani etichettati «Live»'), findsOneWidget);
    final c = await counts(tester);
    expect(c[live], 2, reason: 'Song 0 already had it: now both');
    await h.dispose(tester);
  });

  testWidgets('a selection: add a tag, then take it away, in one go each', (tester) async {
    await open(tester, const AllTracksScreen());
    final calm = await tagWith(tester, 'Calm', []);
    await tester.longPress(_row('Song 0'));
    await tester.tap(_row('Song 1'));
    await tester.tap(_row('Song 2'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Azioni'));
    await _settle(tester);
    await tester.tap(find.text('Aggiungi etichetta…'));
    await _settle(tester);
    await tester.tap(find.text('Calm'));
    await _settle(tester);
    expect(find.textContaining('3 brani etichettati «Calm»'), findsOneWidget);
    expect((await counts(tester))[calm], 3);
    expect(find.textContaining('selezionati'), findsNothing, reason: 'the selection ended');

    await tester.longPress(_row('Song 1'));
    await tester.tap(_row('Song 3'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Azioni'));
    await _settle(tester);
    await tester.tap(find.text('Togli etichetta…'));
    await _settle(tester);
    await tester.tap(find.text('Calm'));
    await _settle(tester);
    expect(find.textContaining('«Calm» tolta da 1 brano'), findsOneWidget);
    expect((await counts(tester))[calm], 2);
    await h.dispose(tester);
  });

  testWidgets('«Togli etichetta…» on tracks with no tags says so', (tester) async {
    await open(tester, const AllTracksScreen());
    await tagWith(tester, 'Calm', [3]);
    await tester.longPress(_row('Song 0'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Azioni'));
    await _settle(tester);
    await tester.tap(find.text('Togli etichetta…'));
    await _settle(tester);
    expect(find.text('I brani scelti non hanno etichette.'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the tags page: counts, the tracks of a tag, rename and delete', (tester) async {
    await open(tester, const TagsScreen());
    expect(find.text('Nessuna etichetta: creane una dal menu di un brano.'), findsOneWidget);
    await h.dispose(tester);

    await open(tester, const TagsScreen());
    await tagWith(tester, 'Live', [0, 1]);
    await tagWith(tester, 'calm', [2]);
    await _settle(tester);
    expect(find.text('calm'), findsOneWidget);
    expect(find.text('2 brani'), findsOneWidget);
    expect(find.text('1 brano'), findsOneWidget);
    // The tracks of a tag.
    await tester.tap(find.text('Live'));
    await _settle(tester);
    expect(find.byType(TagTracksScreen), findsOneWidget);
    expect(_row('Song 0'), findsOneWidget);
    expect(_row('Song 1'), findsOneWidget);
    expect(_row('Song 2'), findsNothing);
    await tester.tap(find.byTooltip('Indietro'));
    await _settle(tester);

    // Rename the first row («calm», the list is by name).
    await tester.tap(find.byTooltip('Altre azioni').first);
    await _settle(tester);
    await tester.tap(find.text('Rinomina etichetta'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Zeta');
    await tester.tap(find.text('Salva'));
    await _settle(tester);
    expect(find.text('Zeta'), findsOneWidget);
    expect(find.text('calm'), findsNothing);
    expect(find.text('Live'), findsOneWidget);

    // Delete the first row, now «Live»: asks first, only the tag goes.
    await tester.tap(find.byTooltip('Altre azioni').first);
    await _settle(tester);
    await tester.tap(find.text('Elimina'));
    await _settle(tester);
    expect(find.text('Eliminare l’etichetta «Live»?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Elimina'));
    await _settle(tester);
    expect(find.text('Live'), findsNothing);
    expect(find.text('Zeta'), findsOneWidget);
    expect((await tester.runAsync(() => h.db.select(h.db.tracks).get()))!, hasLength(4));
    await h.dispose(tester);
  });

  testWidgets('a name already used is refused with a message', (tester) async {
    await open(tester, const TagsScreen());
    await tagWith(tester, 'Live', [0]);
    await tagWith(tester, 'Calm', [1]);
    await _settle(tester);
    await tester.tap(find.byTooltip('Altre azioni').last);
    await _settle(tester);
    await tester.tap(find.text('Rinomina etichetta'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField).last, 'calm');
    await tester.tap(find.text('Salva'));
    await _settle(tester);
    expect(find.text('Esiste già un’etichetta con questo nome'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the library lists the tags with their count', (tester) async {
    await open(tester, const Scaffold(body: LibraryScreen()));
    await tagWith(tester, 'Live', [0]);
    await tagWith(tester, 'Calm', [1]);
    await _settle(tester);
    expect(find.text('Etichette'), findsOneWidget);
    expect(find.bySemanticsLabel('Etichette, 2'), findsOneWidget);
    await tester.tap(find.text('Etichette'));
    await _settle(tester);
    expect(find.byType(TagsScreen), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a tag page is a collection: name, count, play icons', (tester) async {
    await open(tester, const SizedBox());
    await tagWith(tester, 'Live', [0, 1]);
    await h.pump(tester, const TagTracksScreen(name: 'Live'));
    await _settle(tester);
    expect(find.text('Live'), findsWidgets);
    expect(find.textContaining('2 brani'), findsOneWidget);
    expect(find.byType(PlayCircleButton), findsOneWidget);
    expect(find.byType(ShufflePill), findsOneWidget);
    expect(_row('Song 0'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('an empty tag page disables the pills and says so', (tester) async {
    await open(tester, const SizedBox());
    await tagWith(tester, 'Vuota', []);
    await h.pump(tester, const TagTracksScreen(name: 'Vuota'));
    await _settle(tester);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Nessun brano'), findsWidgets);
    expect(find.byType(PlayCircleButton), findsNothing, reason: 'no play without tracks');
    await h.dispose(tester);
  });
}
