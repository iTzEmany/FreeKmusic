import 'package:codecore/data/db/app_database.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/selection_providers.dart';
import 'package:codecore/ui/widgets/bulk_actions.dart';
import 'package:codecore/ui/widgets/selection_bar.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:codecore/ui/widgets/track_row_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

const _key = 'bar-test';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _Page extends ConsumerWidget {
  const _Page({required this.tracks, this.bulk = const BulkContext()});

  final List<Track> tracks;
  final BulkContext bulk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = [for (final t in tracks) t.id];
    final active = ref.watch(selectionProvider(_key).select((s) => s.active));
    return SelectionScope(
      listKey: _key,
      visibleIds: ids,
      child: Scaffold(
        appBar: active
            ? SelectionBar(listKey: _key, tracks: tracks, bulk: bulk)
            : AppBar(title: const Text('List')),
        body: ListView(
          children: [
            for (final t in tracks)
              SizedBox(
                height: 64,
                child: LiveTrackRow(
                  track: t,
                  onTap: () {},
                  selection: RowSelection(listKey: _key, visibleIds: ids),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void main() {
  late Harness h;
  late List<Track> tracks;
  late int playlistId;

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    // Not pumpAndSettle: the bars of a playing row animate for ever.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
  }

  /// [missing]: rows (by index) whose file is gone. [inPlaylist]: the list is
  /// a playlist holding every track.
  Future<void> open(
    WidgetTester tester, {
    Set<int> missing = const {},
    bool inPlaylist = false,
  }) async {
    _phone(tester);
    h = await Harness.create(tester, tracks: 4);
    final repo = TrackRepository(h.db);
    var rows = (await tester.runAsync(
        () => (h.db.select(h.db.tracks)..orderBy([(t) => OrderingTerm.asc(t.id)])).get()))!;
    await tester.runAsync(() => repo.markMissing({for (final i in missing) rows[i].path}, true));
    tracks = (await tester.runAsync(
        () => (h.db.select(h.db.tracks)..orderBy([(t) => OrderingTerm.asc(t.id)])).get()))!;
    var bulk = const BulkContext();
    if (inPlaylist) {
      final pl = PlaylistRepository(h.db);
      final id = (await tester.runAsync(() async {
        final p = await pl.create('Mix');
        await pl.addTracks(p, [for (final t in tracks) t.id]);
        return p;
      }))!;
      playlistId = id;
      bulk = BulkContext(playlistId: id);
    }
    await h.pump(tester, _Page(tracks: tracks, bulk: bulk));
  }

  Selection selection(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold)))
          .read(selectionProvider(_key));

  Future<void> pick(WidgetTester tester, List<int> rows) async {
    await tester.longPress(find.text('Song ${rows.first}'));
    await settle(tester);
    for (final r in rows.skip(1)) {
      await tester.tap(find.text('Song $r'));
      await settle(tester);
    }
  }

  testWidgets('the bar counts what is picked and ✕ leaves the selection', (tester) async {
    await open(tester);
    expect(find.text('List'), findsOneWidget);
    await pick(tester, [0, 2]);
    expect(find.text('2 selezionati'), findsOneWidget);
    expect(find.text('List'), findsNothing, reason: 'the bar takes the header\'s place');
    await tester.tap(find.byTooltip('Esci dalla selezione'));
    await settle(tester);
    expect(selection(tester).active, isFalse);
    expect(find.text('List'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the ⋮ sheet is titled «N selezionati»', (tester) async {
    await open(tester);
    await pick(tester, [0, 2]);
    await tester.tap(find.byTooltip('Azioni'));
    await settle(tester);
    expect(find.text('2 selezionati'), findsNWidgets(2));
    await h.dispose(tester);
  });

  testWidgets('«Seleziona tutto» picks every row shown', (tester) async {
    await open(tester);
    await pick(tester, [1]);
    expect(find.text('1 selezionato'), findsOneWidget);
    await tester.tap(find.byTooltip('Seleziona tutto'));
    await settle(tester);
    expect(selection(tester).ids, {for (final t in tracks) t.id});
    expect(find.text('4 selezionati'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('Esc leaves the selection and Ctrl+A picks everything', (tester) async {
    await open(tester);
    await pick(tester, [0]);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(selection(tester).count, 4);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(selection(tester).active, isFalse);
    await h.dispose(tester);
  });

  testWidgets('favorites: adds to every pick, with undo', (tester) async {
    await open(tester);
    await pick(tester, [0, 1]);
    await tester.tap(find.byTooltip('Aggiungi ai preferiti'));
    await settle(tester);
    final repo = TrackRepository(h.db);
    Future<List<bool>> favs() async => [
          for (final t in (await tester.runAsync(() => repo.getByIds([for (final t in tracks) t.id])))!)
            t.isFavorite,
        ];
    expect(await favs(), [true, true, false, false]);
    expect(find.text('2 brani nei preferiti'), findsOneWidget);
    expect(selection(tester).active, isFalse, reason: 'the action went through');

    await tester.tap(find.text('Annulla'));
    await settle(tester);
    expect(await favs(), [false, false, false, false]);
    await h.dispose(tester);
  });

  testWidgets('«Aggiungi in coda» also follows the order of the taps', (tester) async {
    await open(tester);
    await tester.runAsync(() => h.handler.playQueue([tracks[0].id], 0));
    await pick(tester, [3, 1, 2]);
    await tester.tap(find.byTooltip('Azioni'));
    await settle(tester);
    await tester.tap(find.text('Aggiungi in coda'));
    await settle(tester);
    expect(h.handler.queueIds, [tracks[0].id, tracks[3].id, tracks[1].id, tracks[2].id]);
    await h.dispose(tester);
  });

  testWidgets('add to a playlist: the new tracks land in the order they were picked, and the note '
      'says how many were there already', (tester) async {
    await open(tester);
    final repo = PlaylistRepository(h.db);
    final id = (await tester.runAsync(() async {
      final p = await repo.create('Mix');
      await repo.addTracks(p, [tracks[1].id]);
      return p;
    }))!;
    await pick(tester, [3, 1, 0]);
    await tester.tap(find.byTooltip('Aggiungi a playlist…'));
    await settle(tester);
    await tester.tap(find.text('Mix'));
    await settle(tester);
    final inPlaylist = (await tester.runAsync(() => (h.db.select(h.db.playlistTracks)
          ..where((t) => t.playlistId.equals(id))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get()))!;
    expect([for (final r in inPlaylist) r.trackId], [tracks[1].id, tracks[3].id, tracks[0].id]);
    expect(find.text('2 aggiunti a «Mix», 1 già presenti'), findsOneWidget);
    expect(selection(tester).active, isFalse);
    await h.dispose(tester);
  });

  testWidgets('outside a playlist, and unless every pick is missing, the menu has no removal', (tester) async {
    await open(tester, missing: {0});
    await pick(tester, [0, 1]);
    await tester.tap(find.byTooltip('Azioni'));
    await settle(tester);
    expect(find.text('Rimuovi dalla playlist'), findsNothing);
    expect(find.text('Rimuovi dalla libreria'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('library removal appears only when every pick is missing, and removes just rows', (tester) async {
    await open(tester, missing: {0, 1});
    await pick(tester, [0, 1]);
    await tester.tap(find.byTooltip('Azioni'));
    await settle(tester);
    expect(find.text('Rimuovi dalla libreria'), findsOneWidget);
    await tester.tap(find.text('Rimuovi dalla libreria'));
    await settle(tester);
    expect(find.text('Togliere 2 brani dalla libreria?'), findsOneWidget);
    await tester.tap(find.text('Rimuovi').last);
    await settle(tester);
    final left = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
    expect(left.map((t) => t.id), [tracks[2].id, tracks[3].id]);
    await h.dispose(tester);
  });

  testWidgets('in a playlist: confirm, remove several, undo puts them back in place', (tester) async {
    await open(tester, inPlaylist: true);
    final repo = PlaylistRepository(h.db);
    await pick(tester, [0, 2]);
    await tester.tap(find.byTooltip('Azioni'));
    await settle(tester);
    await tester.tap(find.text('Rimuovi dalla playlist'));
    await settle(tester);
    expect(find.text('Rimuovere 2 brani dalla playlist?'), findsOneWidget);
    await tester.tap(find.text('Rimuovi').last);
    await settle(tester);
    Future<List<int>> order() async =>
        [for (final t in (await tester.runAsync(() => repo.watchTracks(playlistId).first))!) t.id];
    expect(await order(), [tracks[1].id, tracks[3].id]);
    expect(find.text('2 brani rimossi'), findsOneWidget);

    await tester.tap(find.text('Annulla'));
    await settle(tester);
    expect(await order(), [for (final t in tracks) t.id]);
    await h.dispose(tester);
  });

  testWidgets('cancelling the confirmation removes nothing', (tester) async {
    await open(tester, inPlaylist: true);
    final repo = PlaylistRepository(h.db);
    await pick(tester, [0]);
    await tester.tap(find.byTooltip('Azioni'));
    await settle(tester);
    await tester.tap(find.text('Rimuovi dalla playlist'));
    await settle(tester);
    await tester.tap(find.text('Annulla').last);
    await settle(tester);
    expect((await tester.runAsync(() => repo.watchTracks(playlistId).first))!, hasLength(4));
    expect(selection(tester).active, isTrue, reason: 'still selecting');
    await h.dispose(tester);
  });
}
