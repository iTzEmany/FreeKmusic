import 'package:codecore/ui/widgets/shelf_scroller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  late ScrollController ctrl;

  Future<Harness> open(WidgetTester t, {double width = 1200}) async {
    t.view.physicalSize = Size(width, 600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t);
    await h.pump(
      t,
      Scaffold(
        body: SizedBox(
          height: 160,
          child: ShelfScroller(
            builder: (_, c) {
              ctrl = c;
              return ListView.builder(
                controller: c,
                scrollDirection: Axis.horizontal,
                itemExtent: 200,
                itemCount: 20,
                itemBuilder: (_, i) => Text('tile $i'),
              );
            },
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump();
    return h;
  }

  Finder arrow(IconData i) => find.byIcon(i);
  const next = Icons.chevron_right_rounded, back = Icons.chevron_left_rounded;

  testWidgets('the arrows show only where there is more, and a click moves the shelf', (t) async {
    final h = await open(t);
    expect(arrow(back), findsNothing, reason: 'at the start');
    expect(arrow(next), findsOneWidget);
    expect(t.getSize(find.ancestor(of: arrow(next), matching: find.byType(IconButton))).shortestSide, greaterThanOrEqualTo(32));
    await t.tap(arrow(next));
    await t.pumpAndSettle();
    expect(ctrl.offset, greaterThan(0));
    expect(arrow(back), findsOneWidget);
    ctrl.jumpTo(ctrl.position.maxScrollExtent);
    await t.pump();
    await t.pump();
    expect(arrow(next), findsNothing, reason: 'at the end');
    await t.tap(arrow(back));
    await t.pumpAndSettle();
    expect(ctrl.offset, lessThan(ctrl.position.maxScrollExtent));
    await h.dispose(t);
  });

  testWidgets('the wheel moves the shelf sideways, in both senses', (t) async {
    final h = await open(t);
    final p = t.getCenter(find.text('tile 1'));
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: p);
    await mouse.moveTo(p);
    await t.sendEventToBinding(PointerScrollEvent(position: p, scrollDelta: const Offset(0, 120)));
    await t.pump();
    expect(ctrl.offset, 120, reason: 'vertical wheel');
    await t.sendEventToBinding(PointerScrollEvent(position: p, scrollDelta: const Offset(60, 0)));
    await t.pump();
    expect(ctrl.offset, 180, reason: 'horizontal wheel');
    await h.dispose(t);
  });

  testWidgets('the mouse drags the shelf', (t) async {
    final h = await open(t);
    await t.drag(find.text('tile 1'), const Offset(-300, 0), kind: PointerDeviceKind.mouse);
    await t.pumpAndSettle();
    expect(ctrl.offset, greaterThan(0));
    await h.dispose(t);
  });

  testWidgets('on a phone there are no arrows', (t) async {
    final h = await open(t, width: 400);
    expect(arrow(next), findsNothing);
    await h.dispose(t);
  });
}
