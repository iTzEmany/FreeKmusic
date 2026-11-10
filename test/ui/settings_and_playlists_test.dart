import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/ui/screens/playlists/playlist_detail_screen.dart';
import 'package:codecore/ui/screens/playlists/playlists_screen.dart';
import 'package:codecore/ui/screens/settings/settings_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/menu_support.dart';

void main() {
  testWidgets('settings builds (with a Backup group) and theme choice is persisted in state',
      (tester) async {
    tester.view.physicalSize = const Size(500, 3400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await h.pump(tester, const Scaffold(body: SettingsScreen(initial: SettingsPage.appearance)));
    expect(find.text('Aspetto'), findsOneWidget);
    expect(find.text('Italiano'), findsOneWidget);
    expect(find.text('Notte viola'), findsOneWidget);
    await tester.tap(find.text('Nero puro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(h.store.readSettings().theme, 'oled');
    await h.dispose(tester);
  });

  testWidgets('the blurred dock switch is off, labelled, at least 48 dp tall, and the tap saves it', (tester) async {
    tester.view.physicalSize = const Size(500, 3400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await h.pump(tester, const Scaffold(body: SettingsScreen(initial: SettingsPage.appearance)));
    final row = find.byKey(const ValueKey('blurred-chrome'));
    expect(h.store.readSettings().blurredChrome, isFalse);
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(row).label,
      'Dock e intestazioni sfocati\nPuò rallentare sui telefoni meno potenti',
    );
    await tester.tap(row);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(h.store.readSettings().blurredChrome, isTrue);
    await h.dispose(tester);
  });

  testWidgets('the pause-on-zero-volume switch is off by default and a tap is remembered', (tester) async {
    tester.view.physicalSize = const Size(500, 3400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await h.pump(tester, const Scaffold(body: SettingsScreen(initial: SettingsPage.playback)));
    expect(h.store.readSettings().pauseOnZeroVolume, isFalse);
    await tester.tap(find.byKey(const ValueKey('pause-on-zero-volume')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(h.store.readSettings().pauseOnZeroVolume, isTrue);
    await h.dispose(tester);
  });

  testWidgets('settings has «Pulizia libreria»: duplicates open their screen, hidden tracks are counted',
      (tester) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 2);
    await tester.runAsync(() => h.db.customUpdate("UPDATE tracks SET ignored = 1 WHERE title = 'Song 0'"));
    await h.pump(tester, const Scaffold(body: SettingsScreen(initial: SettingsPage.library)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Pulizia libreria'), findsOneWidget);
    expect(find.text('Brani nascosti (1)'), findsOneWidget);

    await tester.ensureVisible(find.text('Duplicati'));
    await tester.tap(find.text('Duplicati'));
    await tester.pumpAndSettle();
    expect(find.text('Cerca duplicati'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('playlists empty state and creation', (tester) async {
    final h = await Harness.create(tester);
    await h.pump(tester, const PlaylistsScreen());
    expect(find.text('Nessuna playlist. Creane una.'), findsOneWidget);
    await tester.tap(find.text('Nuova playlist'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Rock');
    await tester.tap(find.text('Crea'));
    await tester.pumpAndSettle();
    expect(find.text('Rock'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('rename dialog is titled «Rinomina playlist»; delete asks first',
      (tester) async {
    final h = await Harness.create(tester);
    final id = (await tester.runAsync(
        () => h.db.into(h.db.playlists).insert(PlaylistsCompanion.insert(
            name: 'Rock', createdAt: 1))))!;
    final pl = Playlist(id: id, name: 'Rock', createdAt: 1, updatedAt: 1);
    await h.pump(tester, PlaylistDetailScreen(playlist: pl));
    await tester.tap(menuButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rinomina'));
    await tester.pumpAndSettle();
    expect(find.text('Rinomina playlist'), findsOneWidget);
    expect(find.text('Nuova playlist'), findsNothing);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    await tester.tap(menuButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminare la playlist?'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    final left = await tester.runAsync(() => h.db.select(h.db.playlists).get());
    expect(left, hasLength(1));
    await h.dispose(tester);
  });

  testWidgets('«Cambia copertina» of a playlist opens the picker with the covers of its tracks, no online', (tester) async {
    final h = await Harness.create(tester, tracks: 2);
    await tester.runAsync(() async {
      final tracks = await h.db.select(h.db.tracks).get();
      await (h.db.update(h.db.tracks)..where((t) => t.id.equals(tracks[0].id)))
          .write(const TracksCompanion(coverKey: Value('cov-a')));
      final id = await h.db.into(h.db.playlists).insert(PlaylistsCompanion.insert(name: 'Rock', createdAt: 1));
      for (var i = 0; i < tracks.length; i++) {
        await h.db.into(h.db.playlistTracks).insert(
            PlaylistTracksCompanion.insert(playlistId: id, trackId: tracks[i].id, position: i));
      }
    });
    final id = (await tester.runAsync(() => h.db.select(h.db.playlists).get()))!.single.id;
    await h.pump(tester, PlaylistDetailScreen(playlist: Playlist(id: id, name: 'Rock', createdAt: 1, updatedAt: 1)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Altre azioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambia copertina'));
    await tester.pumpAndSettle();
    expect(find.text('Dal dispositivo'), findsOneWidget);
    expect(find.byKey(const ValueKey('library-cover-cov-a')), findsOneWidget);
    expect(find.text('Online'), findsNothing);
    await h.dispose(tester);
  });
}
