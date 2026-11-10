import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/ui/screens/playlists/playlist_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<(Harness, Finder)> _open(WidgetTester tester, int n) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create(tester, tracks: n);
  final id = (await tester.runAsync(() async {
    final repo = PlaylistRepository(h.db);
    final id = await repo.create('Big');
    await repo.addTracks(id, [for (final t in await h.db.select(h.db.tracks).get()) t.id]);
    return id;
  }))!;
  await h.pump(tester, PlaylistDetailScreen(playlist: Playlist(id: id, name: 'Big', createdAt: 0, updatedAt: 0)));
  await _settle(tester);
  return (h, find.byType(TextField).first);
}

void main() {
  testWidgets('clearing the field while the first prime is running leaves the search empty', (tester) async {
    final (h, field) = await _open(tester, 2100);
    expect(find.text('Song 0'), findsOneWidget, reason: 'control: unfiltered list shows Song 0');
    await tester.enterText(field, 'Song 1');
    await tester.pump(const Duration(seconds: 1)); // debounce fires: prime starts
    await tester.enterText(field, ''); // user clears before the isolate answers
    await _settle(tester);
    expect(tester.widget<TextField>(field).controller!.text, '');
    expect(find.text('Song 0'), findsOneWidget, reason: 'filtered by a query the field no longer shows');
    await h.dispose(tester);
  });

  testWidgets('a big list waits for the isolate, then filters', (tester) async {
    final (h, field) = await _open(tester, 2100);
    await tester.enterText(field, 'Song 1999');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Song 0'), findsOneWidget, reason: 'prime still running: not filtered yet');
    await _settle(tester);
    expect(find.text('Song 0'), findsNothing);
    expect(find.text('Song 1999'), findsWidgets);
    await h.dispose(tester);
  });

  testWidgets('a small list filters at once, without the isolate', (tester) async {
    final (h, field) = await _open(tester, 50);
    await tester.enterText(field, 'Song 49');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Song 0'), findsNothing);
    expect(find.text('Song 49'), findsWidgets);
    await h.dispose(tester);
  });

  testWidgets('closing the screen during the prime does not touch the dead state', (tester) async {
    final (h, field) = await _open(tester, 2100);
    await tester.enterText(field, 'Song 1');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });
}
