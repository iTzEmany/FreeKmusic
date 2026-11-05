import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/activity_providers.dart';
import 'package:codecore/providers/enrich_completer_providers.dart';
import 'package:codecore/providers/library_providers.dart' show ScanState;
import 'package:codecore/providers/online_providers.dart' show EnrichJobState;
import 'package:codecore/ui/screens/activity/activity_sheet.dart' show activityTitle;
import 'package:codecore/ui/widgets/activity_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  final busy = ActivityState(const [
    ActivityItem(
        kind: ActivityKind.scan, key: 'scan', name: null, done: 1240, total: 3400, progress: 0.36),
    ActivityItem(
        kind: ActivityKind.download, key: 'dl-1', name: 'Una canzone', progress: 0.5, ref: 1),
    ActivityItem(
        kind: ActivityKind.enrich, key: 'enrich', name: null, done: 2, total: 8, progress: 0.25),
  ], const [
    ActivityItem(
        kind: ActivityKind.download, key: 'dl-2', name: 'Finita', running: false),
  ]);

  Future<Harness> pump(WidgetTester tester, ActivityState state) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [...h.overrides, activityProvider.overrideWithValue(state)],
      child: MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Center(child: ActivityButton())),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    return h;
  }

  testWidgets('hidden while idle', (tester) async {
    final h = await pump(tester, const ActivityState([], []));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('TalkBack: the chip reads «N attività in corso», the sheet reads a percentage', (tester) async {
    final handle = tester.ensureSemantics();
    final h = await pump(tester, busy);
    expect(find.bySemanticsLabel('3 attività in corso'), findsOneWidget);
    expect(find.bySemanticsLabel('3'), findsNothing);
    await tester.tap(find.byType(ActivityButton));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    expect(find.semantics.byValue('36 %'), findsOneWidget);
    handle.dispose();
    await h.dispose(tester);
  });

  testWidgets('shows the count and opens the sheet with every activity',
      (tester) async {
    final h = await pump(tester, busy);
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.byType(ActivityButton));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Attività'), findsOneWidget);
    expect(find.text('Scansione: 1240 di 3400'), findsOneWidget);
    expect(find.text('Download, Una canzone'), findsOneWidget);
    expect(find.text('Arricchimento: 2 di 8'), findsOneWidget);
    expect(find.text('Finita'), findsNothing, reason: 'what ended goes to the Registro');
    expect(find.text('Registro'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('a paused CSV import: its name, the songs saved and a resume button',
      (tester) async {
    final h = await pump(
        tester,
        const ActivityState([
          ActivityItem(
              kind: ActivityKind.import,
              key: 'imp-1',
              name: 'Mood',
              done: 3,
              total: 10,
              progress: 0.3,
              paused: true,
              ref: 1),
        ], []));
    await tester.tap(find.byType(ActivityButton));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Mood'), findsOneWidget);
    expect(find.text('3/10'), findsOneWidget);
    expect(find.byTooltip('Riprendi'), findsOneWidget);
    expect(find.byTooltip('Annulla'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the duplicate search is a line with progress and a cancel button',
      (tester) async {
    final h = await pump(
        tester,
        const ActivityState([
          ActivityItem(
              kind: ActivityKind.cleanup,
              key: 'cleanup',
              name: null,
              done: 4,
              total: 12,
              progress: 1 / 3),
        ], []));
    await tester.tap(find.byType(ActivityButton));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ricerca duplicati: 4 di 12'), findsOneWidget);
    expect(find.byTooltip('Annulla'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the background completion: count, Pausa and Riprendi, Annulla',
      (tester) async {
    final fake = _FakeCompleter();
    final h = await Harness.create(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...h.overrides,
        enrichCompleterProvider.overrideWith(() => fake),
        activityProvider.overrideWith(
          (ref) => buildActivity(
            scan: const ScanState(),
            enrich: const EnrichJobState(),
            downloads: const [],
            outgoing: const [],
            enrichBackground: ref.watch(
              enrichCompleterProvider.select(enrichBackgroundOf),
            ),
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Center(child: ActivityButton())),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(ActivityButton));
    await tester.pump(); // the route
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("Completamento dell'arricchimento: 1530 di 2196"),
        findsOneWidget);
    expect(find.byTooltip('Riprendi'), findsNothing);

    await tester.tap(find.byTooltip('Pausa'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(fake.calls, ['pause']);
    expect(find.byTooltip('Riprendi'), findsOneWidget);

    await tester.tap(find.byTooltip('Riprendi'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(fake.calls, ['pause', 'resume']);
    expect(find.byTooltip('Pausa'), findsOneWidget);

    await tester.tap(find.byTooltip('Annulla'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(fake.calls.last, 'cancel');
    await h.dispose(tester);
  });

  test('buildActivity: the completion is a line only while it is given', () {
    ActivityState build(EnrichBackgroundProgress? p) => buildActivity(
        scan: const ScanState(),
        enrich: const EnrichJobState(),
        downloads: const [],
        outgoing: const [],
        enrichBackground: p);
    expect(build(null).running, isEmpty);
    final item = build(const EnrichBackgroundProgress(1530, 2196, paused: true))
        .running
        .single;
    expect([item.kind, item.done, item.total, item.paused],
        [ActivityKind.enrichBackground, 1530, 2196, true]);
    expect(item.cancellable, isTrue);
  });

  test('buildActivity: a waiting completion has no bar; the title says «in attesa»', () {
    final item = buildActivity(
        scan: const ScanState(),
        enrich: const EnrichJobState(),
        downloads: const [],
        outgoing: const [],
        enrichBackground: enrichBackgroundOf(
            const EnrichCompleterState(running: true, waiting: true, complete: 3, total: 10))).running.single;
    expect([item.waiting, item.progress], [true, null]);
    expect(activityTitle(lookupAppLocalizations(const Locale('it')), item), 'Completamento: in attesa');
    final working = ActivityItem(kind: ActivityKind.enrichBackground, key: 'k', name: null, done: 3, total: 10);
    expect(activityTitle(lookupAppLocalizations(const Locale('it')), working), contains('3 di 10'));
  });
}

class _FakeCompleter extends EnrichCompleterNotifier {
  final calls = <String>[];

  @override
  EnrichCompleterState build() =>
      const EnrichCompleterState(running: true, complete: 1530, total: 2196);

  @override
  void pause() {
    calls.add('pause');
    state = state.copyWith(paused: true);
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    state = state.copyWith(paused: false);
  }

  @override
  void cancel() => calls.add('cancel');
}
