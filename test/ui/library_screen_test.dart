import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_entries.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/ui/screens/library/library_screen.dart';
import 'package:codecore/ui/screens/library/library_shortcuts.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/widgets/cc_search_field.dart';
import 'package:codecore/ui/widgets/skeleton.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:codecore/ui/widgets/segmented_blocks.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/search_input.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  Future<Harness> open(
    WidgetTester tester, {
    double width = 400,
    int tracks = 4,
  }) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: tracks);
    if (width >= 840) {
      await h.pump(tester, const LibraryScreen());
    } else {
      await h.pump(tester, const AppShell());
      await tester.tap(find.text('Libreria'));
    }
    await _settle(tester);
    return h;
  }

  testWidgets('blocks filter the list and the count follows', (t) async {
    final h = await open(t);
    expect(find.text('Tutto'), findsOneWidget);
    expect(find.text('Album 0'), findsOneWidget);
    await t.tap(find.text('Album').first);
    await _settle(t);
    expect(find.text('2 album'), findsOneWidget);
    expect(find.text('Artist'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    await t.tap(find.text('Tutto'));
    await _settle(t);
    expect(find.text('Album 0'), findsOneWidget);
    await t.tap(find.byIcon(Icons.grid_view_rounded));
    await _settle(t);
    expect(find.text('Album 0'), findsOneWidget);
    expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);
    expect(t.takeException(), isNull);
    await h.dispose(t);
  });

  testWidgets('first load shows skeleton rows, not a spinner', (t) async {
    final h = await open(t);
    await t.pumpWidget(const SizedBox());
    await h.pump(
      t,
      const LibraryScreen(),
      extraOverrides: [
        playlistsProvider.overrideWith(
          (_) => Completer<List<PlaylistSummary>>().future.asStream(),
        ),
      ],
    );
    expect(find.byType(Skeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await h.dispose(t);
  });

  testWidgets('the lens opens a focused search with grouped results; Back closes it', (t) async {
    final h = await open(t, width: 900);
    await t.tap(find.byIcon(Icons.search_rounded));
    await _settle(t);
    expect(find.byType(CcSearchField), findsOneWidget);
    expect(t.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, isTrue);
    expect(find.text('Libreria'), findsNothing);
    await t.enterText(find.byType(TextField), 'Song');
    await t.pump();
    await indexReady(t);
    await _settle(t);
    expect(find.text('Brani'), findsOneWidget);
    expect(find.text('Song 0'), findsOneWidget);
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(find.byType(CcSearchField), findsNothing);
    expect(find.text('Libreria'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('with reduced motion the search opens at once', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = await open(t, width: 900);
    await t.tap(find.byIcon(Icons.search_rounded));
    await t.pump();
    await t.pump();
    expect(find.byType(CcSearchField), findsOneWidget);
    expect(find.text('Libreria'), findsNothing);
    await h.dispose(t);
  });

  testWidgets('sort menu switches to A–Z', (t) async {
    final h = await open(t);
    await t.tap(find.text('Recenti'));
    await t.pumpAndSettle();
    await t.tap(find.text('A–Z').last);
    await t.pumpAndSettle();
    await _settle(t);
    expect(find.text('A–Z'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('shortcuts only in Tutto, in spec order', (t) async {
    final h = await open(t);
    final fav = t.getRect(find.text('Preferiti'));
    final all = t.getRect(find.text('Tutti i brani'));
    expect(all.left > fav.left || all.top > fav.top, isTrue);
    await t.tap(find.text('Album').first);
    await _settle(t);
    expect(find.text('Preferiti'), findsNothing);
    await h.dispose(t);
  });

  Rect block(WidgetTester t, String label) => t.getRect(
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
  );

  testWidgets(
    'phone: shortcuts are 2 columns, the odd last one is full width',
    (t) async {
      final h = await open(t, width: 360);
      final fav = block(t, 'Preferiti');
      final all = block(t, 'Tutti i brani');
      final last = block(t, 'Statistiche');
      expect(all.top, fav.top);
      expect(all.left, greaterThan(fav.right));
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      // 7 blocks here: the seventh spans both columns.
      expect(last.left, fav.left);
      expect(last.right, all.right);
      await h.dispose(t);
    },
  );

  testWidgets('desktop: all shortcuts on one row', (t) async {
    final h = await open(t, width: 1600);
    final fav = block(t, 'Preferiti');
    final last = block(t, 'Statistiche');
    expect(last.top, fav.top);
    expect(last.left, greaterThan(fav.right));
    await h.dispose(t);
  });

  testWidgets('desktop, German: shortcuts stay on one row without overflow', (
    t,
  ) async {
    t.view.physicalSize = const Size(1280, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t, tracks: 4);
    await h.pump(t, const LibraryScreen(), locale: const Locale('de'));
    await _settle(t);
    final tops = {
      for (final e
          in find
              .descendant(
                of: find.byType(LibraryShortcuts),
                matching: find.byType(InkWell),
              )
              .evaluate())
        t.getRect(find.byWidget(e.widget)).top,
    };
    expect(tops.length, 1);
    expect(t.takeException(), isNull);
    await h.dispose(t);
  });

  testWidgets('shortcuts with icons keep the old grid on a wide screen', (
    t,
  ) async {
    t.view.physicalSize = const Size(1200, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t);
    await h.pump(
      t,
      Scaffold(
        body: LibraryShortcuts(
          items: [
            for (var i = 0; i < 5; i++)
              LibraryShortcut(label: 'S$i', icon: Icons.star, onTap: () {}),
          ],
        ),
      ),
    );
    // 4 per row, the fifth wraps to a second row.
    expect(t.getRect(find.text('S3')).top, t.getRect(find.text('S0')).top);
    expect(
      t.getRect(find.text('S4')).top,
      greaterThan(t.getRect(find.text('S0')).top),
    );
    await h.dispose(t);
  });

  testWidgets('filters never scroll sideways', (t) async {
    final h = await open(t);
    expect(
      find.descendant(
        of: find.byType(SegmentedBlocks<LibraryKind?>),
        matching: find.byWidgetPredicate(
          (w) => w is ListView && w.scrollDirection == Axis.horizontal,
        ),
      ),
      findsNothing,
    );
    await h.dispose(t);
  });

  testWidgets('with zero podcasts, radios and tags the three shortcuts show', (
    t,
  ) async {
    final h = await open(t);
    expect(find.text('Preferiti'), findsOneWidget);
    expect(find.text('Tutti i brani'), findsOneWidget);
    expect(find.text('Podcast'), findsOneWidget);
    expect(find.text('Radio'), findsOneWidget);
    expect(find.text('Etichette'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('A–Z headers follow leadingLetter', (t) async {
    final h = await open(t, tracks: 0);
    var i = 0;
    for (final album in ['Abba', 'Ägypten', '1999', 'Beta']) {
      await h.db
          .into(h.db.tracks)
          .insert(
            TracksCompanion.insert(
              path: '/m/x${i++}.mp3',
              title: 'T$i',
              albumKey: 'a|$album',
              format: 'mp3',
              sizeBytes: 1,
              mtimeMs: 1,
              addedAt: i,
              artist: const Value('Zed'),
              album: Value(album),
            ),
          );
    }
    await _settle(t);
    expect(find.text('A'), findsNothing);
    await t.tap(find.text('Recenti'));
    await t.pumpAndSettle();
    await t.tap(find.text('A–Z').last);
    await t.pumpAndSettle();
    await _settle(t);
    // Headers only: covers may also show an initial.
    Finder header(String x) => find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data == x &&
          w.style?.color == CcColors.notte.accentSoft,
    );
    for (final x in ['A', 'B', '#', 'Z']) {
      expect(header(x), findsOneWidget, reason: x);
    }
    await h.dispose(t);
  });

  testWidgets(
    'every tab and sort keeps its order, also after Tutto→Playlist→Tutto',
    (t) async {
      final h = await open(t, tracks: 0);
      final rows = [
        ('Mina', 'Zeta', 5000),
        ('Zed', 'Alfa', null),
        ('Bea', 'Beta', null),
      ];
      for (final (i, (artist, album, played)) in rows.indexed) {
        await h.db
            .into(h.db.tracks)
            .insert(
              TracksCompanion.insert(
                path: '/m/o$i.mp3',
                title: 'T$i',
                albumKey: '$artist|$album',
                format: 'mp3',
                sizeBytes: 1,
                mtimeMs: 1,
                addedAt: i,
                artist: Value(artist),
                album: Value(album),
                lastPlayedAt: Value(played),
              ),
            );
      }
      final playlists = PlaylistRepository(h.db);
      await playlists.create('Playlist B');
      await playlists.create('Playlist A');
      await _settle(t);

      List<String> order(List<String> names) {
        final seen =
            [
              for (final n in names)
                if (find.text(n).evaluate().isNotEmpty) n,
            ]..sort(
              (a, b) => t
                  .getTopLeft(find.text(a))
                  .dy
                  .compareTo(t.getTopLeft(find.text(b)).dy),
            );
        return seen;
      }

      const everything = [
        'Mina',
        'Zeta',
        'Alfa',
        'Bea',
        'Beta',
        'Playlist A',
        'Playlist B',
        'Zed',
      ];
      // Recent: the played ones first (the artist and the album, same moment, A–Z), then the rest A–Z.
      const recentAll = [
        'Mina',
        'Zeta',
        'Alfa',
        'Bea',
        'Beta',
        'Playlist A',
        'Playlist B',
        'Zed',
      ];
      expect(order(everything), recentAll);

      Future<void> tab(String label) async {
        await t.tap(find.text(label).first);
        await _settle(t);
      }

      await tab('Playlist');
      expect(order(everything), ['Playlist A', 'Playlist B']);
      await tab('Album');
      expect(order(everything), ['Zeta', 'Alfa', 'Beta']);
      await tab('Artisti');
      expect(order(everything), ['Mina', 'Bea', 'Zed']);
      await tab('Tutto');
      expect(order(everything), recentAll);

      await t.tap(find.text('Recenti'));
      await t.pumpAndSettle();
      await t.tap(find.text('A–Z').last);
      await t.pumpAndSettle();
      await _settle(t);
      const alphaAll = [
        'Alfa',
        'Bea',
        'Beta',
        'Mina',
        'Playlist A',
        'Playlist B',
        'Zed',
        'Zeta',
      ];
      expect(order(everything), alphaAll);
      await tab('Playlist');
      expect(order(everything), ['Playlist A', 'Playlist B']);
      await tab('Album');
      expect(order(everything), ['Alfa', 'Beta', 'Zeta']);
      await tab('Artisti');
      expect(order(everything), ['Bea', 'Mina', 'Zed']);
      await tab('Tutto');
      expect(order(everything), alphaAll);
      await h.dispose(t);
    },
  );

  testWidgets('desktop: content reaches the same right edge as the header', (
    t,
  ) async {
    final h = await open(t, width: 1600);
    final r = t.getRect(find.byType(SegmentedBlocks<LibraryKind?>));
    final menu = t.getRect(find.byTooltip('Altre azioni'));
    expect(r.right, greaterThanOrEqualTo(menu.right - 2 * CcDims.margin));
    await h.dispose(t);
  });
}
