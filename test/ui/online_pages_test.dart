import 'package:codecore/providers/ytm_catalog_providers.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/services/online/ytm_catalog.dart';
import 'package:codecore/ui/screens/online/artist_picker_sheet.dart';
import 'package:codecore/ui/screens/online/artist_songs_screen.dart';
import 'package:codecore/ui/screens/online/discography_screen.dart';
import 'package:codecore/ui/screens/online/online_album_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_ytm.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

const _pink = YtmArtistRef(id: 'UCpf', name: 'Pink Floyd');

final _album = YtmAlbum(
  browseId: 'MPREb_wall',
  title: 'The Wall',
  artist: _pink,
  year: '1979',
  kindLabel: 'Album',
  tracks: [
    YtmAlbumTrack(1, ytmSong('a', 'In the Flesh?', seconds: 199)),
    YtmAlbumTrack(2, ytmSong('b', 'The Thin Ice', seconds: 147)),
    YtmAlbumTrack(3, ytmSong('c', 'Another Brick', seconds: 191)),
  ],
);

void main() {
  Future<Harness> show(WidgetTester tester, Widget page, List<Override> overrides) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await h.pump(tester, page, extraOverrides: overrides);
    await _settle(tester);
    return h;
  }

  testWidgets('album page: header, numbered songs, and «Scarica album» asks before starting', (tester) async {
    final h = await show(
      tester,
      const OnlineAlbumScreen(browseId: 'MPREb_wall'),
      [onlineAlbumProvider.overrideWith((ref, id) async => CatalogResult(_album, DateTime(2026, 10, 22)))],
    );
    expect(find.text('The Wall'), findsWidgets);
    expect(find.text('Album, 1979'), findsOneWidget);
    expect(find.text('3 brani, 8 min'), findsOneWidget);
    expect(find.text('In the Flesh?'), findsOneWidget);
    expect(find.text('3'), findsOneWidget, reason: 'the number of the third song');
    expect(find.byKey(const ValueKey('album-artist')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('album-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<Object>('album-menu-download')));
    await _settle(tester);
    expect(find.text('Scaricare «The Wall»?'), findsOneWidget);
    expect(find.textContaining('3 brani, 8 min, circa'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await _settle(tester);
    expect(find.text('Scaricare «The Wall»?'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('album page: the last song clears the dock height (extendBody padding)', (tester) async {
    final long = YtmAlbum(
      browseId: 'MPREb_long',
      title: 'Long',
      artist: _pink,
      kindLabel: 'Album',
      tracks: [for (var i = 0; i < 30; i++) YtmAlbumTrack(i + 1, ytmSong('l$i', 'Long song $i', seconds: 100 + i))],
    );
    final h = await show(
      tester,
      Builder(
        builder: (c) => MediaQuery(
          data: MediaQuery.of(c).copyWith(padding: const EdgeInsets.only(bottom: 90)),
          child: const OnlineAlbumScreen(browseId: 'MPREb_long'),
        ),
      ),
      [onlineAlbumProvider.overrideWith((ref, id) async => CatalogResult(long, DateTime(2026, 10, 22)))],
    );
    final pos = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    for (var i = 0; i < 4; i++) {
      pos.jumpTo(pos.maxScrollExtent);
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(tester.getRect(find.text('Long song 29')).bottom, lessThanOrEqualTo(1400.0 - 90));
    await h.dispose(tester);
  });

  testWidgets('long song list shows every song', (tester) async {
    final h = await show(
      tester,
      const ArtistSongsScreen(artist: _pink, title: 'Brani', link: YtmBrowseLink('VLOLAK', null)),
      [
        artistSongsProvider.overrideWith((ref, key) async => CatalogResult(
            [for (var i = 0; i < 5; i++) ytmSong('s$i', 'Song $i', seconds: 100 + i)], DateTime(2026, 10, 22))),
      ],
    );
    for (var i = 0; i < 5; i++) {
      expect(find.text('Song $i'), findsOneWidget);
    }
    await h.dispose(tester);
  });

  testWidgets('discography: a grid of covers; a tap opens the album', (tester) async {
    final h = await show(
      tester,
      const DiscographyScreen(artist: _pink, title: 'Album', link: YtmBrowseLink('MPAD', 'p')),
      [
        discographyProvider.overrideWith((ref, key) async => CatalogResult(const [
              YtmRelease(browseId: 'MPREb_wall', title: 'The Wall', subtitle: '1979'),
              YtmRelease(browseId: 'MPREb_2', title: 'Animals', subtitle: '1977'),
            ], DateTime(2026, 10, 22))),
        onlineAlbumProvider.overrideWith((ref, id) async => CatalogResult(_album, DateTime(2026, 10, 22))),
      ],
    );
    expect(find.text('Animals'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('release-MPREb_wall')));
    await _settle(tester);
    expect(find.byType(OnlineAlbumScreen), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the artist chooser lists the artists offered', (tester) async {
    final h = await show(
      tester,
      const Scaffold(
        body: ArtistPickerSheet(artists: [
          YtmArtistRef(id: 'UC1', name: 'Queen', audience: '30M'),
          YtmArtistRef(id: 'UC2', name: 'Queen Latifah'),
        ]),
      ),
      const [],
    );
    expect(find.text('Quale artista?'), findsOneWidget);
    expect(find.byKey(const ValueKey('pick-UC1')), findsOneWidget);
    expect(find.text('30M'), findsOneWidget);
    await h.dispose(tester);
  });
}
