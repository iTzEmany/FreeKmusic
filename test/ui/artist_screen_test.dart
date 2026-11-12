import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/providers/cover_ops.dart';
import 'package:codecore/providers/credits_providers.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/ui/screens/library/artist_screen.dart';
import 'package:codecore/ui/widgets/album_card.dart';
import 'package:flutter/material.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

List<AlbumSummary> _albums(int n) => [
  for (var i = 0; i < n; i++)
    AlbumSummary(
      albumKey: 'a|$i',
      title: 'Album $i',
      artist: 'A',
      variousArtists: false,
      trackCount: 5,
      durationMs: 1000,
      year: 2000 + i,
      coverKey: null,
    ),
];

void main() {
  for (final (n, rows) in [(4, true), (5, false)]) {
    testWidgets('$n albums -> ${rows ? 'rows' : 'grid'}', (tester) async {
      tester.view.physicalSize = const Size(360, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester);
      await h.pump(
        tester,
        const ArtistDetailScreen(
          artist: ArtistSummary(
            key: 'a',
            name: 'A',
            trackCount: 0,
            albumCount: 0,
          ),
        ),
        extraOverrides: [
          artistAlbumsProvider('a')
              .overrideWith((ref) => Stream.value(_albums(n))),
          artistTracksProvider('a').overrideWith((ref) => Stream.value([])),
        ],
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlbumRow), rows ? findsNWidgets(n) : findsNothing);
      expect(find.byType(AlbumCard), rows ? findsNothing : findsWidgets);
      if (rows) expect(find.text('2000, 5 brani'), findsOneWidget);
      await h.dispose(tester);
    });
  }

  for (final has in [true, false]) {
    testWidgets('credited tracks ${has ? 'show' : 'hide'} «Compare come»', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester);
      Track t(int id, String title) => Track(
        id: id,
        path: '/$title.mp3',
        title: title,
        albumKey: 'y',
        format: 'mp3',
        sizeBytes: 1,
        mtimeMs: 1,
        addedAt: 1,
        durationMs: 1000,
        playCount: 0,
        missing: false,
        ignored: false,
        isFavorite: false,
        enrichStatus: 0,
        hasCover: false,
        userEdited: false,
        coverSource: 0,
        kind: 0,
      );
      await h.pump(
        tester,
        const ArtistDetailScreen(
          artist: ArtistSummary(
            key: 'a',
            name: 'A',
            trackCount: 0,
            albumCount: 0,
          ),
        ),
        extraOverrides: [
          artistAlbumsProvider('a').overrideWith((ref) => Stream.value([])),
          // The artist's own track 3 is not «Compare come» material.
          artistTracksProvider('a')
              .overrideWith((ref) => Stream.value([if (has) t(3, 'C1')])),
          artistCreditedProvider('A').overrideWith(
            (ref) => Stream.value(has
                ? [
                    (role: 'producer', track: t(1, 'P1')),
                    (role: 'producer', track: t(2, 'P2')),
                    (role: 'composer', track: t(3, 'C1')),
                  ]
                : []),
          ),
        ],
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Compare come'), has ? findsOneWidget : findsNothing);
      expect(find.text('P1'), has ? findsOneWidget : findsNothing);
      expect(find.text('C1'), findsNothing);
      await h.dispose(tester);
    });
  }

  testWidgets('the artist page offers the image change, and the reset only when one is picked', (tester) async {
    final h = await Harness.create(tester);
    await h.pump(
      tester,
      const ArtistDetailScreen(
        artist: ArtistSummary(key: 'a', name: 'A', trackCount: 0, albumCount: 0),
      ),
      extraOverrides: [
        artistAlbumsProvider('a').overrideWith((ref) => Stream.value([])),
        artistTracksProvider('a').overrideWith((ref) => Stream.value([])),
        artistImagesProvider.overrideWith((ref) => Stream.value({'a': 'k'})),
      ],
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('artist-more')));
    await tester.pumpAndSettle();
    expect(find.text('Cambia copertina'), findsOneWidget);
    expect(find.text('Ripristina immagine automatica'), findsOneWidget);
    await h.dispose(tester);
  });
}
