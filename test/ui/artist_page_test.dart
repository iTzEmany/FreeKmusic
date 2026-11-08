import 'package:codecore/core/constants.dart';
import 'package:codecore/data/repositories/artist_alias_repository.dart';
import 'package:codecore/providers/ytm_catalog_providers.dart';
import 'package:codecore/services/online/innertube_client.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/services/online/ytm_catalog.dart';
import 'package:codecore/ui/screens/online/artist_page_screen.dart';
import 'package:codecore/ui/screens/online/artist_page_sections.dart';
import 'package:codecore/ui/screens/releases/follow_button.dart';
import 'package:codecore/services/online/youtube_service.dart' show YtErrorKind, YtException;
import 'package:dio/dio.dart' show CancelToken;
import 'package:codecore/ui/widgets/net_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_ytm.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 120)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

const _ref = YtmArtistRef(
  id: 'UCpf',
  name: 'Pink Floyd',
  audience: '25.9M ascoltatori mensili',
);

final _full = YtmArtistPage(
  ref: _ref,
  description: 'Una band inglese. ' * 40,
  shelves: [
    YtmSongShelf('Brani più ascoltati', [
      ytmSong('s1', 'Time'),
      ytmSong('s2', 'Money'),
    ], allSongs: const YtmBrowseLink('VLOLAK', null)),
    const YtmReleaseShelf('Album', [
      YtmRelease(browseId: 'MPREb_1', title: 'The Wall', subtitle: '1979'),
    ], more: YtmBrowseLink('MPAD', 'p')),
    const YtmReleaseShelf('Singoli ed EP', [
      YtmRelease(
        browseId: 'MPREb_2',
        title: 'Arnold Layne',
        subtitle: 'Singolo • 1967',
      ),
    ]),
    const YtmArtistShelf('Ai fan potrebbe anche piacere', [
      YtmArtistRef(id: 'UC2', name: 'Roger Waters'),
    ]),
  ],
);

/// The sheet of «Unisci con…» searches through the catalog.
class _SearchCatalog extends FakeCatalog {
  _SearchCatalog(this.onSearch) : super((q) async => null);
  final Future<List<YtmArtistRef>> Function(String q) onSearch;
  final queries = <String>[];

  @override
  Future<List<YtmArtistRef>> searchArtists(String query, String hl, {CancelToken? cancel}) {
    queries.add(query);
    return onSearch(query);
  }
}

class _CountingCatalog extends FakeCatalog {
  _CountingCatalog() : super((q) async => null);
  final refreshFlags = <bool>[];

  @override
  Future<CatalogResult<YtmArtistPage>> artist(
    String id,
    String hl, {
    bool refresh = false,
  }) async {
    refreshFlags.add(refresh);
    return CatalogResult(_full, DateTime(2026, 10, 22));
  }
}

