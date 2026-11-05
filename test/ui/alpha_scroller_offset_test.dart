import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/widgets/alpha_scroller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

// Characterization of phase 87: the A-Z strip jumps to index * row height,
// with the header bar shown and hidden.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

const _rows = 40;

Future<Harness> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create(tester, tracks: _rows);
  await h.pump(tester, const AllTracksScreen(initialSort: SortOption.title));
  await _settle(tester);
  return h;
}

// Drags the strip to 60 % of its height and checks where the list landed.
Future<void> _expectJump(WidgetTester t) async {
  final strip = find.byType(AlphaScroller);
  final top = t.getTopLeft(strip).dy, height = t.getSize(strip).height;
  await t.dragFrom(Offset(390, top + height * 0.4), Offset(0, height * 0.2));
  await t.pump();
  final list = t.widget<ListView>(find.descendant(
      of: strip, matching: find.byType(ListView)));
  final scrollable = t.state<ScrollableState>(find.descendant(
      of: strip,
      matching: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axis == Axis.vertical)).first);
  final index = (0.6 * (_rows - 1)).round();
  expect(index, 23);
  expect(scrollable.position.pixels, index * list.itemExtent!);
}

void main() {
  testWidgets('the jump is index times row height with the bar shown', (t) async {
    final h = await _open(t);
    await _expectJump(t);
    await h.dispose(t);
  });

  testWidgets('the jump is index times row height with the bar hidden', (t) async {
    final h = await _open(t);
    final p = TestPointer(1, PointerDeviceKind.mouse);
    await t.sendEventToBinding(p.hover(const Offset(200, 600)));
    await t.sendEventToBinding(p.scroll(const Offset(0, 400)));
    await t.pump();
    await _settle(t);
    expect(t.getSize(find.descendant(
        of: find.byType(AllTracksScreen),
        matching: find.byType(SizeTransition))).height, 0);
    await _expectJump(t);
    await h.dispose(t);
  });
}
