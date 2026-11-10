import 'package:codecore/providers/online_collection_providers.dart';
import 'dart:async';

import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/smart_search_providers.dart';
import 'package:codecore/providers/ui_providers.dart' show searchPrefillProvider;
import 'package:codecore/services/online/collection_matcher.dart';
import 'package:codecore/services/online/deezer_client.dart' show DeezerNetworkException;
import 'package:codecore/services/online/external_collection.dart';
import 'package:codecore/services/online/external_links.dart';
import 'package:codecore/ui/screens/import/import_intro_sheet.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/shuffle_plus/plus_allowed.dart' show ShufflePlusBlock;
import 'package:codecore/ui/screens/online/online_playlist_screen.dart';
import 'package:codecore/ui/screens/youtube/playlist_source_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_ytm.dart';
import '../support/fake_youtube.dart';

class _Yt extends FakeYoutube {
  _Yt(this.listing);
  PlaylistListing? listing; // null = fail
  int reads = 0;

  @override
  Future<PlaylistListing> listPlaylist(String url, {int limit = 500}) async {
    reads++;
    return listing ?? (throw const YtException(YtErrorKind.network));
  }
}

class _Ctrl implements PlayerController {
  final calls = <String>[];
  @override
  bool inJam = false;
  @override
  Future<void> playOnlineList(List<YtResult> list, {bool shuffle = false, Object? listKey}) async =>
      calls.add('list ${list.map((r) => r.id).join(',')}');
  @override
  Future<ShufflePlusBlock?> cycleListShuffle(Object key, {List<int>? ids, bool plus = true}) async {
    calls.add('toggle plus=$plus');
    return null;
  }

  @override
  bool isPlayingList(Object key) => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

PlaylistListing _listing({bool truncated = false}) => PlaylistListing(
      title: 'Road mix',
      owner: 'Chan',
      truncated: truncated,
      entries: [ytmSong('a', 'First song', seconds: 100), ytmSong('b', 'Second song', seconds: 200)],
    );


class _MixCtrl extends _Ctrl {
  final mixed = <List<String>>[];
  final enqueued = <String>[];
  bool playing = false;
  @override
  bool isPlayingList(Object key) => playing;
  @override
  Future<void> playMixed(List<MixItem> items,
      {int? index, PlayContext? context, bool? shuffle, Object? listKey}) async {
    mixed.add([for (final i in items) i.online!.id]);
    playing = true;
  }

  @override
  Future<void> appendOnline(YtResult r) async => enqueued.add(r.id);
}

class _Matcher implements CollectionMatcher {
  final out = StreamController<(int, TrackMatch)>();
  @override
  Stream<(int, TrackMatch)> match(List<ExternalTrack> tracks) => out.stream;
  @override
  void cancel() => out.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Reader implements ExternalReader {
  _Reader(this.collection, {this.error});
  final ExternalCollection collection;
  final Object? error;
  @override
  Future<ExternalCollection> read(ExternalLink link, {CancelToken? cancelToken}) async =>
      error == null ? collection : throw error!;
}

ExternalCollection _ext({bool truncated = false, String url = 'https://www.deezer.com/playlist/1'}) =>
    ExternalCollection(
      title: 'Mix',
      kind: CollectionKind.playlist,
      sourceUrl: url,
      truncated: truncated,
      tracks: [
        for (final n in ['One', 'Two', 'Three']) ExternalTrack(title: n, artists: ['Band'], key: n),
      ],
    );

void externalTests() {
  const link = ExternalLink(ExternalService.deezer, ExternalLinkKind.playlist, '1');
  late _MixCtrl ctrl;
  late _Matcher matcher;
  late Harness h;

  Future<void> turn(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> showExt(WidgetTester tester, ExternalCollection c, {Object? error, ExternalService service = ExternalService.deezer}) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ctrl = _MixCtrl();
    matcher = _Matcher();
    h = await Harness.create(tester);
    await h.pump(tester, OnlinePlaylistScreen(OnlineCollectionRef.external(ExternalLink(service, link.kind, link.id))),
        extraOverrides: [
          externalReaderProvider.overrideWith((ref, s) => _Reader(c, error: error)),
          collectionMatcherProvider.overrideWith((ref, page) => matcher),
          playerControllerProvider.overrideWithValue(ctrl),
        ]);
    await turn(tester);
  }

  // Pending rows spin forever: pumpAndSettle would never return.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> emit(WidgetTester tester, int i, TrackMatch m) async {
    matcher.out.add((i, m));
    await turn(tester);
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(OnlinePlaylistScreen)));

