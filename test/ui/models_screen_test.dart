import 'dart:async';

import 'package:codecore/core/network_kind.dart';
import 'package:codecore/core/platform.dart' show debugIsDesktopOverride;
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/chinese_dictionary_providers.dart';
import 'package:codecore/providers/model_catalog_providers.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart'
    show networkProbeProvider;
import 'package:codecore/ui/screens/settings/models_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Probe extends NetworkProbe {
  _Probe(this.metered, {this.online = true});
  final bool metered, online;
  @override
  Future<NetworkKind> current() async =>
      NetworkKind(metered: metered, online: online);
}

class _Fake extends ModelCatalogNotifier {
  _Fake(this.entries, {this.failDelete = false, this.failDownload = false});

  List<ModelEntry> entries;
  final bool failDelete, failDownload;
  final downloaded = <String>[], deleted = <String>[];
  Completer<void>? hold;
  Object? loadError;

  @override
  Future<List<ModelEntry>> build() async {
    if (loadError != null) throw loadError!;
    ref.keepAlive(); // as the real one while it works
    return entries;
  }

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

class _Dict extends ChineseDictionaryNotifier {
  _Dict(this.initial);
  final ChineseDictionaryState initial;
  @override
  ChineseDictionaryState build() => initial;
}

ModelEntry _e(ModelKind k, String id, String name, {bool installed = false}) =>
    ModelEntry(
      kind: k,
      id: id,
      name: name,
      estimatedBytes: 10 * kMb,
      installed: installed,
    );

void main() {
  Future<_Fake> pump(
    WidgetTester tester,
    List<ModelEntry> entries, {
    bool metered = false,
    bool online = true,
    bool failDelete = false,
    bool failDownload = false,
    ChineseDictionaryState? dict,
    bool pushed = false,
  }) async {
    final fake = _Fake(
      entries,
      failDelete: failDelete,
      failDownload: failDownload,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modelCatalogProvider.overrideWith(() => fake),
          networkProbeProvider.overrideWithValue(
            _Probe(metered, online: online),
          ),
          if (dict != null)
            chineseDictionaryProvider.overrideWith(() => _Dict(dict)),
        ],
        child: MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: pushed
              ? Builder(
                  builder: (c) => TextButton(
                    onPressed: () => Navigator.of(c).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ModelsScreen(),
                      ),
                    ),
                    child: const Text('apri'),
                  ),
                )
              : const ModelsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (pushed) {
      await tester.tap(find.text('apri'));
      await tester.pumpAndSettle();
    }
    return fake;
  }

  final all = [
    _e(ModelKind.translation, 'fr', 'Francese'),
    _e(ModelKind.translation, 'de', 'Tedesco'),
    _e(ModelKind.dictionary, 'cedict', 'CC-CEDICT', installed: true),
    _e(ModelKind.karaoke, 'spleeter', 'Spleeter'),
  ];

  Future<void> confirm(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text(label)),
    );
    // Not settle: a running download keeps its spinner turning.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'two selected entries: «Scarica selezionati» downloads both, one after the other',
    (tester) async {
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
    },
  );

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

  testWidgets('«Elimina» on an entry asks, then updates the total', (
    tester,
  ) async {
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
    await tester.pump(
      const Duration(milliseconds: 600),
    ); // not settle: the snackbar ring animates
    expect(find.text('Download non riuscito: Spleeter'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .clearSnackBars();
    await tester.pump();
    await tester.tap(find.byTooltip('Elimina CC-CEDICT'));
    await tester.pumpAndSettle();
    await confirm(tester, 'Elimina');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Impossibile eliminare: CC-CEDICT'), findsOneWidget);
  });

  testWidgets(
    'without translation entries (not Android) there is no translation section',
    (tester) async {
      await pump(tester, all.skip(2).toList());
      expect(find.text('Modelli di traduzione'), findsNothing);
      expect(find.text('Dizionario cinese'), findsOneWidget);
    },
  );

  testWidgets(
    'a running download shows a labelled progress and blocks the buttons',
    (tester) async {
      final f = await pump(tester, all);
      f.hold = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('model-karaoke:spleeter')));
      await tester.pump();
      await tester.tap(find.text('Scarica selezionati (1)'));
      await tester.pumpAndSettle();
      await confirm(tester, 'Scarica');
      await tester.pump();
      final p = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(p.semanticsLabel, 'In scaricamento…');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('models-download')))
            .onPressed,
        isNull,
      );
      f.hold!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('tap targets are 48 dp and labelled', (tester) async {
    debugIsDesktopOverride =
        false; // phone targets, not the desktop's dense ones
    addTearDown(() => debugIsDesktopOverride = null);
    final sem = tester.ensureSemantics();
    await pump(tester, all);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    sem.dispose();
  });

  testWidgets(
    '«Elimina selezionati» and a mixed selection with its two counters',
    (tester) async {
      final f = await pump(tester, all);
      await tester.tap(find.byKey(const ValueKey('model-dictionary:cedict')));
      await tester.tap(find.byKey(const ValueKey('model-translation:fr')));
      await tester.pump();
      expect(find.text('Scarica selezionati (1)'), findsOneWidget);
      expect(find.text('Elimina selezionati (1)'), findsOneWidget);
      await tester.tap(find.text('Elimina selezionati (1)'));
      await tester.pumpAndSettle();
      await confirm(tester, 'Elimina');
      expect(f.deleted, ['cedict']);
      // The one deleted leaves the selection, the other stays picked.
      expect(find.text('Scarica selezionati (1)'), findsOneWidget);
      expect(find.text('Elimina selezionati (0)'), findsOneWidget);
    },
  );

  testWidgets('a failed delete keeps the entry selected', (tester) async {
    await pump(tester, all, failDelete: true);
    await tester.tap(find.byKey(const ValueKey('model-dictionary:cedict')));
    await tester.pump();
    await tester.tap(find.text('Elimina selezionati (1)'));
    await tester.pumpAndSettle();
    await confirm(tester, 'Elimina');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Elimina selezionati (1)'), findsOneWidget);
  });

  testWidgets(
    'only the running entry says «In scaricamento», the others «In coda»',
    (tester) async {
      final f = await pump(tester, all);
      f.hold = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('model-translation:fr')));
      await tester.tap(find.byKey(const ValueKey('model-karaoke:spleeter')));
      await tester.pump();
      await tester.tap(find.text('Scarica selezionati (2)'));
      await tester.pumpAndSettle();
      await confirm(tester, 'Scarica');
      expect(find.text('In scaricamento…'), findsOneWidget);
      expect(find.text('In coda'), findsOneWidget);
      f.hold!.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'leaving the page during a download: the queue goes on and the rest is downloaded',
    (tester) async {
      final f = await pump(tester, all, pushed: true);
      f.hold = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('model-translation:fr')));
      await tester.tap(find.byKey(const ValueKey('model-karaoke:spleeter')));
      await tester.pump();
      await tester.tap(find.text('Scarica selezionati (2)'));
      await tester.pumpAndSettle();
      await confirm(tester, 'Scarica');
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      f.hold!.complete();
      await tester.pumpAndSettle();
      expect(f.downloaded, ['fr', 'spleeter']);
      expect(find.textContaining('non riuscito'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reopening the page during a download: the row is still «In scaricamento»',
    (tester) async {
      final f = await pump(tester, all, pushed: true);
      f.hold = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('model-translation:fr')));
      await tester.pump();
      await tester.tap(find.text('Scarica selezionati (1)'));
      await tester.pumpAndSettle();
      await confirm(tester, 'Scarica');
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('apri'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('In scaricamento…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('models-download')))
            .onPressed,
        isNull,
      );
      f.hold!.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('offline: «Serve la connessione», nothing starts', (
    tester,
  ) async {
    final f = await pump(tester, all, online: false);
    await tester.tap(find.byKey(const ValueKey('model-translation:fr')));
    await tester.pump();
    await tester.tap(find.text('Scarica selezionati (1)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.text('Serve la connessione per scaricare i modelli.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(f.downloaded, isEmpty);
  });

  testWidgets('«Annulla» drops the downloads not started yet', (tester) async {
    final f = await pump(tester, all);
    f.hold = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('model-translation:fr')));
    await tester.tap(find.byKey(const ValueKey('model-karaoke:spleeter')));
    await tester.pump();
    await tester.tap(find.text('Scarica selezionati (2)'));
    await tester.pumpAndSettle();
    await confirm(tester, 'Scarica');
    await tester.tap(find.byKey(const ValueKey('models-cancel')));
    await tester.pump();
    expect(find.text('In coda'), findsNothing);
    f.hold!.complete();
    await tester.pumpAndSettle();
    expect(f.downloaded, ['fr']);
  });

  testWidgets('a catalog that fails to load says so and «Riprova» reloads it', (
    tester,
  ) async {
    final fake = _Fake(all)..loadError = StateError('boom');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [modelCatalogProvider.overrideWith(() => fake)],
        child: MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ModelsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Impossibile leggere i modelli.'), findsOneWidget);
    fake.loadError = null;
    await tester.tap(find.text('Riprova'));
    await tester.pumpAndSettle();
    expect(find.text('Impossibile leggere i modelli.'), findsNothing);
    expect(find.text('CC-CEDICT'), findsOneWidget);
  });

  testWidgets('the trash is a button of its own, apart from the checkbox', (
    tester,
  ) async {
    final sem = tester.ensureSemantics();
    await pump(tester, all);
    final node = tester.getSemantics(find.byType(IconButton));
    expect('${node.label}|${node.tooltip}', contains('Elimina CC-CEDICT'));
    expect(node.label, isNot(contains('CC-CEDICT, ')));
    expect(node.flagsCollection.isButton, isTrue);
    sem.dispose();
  });

  testWidgets(
    'the trash is off while something runs, also a download started elsewhere',
    (tester) async {
      await pump(
        tester,
        all,
        dict: const ChineseDictionaryState(
          ChineseDictionaryStatus.downloading,
          progress: 0.3,
        ),
      );
      expect(find.text('In scaricamento…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('models-download')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('models-delete')))
            .onPressed,
        isNull,
      );
      final row = find.ancestor(
        of: find.text('CC-CEDICT'),
        matching: find.byType(ListTile),
      );
      expect(
        tester
            .widget<Checkbox>(
              find.descendant(of: row, matching: find.byType(Checkbox)),
            )
            .onChanged,
        isNull,
      );
    },
  );

  testWidgets('a dictionary in error says it in its row', (tester) async {
    final notInstalled = [...all]
      ..[2] = _e(ModelKind.dictionary, 'cedict', 'CC-CEDICT');
    await pump(
      tester,
      notInstalled,
      dict: const ChineseDictionaryState(ChineseDictionaryStatus.error),
    );
    expect(find.text('Download non riuscito: CC-CEDICT'), findsOneWidget);
  });
}
