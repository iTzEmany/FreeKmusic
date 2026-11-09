import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/credits_repository.dart';
import 'package:codecore/ui/screens/lyrics/lyrics_screen.dart';
import 'package:codecore/ui/shell/side_panel.dart';
import 'package:codecore/providers/nav_providers.dart' show SidePanel;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

const _lrc = '[00:01.00]Hello\n[00:05.00]World';

void main() {
  Future<Harness> open(
    WidgetTester tester, {
    String? plain,
    String? synced,
    Set<int> unsynced = const {},
  }) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 1);
    await tester.runAsync(() async {
      await h.db
          .update(h.db.tracks)
          .write(
            TracksCompanion(
              lyricsPlain: Value(plain),
              lyricsSynced: Value(synced),
            ),
          );
      await h.handler.playQueue([
        (await h.db.select(h.db.tracks).get()).single.id,
      ], 0);
    });
    await tester.runAsync(() => h.store.writeUnsyncedLyrics(unsynced));
    await h.pump(tester, const LyricsScreen());
    await tester.pump(const Duration(milliseconds: 200));
    return h;
  }

  Future<(Track, TrackEnrichData?)> stored(
    WidgetTester tester,
    Harness h,
  ) async => (await tester.runAsync(
    () async => (
      (await h.db.select(h.db.tracks).get()).single,
      await CreditsRepository(h.db).enrichOf(1),
    ),
  ))!;

  Future<void> menu(WidgetTester tester, String item) async {
    await tester.tap(find.byTooltip('Altre azioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'typing timed lines saves them as synced and as the user\'s own',
    (tester) async {
      final h = await open(tester);
      await tester.tap(find.text('Scrivi o incolla'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), _lrc);
      await tester.pump();
      expect(
        find.textContaining('Riconosciuto come sincronizzato: 2'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('lyrics-save')));
      await tester.pumpAndSettle();
      final (t, e) = await stored(tester, h);
      expect(t.lyricsSynced, _lrc);
      expect(t.lyricsPlain, 'Hello\nWorld');
      expect(e?.lyricsByUser, isTrue);
      await h.dispose(tester);
    },
  );

  testWidgets('untimed text is saved as plain; empty text is refused', (
    tester,
  ) async {
    final h = await open(tester);
    await tester.tap(find.text('Scrivi o incolla'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lyrics-save')));
    await tester.pumpAndSettle();
    expect(find.text('Scrivi qualcosa prima di salvare'), findsOneWidget);
    expect((await stored(tester, h)).$1.lyricsPlain, isNull);
    await tester.enterText(find.byType(TextField), 'just words');
    await tester.tap(find.byKey(const ValueKey('lyrics-save')));
    await tester.pumpAndSettle();
    final (t, e) = await stored(tester, h);
    expect((t.lyricsPlain, t.lyricsSynced), ('just words', null));
    expect(e?.lyricsByUser, isTrue);
    await h.dispose(tester);
  });

  testWidgets('Annulla leaves the track untouched', (tester) async {
    final h = await open(tester);
    await tester.tap(find.text('Scrivi o incolla'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'never saved');
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect((await stored(tester, h)).$1.lyricsPlain, isNull);
    expect(find.byType(TextField), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('«Modifica testo» reopens the editor with the stored text', (
    tester,
  ) async {
    final h = await open(tester, plain: 'Hello\nWorld', synced: _lrc);
    await menu(tester, 'Modifica testo');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      _lrc,
    );
    await h.dispose(tester);
  });

  testWidgets(
    '«Elimina testo» clears the text and lets the automatic search try again',
    (tester) async {
      final h = await open(tester, plain: 'Hello\nWorld', synced: _lrc);
      await tester.runAsync(
        () => h.db
            .into(h.db.trackEnrich)
            .insert(
              TrackEnrichCompanion.insert(
                trackId: const Value(1),
                lyricsByUser: const Value(true),
                lyricsNoneAt: const Value(5),
              ),
            ),
      );
      await menu(tester, 'Elimina testo');
      final (t, e) = await stored(tester, h);
      expect((t.lyricsPlain, t.lyricsSynced), (null, null));
      expect((e?.lyricsByUser, e?.lyricsNoneAt), (false, null));
      await h.dispose(tester);
    },
  );

  testWidgets(
    'the sync switch shows the plain text and keeps the synced one; plain-only has no switch',
    (tester) async {
      final h = await open(tester, plain: 'Hello\nWorld', synced: _lrc);
      await menu(tester, 'Testo sincronizzato');
      expect(find.text('Hello\nWorld'), findsOneWidget);
      expect((await stored(tester, h)).$1.lyricsSynced, _lrc);
      await h.dispose(tester);
    },
  );

  testWidgets('no sync switch for a plain text', (tester) async {
    final h = await open(tester, plain: 'Hello');
    await tester.tap(find.byTooltip('Altre azioni'));
    await tester.pumpAndSettle();
    expect(find.text('Testo sincronizzato'), findsNothing);
    expect(find.text('Elimina testo'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('saving a text turns the sync back on for the track', (
    tester,
  ) async {
    final h = await open(
      tester,
      plain: 'Hello\nWorld',
      synced: _lrc,
      unsynced: {1},
    );
    await menu(tester, 'Modifica testo');
    await tester.tap(find.byKey(const ValueKey('lyrics-save')));
    await tester.pumpAndSettle();
    expect(h.store.readUnsyncedLyrics(), isEmpty);
    await h.dispose(tester);
  });

  testWidgets(
    '«Elimina testo» drops the track from the unsynced set and Annulla puts the text back',
    (tester) async {
      final h = await open(
        tester,
        plain: 'Hello\nWorld',
        synced: _lrc,
        unsynced: {1},
      );
      await menu(tester, 'Elimina testo');
      expect(h.store.readUnsyncedLyrics(), isEmpty);
      expect((await stored(tester, h)).$1.lyricsSynced, isNull);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      final (t, e) = await stored(tester, h);
      expect((t.lyricsPlain, t.lyricsSynced), ('Hello\nWorld', _lrc));
      expect(
        e?.lyricsByUser ?? false,
        isFalse,
        reason: 'it was not the user\'s text before',
      );
      expect(h.store.readUnsyncedLyrics(), {1});
      await h.dispose(tester);
    },
  );

  testWidgets(
    'with the sync off the view shows the plain text and the «kept» hint, not the timed lines',
    (tester) async {
      final h = await open(
        tester,
        plain: 'Hello\nWorld',
        synced: _lrc,
        unsynced: {1},
      );
      expect(find.textContaining('Hello'), findsOneWidget);
      expect(
        find.textContaining('La versione sincronizzata è conservata'),
        findsOneWidget,
      );
      await h.dispose(tester);
    },
  );

  testWidgets('the desktop side panel has the lyrics menu', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 1);
    await tester.runAsync(() async {
      await h.db
          .update(h.db.tracks)
          .write(const TracksCompanion(lyricsPlain: Value('Hello')));
      await h.handler.playQueue([
        (await h.db.select(h.db.tracks).get()).single.id,
      ], 0);
    });
    await h.pump(
      tester,
      const Scaffold(body: SidePanelView(panel: SidePanel.lyrics)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byTooltip('Altre azioni'));
    await tester.pumpAndSettle();
    expect(find.text('Modifica testo'), findsOneWidget);
    await h.dispose(tester);
  });
}
