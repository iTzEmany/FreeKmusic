import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/shell/desktop_sidebar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _drag(WidgetTester tester, Finder from, Finder to) async {
  final gesture = await tester.startGesture(
    tester.getCenter(from),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveBy(const Offset(-30, 0));
  await tester.pump();
  await gesture.moveTo(tester.getCenter(to));
  await tester.pump();
  await gesture.up();
  await _settle(tester);
}

void main() {
  late Harness h;
  late List<Track> tracks;
  late PlaylistRepository playlists;
  late int mix;

  Future<void> open(WidgetTester tester) async {
    _desktop(tester);
    h = await Harness.create(tester, tracks: 4);
    tracks = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
    playlists = PlaylistRepository(h.db);
    mix = (await tester.runAsync(() => playlists.create('Mix')))!;
    await h.pump(
      tester,
      Scaffold(
        body: Row(
          children: const [
            DesktopSidebar(collapsed: false),
            Expanded(child: AllTracksScreen()),
          ],
        ),
      ),
    );
    await _settle(tester);
  }

  Future<List<int>> inMix(WidgetTester tester) async => [
        for (final t in (await tester.runAsync(() => playlists.watchTracks(mix).first))!) t.id,
      ];

  testWidgets('dragging a row onto a playlist of the sidebar adds the track', (tester) async {
    await open(tester);
    await _drag(tester, find.text('Song 2'), find.text('Mix'));
    expect(await inMix(tester), [tracks[2].id]);
    expect(find.text('Aggiunto a «Mix»'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the playlist under the pointer lights up while tracks are dragged, and only that one', (tester) async {
    await open(tester);
    await tester.runAsync(() => playlists.create('Other'));
    await tester.pump();
    await _settle(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text('Song 2')), kind: PointerDeviceKind.mouse);
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    int lit() => find.byKey(const ValueKey('drop-target-over')).evaluate().length;
    expect(lit(), 0);
    await gesture.moveTo(tester.getCenter(find.text('Mix')));
    await tester.pump();
    expect(lit(), 1);
    await gesture.moveTo(tester.getCenter(find.text('Other')));
    await tester.pump();
    expect(lit(), 1, reason: 'the first one is dark again');
    await gesture.up();
    await _settle(tester);
    await h.dispose(tester);
  });

  testWidgets('dragging a picked row takes the whole selection, in the order of the picks', (tester) async {
    await open(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Song 3'));
    await tester.tap(find.text('Song 1'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);
    expect(find.text('2 selezionati'), findsOneWidget);
    await _drag(tester, find.text('Song 3'), find.text('Mix'));
    expect(await inMix(tester), [tracks[3].id, tracks[1].id]);
    expect(find.text('2 brani aggiunti a «Mix»'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('dragging a row that is not picked takes only that row', (tester) async {
    await open(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Song 0'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);
    await _drag(tester, find.text('Song 2'), find.text('Mix'));
    expect(await inMix(tester), [tracks[2].id]);
    await h.dispose(tester);
  });

  testWidgets('dropping tracks already in the playlist says so', (tester) async {
    await open(tester);
    await tester.runAsync(() => playlists.addTracks(mix, [tracks[0].id, tracks[1].id]));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Song 0'));
    await tester.tap(find.text('Song 1'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);
    await _drag(tester, find.text('Song 1'), find.text('Mix'));
    expect(find.text('Erano già tutti in «Mix»'), findsOneWidget);
    expect(await inMix(tester), [tracks[0].id, tracks[1].id]);
    await h.dispose(tester);
  });

  testWidgets('dropping on Preferiti marks the tracks as favourites', (tester) async {
    await open(tester);
    await _drag(tester, find.text('Song 1'), find.text('Preferiti'));
    final fav = (await tester.runAsync(() => TrackRepository(h.db).getByIds([for (final t in tracks) t.id])))!;
    expect(fav.map((t) => t.isFavorite), [false, true, false, false]);
    expect(find.text('1 brano nei preferiti'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a plain click on a row still plays it, it is not a drag', (tester) async {
    await open(tester);
    await tester.tap(find.text('Song 1'));
    await _settle(tester);
    expect(h.handler.currentTrack?.title, 'Song 1');
    expect(await inMix(tester), isEmpty);
    await h.dispose(tester);
  });
}
