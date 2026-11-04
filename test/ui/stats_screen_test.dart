import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/play_history_repository.dart';
import 'package:codecore/data/repositories/stats_queries.dart';
import 'package:codecore/providers/history_providers.dart';
import 'package:codecore/ui/screens/home/home_screen.dart';
import 'package:codecore/ui/screens/stats/stats_charts.dart';
import 'package:codecore/ui/screens/stats/stats_screen.dart';
import 'package:codecore/ui/widgets/segmented_blocks.dart';
import 'package:codecore/ui/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

int _ms(int y, int m, int d, [int h = 21]) => DateTime(y, m, d, h, 10).millisecondsSinceEpoch;

void main() {
  late Harness h;
  late List<Track> tracks;
  final now = DateTime(2026, 10, 16, 9);

  Future<void> open(WidgetTester tester, {bool withData = true}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester, tracks: 3);
    tracks = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
    if (withData) {
      final repo = PlayHistoryRepository(h.db);
      await tester.runAsync(() async {
        // October: 3 listens of 21 minutes (63 min); September: one of 10.
        await repo.start(tracks[0].id, _ms(2026, 10, 2), msPlayed: 21 * 60000);
        await repo.start(tracks[0].id, _ms(2026, 10, 3), msPlayed: 21 * 60000);
        await repo.start(tracks[1].id, _ms(2026, 10, 9), msPlayed: 21 * 60000);
        await repo.start(tracks[2].id, _ms(2026, 9, 20), msPlayed: 10 * 60000);
      });
    }
    await h.pump(tester, StatsScreen(now: now));
    await _settle(tester);
  }

  testWidgets('a month: total time, listens, the bars and the rankings', (tester) async {
    await open(tester);
    expect(find.text('Statistiche'), findsOneWidget);
    expect(find.text('ottobre 2026'), findsOneWidget);
    expect(find.text('1 h 3 min'), findsOneWidget);
    expect(find.textContaining('3 ascolti'), findsWidgets);
    expect(find.textContaining('2 brani diversi'), findsOneWidget);
    expect(find.byType(StatsBars), findsOneWidget);
    expect(find.text('Brani più ascoltati'), findsOneWidget);
    expect(find.text('Artisti più ascoltati'), findsOneWidget);
    expect(find.text('Song 0'), findsOneWidget, reason: 'the most played track, twice');
    expect(find.textContaining('2 ascolti'), findsWidgets);
    expect(find.text('21:00–22:00'), findsOneWidget, reason: 'the favourite hour');
    await h.dispose(tester);
  });

  testWidgets('the arrows move between months and the next one stops at today', (tester) async {
    await open(tester);
    final next = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right_rounded));
    expect(next.onPressed, isNull, reason: 'October is the current month');
    await tester.tap(find.byTooltip('Periodo precedente'));
    await _settle(tester);
    expect(find.text('settembre 2026'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
    expect(find.text('Song 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Periodo precedente'));
    await _settle(tester);
    expect(find.text('agosto 2026'), findsOneWidget);
    expect(find.text('Nessun ascolto in questo periodo.'), findsOneWidget);
    await tester.tap(find.byTooltip('Periodo successivo'));
    await _settle(tester);
    expect(find.text('settembre 2026'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the year view sums the months', (tester) async {
    await open(tester);
    await tester.tap(find.text('Anno'));
    await _settle(tester);
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('1 h 13 min'), findsOneWidget);
    expect(find.textContaining('4 ascolti'), findsWidgets);
    await h.dispose(tester);
  });

  testWidgets('stats blocks switch period and the arrows keep working', (tester) async {
    await open(tester);
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(find.byType(SegmentedBlocks<bool>), findsOneWidget);
    await tester.tap(find.text('Anno'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Periodo precedente'));
    await _settle(tester);
    expect(find.text('2025'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('no history at all: an empty state, no chart', (tester) async {
    await open(tester, withData: false);
    expect(find.text('Nessun ascolto in questo periodo.'), findsOneWidget);
    expect(find.byType(StatsBars), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('the stats follow a new listen while the screen is open', (tester) async {
    await open(tester);
    await tester.runAsync(() => PlayHistoryRepository(h.db)
        .start(tracks[2].id, _ms(2026, 10, 12), msPlayed: 10 * 60000));
    await _settle(tester);
    expect(find.text('1 h 13 min'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('Anno then Mese comes back to the last month seen', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Periodo precedente'));
    await _settle(tester);
    await tester.tap(find.text('Anno'));
    await _settle(tester);
    await tester.tap(find.text('Mese'));
    await _settle(tester);
    expect(find.text('settembre 2026'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('with no month seen, a past year opens on the same month number', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester, tracks: 1);
    await h.pump(tester, StatsScreen(now: DateTime(2026, 11, 4)));
    await _settle(tester);
    await tester.tap(find.text('Anno'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Periodo precedente'));
    await _settle(tester);
    await tester.tap(find.text('Mese'));
    await _settle(tester);
    expect(find.text('novembre 2025'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a remembered month in the future falls back to the current month', (tester) async {
    await open(tester);
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byTooltip('Periodo precedente'));
      await tester.pump();
    }
    await _settle(tester);
    expect(find.text('dicembre 2025'), findsOneWidget);
    await tester.tap(find.text('Anno'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Periodo successivo'));
    await _settle(tester);
    expect(find.text('2026'), findsOneWidget);
    await tester.tap(find.text('Mese'));
    await _settle(tester);
    expect(find.text('ottobre 2026'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('first load shows the bars skeleton', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester, tracks: 1);
    await h.pump(tester, StatsScreen(now: now), extraOverrides: [
      periodStatsProvider.overrideWith((ref, k) => const Stream<PeriodStats>.empty()),
    ]);
    expect(find.byType(Skeleton), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('touching a bar selects it for TalkBack, and a future day cannot be selected',
      (tester) async {
    final sem = tester.ensureSemantics();
    await open(tester);
    final box = tester.getRect(find.byType(StatsBars));
    final slot = box.width / 31;
    // 2 October: the bar of day 2.
    await tester.tapAt(Offset(box.left + slot * 1.5, box.center.dy));
    await tester.pump();
    expect(find.semantics.byLabel(RegExp(r'^2\sott,\s21\smin$')), findsOneWidget);
    expect(find.semantics.byLabel(RegExp(r'^20\sott')), findsNothing, reason: 'future day');
    // Drag over a future day (25 October): the selection stays on the last valid bar.
    await tester.dragFrom(
      Offset(box.left + slot * 1.5, box.center.dy),
      Offset(slot * 23, 0),
    );
    await tester.pump();
    expect(find.semantics.byLabel(RegExp(r'^16\sott')), findsOneWidget);
    sem.dispose();
    await h.dispose(tester);
  });

  testWidgets('changing period keeps the old stats dimmed, no spinner', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Periodo precedente'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('1 h 3 min'), findsOneWidget, reason: 'the previous month, dimmed');
    await _settle(tester);
    await h.dispose(tester);
  });

  group('Home «Il tuo mese»', () {
    Future<void> openHome(WidgetTester tester, int listens) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      h = await Harness.create(tester, tracks: 3);
      tracks = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
      final repo = PlayHistoryRepository(h.db);
      final at = DateTime.now().subtract(const Duration(seconds: 5));
      await tester.runAsync(() async {
        for (var i = 0; i < listens; i++) {
          await repo.start(tracks[i % 3].id, at.millisecondsSinceEpoch - i, msPlayed: 3 * 60000);
        }
      });
      await h.pump(tester, const HomeScreen());
      await _settle(tester);
    }

    testWidgets('appears with ten listens in the month and opens the stats', (tester) async {
      await openHome(tester, 10);
      expect(find.text('Il tuo mese'), findsOneWidget);
      expect(find.textContaining('30 min'), findsOneWidget);
      await tester.tap(find.text('Il tuo mese'));
      await _settle(tester);
      expect(find.text('Statistiche'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('stays hidden with fewer', (tester) async {
      await openHome(tester, 9);
      expect(find.text('Il tuo mese'), findsNothing);
      await h.dispose(tester);
    });
  });
}
