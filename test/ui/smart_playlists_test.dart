import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/smart_playlist_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/ui/screens/library/library_screen.dart';
import 'package:codecore/providers/filter_counts_providers.dart';
import 'package:codecore/services/library/rules/rule_ast.dart';
import 'package:codecore/services/library/rules/rule_parser.dart';
import 'package:codecore/ui/screens/smart/smart_filter_model.dart';
import 'package:codecore/ui/screens/smart/smart_playlist_editor.dart';
import 'package:codecore/ui/screens/smart/smart_playlist_screen.dart';
import 'package:codecore/ui/widgets/smart_cover.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
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
  late SmartPlaylistRepository repo;
  late List<Track> tracks;

  Future<int> make(WidgetTester tester, String name, String rules,
          {SmartSort sort = SmartSort.title, int? limit}) async =>
      (await tester.runAsync(() => repo.create(name: name, rules: rules, sort: sort, limit: limit)))!;

  group('the page', () {
    testWidgets('lists what the rules select and says it is a smart playlist', (tester) async {
      h = await Harness.create(tester, tracks: 4);
      repo = SmartPlaylistRepository(h.db, TrackRepository(h.db));
      tracks = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
      final id = await make(tester, 'Album uno', 'album:"Album 1"');
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await h.pump(tester, SmartPlaylistScreen(id: id));
      await _settle(tester);
      expect(find.text('Album uno'), findsWidgets);
      expect(find.text('album:"Album 1"'), findsOneWidget);
      expect(find.textContaining('2 brani'), findsOneWidget);
      expect(_row('Song 1'), findsOneWidget);
      expect(_row('Song 3'), findsOneWidget);
      expect(_row('Song 0'), findsNothing);
      expect(find.byType(SmartCover), findsOneWidget);
      expect(find.text('Aggiungi brani'), findsNothing, reason: 'read-only');
      expect(find.byType(ReorderableDragStartListener), findsNothing);
      await h.dispose(tester);
    });

    testWidgets('it changes by itself: a favourite joins a «preferiti» list', (tester) async {
      h = await Harness.create(tester, tracks: 4);
      repo = SmartPlaylistRepository(h.db, TrackRepository(h.db));
      tracks = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
      final id = await make(tester, 'Cuori', 'preferiti');
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await h.pump(tester, SmartPlaylistScreen(id: id));
      await _settle(tester);
      expect(_row('Song 2'), findsNothing);
      await tester.runAsync(() => TrackRepository(h.db).setFavorite(tracks[2].id, true));
      await _settle(tester);
      expect(_row('Song 2'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('tapping a track plays the list as it was at that moment', (tester) async {
      h = await Harness.create(tester, tracks: 4);
      repo = SmartPlaylistRepository(h.db, TrackRepository(h.db));
      final id = await make(tester, 'Tutti', 'artista:artist');
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await h.pump(tester, SmartPlaylistScreen(id: id));
      await _settle(tester);
      await tester.tap(_row('Song 2'));
      await _settle(tester);
      expect(h.handler.currentTrack?.title, 'Song 2');
      expect(h.handler.queueIds, hasLength(4));
      await h.dispose(tester);
    });

    testWidgets('the search field filters the rows and a tap plays the whole list from there', (tester) async {
      h = await Harness.create(tester, tracks: 4);
      repo = SmartPlaylistRepository(h.db, TrackRepository(h.db));
      final id = await make(tester, 'Tutti', 'artista:artist');
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await h.pump(tester, SmartPlaylistScreen(id: id));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'SONG 2');
      await tester.pump(const Duration(seconds: 1));
      expect(_row('Song 1'), findsNothing);
      await tester.tap(_row('Song 2'));
      await _settle(tester);
      expect(h.handler.currentTrack?.title, 'Song 2');
      expect(h.handler.queueIds, hasLength(4));
      await h.dispose(tester);
    });

    testWidgets('«select all» takes only the rows the search shows; no match says so', (tester) async {
      h = await Harness.create(tester, tracks: 4);
      repo = SmartPlaylistRepository(h.db, TrackRepository(h.db));
      final id = await make(tester, 'Tutti', 'artista:artist');
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await h.pump(tester, SmartPlaylistScreen(id: id));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'SONG 2');
      await tester.pump(const Duration(seconds: 1));
      await tester.longPress(_row('Song 2'));
      await _settle(tester);
      await tester.tap(find.byTooltip('Seleziona tutto'));
      await _settle(tester);
      expect(find.text('1 selezionato'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Nessun risultato'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('«Converti in playlist normale» copies the current list and keeps the rule', (tester) async {
      h = await Harness.create(tester, tracks: 4);
      repo = SmartPlaylistRepository(h.db, TrackRepository(h.db));
      tracks = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
      final id = await make(tester, 'Pari', 'album:"Album 0"');
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await h.pump(tester, SmartPlaylistScreen(id: id));
      await _settle(tester);
      await tester.tap(find.byTooltip('Altre azioni'));
      await _settle(tester);
      await tester.tap(find.text('Converti in playlist normale'));
      await _settle(tester);
      final plain = (await tester.runAsync(() => PlaylistRepository(h.db).watchAll().first))!.single;
      expect(plain.playlist.name, 'Pari');
      final copied = (await tester.runAsync(() => PlaylistRepository(h.db).watchTracks(plain.playlist.id).first))!;
      expect(copied.map((t) => t.title), ['Song 0', 'Song 2']);
      expect((await tester.runAsync(() => repo.get(id)))!.rules, 'album:"Album 0"', reason: 'the rule stays');
      await h.dispose(tester);
    });

    testWidgets('deleting asks first, and only the rule goes', (tester) async {
      h = await Harness.create(tester, tracks: 4);
      repo = SmartPlaylistRepository(h.db, TrackRepository(h.db));
      final id = await make(tester, 'Via', '');
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await h.pump(tester, Scaffold(body: Builder(builder: (c) => TextButton(
          onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => SmartPlaylistScreen(id: id))),
          child: const Text('open')))));
      await tester.tap(find.text('open'));
      await _settle(tester);
      await tester.tap(find.byTooltip('Altre azioni'));
      await _settle(tester);
      await tester.tap(find.text('Elimina'));
      await _settle(tester);
      expect(find.text('Eliminare «Via»?'), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await _settle(tester);
      expect(await tester.runAsync(() => repo.get(id)), isNotNull);
      await tester.tap(find.byTooltip('Altre azioni'));
      await _settle(tester);
      await tester.tap(find.text('Elimina'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Elimina'));
      await _settle(tester);
      expect(await tester.runAsync(() => repo.get(id)), isNull);
      expect((await tester.runAsync(() => h.db.select(h.db.tracks).get()))!, hasLength(4));
      await h.dispose(tester);
    });
  });

  group('the editor', () {
    // Opens the editor as a pushed page (so «Salva» can close it); [rules] makes an existing playlist first.
    Future<int?> openEditor(WidgetTester tester, {String? rules, SmartSort sort = SmartSort.title, int? limit, List<Override> overrides = const []}) async {
      h = await Harness.create(tester, tracks: 4);
      repo = SmartPlaylistRepository(h.db, TrackRepository(h.db));
      tester.view.physicalSize = const Size(400, 2400); // tall: every card is built
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      int? id;
      SmartPlaylist? existing;
      if (rules != null) {
        final made = await make(tester, 'Prima', rules, sort: sort, limit: limit);
        id = made;
        existing = await tester.runAsync<SmartPlaylist?>(() => repo.get(made));
      }
      await h.pump(tester, Scaffold(body: Builder(builder: (c) => TextButton(
          onPressed: () => Navigator.of(c).push(MaterialPageRoute<bool>(builder: (_) => SmartPlaylistEditor(existing: existing))),
          child: const Text('open')))), extraOverrides: overrides);
      await tester.tap(find.text('open'));
      await _settle(tester);
      return id;
    }

    Future<void> addFilter(WidgetTester tester, String field) async {
      await tester.ensureVisible(find.text('Aggiungi filtro'));
      await tester.tap(find.text('Aggiungi filtro'));
      await _settle(tester);
      await tester.tap(find.descendant(of: find.byType(ListTile), matching: find.text(field)));
      await _settle(tester);
    }

    Future<String> savedRules(WidgetTester tester) async {
      await tester.tap(find.text('Salva'));
      await _settle(tester);
      return (await tester.runAsync(() => repo.getAll()))!.single.rules;
    }

    Finder saveButton() => find.widgetWithText(FilledButton, 'Salva');

    testWidgets('«Salva» waits for a complete filter, then needs a name', (tester) async {
      await openEditor(tester);
      expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
      await addFilter(tester, 'Anno');
      expect(find.text('Incompleto: completalo o rimuovilo per salvare.'), findsOneWidget);
      expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull, reason: 'an empty card is not a filter');
      await tester.enterText(find.widgetWithText(TextFormField, 'Da'), '1990');
      await _settle(tester);
      expect(find.text('Incompleto: completalo o rimuovilo per salvare.'), findsNothing);
      await tester.tap(saveButton());
      await _settle(tester);
      expect(find.text('Scrivi un nome'), findsOneWidget);
      expect(await tester.runAsync(() => repo.getAll()), isEmpty);
      await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Mia');
      await tester.tap(saveButton());
      await _settle(tester);
      final saved = (await tester.runAsync(() => repo.getAll()))!.single;
      expect((saved.name, saved.rules), ('Mia', 'anno:1990..'));
      expect(find.text('open'), findsOneWidget, reason: 'the editor closed');
      await h.dispose(tester);
    });

    testWidgets('values come from a list with counts; «Almeno una» joins filters with OR; «Escludi» negates', (tester) async {
      await openEditor(tester);
      await addFilter(tester, 'Artista');
      await tester.tap(find.text('Scegli i valori'));
      await _settle(tester);
      expect(find.descendant(of: find.byType(CheckboxListTile), matching: find.text('4 brani')), findsOneWidget, reason: 'the count of the value');
      await tester.tap(find.byKey(const ValueKey('value:Artist')));
      await tester.tap(find.text('Fatto'));
      await _settle(tester);
      await addFilter(tester, 'Preferiti');
      await tester.tap(find.text('Almeno una'));
      await tester.tap(find.text('Escludi').last);
      await _settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Mix');
      expect(await savedRules(tester), 'artista:"Artist", OR -preferiti');
      await h.dispose(tester);
    });

    testWidgets('dates and numbers: «Negli ultimi N giorni», «Da più di N giorni», da…a', (tester) async {
      await openEditor(tester);
      await addFilter(tester, 'Aggiunto');
      await tester.enterText(find.widgetWithText(TextFormField, 'giorni'), '30');
      await addFilter(tester, 'Ultimo ascolto');
      await tester.tap(find.text('Da più di').last);
      await _settle(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'giorni').last, '7');
      await addFilter(tester, 'Durata');
      await tester.enterText(find.widgetWithText(TextFormField, 'Da'), '2');
      await tester.enterText(find.widgetWithText(TextFormField, 'A'), '5');
      await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Date');
      expect(await savedRules(tester), 'aggiunto<30g ultimoascolto>7g durata:2m..5m');
      await h.dispose(tester);
    });

    testWidgets('an existing playlist opens filled in and saves the same string', (tester) async {
      const rules = 'artista:"Artist", -genere:live ascolti>0 anno:1990..1999 durata:..5m';
      final id = await openEditor(tester, rules: rules);
      expect(find.text('Incompleto: completalo o rimuovilo per salvare.'), findsNothing);
      expect(find.text('Modifica playlist intelligente'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'live'), findsOneWidget, reason: 'a contains filter, excluded');
      expect(find.widgetWithText(TextFormField, 'Più di'), findsOneWidget, reason: 'ascolti>0 keeps its operator');
      await tester.tap(saveButton());
      await _settle(tester);
      expect((await tester.runAsync(() => repo.get(id!)))!.rules, rules);
      await h.dispose(tester);
    });

    testWidgets('a rule the cards cannot show is said so, kept in «Avanzate» and saved untouched', (tester) async {
      const rules = 'preferiti OR anno:2000.. album:x'; // the repository stores the canonical text
      final id = await openEditor(tester, rules: rules);
      expect(find.textContaining('troppo articolata'), findsOneWidget);
      expect(find.text('Aggiungi filtro'), findsNothing);
      expect(find.text(rules), findsOneWidget, reason: 'Avanzate is open, with the stored text');
      await tester.tap(saveButton());
      await _settle(tester);
      expect((await tester.runAsync(() => repo.get(id!)))!.rules, rules, reason: 'not rewritten');
      await h.dispose(tester);
    });

    testWidgets('«Avanzate» shows the canonical text, read only', (tester) async {
      await openEditor(tester, rules: 'preferiti');
      expect(find.text('preferiti'), findsNothing);
      await tester.tap(find.text('Avanzate'));
      await _settle(tester);
      expect(find.text('preferiti'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('a live count at the bottom, capped by the limit', (tester) async {
      await openEditor(tester, rules: 'album:"Album 1"');
      expect(find.text('2 brani'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Limite'), '1');
      await _settle(tester);
      expect(find.text('1 brano'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('a template fills the name, the filters, the order and the limit', (tester) async {
      await openEditor(tester);
      await tester.tap(find.text('I più ascoltati'));
      await _settle(tester);
      expect(find.widgetWithText(TextField, 'I più ascoltati'), findsOneWidget, reason: 'the name');
      expect(find.widgetWithText(TextFormField, 'Più di'), findsOneWidget, reason: 'the filter');
      expect(find.text('50'), findsOneWidget);
      expect(find.textContaining('Più ascoltati'), findsOneWidget, reason: 'the order');
      await h.dispose(tester);
    });

    testWidgets('editing updates the playlist', (tester) async {
      final id = await openEditor(tester, rules: 'preferiti', sort: SmartSort.year, limit: 7);
      expect(find.widgetWithText(TextField, 'Prima'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Prima'), 'Dopo');
      await tester.enterText(find.widgetWithText(TextField, '7'), '');
      await tester.tap(find.text('Salva'));
      await _settle(tester);
      final p = (await tester.runAsync(() => repo.get(id!)))!;
      expect((p.name, p.limitCount, p.sort, p.rules), ('Dopo', null, 'year', 'preferiti'));
      await h.dispose(tester);
    });

    testWidgets('Back with edits asks first; «Annulla» stays, «Scarta» leaves; untouched leaves at once', (tester) async {
      await openEditor(tester);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SmartPlaylistEditor), findsNothing, reason: 'nothing typed: no question');
      await tester.tap(find.text('open'));
      await _settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Mia');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await _settle(tester);
      expect(find.text('Scartare le modifiche?'), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await _settle(tester);
      expect(find.byType(SmartPlaylistEditor), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await _settle(tester);
      await tester.tap(find.text('Scarta'));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SmartPlaylistEditor), findsNothing);
      await h.dispose(tester);
    });

    testWidgets('an existing playlist with an empty rule still saves (rename, order, limit)', (tester) async {
      final id = await openEditor(tester, rules: '');
      expect(tester.widget<FilledButton>(saveButton()).onPressed, isNotNull);
      await tester.enterText(find.widgetWithText(TextField, 'Prima'), 'Tutta');
      await tester.tap(saveButton());
      await _settle(tester);
      final p = (await tester.runAsync(() => repo.get(id!)))!;
      expect((p.name, p.rules), ('Tutta', ''));
      await h.dispose(tester);
    });

    testWidgets('«Ricomincia con i filtri» frees an elaborate rule, with undo', (tester) async {
      final id = await openEditor(tester, rules: 'colore:rosso OR anno:2000..');
      final stored = (await tester.runAsync(() => repo.get(id!)))!.rules;
      await tester.tap(find.text('Ricomincia con i filtri'));
      await _settle(tester);
      expect(find.text('Aggiungi filtro'), findsOneWidget);
      expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull, reason: 'now it needs a filter');
      await tester.tap(find.text('Annulla'));
      await _settle(tester);
      expect(find.textContaining('troppo articolata'), findsOneWidget);
      await tester.tap(saveButton());
      await _settle(tester);
      expect((await tester.runAsync(() => repo.get(id!)))!.rules, stored);
      await h.dispose(tester);
    });

    testWidgets('filling both ends turns «Più di» into a «da…a» range; one end left brings the operator back', (tester) async {
      final id = await openEditor(tester, rules: 'ascolti>0');
      expect(find.widgetWithText(TextFormField, 'Più di'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'A'), '5');
      await _settle(tester);
      expect(find.widgetWithText(TextFormField, 'Più di'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Da'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'A'), '');
      await _settle(tester);
      expect(find.widgetWithText(TextFormField, 'Più di'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'A'), '5');
      await tester.tap(saveButton());
      await _settle(tester);
      expect((await tester.runAsync(() => repo.get(id!)))!.rules, 'ascolti:0..5');
      await h.dispose(tester);
    });

    testWidgets('days are whole numbers, and what is saved opens again as a card', (tester) async {
      await openEditor(tester);
      await addFilter(tester, 'Aggiunto');
      await tester.enterText(find.widgetWithText(TextFormField, 'giorni'), '3.5');
      await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Giorni');
      final rules = await savedRules(tester);
      expect(rules, 'aggiunto<35g');
      expect(FilterModel.fromExpr(parseRules(rules).expr), isNotNull);
      await h.dispose(tester);
    });

    testWidgets('a half-done card blocks «Salva» and says why', (tester) async {
      await openEditor(tester);
      await addFilter(tester, 'Anno');
      await tester.enterText(find.widgetWithText(TextFormField, 'Da'), '1990');
      await addFilter(tester, 'Durata');
      expect(find.text('Incompleto: completalo o rimuovilo per salvare.'), findsOneWidget);
      expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
      await tester.tap(find.byTooltip('Rimuovi filtro').last);
      await _settle(tester);
      expect(tester.widget<FilledButton>(saveButton()).onPressed, isNotNull);
      await h.dispose(tester);
    });

    testWidgets('the count shows a dash for a new empty rule, and says when it fails', (tester) async {
      await openEditor(tester);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('4 brani'), findsNothing);
      await h.dispose(tester);
      await openEditor(tester, rules: 'preferiti', overrides: [
        liveRuleCountProvider.overrideWith((ref, a) async => throw StateError('boom')),
      ]);
      expect(find.text('Conteggio non disponibile'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('tag and format compare the whole value: the field says «È», not «Contiene»', (tester) async {
      await openEditor(tester, rules: 'tag:rock genere:live');
      expect(find.widgetWithText(TextFormField, 'È'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Contiene'), findsOneWidget, reason: 'the genre is a substring');
      await h.dispose(tester);
    });

    testWidgets('a duration that is not whole minutes shows as m:ss and saves the same rule', (tester) async {
      final id = await openEditor(tester, rules: 'durata:200s..');
      expect(find.text('3:20'), findsOneWidget);
      await tester.tap(saveButton());
      await _settle(tester);
      expect((await tester.runAsync(() => repo.get(id!)))!.rules, 'durata:200s..');
      await h.dispose(tester);
    });

    testWidgets('numbers outside the domain leave the card incomplete and never throw', (tester) async {
      for (final v in ['NaN', '-5', 'Infinity', '1e400', '9' * 400]) {
        final y = FilterCard(FilterKind.number, field: RuleField.year, from: v);
        expect(y.toExpr(), isNull, reason: v);
        final d = FilterCard(FilterKind.number, field: RuleField.duration, to: v);
        expect(d.toExpr(), isNull, reason: v);
        final a = FilterCard(FilterKind.age, field: RuleField.added, from: v);
        expect(a.toExpr(), isNull, reason: v);
        expect(FilterModel(cards: [y, d, a]).rules, '');
      }
      FilterCard dur(String v) => FilterCard(FilterKind.number, field: RuleField.duration, from: v);
      expect(dur('1:75').toExpr(), isNull, reason: 'seconds stop at 59');
      expect(dur('1:59').toExpr(), isNotNull);
    });

    testWidgets('a text made only of quotes is not a filter', (tester) async {
      for (final v in ['"', '""', ' " " ']) {
        expect(FilterCard(FilterKind.text, field: RuleField.folder, text: v).toExpr(), isNull, reason: v);
      }
      expect(FilterCard(FilterKind.text, field: RuleField.folder, text: 'a').toExpr(), isNotNull);
    });

    testWidgets('number fields take only digits and separators (m:ss for durations)', (tester) async {
      await openEditor(tester);
      await addFilter(tester, 'Durata');
      await tester.enterText(find.widgetWithText(TextFormField, 'Da'), 'ab1:3x0-');
      await _settle(tester);
      expect(find.text('1:30'), findsOneWidget);
      await addFilter(tester, 'Anno');
      await tester.enterText(find.widgetWithText(TextFormField, 'Da').last, '19e9-0');
      await _settle(tester);
      expect(find.text('1990'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('a value picked then closed by swiping down still counts', (tester) async {
      await openEditor(tester);
      await addFilter(tester, 'Artista');
      await tester.tap(find.text('Scegli i valori'));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('value:Artist')));
      await tester.tapAt(const Offset(200, 20)); // the barrier above the sheet
      await _settle(tester);
      expect(find.text('Artist'), findsOneWidget, reason: 'the value became a chip');
      expect(find.text('Incompleto: completalo o rimuovilo per salvare.'), findsNothing);
      await h.dispose(tester);
    });

    testWidgets('the bottom bar goes away while the keyboard is up', (tester) async {
      await openEditor(tester);
      expect(saveButton(), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      expect(saveButton(), findsNothing);
      await h.dispose(tester);
    });

    testWidgets('number and limit fields have a spoken name', (tester) async {
      final sem = tester.ensureSemantics();
      try {
        await openEditor(tester);
        await addFilter(tester, 'Anno');
        expect(find.bySemanticsLabel(RegExp('^Anno: Da')), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('^Anno: A')), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('Limite')), findsWidgets);
        await h.dispose(tester);
      } finally {
        sem.dispose();
      }
    });

    testWidgets('a rule the cards cannot print back identically (durata>1.9s) is kept untouched', (tester) async {
      final id = await openEditor(tester, rules: 'durata>1.9s');
      expect(find.textContaining('troppo articolata'), findsOneWidget);
      final stored = (await tester.runAsync(() => repo.get(id!)))!.rules;
      await tester.tap(saveButton());
      await _settle(tester);
      expect((await tester.runAsync(() => repo.get(id!)))!.rules, stored);
      await h.dispose(tester);
    });

    testWidgets('a single «>=» end opens as a card and saves the same rule', (tester) async {
      for (final rules in ['bpm>=90', 'anno>=2000']) {
        final id = await openEditor(tester, rules: rules);
        expect(find.textContaining('troppo articolata'), findsNothing, reason: rules);
        await tester.tap(saveButton());
        await _settle(tester);
        expect((await tester.runAsync(() => repo.get(id!)))!.rules, rules);
        await h.dispose(tester);
      }
    });

    testWidgets('tap targets and labels hold (48 dp, named, contrast)', (tester) async {
      final sem = tester.ensureSemantics();
      try {
        await openEditor(tester, rules: 'artista:"Artist", -genere:live ascolti>0 aggiunto<30g preferiti');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await h.dispose(tester);
      } finally {
        sem.dispose();
      }
    });
  });

  group('the library', () {
    testWidgets('shows smart playlists beside the others, with their own cover, and opens them', (tester) async {
      h = await Harness.create(tester, tracks: 4);
      repo = SmartPlaylistRepository(h.db, TrackRepository(h.db));
      await make(tester, 'Intelligente', 'preferiti');
      await tester.runAsync(() => PlaylistRepository(h.db).create('Normale'));
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await h.pump(tester, const Scaffold(body: LibraryScreen()));
      await _settle(tester);
      expect(find.text('Intelligente'), findsOneWidget);
      expect(find.text('Playlist intelligente'), findsOneWidget);
      expect(find.text('Normale'), findsOneWidget);
      expect(find.byType(SmartCover), findsOneWidget);
      await tester.tap(find.text('Intelligente'));
      await _settle(tester);
      expect(find.byType(SmartPlaylistScreen), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('the + menu offers a new smart playlist', (tester) async {
      h = await Harness.create(tester, tracks: 4);
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await h.pump(tester, const Scaffold(body: LibraryScreen()));
      await _settle(tester);
      await tester.tap(find.byTooltip('Nuova playlist'));
      await _settle(tester);
      await tester.tap(find.text('Nuova playlist intelligente'));
      await _settle(tester);
      expect(find.byType(SmartPlaylistEditor), findsOneWidget);
      await h.dispose(tester);
    });
  });
}
