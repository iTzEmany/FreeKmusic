import 'package:codecore/providers/database_providers.dart' show playlistsProvider;
import 'package:codecore/providers/import_providers.dart';
import 'package:codecore/services/import/exportify_zip.dart';
import 'package:codecore/services/import/import_diff.dart' show ImportDiff;
import 'package:codecore/services/import/import_options.dart';
import 'package:codecore/services/import/imported_playlist.dart';
import 'package:codecore/services/import/playlist_import_service.dart';
import 'package:codecore/ui/screens/import/exportify_sync_screen.dart';
import 'package:codecore/ui/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

ImportRow _row(int i) =>
    ImportRow(index: i, title: 'T$i', artists: const ['A']);

ImportedPlaylist _csv(String name) =>
    ImportedPlaylist(name: name, rows: [_row(0), _row(1)]);

/// Records what the screen starts; the diff is +2 for «Rock», none for «Calm».
class _FakeService implements PlaylistImportService {
  final calls = <String>[];
  bool failSync = false;

  @override
  Future<ImportDiff> previewSync(ImportedPlaylist csv, int playlistId) async =>
      ImportDiff(added: csv.name == 'rock' ? [_row(0), _row(1)] : const []);

  @override
  Future<int> sync(
    ImportedPlaylist csv,
    int playlistId, {
    ImportOptions options = const ImportOptions(),
  }) async {
    if (failSync) throw StateError('boom');
    calls.add('sync ${csv.name} $playlistId');
    return 1;
  }

  @override
  Future<int> start(
    ImportedPlaylist csv, {
    String? name,
    int? intoPlaylistId,
    ImportOptions options = const ImportOptions(),
    int? blockSize,
  }) async {
    calls.add('start ${csv.name}');
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('while the playlists load it shows a skeleton, not a spinner', (
    tester,
  ) async {
    final h = await Harness.create(tester);
    await h.pump(
      tester,
      ExportifySyncScreen(
        zip: ExportifyZipResult([
          (fileName: 'rock.csv', playlist: _csv('rock')),
        ], 0),
      ),
      extraOverrides: [
        playlistsProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(Skeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('ticks by the rules and syncs only the ticked ones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await tester.runAsync(() async {
      await h.db.customStatement(
        "INSERT INTO playlists (name, created_at) VALUES ('Rock', 1)",
      );
      await h.db.customStatement(
        "INSERT INTO playlists (name, created_at) VALUES ('Calm', 1)",
      );
      await h.db.customStatement(
        "INSERT INTO playlists (name, created_at) VALUES ('Dup', 1)",
      );
      await h.db.customStatement(
        "INSERT INTO playlists (name, created_at) VALUES ('dup', 1)",
      );
    });
    final svc = _FakeService();
    final zip = ExportifyZipResult([
      (fileName: 'rock.csv', playlist: _csv('rock')),
      (fileName: 'calm.csv', playlist: _csv('calm')),
      (fileName: 'dup.csv', playlist: _csv('dup')),
      (fileName: 'fresh.csv', playlist: _csv('fresh')),
    ], 1);
    await h.pump(
      tester,
      ExportifySyncScreen(zip: zip),
      extraOverrides: [playlistImportServiceProvider.overrideWithValue(svc)],
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.textContaining('+2 nuovi, −0 rimossi'), findsOneWidget);
    expect(find.text('Da scegliere'), findsWidgets); // dup is ambiguous
    expect(find.text('Nuova playlist'), findsOneWidget); // fresh
    expect(find.text('Sincronizza 1'), findsOneWidget); // only rock ticked

    await tester.tap(find.text('Sincronizza 1'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    expect(svc.calls, hasLength(1));
    expect(svc.calls.single, startsWith('sync rock '));
    expect(h.store.readExportifyLastSyncAt(), isNotNull);
    await h.dispose(tester);
  });

  testWidgets('all syncs failing keeps the screen and writes no timestamp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await tester.runAsync(() async {
      await h.db.customStatement(
        "INSERT INTO playlists (name, created_at) VALUES ('Rock', 1)",
      );
    });
    final svc = _FakeService()..failSync = true;
    final zip = ExportifyZipResult([
      (fileName: 'rock.csv', playlist: _csv('rock')),
    ], 0);
    await h.pump(
      tester,
      ExportifySyncScreen(zip: zip),
      extraOverrides: [playlistImportServiceProvider.overrideWithValue(svc)],
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.tap(find.text('Sincronizza 1'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(h.store.readExportifyLastSyncAt(), isNull);
    expect(find.text('Sincronizzazione non riuscita'), findsOneWidget);
    expect(find.byType(ExportifySyncScreen), findsOneWidget);
    await h.dispose(tester);
  });
}
