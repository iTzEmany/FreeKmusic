import 'dart:async';
import 'dart:io';

import 'package:codecore/data/repositories/import_repository.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/providers/import_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/providers/ytm_catalog_providers.dart';
import 'package:codecore/services/import/playlist_import_service.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/ui/screens/online/online_playlist_screen.dart';
import 'package:codecore/ui/screens/youtube/online_results.dart';
import 'package:codecore/ui/screens/youtube/playlist_source_sheet.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_ytm.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

class _Yt implements YoutubeService {
  Future<PlaylistListing> Function(String url)? onList;
  final listed = <String>[];
  var searched = 0;

  @override
  Future<PlaylistListing> listPlaylist(String url, {int limit = 500}) {
    listed.add(url);
    return onList!(url);
  }

  @override
  Future<List<YtResult>> search(String query) async {
    searched++;
    return const [];
  }

  @override
  Future<List<YtResult>> searchSongs(String query, {int limit = 5}) async => const [];
  @override
  Future<List<YtResult>> searchAlbums(String query, {int limit = 3}) async => const [];
  @override
  Future<List<YtResult>> albumTracks(String albumLink) async => const [];
  @override
  Stream<DownloadProgress> download(YtResult r, Directory outDir,
          {CancelToken? cancel, DownloadOptions options = const DownloadOptions()}) =>
      const Stream.empty();
  @override
  Future<String?> toolVersion() async => null;
  @override
  void close() {}
}

YtResult _v(int i) => YtResult(
      id: 'v$i',
      title: 'Video $i',
      channel: 'Chan',
      duration: const Duration(minutes: 3),
    );

class _Opener extends StatelessWidget {
  const _Opener(this.url);
  final String url;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: TextButton(
          key: const ValueKey('open-sheet'),
          onPressed: () => PlaylistSourceSheet.show(context, url),
          child: const Text('open'),
        ),
      );
}

