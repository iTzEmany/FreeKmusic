import 'package:codecore/core/platform.dart';
import 'package:codecore/ui/widgets/cc_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final w in [400.0, 1000.0]) {
    testWidgets('a short sheet takes min(560, width) at $w px', (t) async {
      t.view.physicalSize = Size(w, 800);
      t.view.devicePixelRatio = 1;
      debugIsDesktopOverride = false;
      addTearDown(() {
        t.view.reset();
        debugIsDesktopOverride = null;
      });
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

  Future<BuildContext> host(WidgetTester t, {required bool wide}) async {
    t.view.physicalSize = Size(wide ? 1280 : 400, 800);
    t.view.devicePixelRatio = 1;
    debugIsDesktopOverride = wide;
    addTearDown(() {
      t.view.reset();
      debugIsDesktopOverride = null;
    });
    late BuildContext ctx;
    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    return ctx;
  }

  for (final wide in [false, true]) {
    final mode = wide ? 'dialog' : 'sheet';
    testWidgets('showCcSheet returns the popped value ($mode)', (t) async {
      final ctx = await host(t, wide: wide);
      final result = showCcSheet<String>(
        context: ctx,
        builder: (c) => ListTile(key: const Key('pick'), title: const Text('x'), onTap: () => Navigator.pop(c, 'picked')),
      );
      await t.pumpAndSettle();
      expect(find.byType(BottomSheet), wide ? findsNothing : findsOneWidget);
      expect(find.byType(Dialog), wide ? findsOneWidget : findsNothing);
      await t.tap(find.byKey(const Key('pick')));
      await t.pumpAndSettle();
      expect(await result, 'picked');
    });

    testWidgets('showCcSheet returns null when dismissed ($mode)', (t) async {
      final ctx = await host(t, wide: wide);
      final result = showCcSheet<String>(context: ctx, builder: (_) => const SizedBox(height: 100, child: Text('x')));
      await t.pumpAndSettle();
      await t.tapAt(const Offset(10, 10)); // the barrier
      await t.pumpAndSettle();
      expect(find.text('x'), findsNothing);
      expect(await result, isNull);
    });
  }

  testWidgets('dialog: height of the content, Esc closes, focus starts on the first control', (t) async {
    final ctx = await host(t, wide: true);
    final result = showCcSheet<String>(
      context: ctx,
      builder: (_) => const Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(key: Key('a'), title: Text('a'), onTap: null),
        TextField(key: Key('f')),
      ]),
    );
    await t.pumpAndSettle();
    expect(t.getSize(find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first).height, lessThan(200));
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextField>(), isNotNull);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(await result, isNull);
  });
}
