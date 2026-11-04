import 'dart:async';
import 'dart:io';

import 'package:codecore/providers/shuffle_plus_providers.dart';
import 'package:codecore/services/shuffle_plus/suggestion_log.dart';
import 'package:codecore/ui/screens/now_playing/suggestions_screen.dart';
import 'package:codecore/ui/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/app_harness.dart';

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('sug_screen');
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<SuggestionLog> logWith(WidgetTester tester, {bool seeded = true}) async {
    final log = SuggestionLog(
        file: () async => File(p.join(dir.path, 's.json')), writeDelay: const Duration(days: 1));
    await tester.runAsync(() async {
      await log.load();
      if (!seeded) return;
      log.add(videoId: 'a', title: 'Old one', artist: 'Ann', seedTitle: 'Seed A');
      log.add(videoId: 'b', title: 'New one', artist: 'Bob', seedTitle: 'Seed B');
      log.setOutcome('a', SuggestionOutcome.disliked);
    });
    return log;
  }

  testWidgets('lists the newest first with «simile a» and the outcome; «Svuota registro» asks and empties',
      (tester) async {
    final h = await Harness.create(tester);
    final log = await logWith(tester);
    await h.pump(tester, const SuggestionsScreen(),
        extraOverrides: [suggestionLogProvider.overrideWithValue(log)]);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('New one'), findsOneWidget);
    expect(find.text('simile a «Seed B», In coda'), findsOneWidget);
    expect(find.text('simile a «Seed A», Non mi piace'), findsOneWidget);
    expect(tester.getTopLeft(find.text('New one')).dy,
        lessThan(tester.getTopLeft(find.text('Old one')).dy));

    await tester.tap(find.byTooltip('Svuota registro'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Svuota registro'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    }
    await tester.runAsync(() => log.flush());
    await tester.pump();
    expect(log.length, 1);
    expect(find.text('New one'), findsNothing);
    expect(find.text('Old one'), findsOneWidget); // the dislike stays
    await h.dispose(tester);
    await tester.runAsync(() => log.dispose());
  });

  testWidgets('an empty log says so and has no clear button', (tester) async {
    final h = await Harness.create(tester);
    final log = await logWith(tester, seeded: false);
    await h.pump(tester, const SuggestionsScreen(),
        extraOverrides: [suggestionLogProvider.overrideWithValue(log)]);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Nessun suggerito'), findsOneWidget);
    expect(find.byTooltip('Svuota registro'), findsNothing);
    await h.dispose(tester);
    await tester.runAsync(() => log.dispose());
  });

  testWidgets('while the log loads: skeleton rows as tall as the real ones, no spinner', (tester) async {
    final h = await Harness.create(tester);
    await h.pump(tester, const SuggestionsScreen(),
        extraOverrides: [suggestionRecordsProvider.overrideWith((ref) => Completer<List<SuggestionRecord>>().future)]);
    expect(find.byType(Skeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.getSize(find.byType(Skeleton)).height, 8 * 72);
    await h.dispose(tester);
  });
}
