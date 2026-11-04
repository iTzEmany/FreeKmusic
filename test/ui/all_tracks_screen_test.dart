import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

// Selection, search, sort and drag are covered in selection_lists_test and
// track_drag_test; this file pins what the header buttons and a row tap start.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 120)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<Harness> _open(
  WidgetTester tester, {
  int tracks = 4,
  SortOption? sort,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create(tester, tracks: tracks);
  await h.pump(tester, AllTracksScreen(initialSort: sort));
  await _settle(tester);
  return h;
}

void main() {
  testWidgets(
    'the play icon starts the whole list from the first, shuffle off',
    (tester) async {
      final h = await _open(tester);
      await tester.tap(find.byTooltip('Riproduci'));
      await _settle(tester);
      expect(h.handler.queueIds, hasLength(4));
      expect(h.handler.currentIndex, 0);
      expect(h.handler.shuffleEnabled, isFalse);
      await h.dispose(tester);
    },
  );

  testWidgets('the shuffle icon only turns the mode on: nothing starts', (
    tester,
  ) async {
    final h = await _open(tester);
    await tester.tap(find.byTooltip('Casuale: spenta'));
    await _settle(tester);
    expect(h.handler.shuffleEnabled, isTrue);
    expect(h.handler.queueIds, isEmpty);
    await h.dispose(tester);
  });

  testWidgets('tapping a row plays the list from that row', (tester) async {
    final h = await _open(tester);
    await tester.tap(find.text('Song 2'));
    await _settle(tester);
    expect(h.handler.queueIds, hasLength(4));
    // Default order: latest added first, so Song 2 is the second row.
    expect(h.handler.currentIndex, 1);
    await h.dispose(tester);
  });

  testWidgets('a row menu offers the track actions', (tester) async {
    final h = await _open(tester);
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(TrackRow, 'Song 1').first,
        matching: find.byTooltip('Altre opzioni'),
      ),
    );
    await _settle(tester);
    expect(find.text('Riproduci dopo'), findsOneWidget);
    expect(find.text('Vai all’album'), findsOneWidget);
    await h.dispose(tester);
  });

  // Rows are Draggables on desktop, so a touch drag would not scroll: use the wheel.
  Future<void> wheel(WidgetTester t, double dy) async {
    final p = TestPointer(1, PointerDeviceKind.mouse);
    await t.sendEventToBinding(p.hover(const Offset(200, 600)));
    await t.sendEventToBinding(p.scroll(Offset(0, dy)));
    await t.pump();
  }

  double barHeight(WidgetTester t) =>
      t.getSize(find.byType(SizeTransition)).height;

  testWidgets('the bar hides scrolling down and shows scrolling up', (
    tester,
  ) async {
    final h = await _open(tester, tracks: 40);
    expect(barHeight(tester), greaterThan(100));
    await wheel(tester, 400);
    await _settle(tester);
    expect(barHeight(tester), 0);
    await wheel(tester, -150);
    await _settle(tester);
    expect(barHeight(tester), greaterThan(100));
    await h.dispose(tester);
  });

  testWidgets('the A-Z strip reaches the last letter with the bar hidden', (
    tester,
  ) async {
    final h = await _open(tester, tracks: 40, sort: SortOption.title);
    await wheel(tester, 400);
    await _settle(tester);
    expect(barHeight(tester), 0);
    await tester.dragFrom(const Offset(390, 400), const Offset(0, 495));
    await _settle(tester);
    // Title order: «Song 9» is the last row.
    expect(find.text('Song 9'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('initialSort is applied and the query is cleared on exit', (
    tester,
  ) async {
    final h = await _open(tester, sort: SortOption.title);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(AllTracksScreen)),
    );
    expect(c.read(trackQueryProvider(false)).sort, SortOption.title);
    await tester.enterText(find.byType(TextField), 'Song 2');
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.read(trackQueryProvider(false)).text, 'Song 2');
    var last = 'x';
    c.listen(trackQueryProvider(false), (_, q) => last = q.text);
    await h.dispose(tester); // unmounts the screen
    expect(last, isEmpty);
  });
}
