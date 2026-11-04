import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/track_repository.dart'
    show SortOption;
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/providers/selection_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/providers/ytm_catalog_providers.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/download_queue.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/ui/screens/library/album_detail_screen.dart';
import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/screens/library/favorites_screen.dart';
import 'package:codecore/ui/screens/playlists/playlist_detail_screen.dart';
import 'package:codecore/ui/screens/youtube/online_results.dart';
import 'package:codecore/ui/widgets/segmented_blocks.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/app_harness.dart';
import '../support/results_host.dart';
import '../support/search_input.dart';
import '../support/fake_ytm.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 120)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Selection _sel(WidgetTester tester, Type page, String key) =>
    ProviderScope.containerOf(tester.element(find.byType(page)))
        .read(selectionProvider(key));

class _FakeDownloads extends DownloadsNotifier {
  final added = <String>[];
  @override
  List<DownloadItem> build() => const [];
  @override
  Future<bool> add(YtResult r, {String? tag}) async {
    added.add(r.id);
    return false;
  }
}

class _FakeYoutube implements YoutubeService {
  @override
  Future<List<YtResult>> search(String query) async => [
    for (var i = 0; i < 4; i++)
      YtResult(
        id: 'v$i',
        title: 'Clip $i',
        channel: 'Chan',
        duration: const Duration(minutes: 3),
      ),
  ];
  @override
  Future<List<YtResult>> searchSongs(String query, {int limit = 5}) async =>
      const [];
  @override
  Future<PlaylistListing> listPlaylist(String url, {int limit = 500}) async =>
      const PlaylistListing.empty();
  @override
  Future<List<YtResult>> searchAlbums(String query, {int limit = 3}) async =>
      const [];
  @override
  Future<List<YtResult>> albumTracks(String albumLink) async => const [];
  @override
  Stream<DownloadProgress> download(
    YtResult r,
    Directory outDir, {
    CancelToken? cancel,
    DownloadOptions options = const DownloadOptions(),
  }) => const Stream.empty();
  @override
  Future<String?> toolVersion() async => null;
  @override
  void close() {}
}

