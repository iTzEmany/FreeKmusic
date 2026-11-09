import 'dart:async';

import 'package:codecore/providers/smart_search_providers.dart';
import 'package:codecore/providers/ytm_catalog_providers.dart';
import 'package:codecore/services/online/merge_results.dart';
import 'package:codecore/services/online/query_intent.dart';
import 'package:codecore/services/online/query_match.dart' show MediaKind;
import 'package:codecore/services/online/smart_search.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_album_search.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/services/online/ytm_catalog.dart';
import 'package:codecore/ui/screens/online/artist_page_screen.dart';
import 'package:codecore/ui/screens/online/online_album_screen.dart';
import 'package:codecore/ui/screens/youtube/online_results.dart';

import 'dart:io';

import 'package:codecore/providers/dislike_store_provider.dart';
import 'package:codecore/services/shuffle_plus/dislike_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_ytm.dart';

// 92.2 (source tag) and 92.3 (Artisti and Album rows) on the online results.

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

const _marco = YtmArtistRef(id: 'UCm', name: 'Marco Castello');

List<YtmArtistRef> _artists(int n) => [
  for (var i = 0; i < n; i++) YtmArtistRef(id: 'UCa$i', name: 'Artist $i'),
];

List<YtmAlbumHit> _albums(int n) => [
  for (var i = 0; i < n; i++)
    (
      release: YtmRelease(
        browseId: 'MPREb_$i',
        title: 'Album $i',
        subtitle: 'Album • 202$i',
      ),
      artist: _marco,
    ),
];

SmartResult _song(String id, String title) => SmartResult(
  primary: ytmSong(id, title, seconds: 200),
  sources: {MediaKind.ytmSong},
  alternatives: const [],
  confidence: 0.9,
  hasVideo: false,
);

SmartResult _video(String id, String title) => SmartResult(
  primary: YtResult(
    id: id,
    title: title,
    channel: 'Chan',
    duration: const Duration(minutes: 3),
  ),
  sources: {MediaKind.ytVideo},
  alternatives: const [],
  confidence: 0.7,
  hasVideo: false,
);

