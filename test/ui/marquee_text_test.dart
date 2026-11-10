import 'package:codecore/ui/widgets/marquee_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _long = 'A very long title that cannot fit in a narrow box at all, really';

Widget _host({
  String text = _long,
  bool reduce = false,
  bool tickers = true,
  VoidCallback? onTap,
}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: TickerMode(
          enabled: tickers,
          child: Scaffold(
            body: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: SizedBox(width: 100, child: MarqueeText(text)),
              ),
            ),
          ),
        ),
      ),
    );

double _x(WidgetTester t) => t.getTopLeft(find.byType(Text)).dx;

void main() {
  testWidgets('a short title stays still', (t) async {
    await t.pumpWidget(_host(text: 'Hi'));
    expect(t.hasRunningAnimations, isFalse);
    expect(t.widget<Text>(find.text('Hi')).overflow, TextOverflow.ellipsis);
  });

  testWidgets('a long title waits 2 s, then scrolls', (t) async {
    await t.pumpWidget(_host());
    final x0 = _x(t);
    await t.pump(const Duration(milliseconds: 1900));
    expect(_x(t), x0);
    await t.pump(const Duration(seconds: 2));
    expect(_x(t), lessThan(x0));
  });

  testWidgets('reduced motion: static with an ellipsis', (t) async {
    await t.pumpWidget(_host(reduce: true));
    await t.pump(const Duration(seconds: 5));
    expect(t.hasRunningAnimations, isFalse);
    expect(t.widget<Text>(find.text(_long)).overflow, TextOverflow.ellipsis);
  });

  testWidgets('the semantics label is the full title', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(_host());
    expect(find.bySemanticsLabel(_long), findsOneWidget);
    h.dispose();
  });

  testWidgets('a tap reaches the parent', (t) async {
    var taps = 0;
    await t.pumpWidget(_host(onTap: () => taps++));
    await t.tap(find.byType(MarqueeText));
    expect(taps, 1);
  });

  testWidgets('the animation stops when the screen is covered', (t) async {
    await t.pumpWidget(_host(tickers: false));
    await t.pump(const Duration(milliseconds: 100));
    expect(t.hasRunningAnimations, isFalse);
    final x0 = _x(t);
    await t.pump(const Duration(seconds: 5));
    expect(_x(t), x0);
  });

  testWidgets('a new title restarts from the beginning', (t) async {
    await t.pumpWidget(_host());
    await t.pump(const Duration(seconds: 4));
    await t.pumpWidget(_host(text: '$_long!'));
    final x0 = t.getTopLeft(find.byType(Text)).dx;
    await t.pump(const Duration(seconds: 1));
    expect(_x(t), x0);
  });
}
