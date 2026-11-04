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
}