void main() {
  late StreamController<SmartSearchState> engine;
  late Harness h;
  late SemanticsHandle semantics;
  setUp(
    () => semantics = TestWidgetsFlutterBinding.ensureInitialized()
        .ensureSemantics(),
  );
  tearDown(() => semantics.dispose());

  Future<void> open(
    WidgetTester tester, {
    double textScale = 1,
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester);
    engine = StreamController<SmartSearchState>.broadcast();
    addTearDown(engine.close);
    await h.pump(
      tester,
      const Scaffold(body: OnlineResults(query: 'marco', submitted: 1)),
      textScale: textScale,
      extraOverrides: [
        ...extra,
        smartSearchProvider.overrideWith((ref, request) => engine.stream),
        artistPageProvider.overrideWith(
          (ref, id) async => CatalogResult(
            const YtmArtistPage(ref: _marco, shelves: []),
            DateTime(2026, 10, 22),
          ),
        ),
        onlineAlbumProvider.overrideWith(
          (ref, id) async => CatalogResult(
            YtmAlbum(
              browseId: id,
              title: 'Album 0',
              artist: _marco,
              year: '2020',
              kindLabel: 'Album',
              tracks: const [],
            ),
            DateTime(2026, 10, 22),
          ),
        ),
      ],
    );
  }

  Future<void> emit(
    WidgetTester tester, {
    List<YtmArtistRef> artists = const [],
    List<YtmAlbumHit> albums = const [],
    List<SmartResult> best = const [],
    TopCard? card,
    SearchIntent intent = SearchIntent.artistPage,
  }) async {
    engine.add(
      SmartSearchState(
        query: 'marco',
        best: best,
        intent: intent,
        card: card,
        artists: artists,
        albums: albums,
      ),
    );
    await _settle(tester);
  }

  group('source tag', () {
    testWidgets('a catalog song says «YouTube Music», a video says «YouTube»', (
      tester,
    ) async {
      await open(tester);
      await emit(
        tester,
        best: [_song('a', 'Nella stanza'), _video('v', 'Live clip')],
        intent: SearchIntent.songs,
      );
      final ytm = find.byKey(const ValueKey('source-ytmSong'));
      final yt = find.byKey(const ValueKey('source-ytVideo'));
      expect(ytm, findsOneWidget);
      expect(yt, findsOneWidget);
      expect(
        find.descendant(of: ytm, matching: find.text('YouTube Music')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: yt, matching: find.text('YouTube')),
        findsOneWidget,
      );
      // One node per row: the tag is part of the row's label for TalkBack.
      final label = tester
          .getSemantics(find.byKey(const ValueKey('row-a')))
          .label;
      expect(label, contains('Nella stanza'));
      expect(label, contains('Da YouTube Music'));
      expect(
        tester.getSemantics(find.byKey(const ValueKey('row-v'))).label,
        contains('Da YouTube'),
      );
      await h.dispose(tester);
    });

    testWidgets('no overflow at text scale 1.5', (tester) async {
      await open(tester, textScale: 1.5);
      await emit(
        tester,
        best: [
          _song('a', 'A fairly long song title that has to be cut somewhere'),
          _video('v', 'Live clip'),
        ],
        intent: SearchIntent.songs,
      );
      expect(find.byKey(const ValueKey('source-ytmSong')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.dispose(tester);
    });
  });

  group('Artisti and Album rows', () {
    testWidgets('with data, both rows are there under the card', (
      tester,
    ) async {
      await open(tester);
      await emit(
        tester,
        card: const TopArtist(_marco),
        artists: _artists(3),
        albums: _albums(3),
      );
      expect(find.text('Artisti'), findsOneWidget);
      expect(find.text('Album'), findsOneWidget);
      expect(find.byKey(const ValueKey('artist-hit-UCa0')), findsOneWidget);
      expect(find.byKey(const ValueKey('album-hit-MPREb_2')), findsOneWidget);
      expect(find.text('Marco Castello, Album, 2020'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('artist-card'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('online-artists'))).dy,
        ),
      );
      await h.dispose(tester);
    });

    testWidgets('the card artist is not repeated in the Artisti row', (
      tester,
    ) async {
      await open(tester);
      await emit(
        tester,
        card: const TopArtist(_marco),
        artists: [_marco, ..._artists(2)],
      );
      expect(find.byKey(const ValueKey('artist-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('artist-hit-UCm')), findsNothing);
      expect(find.byKey(const ValueKey('artist-hit-UCa0')), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('empty lists leave no row and no error', (tester) async {
      await open(tester);
      await emit(tester, card: const TopArtist(_marco));
      expect(find.byKey(const ValueKey('online-artists')), findsNothing);
      expect(find.byKey(const ValueKey('online-albums')), findsNothing);
      expect(find.byKey(const ValueKey('artist-card')), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets(
      'a blocked artist shows the lock on the card and in the Artisti row',
      (tester) async {
        final store = DislikeStore(
          file: () async => File('/nonexistent/dislikes.json'),
        );
        await tester.runAsync(store.load);
        store
          ..blockArtist(
            const DislikedArtist(key: 'marco castello', name: 'Marco Castello'),
          )
          ..blockArtist(
            const DislikedArtist(key: 'artist 1', name: 'Artist 1'),
          );
        await open(
          tester,
          extra: [dislikeStoreProvider.overrideWithValue(store)],
        );
        await emit(tester, card: const TopArtist(_marco), artists: _artists(3));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('artist-card')),
            matching: find.byIcon(Icons.block),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('artist-hit-UCa1')),
            matching: find.byIcon(Icons.block),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('artist-hit-UCa0')),
            matching: find.byIcon(Icons.block),
          ),
          findsNothing,
        );
        await h.dispose(tester);
      },
    );

    testWidgets('a tap on an artist opens the artist page', (tester) async {
      await open(tester);
      await emit(tester, card: const TopArtist(_marco), artists: _artists(3));
      await tester.tap(find.byKey(const ValueKey('artist-hit-UCa1')));
      await _settle(tester);
      expect(find.byType(ArtistPageScreen), findsOneWidget);
      expect(
        tester
            .widget<ArtistPageScreen>(find.byType(ArtistPageScreen))
            .artist
            .id,
        'UCa1',
      );
      await h.dispose(tester);
    });

    testWidgets('a tap on an album opens the album page', (tester) async {
      await open(tester);
      await emit(tester, card: const TopArtist(_marco), albums: _albums(3));
      await tester.tap(find.byKey(const ValueKey('album-hit-MPREb_1')));
      await _settle(tester);
      expect(find.byType(OnlineAlbumScreen), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets(
      'ten entries scroll sideways; each tile is a labelled 48 dp target',
      (tester) async {
        await open(tester, textScale: 1.5);
        await emit(
          tester,
          card: const TopArtist(_marco),
          artists: _artists(10),
          albums: _albums(10),
        );
        final ex = tester.takeException();
        if (ex != null) fail('$ex');
        final first = tester.getSize(
          find.byKey(const ValueKey('artist-hit-UCa0')),
        );
        expect(first.width, greaterThanOrEqualTo(48));
        expect(first.height, greaterThanOrEqualTo(48));
        expect(
          find.byKey(const ValueKey('artist-hit-UCa9')),
          findsNothing,
          reason: 'off screen, not built',
        );
        await tester.drag(
          find.descendant(
            of: find.byKey(const ValueKey('online-artists')),
            matching: find.byType(ListView),
          ),
          const Offset(-3000, 0),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byKey(const ValueKey('artist-hit-UCa9')), findsOneWidget);
        expect(find.bySemanticsLabel('Artist 9, Artista'), findsOneWidget);
        await h.dispose(tester);
      },
    );
  });
}