void main() {
  testWidgets('«Tutti i brani»: collection header with title, meta and icons', (
    tester,
  ) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, const AllTracksScreen());
    await _settle(tester);
    final title = find.text('Tutti i brani');
    expect(title, findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: title),
      findsNothing,
    );
    expect(
      tester.widget<Text>(title).style,
      Theme.of(tester.element(title)).textTheme.headlineSmall,
    );
    final meta = find.text('4 brani, 13 minuti');
    expect(meta, findsOneWidget);
    expect(tester.getTopLeft(meta).dx, tester.getTopLeft(title).dx);
    expect(find.byTooltip('Riproduci'), findsOneWidget);
    expect(find.byTooltip('Casuale: spenta'), findsOneWidget);
    expect(
      tester.getTopRight(find.byTooltip('Riproduci')).dx,
      greaterThan(tester.getTopRight(title).dx),
    );
    await h.dispose(tester);
  });

  testWidgets(
    '«Tutti i brani»: long press picks, the bar replaces the title, Back leaves',
    (tester) async {
      _phone(tester);
      final h = await Harness.create(tester, tracks: 4);
      await h.pump(tester, const AllTracksScreen());
      await _settle(tester);
      await tester.longPress(find.text('Song 1'));
      await _settle(tester);
      expect(find.text('1 selezionato'), findsOneWidget);
      await tester.tap(find.text('Song 3'));
      await _settle(tester);
      expect(find.text('2 selezionati'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('1 selezionato'), findsNothing);
      expect(_sel(tester, AllTracksScreen, 'all').active, isFalse);
      await h.dispose(tester);
    },
  );

  testWidgets('all tracks sort is a block row', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, const AllTracksScreen());
    await _settle(tester);
    SegmentedBlocks<SortOption> blocks() =>
        tester.widget(find.byType(SegmentedBlocks<SortOption>));
    expect(blocks().items, hasLength(4));
    expect(blocks().selected, SortOption.defaultOrder);
    await tester.tap(find.text('Artista'));
    await _settle(tester);
    expect(blocks().selected, SortOption.artist);
    await h.dispose(tester);
  });

  testWidgets(
    'searching text that hides a picked track drops it from the selection',
    (tester) async {
      _phone(tester);
      final h = await Harness.create(tester, tracks: 4);
      await h.pump(tester, const AllTracksScreen());
      await _settle(tester);
      await tester.longPress(find.text('Song 1'));
      await tester.tap(find.text('Song 2'));
      await _settle(tester);
      expect(_sel(tester, AllTracksScreen, 'all').count, 2);
      await tester.enterText(find.byType(TextField), 'Song 2');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await _settle(tester);
      await _settle(tester);
      expect(_sel(tester, AllTracksScreen, 'all').count, 1);
      await h.dispose(tester);
    },
  );

  testWidgets('favourites: the same long press and bar', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 3);
    final all = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
    await tester.runAsync(() async {
      for (final t in all) {
        await (h.db.update(h.db.tracks)..where((r) => r.id.equals(t.id))).write(
          TracksCompanion(isFavorite: const Value(true)),
        );
      }
    });
    await h.pump(tester, const FavoritesScreen());
    await _settle(tester);
    await tester.longPress(find.text('Song 0'));
    await _settle(tester);
    expect(find.text('1 selezionato'), findsOneWidget);
    expect(
      find.byTooltip('Togli dai preferiti'),
      findsOneWidget,
      reason: 'all favourites: the action removes',
    );
    await h.dispose(tester);
  });

  testWidgets(
    'album: a long press on a row of the disc list starts a selection',
    (tester) async {
      _phone(tester);
      final h = await Harness.create(tester, tracks: 4);
      final albums = (await tester.runAsync(
        () => LibraryQueries(h.db).watchAlbums().first,
      ))!;
      await h.pump(tester, AlbumDetailScreen(album: albums.first));
      await _settle(tester);
      await tester.longPress(find.textContaining('Song').first);
      await _settle(tester);
      expect(find.text('1 selezionato'), findsOneWidget);
      await h.dispose(tester);
    },
  );

  testWidgets('a playlist: picking offers «Rimuovi dalla playlist»', (
    tester,
  ) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 3);
    final all = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
    final repo = PlaylistRepository(h.db);
    final playlist = (await tester.runAsync(() async {
      final id = await repo.create('Mix');
      await repo.addTracks(id, [for (final t in all) t.id]);
      return (await repo.watchAll().first).first.playlist;
    }))!;
    await h.pump(tester, PlaylistDetailScreen(playlist: playlist));
    await _settle(tester);
    await tester.longPress(find.text('Song 0'));
    await _settle(tester);
    expect(find.text('1 selezionato'), findsOneWidget);
    await tester.tap(find.byTooltip('Azioni'));
    await _settle(tester);
    expect(find.text('Rimuovi dalla playlist'), findsOneWidget);
    await tester.tapAt(const Offset(5, 450)); // closes the menu
    await _settle(tester);
    await h.dispose(tester);
  });

  testWidgets('search results: the tracks section can be picked', (
    tester,
  ) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 3);
    await h.pump(tester, const ResultsHost());
    typeSearch(tester, 'Song');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await _settle(tester);
    await _settle(tester);
    await tester.longPress(find.text('Song 1').last);
    await _settle(tester);
    expect(find.text('1 selezionato'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets(
    'YouTube results: pick several and download, skipping the ones already on their way',
    (tester) async {
      _phone(tester);
      final h = await Harness.create(tester);
      final downloads = _FakeDownloads();
      final dir = Directory.systemTemp.createTempSync('ytsel');
      addTearDown(() => dir.deleteSync(recursive: true));
      final index = DownloadIndex(File(p.join(dir.path, 'downloads.json')));
      final known = File(p.join(dir.path, 'known.mp3'))..writeAsStringSync('x');
      await tester.runAsync(
        () => index.add('v2', known.path),
      ); // «Clip 2» is in the library already
      await h.pump(
        tester,
        Scaffold(body: OnlineResults(query: 'x', submitted: 1)),
        extraOverrides: [
          youtubeServiceProvider.overrideWithValue(_FakeYoutube()),
          ytmCatalogProvider.overrideWithValue(FakeCatalog((_) async => null)),
          downloadsProvider.overrideWith(() => downloads),
          downloadIndexProvider.overrideWith((ref) async => index),
        ],
      );
      await _settle(tester);
      expect(find.text('Clip 0'), findsOneWidget);

      await tester.longPress(find.text('Clip 0'));
      await _settle(tester);
      expect(find.text('1 selezionato'), findsOneWidget);
      await tester.tap(find.text('Clip 2'));
      await tester.tap(find.text('Clip 3'));
      await _settle(tester);
      expect(find.text('3 selezionati'), findsOneWidget);
      await tester.tap(find.byTooltip('Scarica').first);
      await _settle(tester);
      expect(downloads.added, [
        'v0',
        'v3',
      ], reason: 'v2 is already in the library');
      expect(
        find.text('2 download avviati, 1 già in libreria o in corso'),
        findsOneWidget,
      );
      expect(
        find.text('3 selezionati'),
        findsNothing,
        reason: 'the selection ended',
      );
      await h.dispose(tester);
    },
  );
}
