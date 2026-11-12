import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/daylist_providers.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart' show ShuffleMode, listShuffleProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:codecore/providers/suggestion_actions.dart';
import 'package:codecore/services/daylist/daylist_builder.dart';
import 'package:codecore/services/daylist/daylist_slots.dart';
import 'package:codecore/services/daylist/mood_table.dart';
import 'package:codecore/services/online/youtube_service.dart' show YtResult;
import 'package:codecore/services/shuffle_plus/suggestion_pool.dart'
    show SuggestionCandidate;
import 'package:codecore/services/online/ytm_radio_parser.dart' show RadioKind;
import 'package:codecore/ui/screens/daylist/daylist_labels.dart'
    show genreDisplay;
import 'package:codecore/ui/screens/daylist/daylist_card.dart';
import 'package:codecore/ui/screens/daylist/daylist_screen.dart';
import 'package:codecore/ui/screens/settings/settings_screen.dart';
import 'package:codecore/ui/widgets/track_row.dart' show SwipeToQueue;
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
  final calls = <int?>[];
  @override
  Future<void> play({int? startIndex}) async => calls.add(startIndex);
  @override
  Future<void> regenerate() async {}
}

class _FakeSuggest implements SuggestionActions {
  final disliked = <(String, bool)>[];
  @override
  Future<DislikeUndo> dislikeResult(
    YtResult r, {
    required bool artist,
    int? queueId,
  }) async {
    disliked.add((r.id, artist));
    return DislikeUndo();
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

DaylistState _state(List<Track> tracks, {bool tooFew = false, int slot = 5}) =>
    DaylistState(
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
  late _FakeSuggest suggest;

  Future<void> pump(
    WidgetTester tester,
    Widget child,
    DaylistState? Function(List<Track>) state,
  ) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester, tracks: 3);
    final rows = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
    actions = _FakeActions();
    suggest = _FakeSuggest();
    await h.pump(
      tester,
      child,
      extraOverrides: [
        daylistProvider.overrideWith(() => _FakeDaylist(state(rows))),
        daylistActionsProvider.overrideWithValue(actions),
        suggestionActionsProvider.overrideWithValue(suggest),
      ],
    );
    await tester.pump();
  }

  testWidgets('card: shown with the change hour, hidden when off or too few', (
    tester,
  ) async {
    await pump(tester, const Scaffold(body: DaylistCard()), _state);
    expect(find.textContaining('00:00'), findsOneWidget);
    expect(
      find.textContaining('Tarda sera, Lo-Fi, Jazz, Soul'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Riproduci la daylist'));
    expect(actions.calls, [null]);
    await h.dispose(tester);

    await pump(tester, const Scaffold(body: DaylistCard()), (_) => null);
    expect(find.byType(InkWell), findsNothing);
    await h.dispose(tester);

    await pump(
      tester,
      const Scaffold(body: DaylistCard()),
      (_) => _state(const [], tooFew: true),
    );
    expect(find.byType(InkWell), findsNothing);
    await h.dispose(tester);
  });

  testWidgets(
    'screen: title and Play call the actions; Casuale only toggles the daylist mode, starts nothing (D-534)',
    (tester) async {
      await pump(tester, const DaylistScreen(), _state);
      expect(find.text('Tarda sera, Lo-Fi, Jazz, Soul'), findsOneWidget);
      expect(find.textContaining('Solo 3 brani'), findsOneWidget);
      await tester.tap(find.text('Riproduci'));
      final c = ProviderScope.containerOf(
        tester.element(find.byType(DaylistScreen)),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Casuale'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 100));
      expect(actions.calls, [null]);
      expect(c.read(listShuffleProvider(daylistListKey)), ShuffleMode.shuffle);
      expect(h.handler.shuffleEnabled, isFalse, reason: 'the playing queue is untouched');
      expect(h.handler.isPlaying, isFalse);
      expect(find.textContaining('Si aggiorna alle 00:00'), findsOneWidget);
      await h.dispose(tester);
    },
  );

  testWidgets(
    'screen: a suggested row has a clean label and a menu with Non mi piace',
    (tester) async {
      const yt = YtResult(
        id: 'v1',
        title: 'Online',
        channel: 'Ch',
        artists: ['Band'],
        duration: Duration(seconds: 90),
      );
      final handle = tester.ensureSemantics();
      await pump(tester, const DaylistScreen(), (rows) {
        final d = _state(rows);
        return DaylistState(
          result: DaylistResult(
            slotIndex: 5,
            items: [
              DaylistItem.suggested(
                const SuggestionCandidate(yt, 's', RadioKind.song),
              ),
              ...d.result.items,
            ],
            genres: d.result.genres,
            tooFew: false,
          ),
          slot: d.slot,
          slotIndex: 5,
          nextChange: d.nextChange,
        );
      });
      expect(
        find.bySemanticsLabel(RegExp(r'^Online\nSuggerito, Band$')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Altre opzioni').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dislike-artist')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('dislike-track')));
      await tester.pumpAndSettle();
      expect(suggest.disliked, [('v1', false)]);
      handle.dispose();
      await h.dispose(tester);
    },
  );

  test('genreDisplay uses the readable names inside longer keys', () {
    expect(genreDisplay('r and b soul'), 'R&B soul');
    expect(genreDisplay('lo fi beats'), 'Lo-Fi beats');
    expect(genreDisplay('hip hop soul'), 'Hip hop soul');
    expect(genreDisplay('r and b'), 'R&B');
    expect(genreDisplay('jazz'), 'Jazz');
  });

  group('settings', () {
    Future<void> open(WidgetTester tester) async {
      await pump(
        tester,
        const Scaffold(body: SettingsScreen(initial: SettingsPage.daylist)),
        (_) => null,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the slot row label says when it has too few songs', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const Scaffold(body: SettingsScreen(initial: SettingsPage.daylist)),
        (_) => _state(const [], tooFew: true),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(RegExp(r'Tarda sera.*Meno di 15 brani')),
        findsOneWidget,
      );
      handle.dispose();
      await h.dispose(tester);
    });

    testWidgets(
      'switch turns a slot off; the start hour keeps the neighbours',
      (tester) async {
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
        expect(
          tester
              .widget<IconButton>(find.byKey(const ValueKey('daylist-later')))
              .onPressed,
          isNull,
        );
        await h.dispose(tester);
      },
    );

    testWidgets('reset asks first and restores the defaults', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('daylist-switch-1')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ripristina i valori di serie'),
        200,
      );
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

    testWidgets('mood table: search filters and a mood chip is saved', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Genere e umore'));
      await tester.pumpAndSettle();
      expect(find.text('20 di 20 generi'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('daylist-genre-search')),
        'jaz',
      );
      await tester.pumpAndSettle();
      expect(find.text('1 di 20 generi'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('daylist-genre-jazz-energetic')),
      );
      await tester.pumpAndSettle();
      expect(h.store.readMoodTable().moodsOf('jazz'), contains(Mood.energetic));
      await h.dispose(tester);
    });
  });

  testWidgets('a swipe on a daylist row queues the track (R-220)', (tester) async {
    await pump(tester, const DaylistScreen(), _state);
    expect(find.byType(SwipeToQueue), findsWidgets);
    final y = tester.getCenter(find.text('Song 0')).dy;
    await tester.dragFrom(Offset(150, y), const Offset(300, 0));
    await tester.pump(const Duration(milliseconds: 600));
    expect(h.handler.queueIds, hasLength(1));
    await h.dispose(tester);
  });
}
