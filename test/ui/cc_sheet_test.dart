import 'package:codecore/ui/widgets/cc_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final w in [400.0, 1000.0]) {
    testWidgets('a short sheet takes min(560, width) at $w px', (t) async {
      t.view.physicalSize = Size(w, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      late BuildContext ctx;
      await t.pumpWidget(MaterialApp(
        theme: ThemeData(bottomSheetTheme: const BottomSheetThemeData(constraints: BoxConstraints(maxWidth: 560))),
        home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        }),
      ));
      showCcSheet<void>(context: ctx, builder: (_) => const Text('x', key: Key('s')));
      await t.pumpAndSettle();
      expect(t.getSize(find.descendant(of: find.byType(BottomSheet), matching: find.byType(Material)).first).width, w < 560 ? w : 560);
    });
  }

  Future<BuildContext> host(WidgetTester t) async {
    late BuildContext ctx;
    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    return ctx;
  }

  testWidgets('showCcSheet returns the value the sheet pops with', (t) async {
    final ctx = await host(t);
    final result = showCcSheet<String>(
      context: ctx,
      builder: (c) => ListTile(key: const Key('pick'), title: const Text('x'), onTap: () => Navigator.pop(c, 'picked')),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('pick')));
    await t.pumpAndSettle();
    expect(await result, 'picked');
  });

  testWidgets('showCcSheet returns null when dismissed without choosing', (t) async {
    final ctx = await host(t);
    final result = showCcSheet<String>(context: ctx, builder: (_) => const SizedBox(height: 100, child: Text('x')));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(10, 10)); // the barrier
    await t.pumpAndSettle();
    expect(find.text('x'), findsNothing);
    expect(await result, isNull);
  });
}