  testWidgets('the page is there before matching ends, rows pending, Play off', (tester) async {
    await showExt(tester, _ext());
    expect(find.text('Mix'), findsWidgets);
    expect(find.byKey(const ValueKey('pending-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('pending-2')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('playlist-play'))).onPressed, isNull);
    await h.dispose(tester);
  });

  testWidgets('a matched row becomes playable, an unmatched one offers «Cerca a mano»', (tester) async {
    await showExt(tester, _ext());
    await emit(tester, 0, TrackReady.online(ytmSong('y0', 'One found')));
    await emit(tester, 1, const TrackNotFound());
    expect(find.text('One found'), findsOneWidget);
    expect(find.byKey(const ValueKey('pending-0')), findsNothing);
    expect(find.byKey(const ValueKey('pending-2')), findsOneWidget);
    expect(find.text('Cerca a mano'), findsOneWidget);
    await tester.tap(find.text('Cerca a mano'));
    await tester.pump();
    expect(container(tester).read(searchPrefillProvider), 'Two Band');
    await h.dispose(tester);
  });

  testWidgets('Play before the end plays the ready rows; later ones join the queue', (tester) async {
    await showExt(tester, _ext());
    await emit(tester, 0, TrackReady.online(ytmSong('y0', 'One found')));
    await tester.tap(find.byKey(const ValueKey('playlist-play')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(ctrl.mixed, [
      ['y0']
    ]);
    await emit(tester, 2, TrackReady.online(ytmSong('y2', 'Three found')));
    expect(ctrl.enqueued, ['y2']);
    await h.dispose(tester);
  });

  testWidgets('another list with the same name started later gets no rows', (tester) async {
    await showExt(tester, _ext());
    await emit(tester, 0, TrackReady.online(ytmSong('y0', 'One found')));
    await tester.tap(find.byKey(const ValueKey('playlist-play')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    ctrl.playing = false; // a library playlist with the same name started since
    await emit(tester, 2, TrackReady.online(ytmSong('y2', 'Three found')));
    expect(ctrl.enqueued, isEmpty);
    await h.dispose(tester);
  });

  testWidgets('«Scarica tutto» downloads only the ready rows', (tester) async {
    await showExt(tester, _ext());
    await emit(tester, 0, TrackReady.online(ytmSong('y0', 'One found')));
    await emit(tester, 1, const TrackNotFound());
    await tester.tap(find.byKey(const ValueKey('playlist-more')));
    await settle(tester);
    await tester.tap(find.text('Scarica tutto'));
    await settle(tester);
    expect([for (final d in container(tester).read(downloadsProvider)) d.result.id], ['y0']);
    await h.dispose(tester);
  });

  testWidgets('the menu of an external page has «Salva in Libreria» and «Aggiorna»; saving makes a playlist',
      (tester) async {
    await showExt(tester, _ext());
    await emit(tester, 0, TrackReady.online(ytmSong('y0', 'One found')));
    await tester.tap(find.byKey(const ValueKey('playlist-more')));
    await settle(tester);
    expect(find.text('Aggiorna'), findsOneWidget);
    await tester.tap(find.text('Salva in Libreria'));
    await settle(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(find.text('Salvata come «Mix»'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a Spotify list cut short offers the full import with Exportify', (tester) async {
    await showExt(tester, _ext(truncated: true, url: 'https://open.spotify.com/playlist/abc'));
    expect(find.text('Mostro i primi 3 brani.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('playlist-exportify')));
    await tester.tap(find.byKey(const ValueKey('playlist-exportify')));
    await settle(tester);
    expect(find.byType(ImportIntroSheet), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a private or missing page says so, with no «Riprova»', (tester) async {
    await showExt(tester, _ext(), error: const CollectionNotFound());
    expect(find.text('Questa playlist non è pubblica o non esiste'), findsOneWidget);
    expect(find.byKey(const ValueKey('error-retry')), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('no network offers «Riprova»; an unreadable Spotify page offers Exportify, a Deezer one not',
      (tester) async {
    await showExt(tester, _ext(), error: const DeezerNetworkException('u'));
    expect(find.byKey(const ValueKey('error-retry')), findsOneWidget);
    await h.dispose(tester);
    await showExt(tester, _ext(), error: const CollectionUnreadable());
    expect(find.byKey(const ValueKey('error-search')), findsNothing);
    await h.dispose(tester);
    await showExt(tester, _ext(), error: const CollectionUnreadable(), service: ExternalService.spotify);
    expect(find.byKey(const ValueKey('error-search')), findsOneWidget);
    await h.dispose(tester);
  });
}

void main() {
  late _Ctrl ctrl;

  Future<Harness> show(WidgetTester tester, _Yt yt) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ctrl = _Ctrl();
    final h = await Harness.create(tester);
    await h.pump(tester, const OnlinePlaylistScreen(OnlineCollectionRef.youtubeListing('u')),
        extraOverrides: [
          youtubeServiceProvider.overrideWithValue(yt),
          playerControllerProvider.overrideWithValue(ctrl),
        ]);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pumpAndSettle();
    return h;
  }

  testWidgets('shows the header and the songs', (tester) async {
    final h = await show(tester, _Yt(_listing()));
    expect(find.text('Road mix'), findsWidgets);
    expect(find.text('Chan'), findsOneWidget);
    expect(find.text('First song'), findsOneWidget);
    expect(find.text('Second song'), findsOneWidget);
    expect(find.byKey(const ValueKey('playlist-truncated')), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('the menu of a YouTube page saves but has no «Aggiorna»', (tester) async {
    final h = await show(tester, _Yt(_listing()));
    await tester.tap(find.byKey(const ValueKey('playlist-more')));
    await tester.pumpAndSettle();
    expect(find.text('Salva in Libreria'), findsOneWidget);
    expect(find.text('Aggiorna'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('Play plays the list from the first song', (tester) async {
    final h = await show(tester, _Yt(_listing()));
    await tester.tap(find.byKey(const ValueKey('playlist-play')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(ctrl.calls, ['list a,b']);
    await h.dispose(tester);
  });

  testWidgets('Shuffle toggles the list shuffle and starts nothing', (tester) async {
    final h = await show(tester, _Yt(_listing()));
    await tester.tap(find.byKey(const ValueKey('playlist-shuffle')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(ctrl.calls, ['toggle plus=false']);
    await h.dispose(tester);
  });

  testWidgets('«Scarica» in the menu opens the source sheet', (tester) async {
    final h = await show(tester, _Yt(_listing()));
    await tester.tap(find.byKey(const ValueKey('playlist-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<Object>('playlist-menu-download')));
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistSourceSheet), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('an error offers «Riprova», which reads again', (tester) async {
    final yt = _Yt(null);
    final h = await show(tester, yt);
    expect(find.byKey(const ValueKey('error-retry')), findsOneWidget);
    yt.listing = _listing();
    await tester.tap(find.byKey(const ValueKey('error-retry')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pumpAndSettle();
    expect(yt.reads, 2);
    expect(find.text('First song'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('an empty list says so', (tester) async {
    final h = await show(tester, _Yt(const PlaylistListing(title: 'Empty', entries: [])));
    expect(find.text('Non ci sono video da scaricare qui.'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a truncated list says so at the bottom', (tester) async {
    final h = await show(tester, _Yt(_listing(truncated: true)));
    expect(find.byKey(const ValueKey('playlist-truncated')), findsOneWidget);
    expect(find.text('Mostro i primi 2 video.'), findsOneWidget);
    await h.dispose(tester);
  });

  externalTests();
}
