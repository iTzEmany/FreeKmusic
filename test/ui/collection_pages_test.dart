import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/favorite_collections_repository.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/providers/external_share_provider.dart';
import 'package:codecore/data/repositories/track_kinds.dart' show kStreamKind;
import 'package:codecore/providers/favorite_collections_providers.dart' show resolveFavoriteAlbums;
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/providers/keep_offline_providers.dart' show keepOfflineProvider;
import 'package:codecore/ui/screens/library/album_detail_screen.dart';
import 'package:codecore/ui/screens/library/artist_screen.dart';
import 'package:codecore/ui/screens/library/favorites_screen.dart';
import 'package:codecore/ui/screens/playlists/playlist_detail_screen.dart';
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:codecore/ui/widgets/cover_backdrop.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_share.dart';

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

/// Titles of the rows on screen, top to bottom.
List<String> _visibleTitles(WidgetTester t) {
  final rows = find.byType(TrackRow).evaluate().map((e) => e.widget as TrackRow).toList();
  final tops = {
    for (final f in find.textContaining('Song ').evaluate()) (f.widget as Text).data!: t.getTopLeft(find.byWidget(f.widget)).dy,
  };
  expect(tops, hasLength(rows.length));
  return (tops.keys.toList()..sort((a, b) => tops[a]!.compareTo(tops[b]!)));
}

