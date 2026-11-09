import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/daylist_providers.dart';
import 'package:codecore/services/daylist/daylist_builder.dart';
import 'package:codecore/services/daylist/daylist_slots.dart';
import 'package:codecore/services/daylist/mood_table.dart';
import 'package:codecore/ui/screens/daylist/daylist_card.dart';
import 'package:codecore/ui/screens/daylist/daylist_screen.dart';
import 'package:codecore/ui/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// A daylist state that never touches the database.
class _FakeDaylist extends DaylistNotifier {
  _FakeDaylist(this.value);
  final DaylistState? value;
  @override
  Future<DaylistState?> build() async => value;
}

class _FakeActions implements DaylistActions {
  final calls = <bool>[];
  @override
  Future<void> play({bool shuffle = false}) async => calls.add(shuffle);
  @override
  Future<void> regenerate() async {}
}

DaylistState _state(List<Track> tracks, {bool tooFew = false, int slot = 5}) => DaylistState(
  result: DaylistResult(
    slotIndex: slot,
    items: [for (final t in tracks) DaylistItem.own(t)],
    genres: const ['lo-fi', 'jazz', 'soul'],
    tooFew: tooFew,
  ),
  slot: DaylistConfig.defaults().slots[slot],
  slotIndex: slot,
  nextChange: DateTime(2026, 11, 9, 0),
);

void main() {
  late Harness h;
  late _FakeActions actions;

  Future<void> pump(WidgetTester tester, Widget child, DaylistState? Function(List<Track>) state) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester, tracks: 3);
    final rows = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
    actions = _FakeActions();
    await h.pump(tester, child, extraOverrides: [
      daylistProvider.overrideWith(() => _FakeDaylist(state(rows))),
      daylistActionsProvider.overrideWithValue(actions),
    ]);
    await tester.pump();
  }

  testWidgets('card: shown with the change hour, hidden when off or too few', (tester) async {
    await pump(tester, const Scaffold(body: DaylistCard()), _state);
    expect(find.textContaining('00:00'), findsOneWidget);
    expect(find.textContaining('Tarda sera, lo-fi, jazz, soul'), findsOneWidget);
    await tester.tap(find.byTooltip('Riproduci la daylist'));
    expect(actions.calls, [false]);
    await h.dispose(tester);

    await pump(tester, const Scaffold(body: DaylistCard()), (_) => null);
    expect(find.byType(InkWell), findsNothing);
    await h.dispose(tester);

    await pump(tester, const Scaffold(body: DaylistCard()), (_) => _state(const [], tooFew: true));
    expect(find.byType(InkWell), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('screen: title, Play and Shuffle call the actions, short note under 50', (tester) async {
    await pump(tester, const DaylistScreen(), _state);
    expect(find.text('Tarda sera, lo-fi, jazz, soul'), findsOneWidget);
    expect(find.textContaining('Solo 3 brani'), findsOneWidget);
    await tester.tap(find.text('Riproduci'));
    await tester.tap(find.text('Casuale'));
    expect(actions.calls, [false, true]);
    expect(find.textContaining('Si aggiorna alle 00:00'), findsOneWidget);
    await h.dispose(tester);
  });

  group('settings', () {
    Future<void> open(WidgetTester tester) async {
      await pump(tester, const Scaffold(body: SettingsScreen(initial: SettingsPage.daylist)), (_) => null);
      await tester.pumpAndSettle();
    }

    testWidgets('switch turns a slot off; the start hour keeps the neighbours', (tester) async {
      await open(tester);
      expect(find.text('Tarda sera'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('daylist-switch-1')));
      await tester.pumpAndSettle();
      expect(h.store.readDaylistConfig().slots[1].enabled, isFalse);

      // Slot 5 (22:00) sits between 19:00 and 00:00: 23:00 is fine, then 00:00 is not.
      await tester.tap(find.byKey(const ValueKey('daylist-slot-5')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('daylist-later')));
      await tester.pumpAndSettle();
      expect(h.store.readDaylistConfig().slots[5].startHour, 23);
      expect(tester.widget<IconButton>(find.byKey(const ValueKey('daylist-later'))).onPressed, isNull);
      await h.dispose(tester);
    });

    testWidgets('reset asks first and restores the defaults', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('daylist-switch-1')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Ripristina i valori di serie'), 200);
      await tester.tap(find.text('Ripristina i valori di serie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(h.store.readDaylistConfig().slots[1].enabled, isFalse);

      await tester.tap(find.text('Ripristina i valori di serie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ripristina'));
      await tester.pumpAndSettle();
      expect(h.store.readDaylistConfig().slots[1].enabled, isTrue);
      await h.dispose(tester);
    });

    testWidgets('mood table: search filters and a mood chip is saved', (tester) async {
      await open(tester);
      await tester.tap(find.text('Genere e umore'));
      await tester.pumpAndSettle();
      expect(find.text('20 di 20 generi'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('daylist-genre-search')), 'jaz');
      await tester.pumpAndSettle();
      expect(find.text('1 di 20 generi'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('daylist-genre-jazz-energetic')));
      await tester.pumpAndSettle();
      expect(h.store.readMoodTable().moodsOf('jazz'), contains(Mood.energetic));
      await h.dispose(tester);
    });
  });
}
