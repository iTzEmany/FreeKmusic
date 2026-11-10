// Characterization (38.5, points 2-3): multi-track actions, favourites, the
// queries that live in widgets today (setLyrics, pathsById) and the rule that
// tells a streamed entry from a library row. Whoever changes the behaviour
// updates these tests in the same step.
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/export/playlist_exporter.dart';
import 'package:codecore/services/online/lrclib_client.dart';
import 'package:codecore/services/online/lyrics_chain.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/ui/screens/lyrics/lyrics_view.dart';
import 'package:codecore/ui/screens/playlists/export_dialog.dart';
import 'package:codecore/ui/widgets/bulk_actions.dart';
import 'package:codecore/ui/widgets/favorite_actions.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

class _Lrclib implements LrclibClient {
  _Lrclib(this.result);
  final LyricsResult? result;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  Future<LyricsResult?> find({
    required String title,
    required String artist,
    String? album,
    int? durationSec,
    dynamic cancel,
    bool strict = false,
  }) async =>
      result;
}

/// Pumps a page that hands out its `context` and `ref`.
Future<({BuildContext context, WidgetRef ref})> _grab(WidgetTester tester, Harness h) async {
  late BuildContext ctx;
  late WidgetRef ref;
  await h.pump(
      tester,
      Scaffold(
        body: Consumer(builder: (c, r, _) {
          ctx = c;
          ref = r;
          return const SizedBox();
        }),
      ));
  return (context: ctx, ref: ref);
}

