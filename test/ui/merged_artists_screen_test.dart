import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/artist_alias_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:codecore/ui/screens/settings/merged_artists_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  Future<(Harness, ArtistAliasRepository)> open(WidgetTester tester, {bool data = true, Future<void> Function(AppDatabase)? seed}) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    final repo = ArtistAliasRepository(h.db);
    if (data) {
      await tester.runAsync(() async {
        await repo.merge('UCa', 'UCb');
        await repo.merge('UCa', 'UCc');
        await repo.markNotSame('UCx', 'UCy');
      });
    }
    if (seed != null) await tester.runAsync(() => seed(h.db));
    await h.pump(tester, const MergedArtistsScreen());
    await _settle(tester);
    return (h, repo);
  }

  testWidgets('lists the groups and the different pairs; «Separa» splits one profile', (tester) async {
    final (h, repo) = await open(tester);
    expect(find.byKey(const ValueKey('group-row-UCa')), findsOneWidget);
    expect(find.text('Principale'), findsOneWidget);
    expect(find.byKey(const ValueKey('pair-UCx-UCy')), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('separate-UCb'))).height, greaterThanOrEqualTo(48));
    await tester.tap(find.byKey(const ValueKey('separate-UCb')));
    await _settle(tester);
    expect(await tester.runAsync(() => repo.groupOf('UCa')), ['UCa', 'UCc']);
    expect(await tester.runAsync(() => repo.isNotSame('UCa', 'UCb')), isTrue);
    await h.dispose(tester);
  });

  testWidgets('«Separa tutto» breaks the group; «Rimuovi» frees a different pair', (tester) async {
    final (h, repo) = await open(tester);
    await tester.tap(find.byKey(const ValueKey('unmark-UCx-UCy')));
    await _settle(tester);
    expect(await tester.runAsync(() => repo.isNotSame('UCx', 'UCy')), isFalse);
    expect(find.byKey(const ValueKey('pair-UCx-UCy')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('split-all-UCa')));
    await _settle(tester);
    expect(await tester.runAsync(() => repo.groupOf('UCa')), ['UCa']);
    await h.dispose(tester);
  });

  testWidgets('the different pairs show the names known locally, the id only when none is', (tester) async {
    final (h, _) = await open(tester, seed: (db) async {
      await db.into(db.followedArtists).insert(FollowedArtistsCompanion.insert(ytmId: 'UCx', name: 'Name X', excluded: const Value(true)));
      await db.into(db.artistLookups).insert(ArtistLookupsCompanion.insert(
          artistKey: 'k', name: 'y', status: 0, checkedAt: 1, ytmId: const Value('UCy'), ytmName: const Value('Name Y')));
    });
    expect(find.text('Name X'), findsOneWidget);
    expect(find.text('Name Y'), findsOneWidget);
    expect(find.text('UCx'), findsNothing);
    expect(find.text('UCa'), findsWidgets, reason: 'no name known: the id');
    await h.dispose(tester);
  });

  testWidgets('nothing merged: a clear empty state', (tester) async {
    final (h, _) = await open(tester, data: false);
    expect(find.text('Nessun artista unito.'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('buttons have a label and a 48 dp target', (tester) async {
    final (h, _) = await open(tester);
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
    await h.dispose(tester);
  });
}
