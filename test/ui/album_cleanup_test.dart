import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/ui/screens/library/album_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late Harness h;

  /// Four tracks: Song 0 and 2 in «Album 0», Song 1 and 3 in «Album 1».
  Future<void> open(WidgetTester tester, {int summaryCount = 2, int summaryMs = 370000}) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester, tracks: 4);
    await tester.runAsync(() async {
      await h.db.customUpdate("UPDATE tracks SET cover_key = 'cov0', has_cover = 1 WHERE album = 'Album 0'");
      await h.db.customUpdate("UPDATE tracks SET cover_key = 'cov1', has_cover = 1 WHERE album = 'Album 1'");
    });
    await h.pump(
      tester,
      AlbumDetailScreen(
        album: AlbumSummary(
          albumKey: 'artist|album 0',
          title: 'Album 0',
          artist: 'Artist',
          variousArtists: false,
          trackCount: summaryCount,
          durationMs: summaryMs,
          year: null,
          coverKey: 'cov0',
        ),
      ),
    );
    await _settle(tester);
  }

  Future<Map<String, (String, String?)>> state(WidgetTester tester) async {
    final rows = await tester.runAsync(() => h.db.customSelect('SELECT title, album_key, cover_key FROM tracks').get());
    return {
      for (final r in rows!) r.data['title']! as String: (r.data['album_key']! as String, r.data['cover_key'] as String?),
    };
  }

  /// Drift work started from a dialog moves only while real time passes.
  Future<void> until(WidgetTester tester, Finder f) async {
    for (var i = 0; i < 20 && f.evaluate().isEmpty; i++) {
      await _settle(tester);
    }
  }

  testWidgets('the header counts the rows listed, not the stale summary', (tester) async {
    await open(tester, summaryCount: 3, summaryMs: 555000);
    await _settle(tester);
    expect(find.textContaining('2 brani'), findsOneWidget);
    expect(find.textContaining('3 brani'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('«Unisci con…» folds another album in: one key, the main cover, and undo', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Altre azioni').first);
    await _settle(tester);
    await tester.tap(find.text('Unisci con…'));
    await _settle(tester);

    expect(find.text('Unisci album'), findsWidgets);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('merge-go'))).onPressed, isNull,
        reason: 'nothing picked yet');
    expect(find.byKey(const ValueKey('merge-artist|album 0')), findsNothing, reason: 'the main album is not offered');
    await tester.tap(find.byKey(const ValueKey('merge-artist|album 1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('merge-go')));
    await until(tester, find.text('2 album uniti in «Album 0»'));

    var s = await state(tester);
    expect({for (final v in s.values) v.$1}, {'artist|album 0'}, reason: 'one album key');
    expect({for (final v in s.values) v.$2}, {'cov0'}, reason: 'the cover of the main album');
    expect(find.text('2 album uniti in «Album 0»'), findsOneWidget);

    await tester.tap(find.text('Annulla'));
    await _settle(tester);
    s = await state(tester);
    expect(s['Song 1']!.$1, 'artist|album 1');
    expect(s['Song 1']!.$2, 'cov1');
    expect(s['Song 0']!.$1, 'artist|album 0');
    await h.dispose(tester);
  });

  testWidgets('the merge needs a title and an artist, and the list can be searched', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Altre azioni').first);
    await _settle(tester);
    await tester.tap(find.text('Unisci con…'));
    await _settle(tester);

    await tester.enterText(find.byKey(const ValueKey('merge-search')), 'zzz');
    await tester.pump();
    expect(find.text('Non ci sono altri album'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('merge-search')), 'album 1');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('merge-artist|album 1')));
    await tester.enterText(find.byKey(const ValueKey('merge-title')), '  ');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('merge-go'))).onPressed, isNull);
    await h.dispose(tester);
  });

  testWidgets('selected tracks go to a new album, with the common artist suggested, and undo', (tester) async {
    await open(tester);
    await tester.longPress(find.text('Song 0'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Azioni'));
    await _settle(tester);
    await tester.tap(find.text('Sposta in un nuovo album…'));
    await _settle(tester);

    expect(find.text('Sposta in un album'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('move-artist'))).controller!.text, 'Artist');
    await tester.enterText(find.byKey(const ValueKey('move-title')), 'Bonus');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('move-go')));
    await until(tester, find.text('1 brano spostato in «Bonus»'));

    var s = await state(tester);
    expect(s['Song 0']!.$1, 'artist|bonus');
    expect(s['Song 2']!.$1, 'artist|album 0', reason: 'the others stay');
    expect(find.text('1 brano spostato in «Bonus»'), findsOneWidget);

    await tester.tap(find.text('Annulla'));
    await _settle(tester);
    s = await state(tester);
    expect(s['Song 0']!.$1, 'artist|album 0');
    await h.dispose(tester);
  });
}
