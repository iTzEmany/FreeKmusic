import 'package:codecore/ui/theme/palette.dart' show contrastRatio;
import 'package:codecore/ui/widgets/genre_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<Harness> _grid(WidgetTester tester, {double scale = 1}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create(tester);
  await h.pump(
    tester,
    MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 800),
        textScaler: TextScaler.linear(scale),
      ),
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            GenreGrid(
              columns: 3,
              wideColumns: 6,
              onSelect: (_) {},
              items: [
                for (var i = 0; i < 7; i++)
                  GenreItem('t$i', 'A rather long genre name $i', subtitle: '$i brani'),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  return h;
}

int _firstRow(WidgetTester tester) {
  final top = tester.getTopLeft(find.byKey(const ValueKey('genre-t0'))).dy;
  var n = 0;
  while (n < 7 &&
      tester.getTopLeft(find.byKey(ValueKey('genre-t$n'))).dy == top) {
    n++;
  }
  return n;
}

void main() {
  testWidgets('three columns on a 360 dp phone, cells at least 56 dp', (
    tester,
  ) async {
    final h = await _grid(tester);
    expect(_firstRow(tester), 3);
    expect(
      tester.getSize(find.byKey(const ValueKey('genre-t0'))).height,
      greaterThanOrEqualTo(56),
    );
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('two columns at 200 % text, without overflow', (tester) async {
    final h = await _grid(tester, scale: 2);
    expect(_firstRow(tester), 2);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  for (final c in [const Color(0xFFFFEB3B), const Color(0xFF1565C0), const Color(0xFFE91E63), const Color(0xFF4CAF50)]) {
    testWidgets('text on the saturated tile $c reads at 4.5:1 or more, subtitle too (F-117)', (tester) async {
      final h = await Harness.create(tester);
      await h.pump(
        tester,
        Scaffold(
          body: CustomScrollView(
            slivers: [
              GenreGrid(onSelect: (_) {}, items: [GenreItem('x', 'Rock', subtitle: '3 brani', color: c)]),
            ],
          ),
        ),
      );
      for (final t in ['Rock', '3 brani']) {
        final color = tester.widget<Text>(find.text(t)).style!.color!;
        expect(contrastRatio(color, c), greaterThanOrEqualTo(4.5), reason: t);
      }
      await h.dispose(tester);
    });
  }

  testWidgets('13 px text on a wide window, 12 on the phone', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await h.pump(
      tester,
      Scaffold(body: CustomScrollView(slivers: [GenreGrid(onSelect: (_) {}, items: const [GenreItem('x', 'Rock', subtitle: '3 brani')])])),
    );
    expect(tester.widget<Text>(find.text('3 brani')).style!.fontSize, 13);
    await h.dispose(tester);
  });
}
