import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/romanization_ops.dart';
import 'package:codecore/providers/translation_providers.dart';
import 'package:codecore/services/lyrics/romanization_resolver.dart';
import 'package:codecore/ui/screens/lyrics/lyrics_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

const _jaSynced = '[00:01.00]夜の街\n[00:05.00]君の声';

class _FakeTranslation extends LyricsTranslationNotifier {
  @override
  LyricsTranslation? build() => const LyricsTranslation(
    trackId: 1,
    synced: true,
    lines: ['Night town', 'Your voice'],
  );
}

class _FakeOps extends RomanizationOps {
  _FakeOps(super.ref, this.saved, this.log);

  final List<(int, String)> saved;
  final List<String> log;

  @override
  Future<Future<void> Function()?> delete(int id) async {
    log.add('delete $id');
    return () async => log.add('undo $id');
  }

  @override
  Future<Future<void> Function()?> save(int id, String raw) async {
    saved.add((id, raw));
    return () async {};
  }
}

void main() {
  Future<Harness> open(
    WidgetTester tester, {
    String? plain,
    String? synced,
    RomanizationState state = RomanizationState.off,
    List<(int, String)>? saved,
    bool translated = false,
    Map<int, String> manual = const {},
    List<String>? log,
  }) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 1);
    await tester.runAsync(() async {
      await h.db
          .update(h.db.tracks)
          .write(
            TracksCompanion(
              lyricsPlain: Value(plain),
              lyricsSynced: Value(synced),
            ),
          );
      await h.handler.playQueue([
        (await h.db.select(h.db.tracks).get()).single.id,
      ], 0);
    });
    await tester.runAsync(() => h.store.writeManualRomanizations(manual));
    h.romanization = state;
    await h.pump(
      tester,
      const LyricsScreen(),
      extraOverrides: [
        if (translated)
          lyricsTranslationProvider.overrideWith(_FakeTranslation.new),
        romanizationOpsProvider.overrideWith(
          (ref) => _FakeOps(ref, saved ?? [], log ?? []),
        ),
      ],
    );
    await tester.pump(const Duration(milliseconds: 200));
    return h;
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Altre azioni'));
    await tester.pumpAndSettle();
  }

  const ready = RomanizationState.ready([
    'yoru no machi',
    'kimi no koe',
  ], RomanizationSource.found);

  testWidgets(
    'synced rows show the transliteration above the translation slot',
    (tester) async {
      final h = await open(tester, synced: _jaSynced, state: ready);
      expect(find.text('夜の街'), findsOneWidget);
      expect(find.text('yoru no machi'), findsOneWidget);
      expect(find.text('kimi no koe'), findsOneWidget);
      // Original, then transliteration, top to bottom.
      expect(
        tester.getTopLeft(find.text('yoru no machi')).dy,
        greaterThan(tester.getTopLeft(find.text('夜の街')).dy),
      );
      await h.dispose(tester);
    },
  );

  testWidgets('transliteration sits between the original and the translation', (
    tester,
  ) async {
    final h = await open(
      tester,
      synced: _jaSynced,
      state: ready,
      translated: true,
    );
    final y = [
      for (final t in ['夜の街', 'yoru no machi', 'Night town'])
        tester.getTopLeft(find.text(t)).dy,
    ];
    expect(y[0], lessThan(y[1]));
    expect(y[1], lessThan(y[2]));
    await h.dispose(tester);
  });

  testWidgets('with the switch off the rows are as before', (tester) async {
    final h = await open(tester, synced: _jaSynced);
    expect(find.text('夜の街'), findsOneWidget);
    expect(find.byKey(const ValueKey('romanized-0')), findsNothing);
    expect(
      find.text('Traslitterazione non disponibile per questo testo'),
      findsNothing,
    );
    await h.dispose(tester);
  });

  testWidgets('plain text becomes line and transliteration pairs', (
    tester,
  ) async {
    final h = await open(
      tester,
      plain: '夜の街\n\n君の声',
      state: const RomanizationState.ready([
        'yoru no machi',
        null,
        'kimi no koe',
      ], RomanizationSource.computed),
    );
    expect(find.text('夜の街'), findsOneWidget);
    expect(find.text('yoru no machi'), findsOneWidget);
    expect(find.text('kimi no koe'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('plain text with the switch off is the single selectable text', (
    tester,
  ) async {
    final h = await open(tester, plain: '夜の街\n君の声');
    expect(find.byType(SelectableText), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('unavailable and downloading show their notice', (tester) async {
    var h = await open(
      tester,
      synced: _jaSynced,
      state: RomanizationState.unavailable,
    );
    expect(
      find.text('Traslitterazione non disponibile per questo testo'),
      findsOneWidget,
    );
    await h.dispose(tester);
    h = await open(tester, plain: '你好', state: RomanizationState.downloading);
    expect(find.text('Scarico il dizionario cinese…'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the switch is in the menu only for CJK text', (tester) async {
    var h = await open(tester, plain: 'Hello darkness');
    await openMenu(tester);
    expect(find.text('Traslitterazione'), findsNothing);
    expect(find.text('Modifica traslitterazione'), findsNothing);
    await h.dispose(tester);
    h = await open(tester, synced: _jaSynced, state: ready);
    await openMenu(tester);
    expect(find.text('Traslitterazione'), findsOneWidget);
    expect(find.text('Modifica traslitterazione'), findsOneWidget);
    // Nothing typed by hand yet: no delete entry.
    expect(find.text('Elimina traslitterazione'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('editing the transliteration saves through the ops', (
    tester,
  ) async {
    final saved = <(int, String)>[];
    final h = await open(tester, synced: _jaSynced, state: ready, saved: saved);
    await openMenu(tester);
    await tester.tap(find.text('Modifica traslitterazione'));
    await tester.pumpAndSettle();
    // Starts from what is shown now.
    expect(find.text('yoru no machi\nkimi no koe'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'a\nb');
    await tester.tap(find.byKey(const ValueKey('romanization-save')));
    await tester.pumpAndSettle();
    expect(saved, [(1, 'a\nb')]);
    await h.dispose(tester);
  });

  testWidgets('deleting a typed transliteration can be undone', (tester) async {
    final log = <String>[];
    final h = await open(
      tester,
      synced: _jaSynced,
      state: ready,
      manual: {1: 'a\nb'},
      log: log,
    );
    await openMenu(tester);
    await tester.tap(find.text('Elimina traslitterazione'));
    await tester.pumpAndSettle();
    expect(find.text('Traslitterazione eliminata'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(log, ['delete 1', 'undo 1']);
    await h.dispose(tester);
  });

  testWidgets('the menu switch writes the setting', (tester) async {
    final h = await open(tester, synced: _jaSynced, state: ready);
    expect(h.store.readSettings().romanization, isTrue);
    await openMenu(tester);
    await tester.tap(find.text('Traslitterazione'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(h.store.readSettings().romanization, isFalse);
    await h.dispose(tester);
  });

  testWidgets('the editor starts with one line per shown line', (tester) async {
    final h = await open(
      tester,
      synced: '[00:01.00]夜\n[00:03.00]♪\n[00:05.00]君',
      state: const RomanizationState.ready([
        'yoru',
        null,
        'kimi',
      ], RomanizationSource.found),
    );
    await openMenu(tester);
    await tester.tap(find.text('Modifica traslitterazione'));
    await tester.pumpAndSettle();
    expect(find.text('yoru\n\nkimi'), findsOneWidget);
    await h.dispose(tester);
  });
}
