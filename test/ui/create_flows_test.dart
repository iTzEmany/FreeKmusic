import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/ui/screens/playlists/playlist_detail_screen.dart';
import 'package:codecore/ui/screens/playlists/playlist_dialogs.dart';
import 'package:codecore/ui/widgets/create_flows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<Harness> _open(WidgetTester tester, Future<void> Function(BuildContext, WidgetRef) run) async {
  final h = await Harness.create(tester);
  await h.pump(
    tester,
    Consumer(
      builder: (c, ref, _) => Scaffold(
        body: TextButton(onPressed: () => run(c, ref), child: const Text('open')),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return h;
}

Future<void> _submit(WidgetTester tester, String text, String button) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.text(button));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  Future<List<String>> names(Harness h) async =>
      (await h.db.select(h.db.playlists).get()).map((p) => p.name).toList();

  testWidgets('new playlist sheet: blank name cannot be created, Crea trims and opens the playlist', (tester) async {
    final h = await _open(tester, (c, ref) => createPlaylistFlow(c, ref, onSmart: () {}));
    final crea = find.widgetWithText(FilledButton, 'Crea');
    expect(tester.widget<FilledButton>(crea).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(tester.widget<FilledButton>(crea).onPressed, isNull);
    await _submit(tester, '  Mix  ', 'Crea');
    await tester.pump(const Duration(seconds: 1));
    expect(await names(h), ['Mix']);
    expect(find.byType(TextField), findsNothing); // sheet closed
    expect(find.byType(PlaylistDetailScreen), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('new playlist sheet: a duplicate name makes a second playlist; close creates nothing', (tester) async {
    final h = await _open(tester, (c, ref) => createPlaylistFlow(c, ref));
    await _submit(tester, 'Mix', 'Crea');
    await tester.pump(const Duration(seconds: 1));
    await h.db.into(h.db.playlists).insert(PlaylistsCompanion.insert(name: 'Mix', createdAt: 1));
    expect(await names(h), ['Mix', 'Mix']);
    await tester.tap(find.byType(BackButton).evaluate().isEmpty ? find.byIcon(Icons.arrow_back) : find.byType(BackButton));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Mix'), findsNWidgets(2)); // the existing ones are listed
    await tester.tap(find.byTooltip('Chiudi'));
    await tester.pump(const Duration(seconds: 1));
    expect((await names(h)).length, 2);
    await h.dispose(tester);
  });

  testWidgets('new playlist sheet: tapping a playlist opens it; shortcuts only with onSmart', (tester) async {
    final h = await _open(tester, (c, ref) => createPlaylistFlow(c, ref));
    expect(find.text('Nuova playlist intelligente'), findsNothing);
    await tester.tap(find.byTooltip('Chiudi'));
    await tester.pump(const Duration(seconds: 1));
    await h.dispose(tester);

    var smart = 0;
    final h2 = await _open(tester, (c, ref) => createPlaylistFlow(c, ref, onSmart: () => smart++));
    expect(find.text('Importa da Exportify (CSV)'), findsOneWidget);
    await tester.tap(find.text('Nuova playlist intelligente'));
    await tester.pump(const Duration(seconds: 1));
    expect(smart, 1);
    expect(await names(h2), isEmpty);
    await h2.dispose(tester);
  });

  group('add to playlist', () {
    Future<(Harness, List<Track>)> openAdd(WidgetTester tester,
        {Future<void> Function(Harness, List<Track>)? seed}) async {
      final h = await Harness.create(tester, tracks: 2);
      final tracks = await h.db.select(h.db.tracks).get();
      await h.db.into(h.db.playlists).insert(PlaylistsCompanion.insert(name: 'Rock', createdAt: 1));
      await seed?.call(h, tracks);
      await h.pump(
        tester,
        Consumer(
          builder: (c, ref, _) => Scaffold(
            body: TextButton(
              onPressed: () => showAddToPlaylistSheet(c, ref, [tracks.first]),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      return (h, tracks);
    }

    testWidgets('a tap adds the track, says so and closes; the second time says it is already there', (tester) async {
      final (h, tracks) = await openAdd(tester);
      expect(find.text('Nuova playlist intelligente'), findsNothing);
      await tester.tap(find.text('Rock'));
      await tester.pump(const Duration(seconds: 1));
      expect((await h.db.select(h.db.playlistTracks).get()).map((r) => r.trackId), [tracks.first.id]);
      expect(find.text('Aggiunto a «Rock»'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(TextField), findsNothing);

      await tester.pump(const Duration(seconds: 6));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Rock'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Erano già tutti in «Rock»'), findsOneWidget);
      expect(await h.db.select(h.db.playlistTracks).get(), hasLength(1));
      await h.dispose(tester);
    });

    testWidgets('a playlist that already holds the track shows the marker, the others do not', (tester) async {
      final (h, _) = await openAdd(tester, seed: (h, tracks) async {
        await h.db.into(h.db.playlists).insert(PlaylistsCompanion.insert(name: 'Jazz', createdAt: 2));
        final rock = (await h.db.select(h.db.playlists).get()).firstWhere((p) => p.name == 'Rock').id;
        await h.db.into(h.db.playlistTracks).insert(
            PlaylistTracksCompanion.insert(playlistId: rock, trackId: tracks.first.id, position: 0));
      });
      await tester.pump(const Duration(milliseconds: 400));
      Finder marker(String name) => find.descendant(
          of: find.widgetWithText(ListTile, name), matching: find.byIcon(Icons.check_circle_rounded));
      expect(marker('Rock'), findsOneWidget);
      expect(marker('Jazz'), findsNothing);
      await h.dispose(tester);
    });

    testWidgets('Crea makes a new playlist holding the track; smart playlists are not listed', (tester) async {
      final (h, tracks) = await openAdd(tester);
      await h.db.into(h.db.smartPlaylists).insert(
        SmartPlaylistsCompanion.insert(name: 'Magica', rules: 'x', createdAt: 1),
      );
      await _submit(tester, 'Nuova', 'Crea');
      await tester.pump(const Duration(seconds: 1));
      final made = (await h.db.select(h.db.playlists).get()).firstWhere((p) => p.name == 'Nuova');
      final rows = await h.db.select(h.db.playlistTracks).get();
      expect(rows.where((r) => r.playlistId == made.id).map((r) => r.trackId), [tracks.first.id]);
      expect(find.text('Aggiunto a «Nuova»'), findsOneWidget);
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Magica'), findsNothing);
      await h.dispose(tester);
    });
  });

  testWidgets('createTagFlow creates the tag; cancel creates nothing', (tester) async {
    UserTag? made;
    final h = await _open(tester, (c, ref) async => made = await createTagFlow(c, ref));
    await _submit(tester, ' Rock ', 'Salva');
    expect(made?.name, 'Rock');
    expect(await h.db.select(h.db.userTags).get(), hasLength(1));
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Annulla'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(await h.db.select(h.db.userTags).get(), hasLength(1));
    await h.dispose(tester);
  });
}
