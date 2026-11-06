import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/ui/screens/home/home_screen.dart';
import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/theme/custom_theme.dart';
import 'package:codecore/ui/screens/playlists/playlist_detail_screen.dart';
import 'package:codecore/ui/screens/playlists/playlists_screen.dart';
import 'package:codecore/ui/screens/settings/settings_screen.dart';
import 'package:codecore/ui/screens/settings/theme_editor_screen.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/shell/bottom_bar.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

// The list pages scroll under the dock (extendBody): the last content must
// come to rest above it, with the mini-player empty and with a track playing.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)));
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<Harness> _open(WidgetTester t, {required bool playing}) async {
  t.view.physicalSize = const Size(400, 600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final h = await Harness.create(t, tracks: 30);
  await t.runAsync(() async {
    for (var i = 0; i < 30; i++) {
      await h.db.into(h.db.tracks).insert(TracksCompanion.insert(
            path: '/m/x$i.mp3',
            title: 'Other $i',
            albumKey: 'artist $i|album $i',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 100 + i,
            artist: Value('Artist $i'),
            album: Value('Album x$i'),
          ));
    }
    final repo = PlaylistRepository(h.db);
    final id = await repo.create('Long');
    await repo.addTracks(id, [for (var i = 1; i <= 30; i++) i]);
  });
  await h.pump(t, const AppShell());
  await _settle(t);
  if (playing) {
    await t.tap(find.text('Libreria'));
    await _settle(t);
    await t.tap(find.text('Tutti i brani'));
    await _settle(t);
    await t.tap(find.text('Other 0').first);
    await _settle(t);
    await t.tap(find.byIcon(Icons.arrow_back));
    await _settle(t);
    await t.tap(find.text('Home'));
    await _settle(t);
  }
  return h;
}

Future<void> _push(WidgetTester t, Widget page) async {
  Navigator.of(t.element(find.byType(HomeScreen))).push(
    MaterialPageRoute<void>(builder: (_) => page),
  );
  await _settle(t);
}

Future<void> _expectLastAboveDock(WidgetTester t) async {
  // The page's own list: the one that scrolls furthest (text fields have
  // scrollables of their own).
  final pos = [
    for (final e in find
        .descendant(
          of: find.byType(IndexedStack),
          matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axis == Axis.vertical,
          ),
        )
        .evaluate())
      (e as StatefulElement).state is ScrollableState
          ? ((e).state as ScrollableState).position
          : throw StateError('not a Scrollable'),
  ].reduce((a, b) => a.maxScrollExtent >= b.maxScrollExtent ? a : b);
  // Lazy lists refine their extent while they build: jump until it holds.
  for (var i = 0; i < 6; i++) {
    pos.jumpTo(pos.maxScrollExtent);
    await t.pump(const Duration(milliseconds: 300));
  }
  final dockTop = t.getTopLeft(find.byType(ShellDock)).dy;
  final texts = find.descendant(
    of: find.byType(IndexedStack),
    matching: find.byType(Text),
  );
  var bottom = 0.0;
  for (final e in texts.evaluate()) {
    final r = t.getRect(find.byElementPredicate((x) => x == e));
    if (r.top < 600) bottom = r.bottom > bottom ? r.bottom : bottom;
  }
  expect(bottom, lessThanOrEqualTo(dockTop));
}

void main() {
  for (final playing in [false, true]) {
    final mp = playing ? 'mini-player playing' : 'mini-player empty';
    testWidgets('Home: the last row clears the dock, $mp', (t) async {
      final h = await _open(t, playing: playing);
      await _expectLastAboveDock(t);
      await h.dispose(t);
    });

    testWidgets('Library: the last row clears the dock, $mp', (t) async {
      final h = await _open(t, playing: playing);
      await t.tap(find.text('Libreria'));
      await _settle(t);
      await _expectLastAboveDock(t);
      await h.dispose(t);
    });

    testWidgets('All tracks: the last row clears the dock, $mp', (t) async {
      final h = await _open(t, playing: playing);
      await _push(t, const AllTracksScreen());
      await _expectLastAboveDock(t);
      await h.dispose(t);
    });

    testWidgets('Playlist: the last row clears the dock, $mp', (t) async {
      final h = await _open(t, playing: playing);
      final pl = (await t.runAsync(() => h.db.select(h.db.playlists).get()))!;
      await _push(t, PlaylistDetailScreen(playlist: pl.single));
      await _expectLastAboveDock(t);
      await h.dispose(t);
    });
  }
  testWidgets('Settings: the last row clears the dock', (t) async {
    final h = await _open(t, playing: false);
    await _push(t, const SettingsScreen());
    await _expectLastAboveDock(t);
    await h.dispose(t);
  });

  testWidgets('Theme editor: the last row clears the dock', (t) async {
    final h = await _open(t, playing: false);
    await _push(
      t,
      const ThemeEditorScreen(initial: CustomTheme(id: 'sea', name: 'Mare')),
    );
    await _expectLastAboveDock(t);
    await h.dispose(t);
  });

  testWidgets('Playlists: both FABs sit above the dock', (t) async {
    final h = await _open(t, playing: false);
    await _push(t, const PlaylistsScreen());
    final dockTop = t.getTopLeft(find.byType(ShellDock)).dy;
    for (final fab in find.byType(FloatingActionButton).evaluate()) {
      final r = t.getRect(find.byElementPredicate((e) => e == fab));
      expect(r.bottom, lessThanOrEqualTo(dockTop));
    }
    expect(find.byType(FloatingActionButton), findsNWidgets(2));
    await h.dispose(t);
  });
}
