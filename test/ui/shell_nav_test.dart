import 'package:codecore/providers/nav_providers.dart';
import 'package:codecore/ui/shell/shell_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The shell is a tab navigator inside the root one; `ShellNav.openOnTop` is called from the root.
  Future<(WidgetRef, BuildContext, GlobalKey<NavigatorState>)> pump(WidgetTester tester) async {
    late WidgetRef ref;
    late GlobalKey<NavigatorState> tab;
    await tester.pumpWidget(ProviderScope(
      child: Consumer(builder: (c, r, _) {
        ref = r;
        tab = r.read(tabNavigatorKeysProvider)[0];
        return MaterialApp(home: Navigator(key: tab, onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const Text('home'))));
      }),
    ));
    return (ref, tab.currentContext!, tab);
  }

  testWidgets('with only the shell on screen the page opens in the active tab', (tester) async {
    final (ref, ctx, tab) = await pump(tester);
    ShellNav.openOnTop<void>(ctx, ref, const Text('eq'));
    await tester.pumpAndSettle();
    expect(tab.currentState!.canPop(), isTrue);
    expect(Navigator.of(ctx, rootNavigator: true).canPop(), isFalse);
  });

  testWidgets('above a root route (Now Playing) it opens on the root', (tester) async {
    final (ref, ctx, tab) = await pump(tester);
    final root = Navigator.of(ctx, rootNavigator: true);
    root.push(MaterialPageRoute<void>(builder: (_) => const Text('now')));
    await tester.pumpAndSettle();
    ShellNav.openOnTop<void>(ctx, ref, const Text('eq'));
    await tester.pumpAndSettle();
    expect(tab.currentState!.canPop(), isFalse);
    expect(find.text('eq'), findsOneWidget);
  });
}
