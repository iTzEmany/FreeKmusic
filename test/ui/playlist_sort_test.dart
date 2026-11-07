import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/ui/screens/playlists/playlist_detail_screen.dart';
import 'package:codecore/ui/screens/playlists/playlist_order.dart';
import 'package:codecore/ui/widgets/playlist_cover.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Track _t(int i, String? title, {int plays = 0, int? last, int year = 0, int added = 0, int duration = 0, String? artist, String? album}) => Track(
      id: i,
      path: '/$i',
      title: title ?? '',
      artist: artist,
      album: album,
      albumKey: 'k',
      format: 'mp3',
      sizeBytes: 1,
      mtimeMs: 1,
      addedAt: added,
      year: year,
      durationMs: duration,
      coverSource: 0,
      enrichStatus: 0,
      hasCover: false,
      ignored: false,
      isFavorite: false,
      kind: 0,
      missing: false,
      playCount: plays,
      lastPlayedAt: last,
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

  List<int> ids(PlaylistOrder o, List<Track> src) => [for (final t in o.apply(src)) t.id];

  test('text orders fold accents like the Library', () {
    final src = [
      for (final (i, n) in ['Zeta', 'Édith', 'alfa', 'Èlan', 'beta'].indexed) _t(i, n, artist: n, album: n),
    ];
    for (final o in ['title', 'artist', 'album']) {
      expect(ids(PlaylistOrder.parse('$o:asc'), src), [2, 4, 1, 3, 0], reason: o);
    }
  });

  test('missing values come last in both directions', () {
    final src = [
      _t(0, 'b', year: 0, duration: 0),
      _t(1, '', year: 1990, duration: 100),
      _t(2, 'a', year: 2000, duration: 200),
      _t(3, null, year: 1980, duration: 300),
    ];
    expect(ids(PlaylistOrder.parse('title:asc'), src), [2, 0, 1, 3]);
    expect(ids(PlaylistOrder.parse('title:desc'), src), [0, 2, 1, 3]);
    expect(ids(PlaylistOrder.parse('year:asc'), src), [3, 1, 2, 0]);
    expect(ids(PlaylistOrder.parse('year:desc'), src), [2, 1, 3, 0]);
    expect(ids(PlaylistOrder.parse('duration:asc'), src), [1, 2, 3, 0]);
    expect(ids(PlaylistOrder.parse('duration:desc'), src), [3, 2, 1, 0]);
  });

  test('recent and plays: never played last, bigger first, ties keep the personal order', () {
    final src = [
      _t(0, 'a', plays: 2, last: 50),
      _t(1, 'b'),
      _t(2, 'c', plays: 9, last: 90),
      _t(3, 'd', plays: 2, last: 50),
    ];
    expect(ids(PlaylistOrder.parse('recent:desc'), src), [2, 0, 3, 1]);
    expect(ids(PlaylistOrder.parse('recent:asc'), src), [0, 3, 2, 1]);
    expect(ids(PlaylistOrder.parse('plays:desc'), src), [2, 0, 3, 1]);
    expect(ids(PlaylistOrder.parse('plays:asc'), src), [1, 0, 3, 2]);
    expect(PlaylistSort.recent.ascendingByDefault, isFalse);
    expect(PlaylistSort.plays.ascendingByDefault, isFalse);
    expect(PlaylistOrder.parse('plays:desc').sort, PlaylistSort.plays);
  });

  testWidgets('the mosaic keeps the personal order whatever the view order', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 6);
    final id = (await tester.runAsync(() async {
      final all = await h.db.select(h.db.tracks).get();
      for (final t in all) {
        await (h.db.update(h.db.tracks)..where((x) => x.id.equals(t.id)))
            .write(TracksCompanion(coverKey: Value('c${t.id}')));
      }
      final repo = PlaylistRepository(h.db);
      final id = await repo.create('Notte');
      await repo.addTracks(id, [for (final t in all) t.id]);
      await h.store.writeSettings(h.store
          .readSettings()
          .copyWith(playlistSorts: {'$id': 'title:desc'}));
      return id;
    }))!;
    await h.pump(tester,
        PlaylistDetailScreen(playlist: Playlist(id: id, name: 'Notte', createdAt: 0, updatedAt: 0)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final first4 = [for (final t in (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!.take(4)) 'c${t.id}'];
    expect(tester.widget<PlaylistCover>(find.byType(PlaylistCover).first).coverKeys, first4);
    await h.dispose(tester);
  });

  test('equal keys keep the personal order, also descending, on a long list', () {
    final src = [for (var i = 0; i < 500; i++) _t(i, 'same')];
    expect(ids(PlaylistOrder.parse('title:desc'), src), [for (var i = 0; i < 500; i++) i]);
  });

  testWidgets('another order hides «Modifica ordine» and leaves position alone',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 6);
    final id = (await tester.runAsync(() async {
      // Titles by position b d f a e c: alphabetical order is [3,0,5,1,4,2].
      final all = await h.db.select(h.db.tracks).get();
      for (final (i, n) in ['b', 'd', 'f', 'a', 'e', 'c'].indexed) {
        await (h.db.update(h.db.tracks)..where((t) => t.id.equals(all[i].id)))
            .write(TracksCompanion(title: Value(n)));
      }
      final repo = PlaylistRepository(h.db);
      final id = await repo.create('Notte');
      await repo.addTracks(id, [for (final t in all) t.id]);
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
    Future<List<String>> pairs() async => [
          for (final r in (await tester.runAsync(() => h.db.select(h.db.playlistTracks).get()))!)
            '${r.trackId}@${r.position}',
        ]..sort();
    final before = await pairs();
    expect(before, hasLength(6));
    Future<void> openSort() async {
      await tester.tap(find.byTooltip('Altre azioni'));
      await settle();
      await tester.tap(find.text('Ordina per'));
      await settle();
    }

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
    expect(await pairs(), before);
    await tester.tapAt(const Offset(200, 20)); // closes the menu
    await settle();
    await openSort();
    await tester.tap(find.text('Decrescente'));
    await settle();
    await tester.tapAt(const Offset(200, 20));
    await settle();
    expect(h.store.readSettings().playlistSorts['$id'], 'title:desc');
    expect(await pairs(), before);
    await openSort();
    await tester.tap(find.text('Durata'));
    await settle();
    expect(await pairs(), before);
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