Future<List<Track>> _all(WidgetTester tester, Harness h) async => (await tester.runAsync(
    () => (h.db.select(h.db.tracks)..orderBy([(t) => OrderingTerm.asc(t.id)])).get()))!;

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('multi-track actions', () {
    Future<void> runFavorites(WidgetTester tester, Harness h, List<Track> picked) async {
      final g = await _grab(tester, h);
      var left = 0;
      final groups = bulkActions(g.context, g.ref, picked, const BulkContext(), done: () => left++);
      final fav = groups[1].actions.first;
      await tester.runAsync(fav.run);
      await tester.pump();
      expect(left, 1, reason: 'the selection is left');
    }

    testWidgets('on a mixed pick «add to favourites» touches only the ones that were not, and undo reverts those', (tester) async {
      final h = await Harness.create(tester, tracks: 3);
      var rows = await _all(tester, h);
      await tester.runAsync(() => TrackRepository(h.db).setFavorite(rows[0].id, true));
      rows = await _all(tester, h);
      await runFavorites(tester, h, rows);
      expect([for (final t in await _all(tester, h)) t.isFavorite], [true, true, true]);
      expect(find.text('2 brani nei preferiti'), findsOneWidget, reason: 'counts the changed rows only');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Annulla'));
      await _settle(tester);
      expect([for (final t in await _all(tester, h)) t.isFavorite], [true, false, false]);
      await h.dispose(tester);
    });

    testWidgets('when every pick is a favourite the same action removes them', (tester) async {
      final h = await Harness.create(tester, tracks: 2);
      await tester.runAsync(() => TrackRepository(h.db).setFavoriteMany([for (final t in [1, 2]) t], true));
      await runFavorites(tester, h, await _all(tester, h));
      expect([for (final t in await _all(tester, h)) t.isFavorite], [false, false]);
      expect(find.text('2 brani tolti dai preferiti'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('streamed entries (negative id) are skipped; only streamed picks give no actions at all', (tester) async {
      final h = await Harness.create(tester, tracks: 2);
      final rows = await _all(tester, h);
      final online = rows[0].copyWith(id: -1);
      final g = await _grab(tester, h);
      expect(bulkActions(g.context, g.ref, [online], const BulkContext(), done: () {}), isEmpty);
      final groups = bulkActions(g.context, g.ref, [online, rows[1]], const BulkContext(), done: () {});
      final queue = groups.first.actions.firstWhere((a) => a.label == 'Aggiungi in coda');
      await queue.run();
      await tester.pump();
      expect(find.text('1 brano aggiunto in coda'), findsOneWidget, reason: 'the streamed pick is not counted');
      await h.dispose(tester);
    });

    testWidgets('shadow rows (kind 2) in a playlist can be played, queued and removed, never tagged or favourited', (tester) async {
      final h = await Harness.create(tester, tracks: 2);
      final rows = await _all(tester, h);
      final shadow = rows[0].copyWith(kind: 2);
      final g = await _grab(tester, h);
      List<String> labels(List<Track> p) => [
            for (final x in bulkActions(g.context, g.ref, p, const BulkContext(playlistId: 1), done: () {}))
              for (final a in x.actions) a.label
          ];
      final only = labels([shadow]);
      expect(only, containsAll(['Riproduci', 'Aggiungi in coda', 'Rimuovi dalla playlist']));
      expect(only, isNot(contains('Aggiungi ai preferiti')));
      expect(only, isNot(contains('Aggiungi a playlist…')));
      final mixed = labels([shadow, rows[1]]);
      expect(mixed, containsAll(['Riproduci', 'Rimuovi dalla playlist']));
      await h.dispose(tester);
    });

    testWidgets('an episode (kind 1) can be picked but never offers «Elimina dal dispositivo»', (tester) async {
      final h = await Harness.create(tester, tracks: 2);
      final rows = await _all(tester, h);
      final g = await _grab(tester, h);
      final music = bulkActions(g.context, g.ref, [rows[0]], const BulkContext(), done: () {});
      expect([for (final x in music) for (final a in x.actions) a.label], contains('Elimina dal dispositivo'));
      final episode = bulkActions(g.context, g.ref, [rows[0].copyWith(kind: 1)], const BulkContext(), done: () {});
      expect([for (final x in episode) for (final a in x.actions) a.label], isNot(contains('Elimina dal dispositivo')));
      await h.dispose(tester);
    });
  });

  group('single favourite', () {
    testWidgets('toggles the flag and shows an undo snackbar that restores it', (tester) async {
      final h = await Harness.create(tester, tracks: 1);
      final t = (await _all(tester, h)).single;
      final g = await _grab(tester, h);
      await tester.runAsync(() => toggleFavorite(g.context, g.ref, t));
      await tester.pump();
      expect((await _all(tester, h)).single.isFavorite, isTrue);
      expect(find.text('Aggiunto ai preferiti'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Annulla'));
      await _settle(tester);
      expect((await _all(tester, h)).single.isFavorite, isFalse);
      await h.dispose(tester);
    });

    testWidgets('with the undo setting off it toggles silently; the bulk action ignores that setting', (tester) async {
      final h = await Harness.create(tester, tracks: 2);
      await tester.runAsync(() => h.store.writeSettings(const AppSettings(showUndoSnackbar: false)));
      final rows = await _all(tester, h);
      final g = await _grab(tester, h);
      await tester.runAsync(() => toggleFavorite(g.context, g.ref, rows[0]));
      await tester.pump();
      expect(find.text('Aggiunto ai preferiti'), findsNothing);
      expect(g.ref.read(settingsProvider).showUndoSnackbar, isFalse);
      // Known inconsistency, pinned: the bulk action always shows its undo.
      final fav = bulkActions(g.context, g.ref, [rows[1]], const BulkContext(), done: () {})[1].actions.first;
      await tester.runAsync(fav.run);
      await tester.pump();
      expect(find.text('Annulla'), findsOneWidget);
      await h.dispose(tester);
    });
  });

  group('queries written inside widgets', () {
    Future<Harness> pumpLyrics(WidgetTester tester, LyricsResult? result) async {
      final h = await Harness.create(tester, tracks: 1);
      final t = (await _all(tester, h)).single;
      await h.pump(tester, Scaffold(body: LyricsView(track: t)),
          extraOverrides: [lyricsChainProvider.overrideWithValue(LyricsChain(lrclib: _Lrclib(result)))]);
      await tester.tap(find.text('Cerca testo'));
      await _settle(tester);
      return h;
    }

    testWidgets('setLyrics today: «Cerca testo» writes plain and synced of that track', (tester) async {
      final h = await pumpLyrics(tester, const LyricsResult(plain: 'la la', synced: '[00:01.00]la la'));
      final t = (await _all(tester, h)).single;
      expect(t.lyricsPlain, 'la la');
      expect(t.lyricsSynced, '[00:01.00]la la');
      await h.dispose(tester);
    });

    testWidgets('setLyrics today: a plain-only result writes null into the synced column', (tester) async {
      final h = await pumpLyrics(tester, const LyricsResult(plain: 'only plain'));
      final t = (await _all(tester, h)).single;
      expect(t.lyricsPlain, 'only plain');
      expect(t.lyricsSynced, isNull);
      await h.dispose(tester);
    });

    testWidgets('setLyrics today: nothing found leaves the row alone and says so', (tester) async {
      final h = await pumpLyrics(tester, null);
      final t = (await _all(tester, h)).single;
      expect(t.lyricsPlain, isNull);
      expect(find.text('Testo non trovato'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('pathsById today: the export maps folder id to root path and writes a path relative to it', (tester) async {
      final h = await Harness.create(tester, tracks: 1);
      final g = await _grab(tester, h);
      final text = await tester.runAsync(() async {
        final db = g.ref.read(databaseProvider);
        final fid = await db.into(db.folders).insert(FoldersCompanion.insert(path: '/m', addedAt: 1));
        await (db.update(db.tracks)).write(TracksCompanion(folderId: Value(fid)));
        final pl = g.ref.read(playlistRepositoryProvider);
        final pid = await pl.create('Mix');
        await pl.addTracks(pid, [(await db.select(db.tracks).get()).single.id]);
        final archive = await buildPlaylistsArchive(g.ref,
            format: ExportFormat.json, relativePaths: false, favoritesName: 'Preferiti');
        return String.fromCharCodes(archive.files.single.content as List<int>);
      });
      expect(text, contains('"/m"'), reason: 'the folder root');
      expect(text, contains('t0.mp3'), reason: 'relative path below it');
      expect(text, isNot(contains('/m/t0.mp3')));
      await h.dispose(tester);
    });
  });

  test('isOnlineId: negative ids are streamed entries, zero and positive ids are library rows', () {
    const table = {
      -2147483648: true,
      -2: true,
      -1: true,
      0: false,
      1: false,
      2147483647: false,
    };
    table.forEach((id, online) => expect(isOnlineId(id), online, reason: 'id $id'));
  });
}