void main() {
  late Harness h;
  late _Yt yt;
  late List<(YtResult, String)> queued;
  late PlaylistImportService service;
  const url = 'https://www.youtube.com/playlist?list=PLabc';

  Future<void> open(WidgetTester tester, {String query = url, PlaylistListing? listing, bool viaSearch = false}) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester);
    queued = [];
    yt = _Yt();
    service = PlaylistImportService(
      imports: ImportRepository(h.db),
      playlists: PlaylistRepository(h.db),
      loadLibrary: () async => const [],
      youtube: yt,
      enqueue: (r, tag) => queued.add((r, tag)),
      cancelDownloads: (_) {},
      settled: const Stream.empty(),
      trackIdForPath: (_) async => null,
      pathForVideo: (_) async => null,
      applyTags: (_, _) async {},
      searchGap: Duration.zero,
      pollDelay: const Duration(milliseconds: 5),
    );
    addTearDown(service.dispose);
    yt.onList = (_) async =>
        listing ??
        PlaylistListing(
          title: 'Road trip',
          owner: 'Chan',
          entries: [for (var i = 0; i < 3; i++) _v(i)],
          unavailable: 1,
        );
    await h.pump(
      tester,
      query == url && !viaSearch ? const _Opener(url) : Scaffold(body: OnlineResults(query: query, submitted: 1)),
      extraOverrides: [
        youtubeServiceProvider.overrideWithValue(yt),
        playlistImportServiceProvider.overrideWithValue(service),
        ytmCatalogProvider.overrideWithValue(FakeCatalog((_) async => null)),
      ],
    );
    if (query == url && !viaSearch) await tester.tap(find.byKey(const ValueKey('open-sheet')));
    await _settle(tester);
  }

  testWidgets('a pasted playlist address opens the playlist page, not a search', (tester) async {
    await open(tester, viaSearch: true);
    expect(find.byType(OnlinePlaylistScreen), findsOneWidget);
    expect(yt.searched, 0);
    expect(yt.listed, [url]);
    expect(find.byType(PlaylistSourceSheet), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('the sheet lists the videos of a playlist address', (tester) async {
    await open(tester);
    expect(yt.searched, 0);
    expect(yt.listed, [url]);
    expect(find.text('Playlist o canale YouTube'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('playlist-name'))).controller!.text, 'Road trip');
    expect(find.text('3 video'), findsOneWidget);
    expect(find.text('1 video non disponibile (privato o rimosso)'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(tester.widget<CheckboxListTile>(find.byKey(ValueKey('video-v$i'))).value, isTrue, reason: 'all ticked');
    }
    expect(find.text('Scarica in una playlist (3)'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('plain words are a normal search, no list is read', (tester) async {
    await open(tester, query: 'daft punk');
    expect(yt.listed, isEmpty);
    expect(yt.searched, 1);
    expect(find.text('Playlist o canale YouTube'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('untick some, the button follows; none ticked disables it; all comes back', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('video-v1')));
    await tester.pump();
    expect(find.text('Scarica in una playlist (2)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('toggle-all')));
    await tester.pump();
    expect(find.text('Scarica in una playlist (3)'), findsOneWidget, reason: 'not all ticked: the button ticks them all');
    expect(find.text('Nessuno'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('toggle-all')));
    await tester.pump();
    expect(find.text('Scarica in una playlist (0)'), findsOneWidget, reason: 'all ticked: the button clears them');
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('playlist-go'))).onPressed, isNull);
    await h.dispose(tester);
  });

  testWidgets('«Scarica in una playlist» queues the ticked videos in order under the chosen name', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('video-v1')));
    await tester.enterText(find.byKey(const ValueKey('playlist-name')), 'Mine');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('playlist-go')));
    for (var i = 0; i < 20 && queued.length < 2; i++) {
      await _settle(tester);
    }

    expect(queued.map((q) => q.$1.id), ['v0', 'v2']);
    expect(find.text('Download avviati nella playlist «Mine»'), findsOneWidget);
    expect(find.text('Playlist o canale YouTube'), findsNothing, reason: 'the sheet closed');
    final lists = await tester.runAsync(() => PlaylistRepository(h.db).watchAll().first);
    expect(lists!.map((p) => p.playlist.name), ['Mine']);
    await h.dispose(tester);
  });

  testWidgets('more than 200 videos come with a warning and a time estimate', (tester) async {
    await open(
      tester,
      listing: PlaylistListing(
        title: 'Big',
        entries: [for (var i = 0; i < 250; i++) _v(i)],
        truncated: true,
      ),
    );
    expect(find.textContaining('Sono 250 video: ci vorrà circa'), findsOneWidget);
    expect(find.text('Mostro i primi 250 video.'), findsOneWidget);

    await h.dispose(tester);
  });

  testWidgets('a list with nothing playable says so', (tester) async {
    await open(tester, listing: const PlaylistListing(title: 'Empty', entries: [], unavailable: 2));
    expect(find.text('Non ci sono video da scaricare qui.'), findsOneWidget);
    expect(find.byKey(const ValueKey('playlist-go')), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('an error is told and can be retried', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester);
    yt = _Yt();
    var calls = 0;
    yt.onList = (_) async {
      calls++;
      if (calls == 1) throw const YtException(YtErrorKind.network, 'offline');
      return PlaylistListing(title: 'Back', entries: [_v(1)]);
    };
    await h.pump(
      tester,
      const _Opener(url),
      extraOverrides: [youtubeServiceProvider.overrideWithValue(yt)],
    );
    await tester.tap(find.byKey(const ValueKey('open-sheet')));
    await _settle(tester);
    expect(find.text('Riprova'), findsOneWidget);

    await tester.tap(find.text('Riprova'));
    await _settle(tester);
    expect(find.text('1 video'), findsOneWidget);
    await h.dispose(tester);
  });
}
