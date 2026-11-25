import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/play_history_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/ui/screens/history/history_screen.dart';
import 'package:codecore/ui/screens/settings/settings_screen.dart';
import 'package:codecore/ui/widgets/alpha_scroller.dart' show alphaScrollerMinItems;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

int _ms(DateTime d) => d.millisecondsSinceEpoch;

void main() {
  late Harness h;
  late List<Track> tracks;

  Future<void> open(WidgetTester tester, {bool withData = true, bool recordHistory = true, int extra = 0}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester, tracks: 3);
    tracks = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
    if (withData) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final repo = PlayHistoryRepository(h.db);
      await tester.runAsync(() async {
        await repo.start(tracks[0].id, _ms(today.add(const Duration(hours: 0, minutes: 5))));
        await repo.start(tracks[1].id, _ms(today.subtract(const Duration(hours: 2))));
        await repo.start(tracks[2].id, _ms(today.subtract(const Duration(days: 3, hours: -10))));
        await repo.start(tracks[0].id, _ms(today.subtract(const Duration(days: 3, hours: -9))));
        for (var i = 0; i < extra; i++) {
          await repo.start(tracks[0].id, _ms(today.add(Duration(minutes: 10 + i))));
        }
      });
    }
    await h.store.writeSettings(AppSettings(recordHistory: recordHistory));
    await h.pump(tester, const HistoryScreen());
    await _settle(tester);
  }

  testWidgets('three days of listens: day headers, each listen with its time, newest first', (tester) async {
    await open(tester);
    expect(find.text('Cronologia'), findsOneWidget);
    expect(find.text('Oggi'), findsOneWidget);
    expect(find.text('Ieri'), findsOneWidget);
    // The third day gets its date; Song 0 was played on two different days.
    expect(find.text('Song 0'), findsNWidgets(2));
    expect(find.text('Song 1'), findsOneWidget);
    expect(find.text('Song 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('scroller-handle')), findsNothing, reason: 'few entries');
    expect(find.textContaining('00:05'), findsOneWidget);

    // Today above yesterday above the older day.
    final today = tester.getTopLeft(find.text('Oggi')).dy;
    final yesterday = tester.getTopLeft(find.text('Ieri')).dy;
    expect(today, lessThan(yesterday));
    expect(tester.getTopLeft(find.text('Song 1')).dy, greaterThan(yesterday));
    await h.dispose(tester);
  });

  testWidgets('from alphaScrollerMinItems listens on the scroll strip shows', (tester) async {
    await open(tester, extra: alphaScrollerMinItems);
    expect(find.byKey(const ValueKey('scroller-handle')), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('tapping a listen plays that track', (tester) async {
    await open(tester);
    await tester.tap(find.text('Song 1'));
    await _settle(tester);
    expect(h.handler.currentTrack?.title, 'Song 1');
    await h.dispose(tester);
  });

  testWidgets('clearing asks first, empties the list and keeps the play counts', (tester) async {
    await open(tester);
    await tester.runAsync(() => h.db.customUpdate('UPDATE tracks SET play_count = 4'));
    await tester.tap(find.byTooltip('Cancella cronologia'));
    await _settle(tester);
    expect(find.text('Cancellare la cronologia?'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await _settle(tester);
    expect(find.text('Song 1'), findsOneWidget, reason: 'cancelled');

    await tester.tap(find.byTooltip('Cancella cronologia'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Cancella cronologia'));
    await _settle(tester);
    expect(find.text('Qui comparirà quello che ascolti.'), findsOneWidget);
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Apri tutti i brani'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Apri tutti i brani'));
    await _settle(tester);
    expect(find.byType(AllTracksScreen), findsOneWidget);
    expect(find.text('Cronologia cancellata'), findsOneWidget);
    final rows = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
    expect(rows.map((t) => t.playCount), [4, 4, 4]);
    await h.dispose(tester);
  });

  testWidgets('an empty history says so, and says why when it is switched off', (tester) async {
    await open(tester, withData: false);
    expect(find.text('Qui comparirà quello che ascolti.'), findsOneWidget);
    await h.dispose(tester);

    await open(tester, withData: false, recordHistory: false);
    expect(find.textContaining('cronologia è spenta'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('history off: button opens the playback page', (tester) async {
    await open(tester, withData: false, recordHistory: false);
    await tester.tap(find.widgetWithText(FilledButton, 'Apri Riproduzione'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPageView), findsOneWidget);
    expect(find.text('Registra la cronologia di ascolto'), findsOneWidget);
    await h.dispose(tester);
  });
}
