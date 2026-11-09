import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/memory_providers.dart';
import 'package:codecore/services/memory/disk_space.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:codecore/ui/screens/memory/memory_ring.dart';
import 'package:codecore/ui/screens/memory/memory_screen.dart';
import 'package:codecore/ui/widgets/format_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/memory_fakes.dart';

void main() {
  late Harness h;
  late FakeMemoryActions actions;

  /// 38.4 GB of music: one big FLAC and six 10 MB mp3 (7 heavy tracks), a
  /// playlist holding the FLAC.
  Future<void> open(
    WidgetTester tester, {
    DiskSpace? disk,
    Size size = const Size(400, 5000),
    double textScale = 1,
    String playlistName = 'Gym',
    Future<void> Function(AppDatabase db)? extraSeed,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester);
    actions = FakeMemoryActions();
    await tester.runAsync(() => () async {
      await seedMemory(h.db, playlistName: playlistName);
      await extraSeed?.call(h.db);
    }());
    await h.pump(
      tester,
      const MemoryScreen(),
      textScale: textScale,
      extraOverrides: memoryOverrides(actions, disk),
    );
    // The providers read the in-memory database for real.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('formatBytes writes the decimal comma by locale', (tester) async {
    expect(formatBytes(1610612736, 'it'), '1,5 GB');
    expect(formatBytes(1610612736, 'en'), '1.5 GB');
    expect(formatBytes(128 * gb, 'it'), '128 GB');
    expect(formatBytes(1048575, 'it'), '1,0 MB');
  });

  testWidgets('the ring shows the music, the free space and the legend', (tester) async {
    await open(tester, disk: memoryDisk);
    final ring = find.byType(MemoryRing);
    expect(find.descendant(of: ring, matching: find.text('38,4 GB')), findsOneWidget);
    expect(find.text('11,2 GB liberi su 128 GB'), findsOneWidget);
    expect(find.text('Libero'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('without the disk size: the unavailable note and no legend', (tester) async {
    await open(tester);
    expect(find.descendant(of: find.byType(MemoryRing), matching: find.text('38,4 GB')), findsOneWidget);
    expect(find.text('Non disponibile'), findsOneWidget);
    expect(find.text('Libero'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('the Formati block swaps the list below', (tester) async {
    await open(tester, disk: memoryDisk);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('FLAC'), findsNothing);
    await tester.tap(find.text('Formati'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('FLAC'), findsOneWidget);
    expect(find.text('Gym'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('a folder row reads name, path, count and size, and fits at double text', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(
      tester,
      disk: memoryDisk,
      textScale: 2,
      extraSeed: (db) async {
        final f = await db.into(db.folders).insert(FoldersCompanion.insert(path: '/m/Rock', addedAt: 1));
        await (db.update(db.tracks)..where((t) => t.title.equals('Heavy 0')))
            .write(TracksCompanion(folderId: Value(f)));
      },
    );
    await tester.tap(find.text('Cartelle'));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.takeException(), isNull);
    final row = find.bySemanticsLabel(RegExp('Apri la cartella'));
    expect(row, findsOneWidget);
    final label = tester.getSemantics(row).label;
    expect(label, contains('/m/Rock'));
    expect(label, contains('1 brano'));
    expect(label, contains('10,0 MB'));
    semantics.dispose();
    await h.dispose(tester);
  });

  testWidgets('small app data is not listed, there is a note and never 0 B', (tester) async {
    await open(tester, disk: memoryDisk);
    expect(find.text('Copertine'), findsOneWidget);
    expect(find.text('Cache'), findsOneWidget);
    expect(find.text('Libreria'), findsOneWidget);
    expect(find.text('Backup dei tag'), findsNothing);
    expect(find.text('Registro'), findsNothing);
    expect(find.text('I dati sotto 1 MB non sono elencati.'), findsOneWidget);
    final zero = find.byWidgetPredicate((w) => w is Text && (w.data ?? '').endsWith(' 0 B'));
    expect(zero, findsNothing);
    await h.dispose(tester);
  });

  testWidgets('Svuota cache clears at once, without a dialog', (tester) async {
    await open(tester, disk: memoryDisk);
    expect(find.text('Libera 20,0 MB. Brani, copertine e ascolti restano.'), findsOneWidget);
    await tester.tap(find.text('Svuota cache'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(actions.calls, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Liberati 5,0 MB'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('Mostra tutti expands the five heaviest tracks in place', (tester) async {
    await open(tester, disk: memoryDisk);
    final rows = find.textContaining(RegExp(r'^(Heavy \d|Big Flac)$'));
    expect(rows, findsNWidgets(5));
    await tester.tap(find.text('Mostra tutti'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(rows, findsNWidgets(7));
    expect(find.text('Mostra tutti'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('wide window: ring column on the left, no exceptions', (tester) async {
    await open(tester, disk: memoryDisk, size: const Size(1200, 1400));
    expect(find.byType(MemoryRing), findsOneWidget);
    expect(find.text('Strumenti'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('the Arricchimento row shows the size and detail, with no button', (tester) async {
    await open(tester, disk: memoryDisk);
    expect(find.textContaining('Arricchimento'), findsNothing);
    await tester.runAsync(() async {
      await (h.db.update(h.db.tracks)).write(
        TracksCompanion(
          lyricsPlain: Value('a' * (2 * 1024 * 1024)),
          curiosities: const Value('b'),
        ),
      );
    });
    // The page reads it again when the tab is reopened or pulled.
    final ctx = tester.element(find.byType(MemoryScreen));
    ProviderScope.containerOf(ctx).invalidate(enrichmentBytesProvider);
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('Arricchimento: '), findsOneWidget);
    expect(find.textContaining('Testi '), findsOneWidget);
    expect(find.textContaining('curiosità'), findsOneWidget);
    expect(find.textContaining('crediti'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Arricchimento'), findsNothing);
    await h.dispose(tester);
  });
}
