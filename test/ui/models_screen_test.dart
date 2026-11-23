import 'dart:async';

import 'package:codecore/core/network_kind.dart';
import 'package:codecore/core/platform.dart' show debugIsDesktopOverride;
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/model_catalog_providers.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart' show networkProbeProvider;
import 'package:codecore/ui/screens/settings/models_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Probe extends NetworkProbe {
  _Probe(this.metered);
  final bool metered;
  @override
  Future<NetworkKind> current() async => NetworkKind(metered: metered);
}

class _Fake extends ModelCatalogNotifier {
  _Fake(this.entries, {this.failDelete = false, this.failDownload = false});

  List<ModelEntry> entries;
  final bool failDelete, failDownload;
  final downloaded = <String>[], deleted = <String>[];
  Completer<void>? hold;

  @override
  Future<List<ModelEntry>> build() async => entries;

  void _set(ModelEntry e, bool installed) {
    entries = [
      for (final x in entries)
        if (x.id == e.id)
          ModelEntry(
            kind: x.kind,
            id: x.id,
            name: x.name,
            estimatedBytes: x.estimatedBytes,
            installed: installed,
          )
        else
          x,
    ];
    state = AsyncData(entries);
  }

  @override
  Future<void> download(ModelEntry e) async {
    downloaded.add(e.id);
    await hold?.future;
    if (failDownload) throw StateError('boom');
    _set(e, true);
  }

  @override
  Future<void> delete(ModelEntry e) async {
    deleted.add(e.id);
    if (failDelete) throw StateError('boom');
    _set(e, false);
  }
}

ModelEntry _e(ModelKind k, String id, String name, {bool installed = false}) =>
    ModelEntry(kind: k, id: id, name: name, estimatedBytes: 10 * kMb, installed: installed);

void main() {
  Future<_Fake> pump(
    WidgetTester tester,
    List<ModelEntry> entries, {
    bool metered = false,
    bool failDelete = false,
    bool failDownload = false,
  }) async {
    final fake = _Fake(entries, failDelete: failDelete, failDownload: failDownload);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modelCatalogProvider.overrideWith(() => fake),
          networkProbeProvider.overrideWithValue(_Probe(metered)),
        ],
        child: MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ModelsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  final all = [
    _e(ModelKind.translation, 'fr', 'Francese'),
    _e(ModelKind.translation, 'de', 'Tedesco'),
    _e(ModelKind.dictionary, 'cedict', 'CC-CEDICT', installed: true),
    _e(ModelKind.karaoke, 'spleeter', 'Spleeter'),
  ];

  Future<void> confirm(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(label)));
    // Not settle: a running download keeps its spinner turning.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('two selected entries: «Scarica selezionati» downloads both, one after the other', (tester) async {
    final f = await pump(tester, all);
    expect(find.text('Spazio occupato: 10,0 MB'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('model-translation:fr')));
    await tester.tap(find.byKey(const ValueKey('model-karaoke:spleeter')));
    await tester.pump();
    await tester.tap(find.text('Scarica selezionati (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Si scaricano circa 20,0 MB.'), findsOneWidget);
    await confirm(tester, 'Scarica');
    expect(f.downloaded, ['fr', 'spleeter']);
    expect(find.text('Spazio occupato: 30,0 MB'), findsOneWidget);
  });

  testWidgets('a metered network says so in the confirmation', (tester) async {
    await pump(tester, all, metered: true);
    await tester.tap(find.byKey(const ValueKey('model-translation:de')));
    await tester.pump();
    await tester.tap(find.text('Scarica selezionati (1)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('rete a consumo'), findsOneWidget);
  });

  testWidgets('cancelling the confirmation downloads nothing', (tester) async {
    final f = await pump(tester, all);
    await tester.tap(find.byKey(const ValueKey('model-translation:de')));
    await tester.pump();
    await tester.tap(find.text('Scarica selezionati (1)'));
    await tester.pumpAndSettle();
    await confirm(tester, 'Annulla');
    expect(f.downloaded, isEmpty);
  });

  testWidgets('«Elimina» on an entry asks, then updates the total', (tester) async {
    final f = await pump(tester, all);
    await tester.tap(find.byTooltip('Elimina CC-CEDICT'));
    await tester.pumpAndSettle();
    await confirm(tester, 'Annulla');
    expect(f.deleted, isEmpty);
    await tester.tap(find.byTooltip('Elimina CC-CEDICT'));
    await tester.pumpAndSettle();
    await confirm(tester, 'Elimina');
    expect(f.deleted, ['cedict']);
    expect(find.text('Spazio occupato: 0 B'), findsOneWidget);
  });

  testWidgets('a failed download and a failed delete say so', (tester) async {
    await pump(tester, all, failDownload: true, failDelete: true);
    await tester.tap(find.byKey(const ValueKey('model-karaoke:spleeter')));
    await tester.pump();
    await tester.tap(find.text('Scarica selezionati (1)'));
    await tester.pumpAndSettle();
    await confirm(tester, 'Scarica');
    await tester.pump(const Duration(milliseconds: 600)); // not settle: the snackbar ring animates
    expect(find.text('Download non riuscito: Spleeter'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
    await tester.pump();
    await tester.tap(find.byTooltip('Elimina CC-CEDICT'));
    await tester.pumpAndSettle();
    await confirm(tester, 'Elimina');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Impossibile eliminare: CC-CEDICT'), findsOneWidget);
  });

  testWidgets('without translation entries (not Android) there is no translation section', (tester) async {
    await pump(tester, all.skip(2).toList());
    expect(find.text('Modelli di traduzione'), findsNothing);
    expect(find.text('Dizionario cinese'), findsOneWidget);
  });

  testWidgets('a running download shows a labelled progress and blocks the buttons', (tester) async {
    final f = await pump(tester, all);
    f.hold = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('model-karaoke:spleeter')));
    await tester.pump();
    await tester.tap(find.text('Scarica selezionati (1)'));
    await tester.pumpAndSettle();
    await confirm(tester, 'Scarica');
    await tester.pump();
    final p = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
    expect(p.semanticsLabel, 'In scaricamento…');
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('models-download'))).onPressed, isNull);
    f.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('tap targets are 48 dp and labelled', (tester) async {
    debugIsDesktopOverride = false; // phone targets, not the desktop's dense ones
    addTearDown(() => debugIsDesktopOverride = null);
    final sem = tester.ensureSemantics();
    await pump(tester, all);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    sem.dispose();
  });
}
