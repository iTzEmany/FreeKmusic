import 'package:codecore/ui/widgets/alpha_scroller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('leadingLetter folds accents and groups the rest under #', () {
    expect(leadingLetter('Àlbum'), 'A');
    expect(leadingLetter('élan'), 'E');
    expect(leadingLetter('  zebra'), 'Z');
    expect(leadingLetter('7 Years'), '#');
    expect(leadingLetter('¿Qué?'), '#');
    expect(leadingLetter(null), '#');
    expect(leadingLetter(''), '#');
  });

  testWidgets('dragging the strip jumps the list', (tester) async {
    final c = ScrollController();
    final letters = [for (var i = 0; i < 100; i++) String.fromCharCode(65 + i % 26)];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AlphaScroller(
          controller: c,
          itemExtent: 50,
          letters: letters,
          child: ListView.builder(
            controller: c,
            itemExtent: 50,
            itemCount: 100,
            itemBuilder: (_, i) => Text('row $i'),
          ),
        ),
      ),
    ));
    expect(c.offset, 0);
    final size = tester.getSize(find.byType(Scaffold));
    // Drag from the top to the middle of the strip at the right edge.
    await tester.dragFrom(Offset(size.width - 10, 10), Offset(0, size.height / 2));
    await tester.pump();
    expect(c.offset, greaterThan(1000));
  });

  Widget byPosition(ScrollController c, int n) => MaterialApp(
    home: Scaffold(
      body: AlphaScroller(
        controller: c,
        itemCount: n,
        child: ListView.builder(
          controller: c,
          itemExtent: 50,
          itemCount: n,
          itemBuilder: (_, i) => Text('row $i'),
        ),
      ),
    ),
  );

  testWidgets('the bar is absent under 100 items and present from 100', (tester) async {
    final c = ScrollController();
    await tester.pumpWidget(byPosition(c, 99));
    expect(find.byKey(const ValueKey('scroller-handle')), findsNothing);
    await tester.pumpWidget(byPosition(c, 100));
    expect(find.byKey(const ValueKey('scroller-handle')), findsOneWidget);
  });

  testWidgets('touching widens the handle, releasing narrows it', (tester) async {
    final c = ScrollController();
    await tester.pumpWidget(byPosition(c, 200));
    double width() => tester.getSize(find.descendant(
        of: find.byKey(const ValueKey('scroller-handle')),
        matching: find.byType(AnimatedContainer))).width;
    expect(width(), lessThan(6));
    final g = await tester.startGesture(const Offset(790, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(width(), greaterThanOrEqualTo(12));
    expect(tester.getSize(find.byKey(const ValueKey('scroller-handle'))).height, 48);
    await g.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(width(), lessThan(6));
  });

  testWidgets('dragging by position maps the fraction to the scroll extent', (tester) async {
    final c = ScrollController();
    await tester.pumpWidget(byPosition(c, 200));
    final size = tester.getSize(find.byType(Scaffold));
    final g = await tester.startGesture(Offset(size.width - 10, 10));
    await g.moveTo(Offset(size.width - 10, size.height / 2));
    await tester.pump();
    final f = (size.height / 2) / size.height;
    expect(c.offset, closeTo(f * c.position.maxScrollExtent, 0.5));
    expect(find.text('${(f * 199).round() + 1} / 200'), findsOneWidget);
    await g.up();
    await tester.pump();
    expect(find.textContaining(' / 200'), findsNothing);
  });
}
