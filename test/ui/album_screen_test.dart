import 'package:codecore/ui/screens/library/album_detail_screen.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'dart:io';
import 'package:codecore/core/app_log.dart';

import 'package:codecore/ui/widgets/cover_image.dart';
import 'package:drift/drift.dart' show Value;
import 'package:codecore/data/db/app_database.dart' show Track, TracksCompanion;
import 'package:codecore/providers/keep_offline_providers.dart';
import 'package:codecore/providers/ytm_catalog_providers.dart' show albumMissingTracksProvider;
import 'package:codecore/services/online/youtube_service.dart' show YtResult;
import 'package:codecore/services/online/ytm_artist.dart' show YtmAlbumTrack;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('album rows show the duration on a 360 px phone', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(
      tester,
      const AlbumDetailScreen(
        album: AlbumSummary(
          albumKey: 'artist|album 0',
          title: 'Album 0',
          artist: 'Artist',
          variousArtists: false,
          trackCount: 2,
          durationMs: 370000,
          year: 2019,
          coverKey: null,
        ),
      ),
    );
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    // Two tracks of 3:05 in album 0.
    expect(find.text('3:05'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('the album menu has «Cambia copertina»; «Ripristina» appears once a track has a hand-picked album cover',
      (tester) async {
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(
      tester,
      const AlbumDetailScreen(
        album: AlbumSummary(
          albumKey: 'artist|album 0',
          title: 'Album 0',
          artist: 'Artist',
          variousArtists: false,
          trackCount: 2,
          durationMs: 370000,
          year: 2019,
          coverKey: null,
        ),
      ),
    );
    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    await settle();
    await tester.tap(find.byTooltip('Altre azioni'));
    await tester.pumpAndSettle();
    expect(find.text('Cambia copertina'), findsOneWidget);
    expect(find.text('Ripristina copertina originale'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.runAsync(() => TrackRepository(h.db).setManualAlbumCover('artist|album 0', 'manual-key'));
    await settle();
    await tester.tap(find.byTooltip('Altre azioni'));
    await tester.pumpAndSettle();
    expect(find.text('Ripristina copertina originale'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('picking a library cover gives the album a new cover key on screen, cover_source 1', (tester) async {
    final dir = (await tester.runAsync(Directory.systemTemp.createTemp))!;
    // Windows: the cover file can still be open here; a leftover temp dir is harmless.
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException catch (e) {
        AppLog.w('test: temp dir kept', e);
      }
    });
    await tester.runAsync(() => File('${dir.path}/libkey.jpg').writeAsBytes([1, 2, 3]));
    final h = await Harness.create(tester, tracks: 4);
    h.coversDir = dir;
    // Album 1 has a cover; album 0 (the one on screen) has none.
    await tester.runAsync(() => (h.db.update(h.db.tracks)..where((t) => t.albumKey.equals('artist|album 1')))
        .write(const TracksCompanion(coverKey: Value('libkey'))));
    await h.pump(
      tester,
      const AlbumDetailScreen(
        album: AlbumSummary(
          albumKey: 'artist|album 0',
          title: 'Album 0',
          artist: 'Artist',
          variousArtists: false,
          trackCount: 2,
          durationMs: 370000,
          year: 2019,
          coverKey: null,
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    await settle();
    await tester.tap(find.byTooltip('Altre azioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambia copertina'));
    await settle();
    await tester.tap(find.byKey(const ValueKey('library-cover-libkey')));
    // Several rounds: each file and DB step needs the real loop, then a pump.
    Future<List<Track>> album0() async => (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!
        .where((t) => t.albumKey == 'artist|album 0')
        .toList();
    for (var i = 0; i < 20 && (await album0()).any((t) => t.coverSource != 1); i++) {
      await settle();
    }
    final rows = await album0();
    expect(rows.map((t) => t.coverSource), everyElement(1));
    final newKey = rows.first.coverKey;
    expect(newKey, isNot(anyOf(isNull, 'libkey')));
    final covers = tester.widgetList<CoverImage>(find.byType(CoverImage)).toList()
      ..sort((a, b) => b.size.compareTo(a.size));
    expect(covers.first.coverKey, newKey, reason: 'the header follows the new key');
    await h.dispose(tester);
  });

  testWidgets('album «Scarica» icon hands the album tracks to keepOffline and says how many go', (tester) async {
    final h = await Harness.create(tester, tracks: 4);
    await tester.runAsync(() => h.db.update(h.db.tracks).write(const TracksCompanion(kind: Value(2), saved: Value(true))));
    final got = <int>[];
    const queued = 2;
    await h.pump(
      tester,
      const AlbumDetailScreen(
        album: AlbumSummary(
          albumKey: 'artist|album 0',
          title: 'Album 0',
          artist: 'Artist',
          variousArtists: false,
          trackCount: 2,
          durationMs: 370000,
          year: 2019,
          coverKey: null,
        ),
      ),
      extraOverrides: [
        keepOfflineProvider.overrideWithValue((tracks) async {
          got.addAll([for (final t in tracks) t.id]);
          return queued;
        }),
      ],
    );
    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    await settle();
    await tester.tap(find.byTooltip('Scarica'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(got, hasLength(2));
    expect(find.text('2 brani in download'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('an album page opened on a stream key follows the album when a download rewrites it', (tester) async {
    final h = await Harness.create(tester, tracks: 0);
    final id = (await tester.runAsync(() => h.db.into(h.db.tracks).insert(TracksCompanion.insert(
        path: 'stream:youtube:s', title: 'Streamed song', albumKey: 'stream|art|alb', format: '', sizeBytes: 0, mtimeMs: 0, addedAt: 1,
        kind: const Value(2), saved: const Value(true)))))!;
    await h.pump(
      tester,
      const AlbumDetailScreen(
        album: AlbumSummary(
            albumKey: 'stream|art|alb', title: 'Alb', artist: 'Art', variousArtists: false, trackCount: 1, durationMs: 1, year: null, coverKey: null),
      ),
    );
    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    await settle();
    expect(find.text('Streamed song'), findsOneWidget);
    expect(find.byTooltip('Scarica'), findsOneWidget);
    await tester.runAsync(() => (h.db.update(h.db.tracks)..where((t) => t.id.equals(id)))
        .write(const TracksCompanion(albumKey: Value('art|alb'), kind: Value(0), saved: Value(false))));
    await settle();
    expect(find.text('Streamed song'), findsOneWidget, reason: 'the page follows the album to its file key');
    expect(find.byTooltip('Scarica'), findsNothing, reason: 'files only: nothing left to download');
    await h.dispose(tester);
  });

  // D-706: no network on its own outside the streaming mode.
  for (final stream in [false, true]) {
    testWidgets('missing album songs: ${stream ? 'streaming loads them by itself' : 'device mode asks with a row first'}',
        (tester) async {
      final h = await Harness.create(tester, tracks: 4, streamDefault: stream);
      var asked = 0;
      await h.pump(
        tester,
        const AlbumDetailScreen(
          album: AlbumSummary(
              albumKey: 'artist|album 0', title: 'Album 0', artist: 'Artist', variousArtists: false, trackCount: 2, durationMs: 370000, year: null, coverKey: null),
        ),
        extraOverrides: [
          albumMissingTracksProvider.overrideWith((ref, _) async {
            asked++;
            return [
              const YtmAlbumTrack(
                  9, YtResult(id: 'm1', title: 'Missing One', channel: 'Artist', duration: Duration(minutes: 3))),
            ];
          }),
        ],
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));
      if (stream) {
        expect(find.text('Missing One'), findsOneWidget);
      } else {
        expect(asked, 0);
        expect(find.text('Missing One'), findsNothing);
        await tester.scrollUntilVisible(find.text("Altri brani dell'album"), 200, scrollable: find.byType(Scrollable).first);
        await tester.tap(find.text("Altri brani dell'album"));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.scrollUntilVisible(find.text('Missing One'), 200, scrollable: find.byType(Scrollable).first);
        expect(find.text('Missing One'), findsOneWidget);
      }
      expect(asked, 1);
      await h.dispose(tester);
    });
  }
}