void main() {
  Future<Harness> open(
    WidgetTester tester,
    Future<CatalogResult<YtmArtistPage>> Function() page, {
    YtmArtistRef artist = _ref,
    int libraryTracks = 0,
  }) async {
    tester.view.physicalSize = const Size(600, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: libraryTracks);
    await h.pump(
      tester,
      ArtistPageScreen(artist: artist),
      extraOverrides: [
        artistPageProvider.overrideWith((ref, id) => page()),
      ],
    );
    await _settle(tester);
    return h;
  }

  double y(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  testWidgets(
    'sections come in the page order: songs, releases, similar artists, about',
    (tester) async {
      final h = await open(
        tester,
        () async => CatalogResult(_full, DateTime(2026, 10, 22)),
      );
      expect(find.text('25.9M ascoltatori mensili'), findsOneWidget);
      final order = [
        y(tester, 'Brani più ascoltati'),
        y(tester, 'Album'),
        y(tester, 'Singoli ed EP'),
        y(tester, 'Ai fan potrebbe anche piacere'),
        y(tester, 'Informazioni'),
      ];
      expect(order, [...order]..sort());
      expect(
        find.text('Tutti'),
        findsNWidgets(2),
        reason: 'songs and albums have a link; singles do not',
      );
      expect(
        find.text('Nella tua libreria'),
        findsNothing,
        reason: 'no songs of the artist in the library',
      );
      expect(find.byKey(const ValueKey('offline-notice')), findsNothing);
      await h.dispose(tester);
    },
  );

  testWidgets(
    'a missing section is not shown; «Altro» opens the whole biography',
    (tester) async {
      final sparse = YtmArtistPage(
        ref: _ref,
        description: 'Una band inglese. ' * 40,
        shelves: const [
          YtmReleaseShelf('Singoli ed EP', [
            YtmRelease(
              browseId: 'MPREb_2',
              title: 'Arnold Layne',
              subtitle: '1967',
            ),
          ]),
        ],
      );
      final h = await open(
        tester,
        () async => CatalogResult(sparse, DateTime(2026, 10, 22)),
      );
      expect(find.text('Singoli ed EP'), findsOneWidget);
      expect(find.text('Album'), findsNothing);
      expect(find.text('Brani più ascoltati'), findsNothing);

      final collapsed = tester
          .getSize(find.byKey(const ValueKey('about-text')))
          .height;
      await tester.tap(find.byKey(const ValueKey('about-toggle')));
      await _settle(tester);
      expect(
        tester.getSize(find.byKey(const ValueKey('about-text'))).height,
        greaterThan(collapsed),
      );
      await h.dispose(tester);
    },
  );

  testWidgets(
    '«Nella tua libreria» only with the artist\'s songs in the library,',
    (tester) async {
      final mine = await open(
        tester,
        () async => CatalogResult(_full, DateTime(2026, 10, 22)),
        artist: const YtmArtistRef(id: 'UCpf', name: 'Artist'),
        libraryTracks: 2,
      );
      expect(find.text('Nella tua libreria'), findsOneWidget);
      expect(find.text('Song 0'), findsOneWidget);
      await mine.dispose(tester);

      final other = await open(
        tester,
        () async => CatalogResult(_full, DateTime(2026, 10, 22)),
        libraryTracks: 2,
      );
      expect(
        find.text('Nella tua libreria'),
        findsNothing,
        reason: 'the library has songs of «Artist», not of Pink Floyd',
      );
      await other.dispose(tester);
    },
  );

  testWidgets('a top song you already have (found by title) says so', (
    tester,
  ) async {
    final page = YtmArtistPage(
      ref: const YtmArtistRef(id: 'UCpf', name: 'Artist'),
      shelves: [
        YtmSongShelf('Brani più ascoltati', [
          ytmSong('s1', 'Song 0', artist: 'Artist'),
          ytmSong('s2', 'Other'),
        ]),
      ],
    );
    final h = await open(
      tester,
      () async => CatalogResult(page, DateTime(2026, 10, 22)),
      artist: const YtmArtistRef(id: 'UCpf', name: 'Artist'),
      libraryTracks: 2,
    );
    expect(find.text('Già in libreria'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('online header: photo left, follow outlined', (tester) async {
    final h = await open(
      tester,
      () async => CatalogResult(_full, DateTime(2026, 10, 22)),
    );
    final photo = tester.getRect(
      find.byKey(const ValueKey('collection-cover')),
    );
    final name = tester.getRect(find.byKey(const ValueKey('collection-name')));
    expect(photo.right, lessThanOrEqualTo(name.left));
    expect(find.text('25.9M ascoltatori mensili'), findsOneWidget);
    if (kEnableYoutube) {
      expect(find.byKey(const ValueKey('follow-button')), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    }
    await h.dispose(tester);
  });

  testWidgets('online header: no photo, no audience, long name', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    final artist = YtmArtistRef(id: 'UCx', name: 'N' * 80);
    await h.pump(
      tester,
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 780),
          textScaler: TextScaler.linear(1.5),
        ),
        child: ArtistPageScreen(artist: artist),
      ),
      extraOverrides: [
        artistPageProvider.overrideWith(
          (ref, id) async => CatalogResult(
            YtmArtistPage(ref: artist, shelves: const []),
            DateTime(2026, 10, 22),
          ),
        ),
      ],
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
    final name = find.byKey(const ValueKey('collection-name'));
    final cover = find.byKey(const ValueKey('collection-cover'));
    expect(name, findsOneWidget);
    expect(cover, findsOneWidget);
    expect(
      tester.getRect(cover).bottom,
      lessThanOrEqualTo(tester.getRect(name).top),
      reason: 'narrow and large text: the cover sits above the name',
    );
    expect(
      find.descendant(
        of: find.byType(ArtistHeader),
        matching: find.byWidgetPredicate((w) => w is NetThumbnail && w.circle),
      ),
      findsOneWidget,
    );
    await h.dispose(tester);
  });

  testWidgets(
    'sections are rows: no sideways lists, three similar artists, plain release line',
    (tester) async {
      final page = YtmArtistPage(
        ref: _ref,
        description: 'Una band inglese. ' * 60,
        shelves: [
          const YtmReleaseShelf('Album', [
            YtmRelease(
              browseId: 'MPREb_1',
              title: 'The Wall',
              subtitle: 'EP • 2025',
            ),
            YtmRelease(browseId: 'MPREb_2', title: 'Animals', subtitle: ''),
          ], more: YtmBrowseLink('MPAD', 'p')),
          YtmArtistShelf('Simili', [
            for (var i = 0; i < 5; i++)
              YtmArtistRef(id: 'UC$i', name: 'Simile $i'),
          ]),
        ],
      );
      final h = await open(
        tester,
        () async => CatalogResult(page, DateTime(2026, 10, 22)),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is ListView && w.scrollDirection == Axis.horizontal,
        ),
        findsNothing,
      );
      expect(find.text('Tutti'), findsOneWidget);
      expect(find.text('Mostra tutto'), findsNothing);
      expect(find.byKey(const ValueKey('similar-UC2')), findsOneWidget);
      expect(find.byKey(const ValueKey('similar-UC3')), findsNothing);
      expect(find.text('EP, 2025'), findsOneWidget);
      expect(find.text('EP • 2025'), findsNothing);
      final text = tester.widget<Text>(
        find.byKey(const ValueKey('about-text')),
      );
      expect(text.maxLines, 4);
      await tester.ensureVisible(find.byKey(const ValueKey('about-toggle')));
      await tester.tap(find.byKey(const ValueKey('about-toggle')));
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('about-text'))).maxLines,
        isNull,
      );
      await h.dispose(tester);
    },
  );

  testWidgets('an old copy is shown with the date it comes from', (
    tester,
  ) async {
    final h = await open(
      tester,
      () async => CatalogResult(_full, DateTime(2026, 10, 20), stale: true),
    );
    expect(find.byKey(const ValueKey('offline-notice')), findsOneWidget);
    expect(find.textContaining('Non in linea, dati del'), findsOneWidget);
    expect(
      find.text('Brani più ascoltati'),
      findsOneWidget,
      reason: 'the page is there as well',
    );
    await h.dispose(tester);
  });

  testWidgets(
    'an unreadable page offers the normal search; «not found» offers no retry',
    (tester) async {
      var h = await open(tester, () async => throw const InnerTubeChanged('x'));
      expect(find.textContaining('non si legge'), findsOneWidget);
      expect(find.text('Cerca i brani di Pink Floyd'), findsOneWidget);
      expect(find.byKey(const ValueKey('error-retry')), findsOneWidget);
      await h.dispose(tester);

      h = await open(tester, () async => throw const ArtistNotFound('UCpf'));
      expect(find.text('Artista non trovato'), findsOneWidget);
      expect(find.byKey(const ValueKey('error-retry')), findsNothing);
      expect(find.byKey(const ValueKey('error-search')), findsNothing);
      await h.dispose(tester);
    },
  );

  testWidgets(
    'pulling the page down asks the catalog again with refresh and reloads',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final catalog = _CountingCatalog();
      final h = await Harness.create(tester);
      await h.pump(
        tester,
        ArtistPageScreen(artist: _ref),
        extraOverrides: [ytmCatalogProvider.overrideWithValue(catalog)],
      );
      await _settle(tester);
      expect(catalog.refreshFlags, [false]);

      await tester.fling(
        find.text('Brani più ascoltati'),
        const Offset(0, 400),
        1000,
      );
      await _settle(tester);
      await _settle(tester);
      expect(catalog.refreshFlags, [
        false,
        true,
        false,
      ], reason: 'refresh, then the provider reads the new copy');
      await h.dispose(tester);
    },
  );

  group('merged profiles (D-402)', () {
    const a = YtmArtistRef(id: 'UCa', name: 'Marco Castello');
    const b = YtmArtistRef(id: 'UCb', name: 'Marco Castello', audience: '38 mila');
    const c = YtmArtistRef(id: 'UCc', name: 'Altro Nome');

    YtmArtistPage pageOf(YtmArtistRef ref, List<YtmRelease> albums) =>
        YtmArtistPage(ref: ref, shelves: [YtmReleaseShelf('Album', albums)]);

    final pages = {
      'UCa': pageOf(a, const [
        YtmRelease(browseId: 'M1', title: 'Contenta Tuttə', subtitle: 'Album • 2021'),
        YtmRelease(browseId: 'M2', title: 'Pezzi', subtitle: 'Album • 2019'),
      ]),
      'UCb': pageOf(b, const [
        YtmRelease(browseId: 'M3', title: 'CONTENTA tuttə', subtitle: '2021'),
        YtmRelease(browseId: 'M4', title: 'Nella stanza', subtitle: '2023'),
      ]),
    };

    late Harness h;
    late _SearchCatalog catalog;

    Future<void> openGroup(
      WidgetTester tester, {
      YtmArtistRef from = a,
      bool merged = true,
      List<YtmArtistRef> found = const [],
      Future<List<YtmArtistRef>> Function(String q)? search,
    }) async {
      tester.view.physicalSize = const Size(600, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      h = await Harness.create(tester);
      if (merged) await tester.runAsync(() => ArtistAliasRepository(h.db).merge('UCa', 'UCb'));
      h.mergeSearch = (_) => Future.value(found);
      catalog = _SearchCatalog(search ?? (_) async => found);
      await h.pump(
        tester,
        ArtistPageScreen(artist: from),
        extraOverrides: [
          ytmCatalogProvider.overrideWithValue(catalog),
          artistPageProvider.overrideWith(
            (ref, id) async => CatalogResult(pages[id]!, DateTime(2026, 10, 22)),
          ),
        ],
      );
      await _settle(tester);
    }

    Future<List<String>> aliases(WidgetTester tester) async =>
        (await tester.runAsync(() => ArtistAliasRepository(h.db).groupOf('UCa')))!;

    Future<void> menu(WidgetTester tester, String item) async {
      await tester.tap(find.byKey(const ValueKey('artist-menu')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(item));
      await _settle(tester);
    }

    testWidgets('two profiles with a shared album show it once, with the note', (tester) async {
      await openGroup(tester);
      expect(find.text('2 profili uniti'), findsOneWidget);
      expect(find.text('Contenta Tuttə'), findsOneWidget);
      expect(find.text('CONTENTA tuttə'), findsNothing);
      expect(find.text('Pezzi'), findsOneWidget);
      expect(find.text('Nella stanza'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('opening the alias shows the main profile page', (tester) async {
      await openGroup(tester, from: b);
      expect(find.text('2 profili uniti'), findsOneWidget);
      expect(find.text('Marco Castello'), findsWidgets);
      expect(find.text('Pezzi'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('«Separa profili» goes back to the main profile alone', (tester) async {
      await openGroup(tester);
      await menu(tester, 'Separa profili');
      expect(await aliases(tester), ['UCa']);
      expect(find.text('2 profili uniti'), findsNothing);
      expect(find.text('Nella stanza'), findsNothing);
      expect(find.text('Pezzi'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('the note lists the profiles; «Separa» splits one, marks it different, and «Annulla» joins it back', (tester) async {
      await openGroup(tester);
      await tester.tap(find.byKey(const ValueKey('merged-note')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('profile-UCa')), findsOneWidget);
      expect(find.text('Principale'), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('separate-UCb'))).height, greaterThanOrEqualTo(48));
      expect(find.byKey(const ValueKey('separate-UCa')), findsOneWidget, reason: 'the main one can leave too');
      await tester.tap(find.byKey(const ValueKey('separate-UCb')));
      await _settle(tester);
      final repo = ArtistAliasRepository(h.db);
      expect(await aliases(tester), ['UCa']);
      expect(await tester.runAsync(() => repo.isNotSame('UCa', 'UCb')), isTrue);
      expect(find.text('Profilo separato.'), findsOneWidget);
      await tester.tap(find.text('Annulla'));
      await _settle(tester);
      expect(await aliases(tester), ['UCa', 'UCb']);
      expect(await tester.runAsync(() => repo.isNotSame('UCa', 'UCb')), isFalse);
      await h.dispose(tester);
    });

    testWidgets('«Unisci con…» offers the likely profile first and merges the one chosen', (tester) async {
      await openGroup(tester, merged: false, found: const [c, b]);
      expect(find.text('Separa profili'), findsNothing);
      await menu(tester, 'Unisci con…');
      expect(find.byKey(const ValueKey('pick-UCa')), findsNothing, reason: 'the page itself is not offered');
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('pick-UCb'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('pick-UCc'))).dy),
      );
      await tester.tap(find.byKey(const ValueKey('pick-UCc')));
      await _settle(tester);
      expect(await aliases(tester), ['UCa', 'UCc']);
      await h.dispose(tester);
    });

    testWidgets('dismissing the «Unisci con…» sheet changes nothing', (tester) async {
      await openGroup(tester, merged: false, found: const [b]);
      await menu(tester, 'Unisci con…');
      expect(find.byKey(const ValueKey('pick-UCb')), findsOneWidget);
      await tester.tapAt(const Offset(300, 20));
      await _settle(tester);
      expect(find.byKey(const ValueKey('pick-UCb')), findsNothing);
      expect(await aliases(tester), ['UCa']);
      await h.dispose(tester);
    });

    testWidgets('the warning offers «Unisci»', (tester) async {
      await openGroup(tester, merged: false, found: const [b]);
      expect(find.byKey(const ValueKey('merge-warning')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('merge-yes')));
      await _settle(tester);
      expect(await aliases(tester), ['UCa', 'UCb']);
      expect(find.byKey(const ValueKey('merge-warning')), findsNothing);
      await h.dispose(tester);
    });

    testWidgets('«Sono diversi» hides the warning and it does not come back', (tester) async {
      await openGroup(tester, merged: false, found: const [b]);
      await tester.tap(find.byKey(const ValueKey('merge-different')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('merge-warning')), findsNothing);
      expect(await aliases(tester), ['UCa']);
      expect(await tester.runAsync(() => ArtistAliasRepository(h.db).isNotSame('UCa', 'UCb')), isTrue);
      await h.dispose(tester);
    });

    testWidgets('no warning for a different name or an already merged profile', (tester) async {
      await openGroup(tester, merged: false, found: const [c]);
      expect(find.byKey(const ValueKey('merge-warning')), findsNothing);
      await h.dispose(tester);
      await openGroup(tester, found: const [b]);
      expect(find.byKey(const ValueKey('merge-warning')), findsNothing);
      await h.dispose(tester);
    });

    testWidgets('the «Unisci con…» field starts as the name and searches for a different one', (tester) async {
      await openGroup(tester, merged: false, search: (q) async => q == 'Marco Castello Official' ? [c] : [b]);
      await menu(tester, 'Unisci con…');
      expect(tester.widget<TextField>(find.byKey(const ValueKey('merge-search'))).controller!.text, 'Marco Castello');
      await tester.enterText(find.byKey(const ValueKey('merge-search')), 'Marco Castello Official');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);
      expect(catalog.queries, ['Marco Castello', 'Marco Castello Official']);
      expect(find.byKey(const ValueKey('pick-UCc')), findsOneWidget);
      expect(find.byKey(const ValueKey('pick-UCb')), findsNothing);
      await h.dispose(tester);
    });

    testWidgets('a failed search says why; no result says so apart', (tester) async {
      await openGroup(tester, merged: false, search: (_) => Future.error(const YtException(YtErrorKind.network)));
      await menu(tester, 'Unisci con…');
      expect(find.byKey(const ValueKey('merge-message')), findsOneWidget);
      expect(find.text('Nessun artista trovato su YouTube Music'), findsNothing);
      await tester.tapAt(const Offset(300, 20));
      await _settle(tester);
      await h.dispose(tester);
      await openGroup(tester, merged: false, search: (_) async => const []);
      await menu(tester, 'Unisci con…');
      expect(find.text('Nessun artista trovato su YouTube Music'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('after «Separa profili» the pair is «diversi»: no warning comes back', (tester) async {
      await openGroup(tester, found: const [b]);
      await menu(tester, 'Separa profili');
      expect(find.byKey(const ValueKey('merge-warning')), findsNothing);
      expect(await tester.runAsync(() => ArtistAliasRepository(h.db).isNotSame('UCa', 'UCb')), isTrue);
      await h.dispose(tester);
    });

    testWidgets('opened from an alias, the follow button carries no photo of the alias', (tester) async {
      await openGroup(tester, from: const YtmArtistRef(id: 'UCb', name: 'Marco Castello', thumbnailUrl: 'https://x/b.jpg'));
      expect(tester.widget<FollowButton>(find.byType(FollowButton)).artist.id, 'UCa');
      expect(tester.widget<FollowButton>(find.byType(FollowButton)).artist.thumbnailUrl, isNull);
      await h.dispose(tester);
    });

    test('merged shelves: one release per title and year across shelves, newest first', () {
      const old = YtmRelease(browseId: 'o', title: 'Old', subtitle: '2010');
      final main = YtmArtistPage(ref: a, shelves: const [
        YtmReleaseShelf('Album', [old, YtmRelease(browseId: 'n', title: 'New', subtitle: '2024')], more: YtmBrowseLink('M', null)),
      ]);
      final other = YtmArtistPage(ref: b, shelves: const [
        YtmReleaseShelf('Singoli', [YtmRelease(browseId: 'x', title: 'new', subtitle: 'Singolo • 2024')]),
        YtmReleaseShelf('Album', [YtmRelease(browseId: 'm', title: 'Mid', subtitle: '2018')]),
      ]);
      final shelves = mergeArtistShelves(main, [other]).cast<YtmReleaseShelf>();
      expect(shelves.length, 1, reason: 'the single is the main profile\'s album: not a new shelf');
      expect([for (final r in shelves.single.releases) r.title], ['New', 'Mid', 'Old']);
      expect(shelves.single.more, isNotNull);
    });

    test('merged shelves: same title in different years stays two releases; symbol-only titles do not collapse', () {
      final main = YtmArtistPage(ref: a, shelves: const [
        YtmReleaseShelf('Album', [
          YtmRelease(browseId: 'l1', title: 'Live', subtitle: '2010'),
          YtmRelease(browseId: 'h', title: '\u2665', subtitle: '2020'),
        ]),
      ]);
      final other = YtmArtistPage(ref: b, shelves: const [
        YtmReleaseShelf('Album', [
          YtmRelease(browseId: 'l2', title: 'Live', subtitle: '2015'),
          YtmRelease(browseId: 's', title: '\u2606', subtitle: '2020'),
        ]),
      ]);
      final shelf = mergeArtistShelves(main, [other]).single as YtmReleaseShelf;
      expect(shelf.releases.length, 4);
    });

    test('groupShelvesProvider groups like mergeArtistShelves, and is null while the main page is missing', () async {
      final main = YtmArtistPage(
        ref: a,
        shelves: const [
          YtmReleaseShelf('Album', [
            YtmRelease(browseId: 'n', title: 'New', subtitle: '2024'),
          ]),
        ],
      );
      final other = YtmArtistPage(
        ref: b,
        shelves: const [
          YtmReleaseShelf('Album', [
            YtmRelease(browseId: 'm', title: 'Mid', subtitle: '2018'),
          ]),
        ],
      );
      ProviderContainer make(Map<String, YtmArtistPage> pages) =>
          ProviderContainer(
            overrides: [
              artistPageProvider.overrideWith((ref, id) async {
                final p = pages[id];
                if (p == null) throw StateError('missing $id');
                return CatalogResult(p, DateTime(2026, 10, 22));
              }),
            ],
          );
      List<List<String>> titles(List<YtmShelf>? l) => [
        for (final s in l!.cast<YtmReleaseShelf>())
          [for (final r in s.releases) r.title],
      ];

      final both = make({a.id: main, b.id: other});
      addTearDown(both.dispose);
      final sub = both.listen(
        groupShelvesProvider('${a.id}|${b.id}'),
        (_, _) {},
      );
      await both.read(artistPageProvider(a.id).future);
      await both.read(artistPageProvider(b.id).future);
      expect(titles(sub.read()), [
        ['New', 'Mid'],
      ]);
      expect([for (final s in sub.read()!) s.title], ['Album']);

      final none = make({b.id: other});
      addTearDown(none.dispose);
      final sub2 = none.listen(
        groupShelvesProvider('${a.id}|${b.id}'),
        (_, _) {},
      );
      await none.read(artistPageProvider(b.id).future);
      await Future<void>.delayed(Duration.zero);
      expect(sub2.read(), isNull);
    });
  });
}

