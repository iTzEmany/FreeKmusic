import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codecore/app.dart';

void main() {
  Widget host(ScrollController c) => MaterialApp(
        scrollBehavior: const AppScrollBehavior(),
        home: Scaffold(
          body: ListView(
            controller: c,
            scrollDirection: Axis.horizontal,
            children: [for (var i = 0; i < 20; i++) SizedBox(width: 200, child: Text('$i'))],
          ),
        ),
      );

  testWidgets('horizontal list scrolls with mouse drag', (tester) async {
    final c = ScrollController();
    await tester.pumpWidget(host(c));
    await tester.drag(find.byType(ListView), const Offset(-300, 0), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(c.offset, greaterThan(0));
  });

  testWidgets('horizontal list scrolls with shift+wheel', (tester) async {
    final c = ScrollController();
    await tester.pumpWidget(host(c));
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: tester.getCenter(find.byType(ListView)));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendEventToBinding(PointerScrollEvent(
      kind: PointerDeviceKind.mouse,
      position: tester.getCenter(find.byType(ListView)),
      scrollDelta: const Offset(0, 100),
    ));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(c.offset, greaterThan(0));
  });
}
