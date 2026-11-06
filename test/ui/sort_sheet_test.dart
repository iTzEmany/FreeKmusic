import 'package:codecore/ui/widgets/sort_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('sort sheet: picks a criterion, flips the direction, switch off when asked', (
    tester,
  ) async {
    final h = await Harness.create(tester);
    final calls = <(String, bool)>[];
    await h.pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSortSheet<String>(
              context: context,
              choices: const [
                SortChoice('own', 'Mio', hasDirection: false),
                SortChoice('plays', 'Tante', ascendingByDefault: false),
              ],
              selected: 'plays',
              ascending: false,
              onChanged: (v, a) => calls.add((v, a)),
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    bool ignoring() => tester
        .widget<IgnorePointer>(find.byKey(const ValueKey('sort-direction')))
        .ignoring;
    expect(ignoring(), isFalse);

    await tester.tap(find.text('Crescente'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, [('plays', true)]);
    expect(find.text('Tante'), findsOneWidget, reason: 'still open');

    await tester.tap(find.text('Mio'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls.last, ('own', true));
    expect(find.text('Tante'), findsNothing, reason: 'closed');
    await h.dispose(tester);
  });

  testWidgets('sort sheet: the direction is off while a directionless choice is selected', (
    tester,
  ) async {
    final h = await Harness.create(tester);
    var calls = 0;
    await h.pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSortSheet<String>(
              context: context,
              choices: const [SortChoice('own', 'Mio', hasDirection: false)],
              selected: 'own',
              ascending: true,
              onChanged: (_, _) => calls++,
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<IgnorePointer>(find.byKey(const ValueKey('sort-direction'))).ignoring,
      isTrue,
    );
    await tester.tap(find.text('Decrescente'), warnIfMissed: false);
    expect(calls, 0);
    await h.dispose(tester);
  });

  testWidgets('sort sheet: the selected criterion again keeps its direction; unknown selection does not crash', (
    tester,
  ) async {
    final h = await Harness.create(tester);
    final calls = <(String, bool)>[];
    await h.pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSortSheet<String>(
              context: context,
              choices: const [SortChoice('a', 'Aaa'), SortChoice('b', 'Bbb')],
              selected: 'zzz',
              ascending: false,
              onChanged: (v, a) => calls.add((v, a)),
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Aaa'), findsOneWidget);
    await h.dispose(tester);
  });
}
