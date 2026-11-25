import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/selection_providers.dart';
import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<Harness> _open(WidgetTester tester, {required Size size}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create(tester, tracks: 4);
  await h.pump(tester, const AllTracksScreen());
  await _settle(tester);
  return h;
}

/// Titles of the rows on screen, top to bottom.
List<String> _titles(WidgetTester t) {
  final tops = {
    for (final f in find.textContaining('Song ').evaluate()) (f.widget as Text).data!: t.getTopLeft(find.byWidget(f.widget)).dy,
  };
  return tops.keys.toList()..sort((a, b) => tops[a]!.compareTo(tops[b]!));
}

void main() {
  testWidgets('a click on «Titolo» sorts, a second one reverses; the row played has its place in the shown order', (tester) async {
    final h = await _open(tester, size: const Size(1280, 800));
    expect(find.text('Album'), findsOneWidget, reason: 'the wide table has its header');
    await tester.tap(find.text('Titolo'));
    await _settle(tester);
    expect(_titles(tester), ['Song 0', 'Song 1', 'Song 2', 'Song 3']);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

    await tester.tap(find.text('Titolo'));
    await _settle(tester);
    expect(_titles(tester), ['Song 3', 'Song 2', 'Song 1', 'Song 0']);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);

    await tester.tap(find.text('Song 1'));
    await _settle(tester);
    final all = await tester.runAsync(() => h.db.select(h.db.tracks).get());
    final byId = {for (final r in all!) r.id: r.title};
    expect([for (final id in h.handler.queueIds) byId[id]], ['Song 3', 'Song 2', 'Song 1', 'Song 0']);
    expect(h.handler.currentIndex, 2);
    await h.dispose(tester);
  });

  testWidgets('the headers are sorted for a screen reader and the sort lives in the list\'s query', (tester) async {
    final sem = tester.ensureSemantics();
    final h = await _open(tester, size: const Size(1280, 800));
    expect(find.bySemanticsLabel('Ordina per Titolo'), findsOneWidget);
    await tester.tap(find.text('Durata'));
    await _settle(tester);
    expect(find.bySemanticsLabel('Durata, in ordine crescente'), findsOneWidget);
    final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    expect(c.read(trackQueryProvider(false)).sort, SortOption.duration);
    sem.dispose();
    await h.dispose(tester);
  });

  testWidgets('below 840 px there is no header: the rows of the phone', (tester) async {
    final h = await _open(tester, size: const Size(400, 900));
    expect(find.text('Album'), findsNothing);
    expect(find.byType(TrackRow), findsNWidgets(4));
    await h.dispose(tester);
  });

  testWidgets('Ctrl+click picks a row and Shift+click a range in the wide table', (tester) async {
    final h = await _open(tester, size: const Size(1280, 800));
    await tester.tap(find.text('Titolo'));
    await _settle(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('Song 0'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await _settle(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('Song 2'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _settle(tester);
    final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    expect(c.read(selectionProvider(SelectionKey.all.key)).count, 3);
    expect(h.handler.queueIds, isEmpty, reason: 'picking does not play');
    await h.dispose(tester);
  });
}
