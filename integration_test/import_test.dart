import 'package:codecore/data/db/app_database.dart' show TracksCompanion;
import 'package:codecore/data/repositories/import_repository.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/services/import/imported_playlist.dart';
import 'package:codecore/services/import/playlist_import_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app_driver.dart';
import 'support/no_network_youtube.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a CSV of files already in the library becomes a playlist in the CSV order, with no network', (tester) async {
    final app = await AppUnderTest.create();
    await app.launch(tester);
    await tester.runAsync(() => app.addMusicFolder(tester));
    await settle(tester);

    final c = app.container(tester);
    final tracks = TrackRepository(app.db);
    final playlists = c.read(playlistRepositoryProvider);
    final yt = NoNetworkYoutube();
    final service = PlaylistImportService(
      imports: ImportRepository(app.db),
      playlists: playlists,
      loadLibrary: tracks.liteEntries,
      youtube: yt,
      enqueue: (r, tag) => fail('nothing may be downloaded'),
      cancelDownloads: (_) {},
      settled: const Stream.empty(),
      trackIdForPath: tracks.idForPath,
      pathForVideo: (_) async => null,
      applyTags: (id, r) async {},
      searchGap: Duration.zero,
    );
    // The CSV lists the tracks in an order different from the library's.
    final order = ['Tone C', 'Tone A', 'Tone D'];
    // Rows without an artist never match the library (too risky), and the generated files have none.
    await tester.runAsync(() => app.db.update(app.db.tracks).write(const TracksCompanion(artist: Value('Tone Band'))));
    final all = (await tester.runAsync(() => tracks.liteEntries()))!;
    final byTitle = {for (final t in all) t.title.toLowerCase(): t};
    final csv = ImportedPlaylist(name: 'Da CSV', rows: [
      for (var i = 0; i < order.length; i++)
        ImportRow(
            index: i,
            title: byTitle[order[i].toLowerCase()]!.title,
            artists: [byTitle[order[i].toLowerCase()]!.artist ?? ''],
            durationMs: byTitle[order[i].toLowerCase()]!.durationMs),
    ]);
    final importId = (await tester.runAsync(() => service.start(csv)))!;
    // The import runs in the background: wait for the playlist to fill, not for a fixed time.
    late List<String> titles;
    late PlaylistSummary list;
    await tester.runAsync(() async {
      for (var i = 0; i < 300; i++) {
        final all = await playlists.watchAll().first;
        if (all.isNotEmpty) {
          list = all.single;
          titles = (await playlists.watchTracks(list.playlist.id).first).map((t) => t.title.toLowerCase()).toList();
          if (titles.length >= order.length) return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    expect(list.playlist.name, 'Da CSV');
    expect(titles, order.map((s) => s.toLowerCase()).toList());
    expect(yt.searches, 0, reason: 'every row was matched in the library');
    expect(importId, isNonZero);
    service.dispose();
    await app.dispose(tester);
  });
}
