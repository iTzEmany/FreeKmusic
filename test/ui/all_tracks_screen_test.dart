import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:flutter/material.dart';
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

Future<Harness> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create(tester, tracks: 4);
  await h.pump(tester, const AllTracksScreen());
  await _settle(tester);
  return h;
}

void main() {
  testWidgets('Riproduci starts the whole list from the first, shuffle off', (
    tester,
  ) async {
    final h = await _open(tester);
    await tester.tap(find.text('Riproduci'));
    await _settle(tester);
    expect(h.handler.queueIds, hasLength(4));
    expect(h.handler.currentIndex, 0);
    expect(h.handler.shuffleEnabled, isFalse);
    await h.dispose(tester);
  });

  testWidgets('Casuale only turns the mode on: nothing starts', (tester) async {
    final h = await _open(tester);
    await tester.tap(find.text('Casuale'));
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
}
