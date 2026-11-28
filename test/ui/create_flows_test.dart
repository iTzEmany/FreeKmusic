import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/ui/screens/playlists/playlist_detail_screen.dart';
import 'package:codecore/ui/screens/playlists/playlist_dialogs.dart';
import 'package:codecore/ui/widgets/create_flows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:codecore/providers/playlist_ops.dart';
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

class _FailSecondOps extends PlaylistOps {
  _FailSecondOps(super.ref);
  var _n = 0;
  @override
  Future<int> addTracks(int playlistId, List<int> trackIds) async {
    if (++_n == 2) throw StateError('boom');
    return super.addTracks(playlistId, trackIds);
  }
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

  testWidgets('new playlist sheet: the name field has no focus on open', (tester) async {
    final h = await _open(tester, (c, ref) => createPlaylistFlow(c, ref, onSmart: () {}));
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>(), isNull);
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
        {Future<void> Function(Harness, List<Track>)? seed, List<Override> extra = const []}) async {
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
        extraOverrides: extra,
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      return (h, tracks);
    }

    Future<void> reopen(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 6));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> confirm(WidgetTester tester) async {
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(seconds: 1));
    }

    Future<Set<int>> rowsOf(Harness h, String name) async {
      final id = (await h.db.select(h.db.playlists).get()).firstWhere((p) => p.name == name).id;
      return {
        for (final r in await h.db.select(h.db.playlistTracks).get())
          if (r.playlistId == id) r.trackId,
      };
    }

    FilledButton button(WidgetTester tester) => tester.widget<FilledButton>(find.byType(FilledButton));

    testWidgets('a tap only ticks (sheet stays open, nothing written); the button confirms, says so and closes', (tester) async {
      final (h, tracks) = await openAdd(tester);
      expect(find.text('Nuova playlist intelligente'), findsNothing);
      expect(button(tester).onPressed, isNull);
      expect(find.text('Aggiungi a 0 playlist'), findsOneWidget);
      await tester.tap(find.text('Rock'));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(await h.db.select(h.db.playlistTracks).get(), isEmpty);
      expect(find.text('Aggiungi a 1 playlist'), findsOneWidget);
      await confirm(tester);
      expect((await h.db.select(h.db.playlistTracks).get()).map((r) => r.trackId), [tracks.first.id]);
      expect(find.text('Aggiunto a «Rock»'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(TextField), findsNothing);
      await h.dispose(tester);
    });

    testWidgets('two ticked playlists: both get the track, the message counts them; un-ticking drops one', (tester) async {
      final (h, tracks) = await openAdd(tester, seed: (h, _) async {
        await h.db.into(h.db.playlists).insert(PlaylistsCompanion.insert(name: 'Jazz', createdAt: 2));
      });
      await tester.tap(find.text('Rock'));
      await tester.tap(find.text('Jazz'));
      await tester.pump();
      await tester.tap(find.text('Rock'));
      await tester.pump();
      await tester.tap(find.text('Rock'));
      await tester.pump();
      expect(find.text('Aggiungi a 2 playlist'), findsOneWidget);
      await confirm(tester);
      expect(await rowsOf(h, 'Rock'), {tracks.first.id});
      expect(await rowsOf(h, 'Jazz'), {tracks.first.id});
      expect(find.text('Aggiunto a 2 playlist'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('a playlist that already holds the track is ticked and locked, the others are not', (tester) async {
      final (h, _) = await openAdd(tester, seed: (h, tracks) async {
        await h.db.into(h.db.playlists).insert(PlaylistsCompanion.insert(name: 'Jazz', createdAt: 2));
        final rock = (await h.db.select(h.db.playlists).get()).firstWhere((p) => p.name == 'Rock').id;
        await h.db.into(h.db.playlistTracks).insert(
            PlaylistTracksCompanion.insert(playlistId: rock, trackId: tracks.first.id, position: 0));
      });
      await tester.pump(const Duration(milliseconds: 400));
      Checkbox box(String name) => tester.widget<Checkbox>(
          find.descendant(of: find.widgetWithText(ListTile, name), matching: find.byType(Checkbox)));
      expect(box('Rock').value, isTrue);
      expect(box('Rock').onChanged, isNull);
      expect(box('Jazz').value, isFalse);
      expect(find.text('Già presente'), findsOneWidget);
      await tester.tap(find.text('Rock'));
      await tester.pump();
      expect(button(tester).onPressed, isNull); // locked rows never count
      await h.dispose(tester);
    });

    testWidgets('a partial playlist gets only the missing tracks', (tester) async {
      final h = await Harness.create(tester, tracks: 2);
      final tracks = await h.db.select(h.db.tracks).get();
      await h.db.into(h.db.playlists).insert(PlaylistsCompanion.insert(name: 'Rock', createdAt: 1));
      final rock = (await h.db.select(h.db.playlists).get()).single.id;
      await h.db.into(h.db.playlistTracks).insert(
          PlaylistTracksCompanion.insert(playlistId: rock, trackId: tracks.first.id, position: 0));
      await h.pump(
        tester,
        Consumer(
          builder: (c, ref, _) => Scaffold(
            body: TextButton(onPressed: () => showAddToPlaylistSheet(c, ref, tracks), child: const Text('open')),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Rock'));
      await tester.pump();
      await confirm(tester);
      expect(await rowsOf(h, 'Rock'), {for (final t in tracks) t.id});
      expect(await h.db.select(h.db.playlistTracks).get(), hasLength(2));
      expect(find.text('1 aggiunti a «Rock», 1 già presenti'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('the field filters the playlists without case or accents', (tester) async {
      final (h, _) = await openAdd(tester, seed: (h, _) async {
        await h.db.into(h.db.playlists).insert(PlaylistsCompanion.insert(name: 'Caffè', createdAt: 2));
      });
      await tester.enterText(find.byType(TextField), 'CAFFE');
      await tester.pump();
      expect(find.widgetWithText(ListTile, 'Caffè'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Rock'), findsNothing);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('Nessuna playlist chiamata «zzz»'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pump();
      expect(find.widgetWithText(ListTile, 'Rock'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('Crea row: partial match offers it, creates, ticks, clears the field and stays open; identical name hides it',
        (tester) async {
      final (h, tracks) = await openAdd(tester);
      await h.db.into(h.db.smartPlaylists).insert(
        SmartPlaylistsCompanion.insert(name: 'Magica', rules: 'x', createdAt: 1),
      );
      await tester.enterText(find.byType(TextField), 'Roc');
      await tester.pump();
      expect(find.text('Crea «Roc»'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'rock');
      await tester.pump();
      expect(find.text('Crea «rock»'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Nuova');
      await tester.pump();
      await tester.tap(find.text('Crea «Nuova»'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      expect(await rowsOf(h, 'Nuova'), isEmpty);
      expect(find.text('Aggiungi a 1 playlist'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Nuova')).dy, lessThan(tester.getTopLeft(find.text('Rock')).dy));
      await confirm(tester);
      expect(await rowsOf(h, 'Nuova'), {tracks.first.id});
      expect(find.text('Aggiunto a «Nuova»'), findsOneWidget);
      await reopen(tester);
      expect(find.text('Magica'), findsNothing);
      await h.dispose(tester);
    });

    testWidgets('a locked row is never written; the button counts only the unlocked ones', (tester) async {
      final (h, tracks) = await openAdd(tester, seed: (h, tracks) async {
        await h.db.into(h.db.playlists).insert(PlaylistsCompanion.insert(name: 'Jazz', createdAt: 2));
        final rock = (await h.db.select(h.db.playlists).get()).firstWhere((p) => p.name == 'Rock').id;
        await h.db.into(h.db.playlistTracks).insert(
            PlaylistTracksCompanion.insert(playlistId: rock, trackId: tracks.first.id, position: 0));
      });
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Rock'));
      await tester.tap(find.text('Jazz'));
      await tester.pump();
      expect(find.text('Aggiungi a 1 playlist'), findsOneWidget);
      await confirm(tester);
      expect(await h.db.select(h.db.playlistTracks).get(), hasLength(2));
      expect(await rowsOf(h, 'Jazz'), {tracks.first.id});
      expect(find.text('Aggiunto a «Jazz»'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('playlists created in the sheet show newest first; Enter creates too; the title is the add one', (tester) async {
      final (h, _) = await openAdd(tester);
      expect(find.text('Aggiungi a playlist…'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Aaa');
      await tester.pump();
      tester.widget<TextField>(find.byType(TextField)).onSubmitted!('Aaa');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Aggiungi a 1 playlist'), findsOneWidget, reason: 'Enter');
      await tester.enterText(find.byType(TextField), 'Bbb');
      await tester.pump();
      await tester.tap(find.text('Crea «Bbb»'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Aggiungi a 2 playlist'), findsOneWidget);
      double y(String n) => tester.getTopLeft(find.text(n)).dy;
      expect(y('Bbb'), lessThan(y('Aaa')));
      expect(y('Aaa'), lessThan(y('Rock')));
      await h.dispose(tester);
    });

    testWidgets('a failing write: the other playlists are still written, an error is shown and logged', (tester) async {
      final logged = <String?>[];
      final old = debugPrint;
      debugPrint = (m, {wrapWidth}) => logged.add(m);
      final (h, tracks) = await openAdd(tester, extra: [
        playlistOpsProvider.overrideWith(_FailSecondOps.new),
      ], seed: (h, _) async {
        await h.db.into(h.db.playlists).insert(PlaylistsCompanion.insert(name: 'Jazz', createdAt: 2));
      });
      await tester.tap(find.text('Rock'));
      await tester.tap(find.text('Jazz'));
      await tester.pump();
      await confirm(tester);
      final written = [await rowsOf(h, 'Rock'), await rowsOf(h, 'Jazz')];
      expect(written.where((r) => r.contains(tracks.first.id)), hasLength(1));
      expect(find.text('Non sono riuscito ad aggiungere i brani a una playlist'), findsOneWidget);
      debugPrint = old;
      expect(logged.any((m) => m?.contains('add to playlist') ?? false), isTrue);
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
