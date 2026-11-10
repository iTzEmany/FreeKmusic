import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/ui/screens/library/album_detail_screen.dart';
import 'package:codecore/ui/screens/library/artist_screen.dart';
import 'package:codecore/ui/screens/library/favorites_screen.dart';
import 'package:codecore/ui/screens/playlists/playlist_detail_screen.dart';
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:codecore/ui/widgets/cover_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  test('collectionMeta in words', () {
    final l = lookupAppLocalizations(const Locale('it'));
    expect(collectionMeta(l, year: 2004, tracks: 12, durationMs: 48 * 60000),
        '2004, 12 brani, 48 minuti');
    expect(collectionMeta(l, tracks: 32, durationMs: 112 * 60000),
        '32 brani, 1 ora e 52 minuti');
    expect(collectionMeta(l, albums: 6, tracks: 84, durationMs: 300 * 60000),
        '6 album, 84 brani, 5 ore');
    expect(collectionMeta(l, tracks: 1, durationMs: 20000), '1 brano, 1 minuto');
    expect(collectionMeta(l, tracks: 0, durationMs: 0), 'Nessun brano');
  });

  testWidgets('album page: «Casuale» leaves the playing queue alone, the next Play is shuffled (D-534)',
      (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 4);
    await tester.runAsync(() => h.handler.playQueue([3, 4], 0)); // another list
    await h.pump(
        tester,
        const AlbumDetailScreen(
            album: AlbumSummary(
          albumKey: 'artist|album 0',
          title: 'Album 0',
          artist: 'Artist',
          variousArtists: false,
          trackCount: 2,
          durationMs: 370000,
          year: 2019,
          coverKey: null,
        )));
    await _settle(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('Casuale'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.handler.shuffleEnabled, isFalse);
    expect(h.handler.queueIds, [3, 4]);
    await tester.runAsync(() async {
      await tester.tap(find.text('Riproduci'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    expect(h.handler.shuffleEnabled, isTrue);
    expect(h.handler.sourceIds, isNot([3, 4]));
    await h.dispose(tester);
  });

  testWidgets('album page: header, Play, disc-less rows, artist link',
      (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(
        tester,
        const AlbumDetailScreen(
            album: AlbumSummary(
          albumKey: 'artist|album 0',
          title: 'Album 0',
          artist: 'Artist',
          variousArtists: false,
          trackCount: 2,
          durationMs: 370000,
          year: 2019,
          coverKey: null,
        )));
    await _settle(tester);
    expect(find.text('Album 0'), findsWidgets);
    expect(find.text('Artist'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Riproduci'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Casuale'), findsOneWidget);
    expect(find.text('Song 0'), findsOneWidget);
    expect(find.textContaining('2019'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  AlbumSummary album(String title) => AlbumSummary(
        albumKey: 'artist|album 0',
        title: title,
        artist: 'Artist',
        variousArtists: false,
        trackCount: 2,
        durationMs: 370000,
        year: 2019,
        coverKey: null,
      );

  testWidgets('header: cover left of the name, no backdrop', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, AlbumDetailScreen(album: album('Album 0')));
    await _settle(tester);
    expect(find.byType(CoverBackdrop), findsNothing);
    final cover = tester.getRect(find.byKey(const ValueKey('collection-cover')));
    final name = tester.getRect(find.byKey(const ValueKey('collection-name')));
    expect(cover.left, CcDims.margin);
    expect(name.left, greaterThan(cover.right));
    await h.dispose(tester);
  });

  testWidgets('header stacks at 150 % on 360 dp', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(
      tester,
      MediaQuery(
        data: const MediaQueryData(
            size: Size(360, 780), textScaler: TextScaler.linear(1.5)),
        child: AlbumDetailScreen(album: album('A very long album name ' * 4)),
      ),
    );
    await _settle(tester);
    final cover = tester.getRect(find.byKey(const ValueKey('collection-cover')));
    final name = tester.getRect(find.byKey(const ValueKey('collection-name')));
    expect(name.top, greaterThan(cover.bottom));
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('artist page: counts, Play and the albums', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(
        tester,
        const ArtistDetailScreen(
            artist: ArtistSummary(
                key: 'artist', name: 'Artist', trackCount: 4, albumCount: 2)));
    await _settle(tester);
    expect(find.text('Artist'), findsWidgets);
    expect(find.textContaining('2 album, 4 brani'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Riproduci'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Casuale'), findsOneWidget);
    expect(find.text('Album 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('playlist page: tracks, edit mode with handles', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 3);
    final id = await tester.runAsync(() async {
      final repo = PlaylistRepository(h.db);
      final id = await repo.create('Notte');
      final rows = await h.db.select(h.db.tracks).get();
      await repo.addTracks(id, [for (final t in rows) t.id]);
      return id;
    });
    await h.pump(
        tester,
        PlaylistDetailScreen(
            playlist: Playlist(id: id!, name: 'Notte', createdAt: 0, updatedAt: 0)));
    await _settle(tester);
    expect(find.text('Notte'), findsWidgets);
    expect(find.text('Song 0'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Riproduci'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Casuale'), findsOneWidget);
    await tester.tap(find.byTooltip('Altre azioni'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Modifica ordine'));
    await _settle(tester);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('favourites page: empty state and Play', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 2);
    await h.pump(tester, const FavoritesScreen());
    await _settle(tester);
    expect(find.text('Preferiti'), findsWidgets);
    expect(find.text('Nessun preferito, per ora'), findsOneWidget);
    expect(find.text('Riproduci'), findsNothing);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('empty collection hides the pills, keeps the menu', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 1);
    final id = await tester.runAsync(() => PlaylistRepository(h.db).create('Vuota'));
    await h.pump(
        tester,
        PlaylistDetailScreen(
            playlist: Playlist(id: id!, name: 'Vuota', createdAt: 0, updatedAt: 0)));
    await _settle(tester);
    expect(find.text('Riproduci'), findsNothing);
    expect(find.text('Casuale'), findsNothing);
    expect(find.byTooltip('Altre azioni'), findsOneWidget);
    await h.dispose(tester);
  });
}
