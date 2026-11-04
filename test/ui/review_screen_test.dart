import 'dart:async';

import 'package:codecore/data/db/app_database.dart' show Track;
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/providers/review_providers.dart';
import 'package:codecore/providers/second_opinion_providers.dart';
import 'package:codecore/ui/screens/library/review_screen.dart';
import 'package:codecore/ui/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 120)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

/// A job whose state the test sets by hand; it never touches the network.
class _FakeJob extends SecondOpinionNotifier {
  int cancelled = 0;

  @override
  Future<void> run(List<int> ids, {bool force = false}) async {}

  @override
  void cancel() => cancelled++;

  // ignore: use_setters_to_change_properties
  void set(SecondOpinionState s) => state = s;
}

/// Song 0: nothing found; Song 1: found but no lyrics; Song 2: not tried.
Future<Harness> _seeded(
  WidgetTester tester, {
  double textScale = 1,
  List<Override> extra = const [],
  bool host = false,
}) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await Harness.create(tester, tracks: 3);
  await tester.runAsync(() async {
    await h.db.customUpdate(
      "UPDATE tracks SET enrich_status = 2 WHERE title = 'Song 0'",
    );
    await h.db.customUpdate(
      "UPDATE tracks SET enrich_status = 1, lyrics_plain = NULL, has_cover = 1, year = 2000, genre = 'Rock' WHERE title = 'Song 1'",
    );
  });
  await h.pump(
    tester,
    host
        ? Builder(
            builder: (c) => TextButton(
              onPressed: () => Navigator.of(c).push(
                MaterialPageRoute<void>(builder: (_) => const ReviewScreen()),
              ),
              child: const Text('open'),
            ),
          )
        : const ReviewScreen(),
    textScale: textScale,
    extraOverrides: [
      secondOpinionJobProvider.overrideWith(_FakeJob.new),
      ...extra,
    ],
  );
  await _settle(tester);
  if (host) {
    await tester.tap(find.text('open'));
    await _settle(tester);
  }
  return h;
}

class _FakeEnrich extends EnrichJobNotifier {
  List<int>? started;

  @override
  EnrichJobState build() => const EnrichJobState();

  @override
  bool start(List<int> ids, {void Function()? onFinished}) {
    started = ids;
    return true;
  }
}

void main() {
  testWidgets('filters show their counts and narrow the list', (tester) async {
    final h = await _seeded(tester);
    expect(find.text('Song 0'), findsOneWidget);
    expect(find.text('Song 1'), findsOneWidget);
    expect(find.text('Song 2'), findsNothing);
    expect(find.text('Tutti 2'), findsOneWidget);
    expect(find.text('Nessun risultato 1'), findsOneWidget);
    expect(find.text('Senza testo 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('review-filter-nothingFound')));
    await _settle(tester);
    expect(find.text('Song 0'), findsOneWidget);
    expect(find.text('Song 1'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('reasons are chips and the primary action fits the row', (
    tester,
  ) async {
    final h = await _seeded(tester);
    final reasons = find.byWidgetPredicate(
      (w) => w.key.toString().contains('review-reasons-'),
    );
    expect(
      find.descendant(
        of: reasons.first,
        matching: find.text('Nessun risultato'),
      ),
      findsOneWidget,
    );
    // Nothing found: «Riprova»; the other row: «Cerca».
    expect(find.widgetWithText(TextButton, 'Riprova'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cerca'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('«Ignora» removes the picked row and Annulla puts it back', (
    tester,
  ) async {
    final h = await _seeded(tester);
    await tester.longPress(find.text('Song 0'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('review-dismiss')));
    await _settle(tester);
    expect(find.text('Song 0'), findsNothing);
    expect(find.text('Annulla'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await _settle(tester);
    expect(find.text('Song 0'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('«Riprova» on a nothing-found row starts the search', (
    tester,
  ) async {
    final enrich = _FakeEnrich();
    final h = await _seeded(
      tester,
      extra: [enrichJobProvider.overrideWith(() => enrich)],
    );
    final riprova = find.widgetWithText(TextButton, 'Riprova');
    await tester.tap(riprova);
    await _settle(tester);
    expect(enrich.started, hasLength(1));
    await h.dispose(tester);
  });

  testWidgets('an emptied filter shows the empty state with the chips', (
    tester,
  ) async {
    final h = await _seeded(tester);
    await tester.tap(find.byKey(const ValueKey('review-filter-nothingFound')));
    await _settle(tester);
    await tester.longPress(find.text('Song 0'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('review-dismiss')));
    await _settle(tester);
    expect(
      find.text('Niente da revisionare: ai brani cercati non manca nulla'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('review-filter-all')), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('Annulla still works after the screen was left', (tester) async {
    final h = await _seeded(tester, host: true);
    await tester.longPress(find.text('Song 0'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('review-dismiss')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pump(const Duration(milliseconds: 500));
    // The snackbar slides away with the route: press its action directly.
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('open'));
    await _settle(tester);
    await _settle(tester);
    expect(find.text('Song 0'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('selection mode shows the bulk actions and a filter clears it', (
    tester,
  ) async {
    final h = await _seeded(tester);
    await tester.longPress(find.text('Song 0'));
    await _settle(tester);
    expect(find.widgetWithText(TextButton, 'Riprova'), findsWidgets);
    expect(find.widgetWithText(TextButton, 'Ignora'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('review-dismiss'))).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byKey(const ValueKey('review-filter-noLyrics')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('review-dismiss')), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('loading shows the row skeleton', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final feed = StreamController<List<Track>>();
    final h = await Harness.create(tester, tracks: 1);
    await h.pump(
      tester,
      const ReviewScreen(),
      extraOverrides: [
        secondOpinionJobProvider.overrideWith(_FakeJob.new),
        reviewTracksProvider.overrideWith((ref) => feed.stream),
      ],
    );
    await tester.pump();
    expect(find.byType(Skeleton), findsOneWidget);
    // A provider may not be disposed while it has never emitted.
    feed.add(const []);
    await tester.pump();
    await h.dispose(tester);
  });

  testWidgets('nothing overflows at 200 % text on a phone', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 3);
    await tester.runAsync(
      () => h.db.customUpdate(
        "UPDATE tracks SET enrich_status = 2 WHERE title = 'Song 0'",
      ),
    );
    await h.pump(
      tester,
      const ReviewScreen(),
      textScale: 2.0,
      extraOverrides: [secondOpinionJobProvider.overrideWith(_FakeJob.new)],
    );
    await _settle(tester);
    expect(find.text('Song 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets(
    'second-opinion row shows the progress and Ferma, goes away at the end with a snackbar',
    (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester, tracks: 1);
      final job = _FakeJob();
      await h.pump(
        tester,
        const ReviewScreen(),
        extraOverrides: [secondOpinionJobProvider.overrideWith(() => job)],
      );
      expect(find.byKey(const ValueKey('review-second-opinion')), findsNothing);

      job.set(const SecondOpinionState(running: true, done: 3, total: 12));
      await tester.pump();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('review-second-opinion')))
            .height,
        48,
      );
      expect(find.text('Controllo con YouTube Music, 3 di 12'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('review-second-opinion-stop')),
      );
      expect(job.cancelled, 1);

      job.set(const SecondOpinionState(done: 12, total: 12, updated: 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('review-second-opinion')), findsNothing);
      expect(find.text('Aggiornati 5 brani con YouTube Music'), findsOneWidget);
      await h.dispose(tester);
    },
  );
}
