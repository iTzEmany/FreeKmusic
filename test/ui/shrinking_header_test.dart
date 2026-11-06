import 'package:codecore/ui/widgets/shrinking_header.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _max = 100.0;

Future<void> _open(
  WidgetTester t, {
  bool disableAnimations = false,
  Widget header = const SizedBox(height: _max),
  void Function(String)? onTap,
}) async {
  final c = ScrollController();
  addTearDown(c.dispose);
  await t.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            controller: c,
            slivers: [
              ShrinkingHeader(child: header),
              SliverFixedExtentList(
                itemExtent: 50,
                delegate: SliverChildBuilderDelegate(
                  childCount: 60,
                  (_, i) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap?.call('row $i'),
                    child: Text('row $i'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Visible part of the header.
double _height(WidgetTester t) =>
    t.renderObject<RenderSliver>(find.byType(ShrinkingHeader, skipOffstage: false)).geometry!.paintExtent;

// A wheel notch is exact, unlike a touch drag (which loses the touch slop).
Future<void> _wheel(WidgetTester t, double dy) async {
  final p = TestPointer(1, PointerDeviceKind.mouse);
  await t.sendEventToBinding(p.hover(const Offset(200, 400)));
  await t.sendEventToBinding(p.scroll(Offset(0, dy)));
  await t.pump();
}

void main() {
  testWidgets('the first frame already has the full height', (t) async {
    await _open(t);
    expect(_height(t), _max);
  });

  testWidgets('it shrinks by exactly the scroll delta, down to nothing', (t) async {
    await _open(t);
    expect(_height(t), _max);
    for (final (d, h) in [(10.0, 90.0), (25.0, 65.0), (70.0, 0.0)]) {
      await _wheel(t, d);
      expect(_height(t), h);
    }
    await _wheel(t, 500);
    expect(_height(t), 0);
  });

  testWidgets('going up brings it back by the same delta, far from the top', (t) async {
    await _open(t);
    await _wheel(t, 1000);
    await _wheel(t, -30);
    expect(_height(t), 30);
    await _wheel(t, -50);
    expect(_height(t), 80);
    await _wheel(t, -500);
    expect(_height(t), _max);
  });

  testWidgets('with reduced motion nothing snaps after the scroll stops', (t) async {
    await _open(t, disableAnimations: true);
    await _wheel(t, 1000);
    await _wheel(t, -30);
    await t.pumpAndSettle();
    expect(_height(t), 30);
  });

  // Two 50 dp blocks, each a button.
  Widget twoBlocks(void Function(String) onTap) => Column(
    children: [
      for (final n in ['A', 'B'])
        SizedBox(
          height: 50,
          width: double.infinity,
          child: ElevatedButton(onPressed: () => onTap(n), child: Text(n)),
        ),
    ],
  );

  testWidgets('it is painted where it is laid out, and back at 0 going up', (t) async {
    await _open(t, header: twoBlocks((_) {}));
    await _wheel(t, 30);
    expect(t.getTopLeft(find.widgetWithText(ElevatedButton, 'A')).dy, -30);
    expect(t.getTopLeft(find.widgetWithText(ElevatedButton, 'B')).dy, 20);
    await _wheel(t, -500);
    expect(t.getTopLeft(find.widgetWithText(ElevatedButton, 'A')).dy, 0);
    expect(t.getTopLeft(find.widgetWithText(ElevatedButton, 'B')).dy, 50);
  });

  testWidgets('taps reach the button in a partly shown header and the row below', (t) async {
    final taps = <String>[];
    await _open(t, header: twoBlocks(taps.add), onTap: taps.add);
    await _wheel(t, 30);
    await t.tapAt(const Offset(100, 10)); // A: -30..20
    await t.tapAt(const Offset(100, 40)); // B: 20..70
    // Rows start at 70.
    await t.tapAt(const Offset(100, 80));
    expect(taps, ['A', 'B', 'row 0']);
  });

  testWidgets('a header taller than the viewport keeps its top tappable', (t) async {
    t.view.physicalSize = const Size(400, 300);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final taps = <String>[];
    await _open(t, header: Column(children: [
      SizedBox(height: 56, width: double.infinity, child: ElevatedButton(onPressed: () => taps.add('top'), child: const Text('top'))),
      const SizedBox(height: 600),
    ]));
    await t.tap(find.text('top'));
    expect(taps, ['top']);
  });
}