Future<List<String>> _queueTitles(WidgetTester t, Harness h) async {
  final all = await t.runAsync(() => h.db.select(h.db.tracks).get());
  final byId = {for (final r in all!) r.id: r.title};
  return [for (final id in h.handler.queueIds) byId[id]!];
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
      await tester.tap(find.byIcon(Icons.shuffle_rounded));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.handler.shuffleEnabled, isFalse);
    expect(h.handler.queueIds, [3, 4]);
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Riproduci'));
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
    // The artist link is a 48 dp touch target and a named link for TalkBack.
    expect(tester.getSize(find.ancestor(of: find.text('Artist'), matching: find.byType(InkWell)).first).height,
        greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel('Artist'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Artist')).getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(find.byTooltip('Riproduci'), findsOneWidget);
    expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
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

  testWidgets('album page: a row tap queues the visible list, in order, at the tapped row', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, AlbumDetailScreen(album: album('Album 0')));
    await _settle(tester);
    final visible = _visibleTitles(tester);
    expect(visible, hasLength(2));
    await tester.runAsync(() async {
      await tester.tap(find.text(visible[1]));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    expect(await _queueTitles(tester, h), visible);
    expect(h.handler.currentIndex, 1);
    await h.dispose(tester);
  });

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
    expect(find.byTooltip('Riproduci'), findsOneWidget);
    expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
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
    expect(find.byTooltip('Riproduci'), findsOneWidget);
    expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('Altre azioni').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Modifica ordine'));
    await _settle(tester);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  group('playlist page: search (D-490)', () {
    Future<(Harness, int)> open(WidgetTester tester, {bool search = true, int tracks = 4}) async {
      _phone(tester);
      final h = await Harness.create(tester, tracks: tracks);
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
      if (search) {
        await tester.enterText(find.byType(TextField), 'SONG 2');
        await tester.pump(const Duration(seconds: 1));
      }
      return (h, id);
    }

    testWidgets('the filter field is named for TalkBack', (tester) async {
      final (h, _) = await open(tester, search: false);
      expect(find.bySemanticsLabel('Cerca'), findsOneWidget);
      // The hint disappears with text typed: the field keeps its name.
      await tester.enterText(find.byType(TextField), 'x');
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('^Cerca')), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('a result plays the whole playlist from there', (tester) async {
      final (h, _) = await open(tester);
      expect(find.text('Song 1'), findsNothing);
      await tester.runAsync(() async {
        await tester.tap(find.text('Song 2'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      expect(h.handler.currentTrack?.title, 'Song 2');
      expect(h.handler.queueIds, hasLength(4));
      await h.dispose(tester);
    });

    testWidgets('a row tap queues the playlist only, in its order, at the tapped row', (tester) async {
      _phone(tester);
      final h = await Harness.create(tester, tracks: 4);
      final id = await tester.runAsync(() async {
        final repo = PlaylistRepository(h.db);
        final id = await repo.create('Notte');
        final rows = await h.db.select(h.db.tracks).get();
        final byTitle = {for (final r in rows) r.title: r.id};
        // Not all of the library, and not in library order.
        await repo.addTracks(id, [byTitle['Song 3']!, byTitle['Song 1']!, byTitle['Song 2']!]);
        return id;
      });
      await h.pump(
          tester,
          PlaylistDetailScreen(
              playlist: Playlist(id: id!, name: 'Notte', createdAt: 0, updatedAt: 0)));
      await _settle(tester);
      final visible = _visibleTitles(tester);
      expect(visible, hasLength(3));
      expect(find.text('Song 0'), findsNothing);
      await tester.runAsync(() async {
        await tester.tap(find.text(visible[1]));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      expect(await _queueTitles(tester, h), visible);
      expect(h.handler.currentIndex, 1);
      await h.dispose(tester);
    });

    testWidgets('reordering is off while searching', (tester) async {
      final (h, _) = await open(tester);
      await tester.tap(find.byTooltip('Altre azioni').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Modifica ordine'), findsNothing);
      expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
      await h.dispose(tester);
    });

    testWidgets('removing a result takes out that track; Annulla puts it back in its place',
        (tester) async {
      final (h, id) = await open(tester);
      await tester.tap(find.byIcon(Icons.more_vert_rounded).last);
      await _settle(tester);
      await tester.tap(find.text('Rimuovi dalla playlist'));
      await _settle(tester);
      Future<List<String>> titles() async => (await tester.runAsync(
          () => PlaylistRepository(h.db).watchTracks(id).first))!.map((t) => t.title).toList();
      expect(await titles(), ['Song 0', 'Song 1', 'Song 3']);
      await tester.tap(find.text('Annulla'));
      await _settle(tester);
      expect(await titles(), ['Song 0', 'Song 1', 'Song 2', 'Song 3']);
      await h.dispose(tester);
    });

    testWidgets('«select all» takes only the rows the search shows', (tester) async {
      final (h, _) = await open(tester);
      await tester.longPress(find.text('Song 2'));
      await _settle(tester);
      await tester.tap(find.byTooltip('Seleziona tutto'));
      await _settle(tester);
      expect(find.text('1 selezionato'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('a search with no match says so', (tester) async {
      final (h, _) = await open(tester);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Nessun risultato'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('starting a search leaves the reorder mode: no handles, even after clearing it',
        (tester) async {
      final (h, _) = await open(tester, search: false);
      Future<void> menu() async {
        await tester.tap(find.byTooltip('Altre azioni').first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
      }

      await menu();
      await tester.tap(find.text('Modifica ordine'));
      await _settle(tester);
      expect(find.byIcon(Icons.drag_handle_rounded), findsWidgets);
      await tester.enterText(find.byType(TextField), 'SONG 2');
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
      await h.dispose(tester);
    });

    testWidgets('an empty playlist has no search field', (tester) async {
      final (h, _) = await open(tester, search: false, tracks: 0);
      expect(find.byType(TextField), findsNothing);
      await h.dispose(tester);
    });
  });

  testWidgets('playlist page: the pill and Play share one key (toggle, then Play starts shuffled)',
      (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 4);
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
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.shuffle_rounded));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    expect(h.handler.shuffleEnabled, isFalse);
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Riproduci'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    expect(h.handler.shuffleEnabled, isTrue);
    await h.dispose(tester);
  });

  testWidgets('favourites page: empty state and Play', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 2);
    await h.pump(tester, const FavoritesScreen());
    await _settle(tester);
    expect(find.text('Preferiti'), findsWidgets);
    expect(find.text('Nessun preferito, per ora'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Apri tutti i brani'), findsOneWidget);
    expect(find.byTooltip('Riproduci'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Apri tutti i brani'));
    await _settle(tester);
    expect(find.byType(AllTracksScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('playlist page: Condividi icon and «Invia a un dispositivo» in the menu', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 2);
    final id = await tester.runAsync(() async {
      final repo = PlaylistRepository(h.db);
      final id = await repo.create('Notte');
      await repo.addTracks(id, [1, 2]);
      return id;
    });
    await h.pump(tester, PlaylistDetailScreen(playlist: Playlist(id: id!, name: 'Notte', createdAt: 0, updatedAt: 0)));
    await _settle(tester);
    expect(find.byTooltip('Condividi'), findsOneWidget);
    await tester.tap(find.byTooltip('Altre azioni').first);
    await tester.pumpAndSettle();
    expect(find.text('Invia a un dispositivo'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('playlist page of streamed rows only: no «Invia a un dispositivo»', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 2);
    final id = await tester.runAsync(() async {
      final rows = await h.db.select(h.db.tracks).get();
      for (final t in rows) {
        await h.db.update(h.db.tracks).replace(t.copyWith(kind: kStreamKind, path: 'stream:youtube:abcdefghij${t.id}'));
      }
      final repo = PlaylistRepository(h.db);
      final id = await repo.create('Notte');
      await repo.addTracks(id, [for (final t in rows) t.id]);
      return id;
    });
    await h.pump(tester, PlaylistDetailScreen(playlist: Playlist(id: id!, name: 'Notte', createdAt: 0, updatedAt: 0)));
    await _settle(tester);
    await tester.tap(find.byTooltip('Altre azioni').first);
    await tester.pumpAndSettle();
    expect(find.text('Invia a un dispositivo'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('album page: Condividi shares the album text from the icon rectangle', (tester) async {
    _phone(tester);
    final fake = FakeShare();
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, AlbumDetailScreen(album: album('Album 0')), extraOverrides: [externalShareProvider.overrideWithValue(fake)]);
    await _settle(tester);
    await tester.tap(find.byTooltip('Condividi'));
    await _settle(tester);
    expect(fake.texts.single, startsWith('Album 0 - Artist\n1. '));
    expect(fake.origins.single, tester.getRect(find.byTooltip('Condividi')));
    await h.dispose(tester);
  });

  testWidgets('favourites page: Condividi shares the favourite tracks from the icon rectangle', (tester) async {
    _phone(tester);
    final fake = FakeShare();
    final h = await Harness.create(tester, tracks: 2);
    await tester.runAsync(() async {
      final t = (await h.db.select(h.db.tracks).get()).first;
      await h.db.update(h.db.tracks).replace(t.copyWith(isFavorite: true));
    });
    await h.pump(tester, const FavoritesScreen(), extraOverrides: [externalShareProvider.overrideWithValue(fake)]);
    await _settle(tester);
    await tester.tap(find.byTooltip('Condividi'));
    await _settle(tester);
    expect(fake.texts.single, startsWith('Preferiti\n1. '));
    expect(fake.origins.single, tester.getRect(find.byTooltip('Condividi')));
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
    expect(find.byTooltip('Riproduci'), findsNothing);
    expect(find.byIcon(Icons.shuffle_rounded), findsNothing);
    expect(find.byTooltip('Altre azioni'), findsOneWidget);
    await h.dispose(tester);
  });

  test('favourite album keys: canonical finds the stream spelling, the file one wins, gone keys drop', () {
    AlbumSummary a(String key) => AlbumSummary(
        albumKey: key, title: 't', artist: 'a', variousArtists: false, trackCount: 1, durationMs: 1, year: null, coverKey: null);
    expect(resolveFavoriteAlbums(['x|y', 'gone|z'], [a('stream|x|y')]).map((e) => e.albumKey), ['stream|x|y']);
    expect(resolveFavoriteAlbums(['x|y'], [a('stream|x|y'), a('x|y')]).single.albumKey, 'x|y');
    // A key stored with the prefix finds the same album, and the file one still wins.
    expect(resolveFavoriteAlbums(['stream|x|y'], [a('stream|x|y')]).single.albumKey, 'stream|x|y');
    expect(resolveFavoriteAlbums(['stream|x|y'], [a('stream|x|y'), a('x|y')]).single.albumKey, 'x|y');
    expect(resolveFavoriteAlbums(['x|y', 'stream|x|y'], [a('stream|x|y')]), hasLength(1));
  });

  testWidgets('album page: Scarica icon, «Invia a un dispositivo» and the heart in the menu; the album shows in Preferiti and leaves it',
      (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, AlbumDetailScreen(album: album('Album 0')));
    await _settle(tester);
    expect(find.byIcon(Icons.download_rounded), findsNothing, reason: 'files only: nothing to download');
    expect(find.byTooltip('Condividi'), findsOneWidget);
    await tester.tap(find.byTooltip('Altre azioni').first);
    await tester.pumpAndSettle();
    expect(find.text('Invia a un dispositivo'), findsOneWidget);
    expect(find.text('Aggiungi ai preferiti'), findsNothing, reason: 'the heart is in the header now');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('collection-favorite')));
    await _settle(tester);
    final repo = FavoriteCollectionsRepository(h.db);
    expect(await tester.runAsync(() => repo.isFavoriteNow('album', 'artist|album 0')), isTrue);
    expect(find.byTooltip('Togli dai preferiti'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('favourites page: a favourite album and playlist show in sections and leave when removed',
      (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 2);
    final repo = FavoriteCollectionsRepository(h.db);
    final uuid = await tester.runAsync(() async {
      final pr = PlaylistRepository(h.db);
      final id = await pr.create('Notte');
      await repo.add('album', 'artist|album 0');
      final u = (await pr.uuidOf(id))!;
      await repo.add('playlist', u);
      return u;
    });
    await h.pump(tester, const FavoritesScreen());
    await _settle(tester);
    expect(find.text('Album 0'), findsOneWidget);
    expect(find.text('Notte'), findsOneWidget);
    await tester.runAsync(() => repo.remove('album', 'artist|album 0'));
    await _settle(tester);
    expect(find.text('Album 0'), findsNothing);
    expect(find.text('Notte'), findsOneWidget);
    await tester.runAsync(() => repo.remove('playlist', uuid!));
    await _settle(tester);
    expect(find.text('Notte'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('playlist page: Scarica icon hands the playlist tracks to keepOffline', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 3);
    final got = <int>[];
    final id = await tester.runAsync(() async {
      final pr = PlaylistRepository(h.db);
      final id = await pr.create('Notte');
      await pr.addTracks(id, [1, 2]);
      await h.db.update(h.db.tracks).write(const TracksCompanion(kind: Value(2), saved: Value(true)));
      return id;
    });
    await h.pump(
      tester,
      PlaylistDetailScreen(playlist: Playlist(id: id!, name: 'Notte', createdAt: 0, updatedAt: 0)),
      extraOverrides: [
        keepOfflineProvider.overrideWithValue((tracks) async {
          got.addAll([for (final t in tracks) t.id]);
          return 2;
        }),
      ],
    );
    await _settle(tester);
    await tester.tap(find.byTooltip('Scarica'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(got, unorderedEquals([1, 2]));
    await h.dispose(tester);
  });
}
