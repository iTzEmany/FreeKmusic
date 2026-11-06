import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/widgets/alpha_scroller.dart';
import 'package:codecore/ui/widgets/shrinking_header.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

// The A-Z strip jumps to the header's height + index * row height (the first
// row under the fixed row), with the search block shown and scrolled away.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

const _rows = 40;

double _headerHeight(WidgetTester t) =>
    t.renderObject<RenderSliver>(find.byType(ShrinkingHeader, skipOffstage: false)).geometry!.paintExtent;

Future<Harness> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create(tester, tracks: _rows);
  await h.pump(tester, const AllTracksScreen(initialSort: SortOption.title));
  await _settle(tester);
  return h;
}

// Drags the strip to a fraction (60 % by default) of its height and checks where the list landed.
Future<void> _expectJump(WidgetTester t, double header, [double f = 0.6, int index = 23]) async {
  final strip = find.byType(AlphaScroller);
  // The strip starts below the visible part of the header.
  final inset = _headerHeight(t);
  final top = t.getTopLeft(strip).dy + inset, height = t.getSize(strip).height - inset;
  await t.dragFrom(Offset(390, top + height * (f - 0.2)), Offset(0, height * 0.2));
  await t.pump();
  final list = t.widget<SliverFixedExtentList>(find.byType(SliverFixedExtentList));
  final scrollable = t.state<ScrollableState>(find.descendant(
      of: strip,
      matching: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axis == Axis.vertical)).first);
  expect((f * (_rows - 1)).round(), index);
  expect(scrollable.position.pixels, header + index * list.itemExtent);
}

void main() {
  testWidgets('the jump rounds to the nearest row, not down', (t) async {
    final h = await _open(t);
    // 0.64 * 39 = 24.96: round gives 25, floor would give 24.
    await _expectJump(t, _headerHeight(t), 0.64, 25);
    await h.dispose(t);
  });

  testWidgets('the jump is header height plus index times row height', (t) async {
    final h = await _open(t);
    await _expectJump(t, _headerHeight(t));
    await h.dispose(t);
  });

  testWidgets('the jump lands on the same row with the bar scrolled away', (t) async {
    final h = await _open(t);
    final header = _headerHeight(t);
    final p = TestPointer(1, PointerDeviceKind.mouse);
    await t.sendEventToBinding(p.hover(const Offset(200, 600)));
    await t.sendEventToBinding(p.scroll(const Offset(0, 400)));
    await t.pump();
    await _settle(t);
    expect(find.byType(TextField), findsNothing);
    await _expectJump(t, header);
    await h.dispose(t);
  });

  testWidgets('a backward jump hides a partly shown header: the row is fully visible', (t) async {
    final h = await _open(t);
    final header = _headerHeight(t);
    final p = TestPointer(1, PointerDeviceKind.mouse);
    await t.sendEventToBinding(p.hover(const Offset(200, 600)));
    await t.sendEventToBinding(p.scroll(const Offset(0, 1000)));
    await t.pump();
    // Wheel up a little: the header is partly shown again.
    await t.sendEventToBinding(p.scroll(const Offset(0, -40)));
    await t.pump();
    await t.pump(); // the strip catches up with the header
    expect(_headerHeight(t), 40);
    await _expectJump(t, header, 0.4, 16);
    await t.pump();
    expect(_headerHeight(t), 0);
    await h.dispose(t);
  });
}
