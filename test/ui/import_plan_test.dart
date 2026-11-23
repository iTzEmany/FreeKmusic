import 'package:codecore/core/import_row.dart';
import 'package:codecore/data/repositories/import_repository.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/ui/screens/import/import_plan_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

const _candidates =
    '[{"id":"a","title":"Song 0","channel":"Band - Topic","durationSec":200,"score":0.95},'
    '{"id":"b","title":"Song 0 (Live)","channel":"Band","durationSec":260,"score":0.6}]';

void main() {
  testWidgets('plan screen lists the chosen video, switches it and starts',
      (tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    late int iid;
    await tester.runAsync(() async {
      final pid = await PlaylistRepository(h.db).create('Mood');
      final imports = ImportRepository(h.db);
      iid = await imports.create(playlistId: pid, sourceName: 'Mood', rows: [
        const ImportRow(
            index: 0, title: 'Song 0', artists: ['Band'], durationMs: 200000),
      ]);
      await imports.setItem(iid, 0,
          status: ImportItemStatus.planned,
          videoId: const Value('a'),
          candidates: const Value(_candidates),
          score: const Value(0.95));
      await imports.setStatus(iid, ImportStatus.paused);
    });
    await h.pump(tester, ImportPlanScreen(importId: iid), extraOverrides: [
      downloadIndexProvider.overrideWith((ref) async => DownloadIndex(
          DownloadIndex.defaultFile(h.coversDir.path))),
    ]);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Abbinamenti'), findsOneWidget);
    expect(find.textContaining('Song 0, Band'), findsOneWidget);
    expect(find.textContaining('Band - Topic'), findsOneWidget);
    expect(find.text('Scarica 1 brano'), findsOneWidget);

    expect(
      tester.getSemantics(find.byType(Checkbox)),
      matchesSemantics(
        label: 'Song 0, Band',
        hasCheckedState: true,
        isChecked: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('plan-deselect-all')));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(find.text('Scarica 0 brani'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plan-select-all')));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

    await tester.tap(find.textContaining('Song 0, Band'));
    await tester.pumpAndSettle();
    expect(find.text('Song 0 (Live)'), findsOneWidget);
    expect(find.textContaining('+60 s'), findsOneWidget);
    await tester.tap(find.text('Song 0 (Live)'));
    await tester.pump(const Duration(milliseconds: 300));
    final chosen =
        await tester.runAsync(() => ImportRepository(h.db).item(iid, 0));
    expect(chosen!.videoId, 'b');
    await h.dispose(tester);
  });
}
