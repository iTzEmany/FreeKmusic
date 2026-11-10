import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/widgets/play_buttons.dart';
import 'package:codecore/ui/widgets/shrinking_header.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

// Selection, search, sort and drag are covered in selection_lists_test and
// track_drag_test; this file pins what the header buttons and a row tap start.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 120)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<Harness> _open(
  WidgetTester tester, {
  int tracks = 4,
  SortOption? sort,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create(tester, tracks: tracks);
  await h.pump(tester, AllTracksScreen(initialSort: sort));
  await _settle(tester);
  return h;
}

void main() {
  testWidgets('downloadedNoPlaylist lists only the matching tracks, with search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 4);
    final folder = await h.db.into(h.db.folders).insert(
      FoldersCompanion.insert(path: '/m', addedAt: 1),
    );
    // Song 0 and 1 are in the download folder; 1 is also in a playlist.
    await (h.db.update(h.db.tracks)..where((t) => t.title.isIn(['Song 0', 'Song 1'])))
        .write(TracksCompanion(folderId: Value(folder)));
    final pl = await h.db.into(h.db.playlists).insert(
      PlaylistsCompanion.insert(name: 'P', createdAt: 1),
    );
    final id1 = (await (h.db.select(h.db.tracks)..where((t) => t.title.equals('Song 1'))).getSingle()).id;
    await h.db.into(h.db.playlistTracks).insert(
      PlaylistTracksCompanion.insert(playlistId: pl, trackId: id1, position: 0),
    );
    h.downloadFolderId = folder;
    await h.pump(tester, const AllTracksScreen(downloadedNoPlaylist: true));
    await _settle(tester);
    expect(find.text('Scaricati senza playlist'), findsOneWidget);
    expect(find.byType(TrackRow), findsOneWidget);
    expect(find.text('Song 0'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    expect(find.byType(TrackRow), findsNothing);
    expect(find.text('Nessun risultato'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('downloadedNoPlaylist with nothing to list says every download is in a playlist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 2);
    await h.pump(tester, const AllTracksScreen(downloadedNoPlaylist: true));
    await _settle(tester);
    expect(find.text('Tutti i brani scaricati stanno già in una playlist'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets(
    'the play icon starts the whole list from the first, shuffle off',
    (tester) async {
      final h = await _open(tester);
      expect(
        tester.getSize(find.byType(PlayCircleButton)),
        const Size(48, 48),
      );
      await tester.tap(find.byTooltip('Riproduci'));
      await _settle(tester);
      expect(h.handler.queueIds, hasLength(4));
      expect(h.handler.currentIndex, 0);
      expect(h.handler.shuffleEnabled, isFalse);
      await h.dispose(tester);
    },
  );

  testWidgets('the shuffle icon turns the list mode on: nothing starts (D-534)', (
    tester,
  ) async {
    final h = await _open(tester);
    await tester.tap(find.byTooltip('Casuale: spenta'));
    await _settle(tester);
    expect(find.byTooltip('Casuale: attiva'), findsOneWidget);
    expect(h.handler.queueIds, isEmpty);
    expect(h.handler.shuffleEnabled, isFalse, reason: 'not the playing queue');
    // The list's next Play applies its own mode.
    await tester.tap(find.byType(PlayCircleButton));
    await _settle(tester);
    expect(h.handler.shuffleEnabled, isTrue);
    await h.dispose(tester);
  });

  testWidgets('tapping a row plays the list from that row', (tester) async {
    final h = await _open(tester);
    await tester.tap(find.text('Song 2'));
    await _settle(tester);
    expect(h.handler.queueIds, hasLength(4));
    // Default order: latest added first, so Song 2 is the second row.
    expect(h.handler.currentIndex, 1);
    await h.dispose(tester);
  });

  testWidgets('a row menu offers the track actions', (tester) async {
    final h = await _open(tester);
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(TrackRow, 'Song 1').first,
        matching: find.byTooltip('Altre opzioni'),
      ),
    );
    await _settle(tester);
    expect(find.text('Aggiungi in coda'), findsOneWidget);
    expect(find.text('Vai all’album'), findsOneWidget);
    await h.dispose(tester);
  });

  // Rows are Draggables on desktop, so a touch drag would not scroll: use the wheel.
  Future<void> wheel(WidgetTester t, double dy) async {
    final p = TestPointer(1, PointerDeviceKind.mouse);
    await t.sendEventToBinding(p.hover(const Offset(200, 600)));
    await t.sendEventToBinding(p.scroll(Offset(0, dy)));
    await t.pump();
  }

  // Visible height of the search and chips block (0 once it is gone).
  double barHeight(WidgetTester t) =>
      t.renderObject<RenderSliver>(find.byType(ShrinkingHeader, skipOffstage: false)).geometry!.paintExtent;

  testWidgets('the search block follows the scroll 1:1 and returns going up', (
    tester,
  ) async {
    final h = await _open(tester, tracks: 40);
    final full = barHeight(tester);
    expect(full, greaterThan(100));
    await wheel(tester, 100);
    expect(barHeight(tester), full - 100);
    await wheel(tester, 400);
    expect(barHeight(tester), 0);
    // The fixed row stays while the block is gone.
    expect(find.byType(PlayCircleButton), findsOneWidget);
    await wheel(tester, -60);
    expect(barHeight(tester), 60);
    await h.dispose(tester);
  });

  testWidgets('an active search survives the block scrolling away and back', (
    tester,
  ) async {
    final h = await _open(tester, tracks: 40);
    await tester.enterText(find.byType(TextField), 'Song');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    await wheel(tester, 600);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TrackRow), findsWidgets);
    await wheel(tester, -600);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Song');
    await h.dispose(tester);
  });

  testWidgets('the A-Z strip reaches the last letter with the block gone', (
    tester,
  ) async {
    final h = await _open(tester, tracks: 40, sort: SortOption.title);
    await wheel(tester, 400);
    expect(barHeight(tester), 0);
    await tester.dragFrom(const Offset(390, 400), const Offset(0, 495));
    await _settle(tester);
    // Title order: «Song 9» is the last row.
    expect(find.text('Song 9'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('initialSort is applied and typing filters this screen', (
    tester,
  ) async {
    final h = await _open(tester, sort: SortOption.title);
    final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    expect(c.read(trackQueryProvider(false)).sort, SortOption.title);
    await tester.enterText(find.byType(TextField), 'Song 2');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    expect(find.byType(TrackRow), findsOneWidget);
    // The text is the screen's own: nothing shared to clean up.
    expect(c.read(trackQueryProvider(false)).text, isEmpty);
    await h.dispose(tester);
  });

  testWidgets('changing the sort reorders the rows', (tester) async {
    final h = await _open(tester);
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('Song 0'), lessThan(y('Song 1'))); // default: by album
    expect(y('Song 2'), lessThan(y('Song 1')));
    final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    c.read(trackQueryProvider(false).notifier).update((q) => q.copyWith(sort: SortOption.addedAt));
    await _settle(tester);
    expect(y('Song 3'), lessThan(y('Song 2'))); // newest first
    expect(y('Song 1'), lessThan(y('Song 0')));
    await h.dispose(tester);
  });
  testWidgets('two screens open together do not share the search text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, const Scaffold(body: SizedBox()));
    final nav = Navigator.of(tester.element(find.byType(Scaffold)));
    for (var i = 0; i < 2; i++) {
      unawaited(
        nav.push(
          MaterialPageRoute<void>(builder: (_) => const AllTracksScreen()),
        ),
      );
      await _settle(tester);
    }
    await tester.enterText(find.byType(TextField, skipOffstage: false).last, 'Song 2');
    await tester.pump(const Duration(milliseconds: 400));
    await _settle(tester);
    final fields = tester
        .widgetList<TextField>(find.byType(TextField, skipOffstage: false))
        .toList();
    expect(fields, hasLength(2));
    expect(fields.where((f) => f.controller!.text.isEmpty), hasLength(1));
    await h.dispose(tester);
  });
}
