import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/ui/screens/playlists/playlist_detail_screen.dart';
import 'package:codecore/ui/screens/playlists/playlist_order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Track _t(int i, String title, {int year = 0, int added = 0}) => Track(
      id: i,
      path: '/$i',
      title: title,
      albumKey: 'k',
      format: 'mp3',
      sizeBytes: 1,
      mtimeMs: 1,
      addedAt: added,
      year: year,
      durationMs: 0,
      coverSource: 0,
      enrichStatus: 0,
      hasCover: false,
      ignored: false,
      isFavorite: false,
      kind: 0,
      missing: false,
      playCount: 0,
      userEdited: false,
    );

void main() {
  test('order parses, falls back to personal, and sorts without touching the input', () {
    expect(PlaylistOrder.parse(null).sort, PlaylistSort.personal);
    expect(PlaylistOrder.parse('bogus:asc').sort, PlaylistSort.personal);
    final o = PlaylistOrder.parse('title:desc');
    expect(o.encode(), 'title:desc');
    final src = [_t(1, 'b'), _t(2, 'C'), _t(3, 'a')];
    expect([for (final t in o.apply(src)) t.title], ['C', 'b', 'a']);
    expect([for (final t in src) t.id], [1, 2, 3]);
  });

  testWidgets('another order hides «Modifica ordine» and leaves position alone',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 3);
    final id = (await tester.runAsync(() async {
      final repo = PlaylistRepository(h.db);
      final id = await repo.create('Notte');
      await repo.addTracks(id, [for (final t in await h.db.select(h.db.tracks).get()) t.id]);
      return id;
    }))!;
    await h.pump(tester,
        PlaylistDetailScreen(playlist: Playlist(id: id, name: 'Notte', createdAt: 0, updatedAt: 0)));
    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    await settle();
    await tester.tap(find.byTooltip('Altre azioni'));
    await settle();
    expect(find.text('Modifica ordine'), findsOneWidget);
    await tester.tap(find.text('Ordina per'));
    await settle();
    await tester.tap(find.text('Titolo'));
    await settle();
    expect(h.store.readSettings().playlistSorts['$id'], 'title:asc');
    await tester.tap(find.byTooltip('Altre azioni'));
    await settle();
    expect(find.text('Modifica ordine'), findsNothing);
    final rows = await tester.runAsync(() => h.db.select(h.db.playlistTracks).get());
    expect([for (final r in rows!) r.position]..sort(), [0, 1, 2]);
    await h.dispose(tester);
  });

  testWidgets('descending title order is shown, and play and a row tap follow it',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 3);
    final id = (await tester.runAsync(() async {
      final repo = PlaylistRepository(h.db);
      final id = await repo.create('Notte');
      await repo.addTracks(id, [for (final t in await h.db.select(h.db.tracks).get()) t.id]);
      return id;
    }))!;
    await h.pump(tester,
        PlaylistDetailScreen(playlist: Playlist(id: id, name: 'Notte', createdAt: 0, updatedAt: 0)));
    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> openSort() async {
      await tester.tap(find.byTooltip('Altre azioni'));
      await settle();
      await tester.tap(find.text('Ordina per'));
      await settle();
    }

    await settle();
    await openSort();
    await tester.tap(find.text('Titolo'));
    await settle();
    await openSort();
    await tester.tap(find.text('Decrescente'));
    await settle();
    await tester.tapAt(const Offset(200, 20)); // closes the sheet
    await settle();
    expect(h.store.readSettings().playlistSorts['$id'], 'title:desc');
    final ys = [for (var n = 2; n >= 0; n--) tester.getTopLeft(find.text('Song $n')).dy];
    expect(ys, orderedEquals([...ys]..sort()));

    Future<List<int>> queue() async {
      for (var i = 0; i < 100 && h.handler.queueIds.isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
      return h.handler.queueIds.toList();
    }

    final byTitle = {
      for (final t in (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!) t.title: t.id,
    };
    final want = [byTitle['Song 2']!, byTitle['Song 1']!, byTitle['Song 0']!];
    await tester.tap(find.text('Song 1'));
    await settle();
    expect(await queue(), want);
    await tester.tap(find.widgetWithText(FilledButton, 'Riproduci'));
    await settle();
    expect(await queue(), want);
    await h.dispose(tester);
  });
}
