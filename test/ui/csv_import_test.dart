import 'dart:io';

import 'package:codecore/core/constants.dart';
import 'package:codecore/data/db/app_database.dart' show PlaylistImportItem;
import 'package:codecore/services/import/csv_profiles.dart';
import 'package:codecore/services/import/imported_playlist.dart';
import 'package:codecore/services/import/import_diff.dart' show ImportDiff;
import 'package:codecore/ui/screens/import/import_intro_sheet.dart';
import 'package:codecore/ui/screens/import/import_preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

ImportedPlaylist fixture() => readCsvPlaylist('Just_a_mood.csv',
    File('test/fixtures/Just_a_mood.csv').readAsStringSync());

/// These screens are about downloading; without YouTube they are not there.
const _noYoutube = !kEnableYoutube;

void main() {
  testWidgets('intro sheet says where the CSV comes from and copies the address',
      (tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final h = await Harness.create(tester);
    await h.pump(tester, const Scaffold(body: ImportIntroSheet()));

    expect(find.text('Importa una playlist'), findsOneWidget);
    expect(find.textContaining('Exportify — exportify.net'), findsOneWidget);
    expect(find.textContaining('https://exportify.net nel browser'),
        findsOneWidget);
    expect(find.text('Scegli file'), findsOneWidget);

    await tester.tap(find.text('Copia indirizzo'));
    await tester.pump();
    expect(copied, 'https://exportify.net');
    expect(find.text('Indirizzo copiato'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('preview counts what is already in the library', (tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await h.pump(
        tester,
        Scaffold(
            body: ImportPreviewDialog(csv: fixture(), known: 1, existing: const {})));

    expect(find.text('Importa playlist'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Just a mood'), findsOneWidget);
    expect(find.text('34 brani, 1 già in libreria, 33 da scaricare'),
        findsOneWidget);
    expect(find.textContaining('Tempo stimato'), findsOneWidget);
    expect(find.text('Esiste già una playlist con questo nome'), findsNothing);
    await h.dispose(tester);
  }, skip: _noYoutube);

  testWidgets('streaming: folder and numbering options appear only with «Scarica anche i file»; device mode always shows them', (tester) async {
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    for (final streaming in [true, false]) {
      await h.pump(
          tester,
          Scaffold(
              body: SingleChildScrollView(
                  child: ImportPreviewDialog(csv: fixture(), known: 1, existing: const {}, streaming: streaming))));
      expect(find.text('Scarica anche i file'), streaming ? findsOneWidget : findsNothing);
      expect(find.text('Numera i file'), streaming ? findsNothing : findsOneWidget);
      if (streaming) {
        await tester.tap(find.text('Scarica anche i file'));
        await tester.pump();
        expect(find.text('Numera i file'), findsOneWidget);
        expect(find.text('Cartella per questa playlist'), findsOneWidget);
      }
    }
    await h.dispose(tester);
  }, skip: _noYoutube);

  testWidgets('same-name playlist offers update or new and returns the choice',
      (tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    ImportChoice? picked;
    await h.pump(
        tester,
        Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async => picked = await showDialog<ImportChoice>(
                        context: context,
                        builder: (_) => ImportPreviewDialog(
                            csv: fixture(),
                            known: 0,
                            existing: const {7: 'just a mood'})),
                    child: const Text('open')))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Esiste già una playlist con questo nome'),
        findsOneWidget);
    expect(find.textContaining('Aggiorna quella esistente'), findsOneWidget);
    expect(find.text('Crea una nuova playlist'), findsOneWidget);
    await tester.tap(find.text('Importa'));
    await tester.pumpAndSettle();
    expect(picked!.intoPlaylistId, 7);
    expect(picked!.name, 'Just a mood');

    // Renaming away from the existing one hides the question.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Other name');
    await tester.pump();
    expect(find.text('Esiste già una playlist con questo nome'), findsNothing);
    await tester.tap(find.text('Importa'));
    await tester.pumpAndSettle();
    expect(picked!.intoPlaylistId, isNull);
    await h.dispose(tester);
  });

  testWidgets('preview offers «solo collega» and «rivedi prima» and returns them',
      (tester) async {
    tester.view.physicalSize = const Size(600, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    ImportChoice? picked;
    await h.pump(
        tester,
        Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async => picked = await showDialog<ImportChoice>(
                        context: context,
                        builder: (_) => ImportPreviewDialog(
                            csv: fixture(), known: 0, existing: const {})),
                    child: const Text('open')))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Solo collega (nessun download)'), findsOneWidget);
    expect(find.text('Rivedi prima di scaricare'), findsOneWidget);
    await tester.tap(find.text('Rivedi prima di scaricare'));
    await tester.pump();
    await tester.tap(find.text('Importa'));
    await tester.pumpAndSettle();
    expect(picked!.options.planFirst, isTrue);
    expect(picked!.options.linkOnly, isFalse);

    // «Solo collega» wins and hides the other switch.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Solo collega (nessun download)'));
    await tester.pump();
    expect(find.text('Rivedi prima di scaricare'), findsNothing);
    await tester.tap(find.text('Importa'));
    await tester.pumpAndSettle();
    expect(picked!.options.linkOnly, isTrue);
    expect(picked!.options.planFirst, isFalse);
    await h.dispose(tester);
  }, skip: _noYoutube);

  testWidgets('a big file suggests blocks of 100 and shows the time in hours',
      (tester) async {
    tester.view.physicalSize = const Size(600, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    final big = ImportedPlaylist(name: 'Big', rows: [
      for (var i = 0; i < 400; i++)
        ImportRow(index: i, title: 'S$i', artists: const ['A']),
    ]);
    ImportChoice? picked;
    await h.pump(
        tester,
        Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async => picked = await showDialog<ImportChoice>(
                        context: context,
                        builder: (_) => ImportPreviewDialog(
                            csv: big, known: 0, existing: const {})),
                    child: const Text('open')))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('400 brani da scaricare'), findsOneWidget);
    expect(find.text('Importa a blocchi da 100'), findsOneWidget);
    expect(find.text('Tempo stimato: circa 1 h 20 min'), findsOneWidget);
    await tester.tap(find.text('Importa'));
    await tester.pumpAndSettle();
    expect(picked!.blockSize, 100, reason: 'on by default above 200');

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importa a blocchi da 100'));
    await tester.pump();
    await tester.tap(find.text('Importa'));
    await tester.pumpAndSettle();
    expect(picked!.blockSize, isNull);
    await h.dispose(tester);
  }, skip: _noYoutube);

  testWidgets('same-name playlist can be synced, with the counts of the changes',
      (tester) async {
    tester.view.physicalSize = const Size(600, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    final calls = <int>[];
    ImportChoice? picked;
    await h.pump(
        tester,
        Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async => picked = await showDialog<ImportChoice>(
                        context: context,
                        builder: (_) => ImportPreviewDialog(
                              csv: fixture(),
                              known: 0,
                              existing: const {7: 'just a mood'},
                              syncPreview: (id) async {
                                calls.add(id);
                                return ImportDiff(
                                  added: [
                                    for (var i = 0; i < 3; i++)
                                      ImportRow(index: i, title: 'n$i', artists: const ['A']),
                                  ],
                                  removed: [
                                    PlaylistImportItem(
                                        importId: 1,
                                        rowIndex: 0,
                                        title: 'gone',
                                        artists: 'A',
                                        status: 2),
                                  ],
                                );
                              },
                            )),
                    child: const Text('open')))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Sincronizza'), findsOneWidget);
    expect(calls, isEmpty, reason: 'counted only once Sincronizza is chosen');
    await tester.tap(find.text('Sincronizza'));
    await tester.pumpAndSettle();
    expect(find.text('3 nuovi, 1 rimossi dalla playlist (i file restano)'),
        findsOneWidget);
    expect(calls, [7], reason: 'asked once for that playlist');
    await tester.tap(find.text('Importa'));
    await tester.pumpAndSettle();
    expect(picked!.sync, isTrue);
    expect(picked!.intoPlaylistId, 7);
    await h.dispose(tester);
  });
}
