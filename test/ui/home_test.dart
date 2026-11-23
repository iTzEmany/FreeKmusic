import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/ui/screens/home/home_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<Harness> _open(WidgetTester tester, {double textScale = 1}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final h = await Harness.create(tester, tracks: 4);
  await tester.runAsync(
    () => (h.db.update(h.db.tracks)..where((t) => t.title.equals('Song 2')))
        .write(
          const TracksCompanion(
            resumePositionMs: Value(60000),
            lastPlayedAt: Value(1000),
          ),
        ),
  );
  await h.pump(tester, const HomeScreen());
  await _settle(tester);
  return h;
}

void main() {
  testWidgets('Riprendi draws a progress bar on a track left in the middle', (
    tester,
  ) async {
    final h = await _open(tester);
    final bar = tester.widget<LinearProgressIndicator>(
      find.descendant(
        of: find.byKey(const ValueKey('resume-track')),
        matching: find.byType(LinearProgressIndicator),
      ),
    );
    expect(bar.value, closeTo(60 / 185, 0.01));
    await h.dispose(tester);
  });

  testWidgets('no overflow at text scale 2.0 on 360 px', (tester) async {
    final h = await _open(tester, textScale: 2);
    expect(find.text('Riprendi'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });
}
