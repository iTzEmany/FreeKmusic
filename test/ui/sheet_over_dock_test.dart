import 'package:codecore/ui/screens/home/home_screen.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/shell/bottom_bar.dart';
import 'package:codecore/ui/widgets/cc_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('on the phone a sheet opened from a tab covers the dock', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await h.pump(tester, const AppShell());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 300));

    // Before the sheet a touch at the dock's centre reaches the dock.
    final dock = find.byType(ShellDock);
    final at = tester.getCenter(dock);
    bool dockHit() => tester.hitTestOnBinding(at).path.any((e) => e.target is RenderObject && _inside(e.target as RenderObject, tester.renderObject(dock)));
    expect(dockHit(), isTrue);

    showCcSheet<void>(
      context: tester.element(find.byType(HomeScreen)),
      builder: (_) => const SizedBox(height: 600, width: double.infinity, child: Text('sheet-body')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('sheet-body'), findsOneWidget);
    expect(dockHit(), isFalse, reason: 'the sheet is above the dock');
    await h.dispose(tester);
  });
}

bool _inside(RenderObject node, RenderObject ancestor) {
  RenderObject? n = node;
  while (n != null) {
    if (n == ancestor) return true;
    n = n.parent;
  }
  return false;
}
