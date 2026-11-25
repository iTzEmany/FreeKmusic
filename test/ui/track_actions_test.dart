import 'dart:io';

import 'dart:async';

import 'package:codecore/core/platform.dart' show debugIsDesktopOverride;
import 'package:codecore/data/db/app_database.dart' show Track, TracksCompanion;
import 'package:codecore/data/repositories/playlist_repository.dart' show PlaylistRepository;
import 'package:codecore/providers/external_share_provider.dart';
import 'package:codecore/ui/widgets/download_bar.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/repositories/track_kinds.dart'
    show kMusicKind, kStreamKind;
import 'package:codecore/data/settings/settings_store.dart' show StorageMode;
import 'package:codecore/providers/player_providers.dart'
    show onlineEntriesProvider;
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/providers/library_add_providers.dart'
    show trackRowLookupProvider;
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/online/download_queue.dart' show DownloadItem, DownloadStatus;
import 'package:codecore/services/online/download_index.dart'
    show DownloadIndex;
import 'package:codecore/services/online/youtube_service.dart' show YtResult;
import 'package:codecore/ui/theme/tokens.dart';
import 'package:codecore/ui/widgets/track_actions.dart';
import 'package:drift/drift.dart' show Value;
import 'package:codecore/providers/preview_providers.dart';
import 'package:codecore/ui/widgets/cover_image.dart';
import 'package:codecore/ui/screens/library/album_detail_screen.dart';
import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/screens/now_playing/queue_sheet.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_backend.dart';
import '../support/fake_share.dart';

Track _stub() => const Track(
  saved: false, coverSource: 0, id: 1, path: '/m/1.mp3', title: 'Song', artist: 'Band', album: null, albumKey: 'k',
  durationMs: 1000, format: 'mp3', sizeBytes: 1, mtimeMs: 1, hasCover: false, isFavorite: false, enrichStatus: 0,
  userEdited: false, missing: false, ignored: false, kind: 0, addedAt: 1, playCount: 0,
);

Future<void> _settle(WidgetTester tester) async {
  // Two rounds: the menu's reload is a chain of real I/O steps (DB, then the file signature).
  for (var i = 0; i < 2; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

/// The ⋯ of a row (a long press now starts a selection).
Future<void> _openMenu(WidgetTester tester, String title) => tester.tap(
  find
      .descendant(
        of: find.widgetWithText(TrackRow, title).first,
        matching: find.byTooltip('Altre azioni'),
      )
      .first,
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('⋯ → menu groups → «Vai all\'album» opens the album', (
    tester,
  ) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 3);
    await h.pump(tester, const AppShell());
    await tester.tap(find.text('Libreria'));
    await _settle(tester);
    await tester.tap(find.text('Tutti i brani'));
    await _settle(tester);
    await _openMenu(tester, 'Song 1');
    await _settle(tester);
    // Grouped menu under the track header.
    expect(find.text('Aggiungi in coda'), findsOneWidget);
    expect(find.text('Vai all’album'), findsOneWidget);
    expect(find.text('Vai all’artista'), findsOneWidget);
    // No bookmark: no restart entry and no «riprendi da».
    expect(find.text('Ricomincia dall’inizio'), findsNothing);
    expect(find.textContaining('riprendi da'), findsNothing);
    await tester.tap(find.text('Vai all’album'));
    await _settle(tester);
    await _settle(tester);
    expect(find.byType(AlbumDetailScreen), findsOneWidget);
    expect(find.text('Libreria'), findsWidgets); // bottom bar still there
    await h.dispose(tester);
  });

  testWidgets(
    'a track with a bookmark says where it resumes and offers a restart',
    (tester) async {
      _phone(tester);
      final h = await Harness.create(tester, tracks: 3);
      final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
      final marked = rows!.firstWhere((t) => t.title == 'Song 1');
      await tester.runAsync(
        () => TrackRepository(h.db).setResumePosition(
          marked.id,
          const Duration(minutes: 42, seconds: 10).inMilliseconds,
        ),
      );
      await h.pump(tester, const AppShell());
      await tester.tap(find.text('Libreria'));
      await _settle(tester);
      await tester.tap(find.text('Tutti i brani'));
      await _settle(tester);

      expect(find.textContaining('riprendi da 42:10'), findsOneWidget);
      await _openMenu(tester, 'Song 1');
      await _settle(tester);
      expect(find.text('Ricomincia dall’inizio'), findsOneWidget);
      await tester.tap(find.text('Ricomincia dall’inizio'));
      await _settle(tester);
      final after = await tester.runAsync(
        () => TrackRepository(h.db).getById(marked.id),
      );
      expect(
        after!.resumePositionMs,
        isNull,
        reason: 'the bookmark is cleared',
      );
      expect(
        h.handler.currentTrack?.id,
        marked.id,
        reason: 'and it plays from the start',
      );
      await h.dispose(tester);
    },
  );

  testWidgets('holding a cover previews that track on its own player', (
    tester,
  ) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 3);
    final previews = <FakeBackend>[];
    await h.pump(
      tester,
      const AppShell(),
      extraOverrides: [
        previewBackendFactoryProvider.overrideWithValue(() {
          final b = FakeBackend();
          previews.add(b);
          return b;
        }),
      ],
    );
    await tester.tap(find.text('Libreria'));
    await _settle(tester);
    await tester.tap(find.text('Tutti i brani'));
    await _settle(tester);

    // The cover of the first row of this page (the Library below has its own).
    final cover = find
        .descendant(
          of: find.byType(AllTracksScreen),
          matching: find.byType(CoverImage),
        )
        .first;
    final gesture = await tester.startGesture(tester.getCenter(cover));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(previews, hasLength(1), reason: 'the hold started a preview');
    expect(previews.single.loaded, hasLength(1));
    expect(
      find.text('Aggiungi in coda'),
      findsNothing,
      reason: 'the track menu belongs to the rest of the row',
    );
    await gesture.up();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(previews.single.disposed, isTrue, reason: 'letting go ends it');
    expect(h.handler.currentTrack, isNull, reason: 'nothing was queued');
    await h.dispose(tester);
  });

  testWidgets(
    'on desktop a click or Esc ends a preview started from the menu',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester, tracks: 3);
      await h.pump(
        tester,
        const AppShell(),
        extraOverrides: [
          previewBackendFactoryProvider.overrideWithValue(FakeBackend.new),
        ],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
      );
      final track = (await tester.runAsync(
        () => h.db.select(h.db.tracks).get(),
      ))!.first;

      await tester.runAsync(
        () => container.read(previewProvider.notifier).start(track),
      );
      await tester.pump();
      expect(container.read(previewProvider).active, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(container.read(previewProvider).active, isFalse, reason: 'Esc');

      await tester.runAsync(
        () => container.read(previewProvider.notifier).start(track),
      );
      await tester.pump();
      expect(container.read(previewProvider).active, isTrue);
      await tester.tapAt(const Offset(700, 400));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(
        container.read(previewProvider).active,
        isFalse,
        reason: 'a click',
      );
      await h.dispose(tester);
    },
  );

  testWidgets('queue: now playing and next sections, no played tracks', (
    tester,
  ) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 4);
    final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
    await tester.runAsync(
      () => h.handler.playQueue([for (final t in rows!) t.id], 1),
    );
    await h.pump(
      tester,
      Scaffold(body: QueueSheet(scrollController: ScrollController())),
    );
    await _settle(tester);
    expect(find.text('In riproduzione'), findsOneWidget);
    expect(find.text('Prossimi'), findsOneWidget);
    expect(find.text('Svuota'), findsOneWidget);
    expect(find.text('Song 0'), findsNothing); // already played
    expect(find.text('Song 1'), findsOneWidget);
    expect(find.text('Song 3'), findsOneWidget);

    // «Svuota» drops the extra song and builds the list again after Song 1.
    h.handler.addToQueue(rows!.first.id);
    await _settle(tester);
    await tester.tap(find.text('Svuota'));
    await _settle(tester);
    expect(find.text('Coda ricreata dalla lista in ascolto'), findsOneWidget);
    expect(find.text('Song 0'), findsNothing);
    expect(find.text('Song 3'), findsOneWidget);
    expect(h.handler.hasNext, isTrue);
    await h.dispose(tester);
  });

  Future<Harness> openSheet(
    WidgetTester tester,
    Track Function(Track) edit, {
    double scale = 1,
    List<Override> extra = const [],
    StorageMode? mode,
    ValueNotifier<bool>? opener,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 1);
    if (mode != null) await tester.runAsync(() => h.store.writeSettings(h.store.readSettings().copyWith(storageMode: mode)));
    final t = edit(
      (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!.first,
    );
    // The menu follows the DB row: it holds what the test says the track is (an online id has no row).
    if (t.id > 0) await tester.runAsync(() => h.db.update(h.db.tracks).replace(t));
    await h.pump(
      tester,
      extraOverrides: extra,
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          // [opener] false takes the row that opened the sheet out of the tree.
          body: ValueListenableBuilder<bool>(
            valueListenable: opener ?? ValueNotifier(true),
            builder: (_, shown, _) => !shown
                ? const SizedBox()
                : Consumer(
                    builder: (context, ref, _) => TextButton(
                      onPressed: () => showTrackActions(context, t),
                      child: const Text('open'),
                    ),
                  ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    if (settle) await _settle(tester);
    return h;
  }

  // 155.1: «Aggiungi a playlist…» from the sheet, in both modes: same entries, same result.
  for (final desktop in [false, true]) {
    testWidgets('«Aggiungi a playlist…» picks an existing playlist, desktop: $desktop', (tester) async {
      debugIsDesktopOverride = desktop;
      addTearDown(() => debugIsDesktopOverride = null);
      final h = await openSheet(tester, (t) => t);
      final id = (await tester.runAsync(() => PlaylistRepository(h.db).create('Notte')))!;
      await tester.tap(find.text('Aggiungi a playlist…'));
      await _settle(tester);
      await tester.tap(find.text('Notte'));
      await _settle(tester);
      final ids = (await tester.runAsync(() => PlaylistRepository(h.db).watchTracks(id).first))!;
      expect([for (final t in ids) t.id], [1]);
      await h.dispose(tester);
    });

    testWidgets('«Nuova playlist» from the sheet creates it with the song, desktop: $desktop', (tester) async {
      debugIsDesktopOverride = desktop;
      addTearDown(() => debugIsDesktopOverride = null);
      final h = await openSheet(tester, (t) => t);
      await tester.tap(find.text('Aggiungi a playlist…'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'Nuova');
      await tester.pump();
      await tester.tap(find.text('Crea'));
      await _settle(tester);
      final made = (await tester.runAsync(() => h.db.select(h.db.playlists).get()))!.single;
      expect(made.name, 'Nuova');
      final ids = (await tester.runAsync(() => PlaylistRepository(h.db).watchTracks(made.id).first))!;
      expect([for (final t in ids) t.id], [1]);
      await h.dispose(tester);
    });
  }

  testWidgets('sheet header has title, artist, album on three lines', (
    tester,
  ) async {
    final h = await openSheet(tester, (t) => t);
    expect(find.textContaining('·'), findsNothing);
    final a = tester.getRect(find.text('Artist'));
    final b = tester.getRect(find.text('Album 0'));
    expect(b.top, greaterThanOrEqualTo(a.bottom));
    await h.dispose(tester);
  });

  testWidgets('delete is last and red', (tester) async {
    final h = await openSheet(tester, (t) => t);
    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect((tiles.last.title as Text).data, 'Elimina dal dispositivo');
    Color? red(ListTile x) => (x.title as Text).style?.color;
    expect(red(tiles.last), CcColors.notte.error);
    expect(tiles.where((x) => red(x) == CcColors.notte.error), hasLength(1));
    await h.dispose(tester);
  });

  testWidgets('header lines with missing album and long title', (tester) async {
    final h = await openSheet(
      tester,
      (t) => t.copyWith(
        title: 'x' * 200,
        artist: const Value(null),
        album: const Value(null),
      ),
      scale: 1.5,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Artista sconosciuto'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('online track: no destructive row', (tester) async {
    final h = await openSheet(tester, (t) => t.copyWith(id: -5));
    expect(find.byType(ListTile), findsWidgets);
    expect(
      tester
          .widgetList<ListTile>(find.byType(ListTile))
          .where((x) => (x.title as Text).style?.color == CcColors.notte.error),
      isEmpty,
    );
    await h.dispose(tester);
  });

  testWidgets('«Vai all\'artista» is in the menu of a streamed track', (
    tester,
  ) async {
    final h = await openSheet(tester, (t) => t.copyWith(id: -5));
    expect(find.text('Vai all’artista'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('menu entries by state: local, online unsaved, saved stream, downloaded', (tester) async {
    // Local (kind 0) and downloaded rows are the same today: the full menu, no «Scarica».
    var h = await openSheet(tester, (t) => t);
    for (final t in ['Aggiungi in coda', 'Aggiungi a playlist…', 'Modifica info', 'Elimina dal dispositivo']) {
      expect(find.text(t, skipOffstage: false), findsOneWidget, reason: 'local: $t');
    }
    for (final t in ['Scarica', 'Aggiungi alla libreria', 'Rimuovi dalla libreria']) {
      expect(find.text(t), findsNothing, reason: 'local: $t');
    }
    await h.dispose(tester);

    // Online entry not saved: «Aggiungi alla libreria», no destructive or library-removal row.
    h = await openSheet(tester, (t) => t.copyWith(id: -5));
    expect(find.text('Aggiungi alla libreria'), findsOneWidget);
    expect(find.text('Rimuovi dalla libreria'), findsNothing);
    expect(find.text('Elimina dal dispositivo', skipOffstage: false), findsNothing);
    await h.dispose(tester);

    // Saved stream row: «Scarica» + «Rimuovi dalla libreria», never «Aggiungi alla libreria».
    h = await openSheet(tester, (t) => t.copyWith(kind: kStreamKind, path: 'stream:youtube:abc', saved: true));
    expect(find.text('Scarica'), findsOneWidget);
    expect(find.text('Rimuovi dalla libreria', skipOffstage: false), findsOneWidget);
    expect(find.text('Aggiungi alla libreria'), findsNothing);
    expect(find.text('Elimina dal dispositivo', skipOffstage: false), findsNothing);
    await h.dispose(tester);
  });

  testWidgets(
    '«Cambia copertina» is in every library menu, «Ripristina» only with a hand-picked cover, never online',
    (tester) async {
      var h = await openSheet(tester, (t) => t);
      expect(find.text('Cambia copertina'), findsOneWidget);
      expect(find.text('Ripristina copertina originale'), findsNothing);
      await h.dispose(tester);

      h = await openSheet(tester, (t) => t.copyWith(coverSource: 2));
      expect(find.text('Ripristina copertina originale'), findsOneWidget);
      await h.dispose(tester);

      h = await openSheet(tester, (t) => t.copyWith(id: -5, coverSource: 2));
      expect(find.text('Cambia copertina'), findsNothing);
      expect(find.text('Ripristina copertina originale'), findsNothing);
      await h.dispose(tester);

      h = await openSheet(
        tester,
        (t) => t.copyWith(kind: kStreamKind, path: 'stream:youtube:abc'),
      );
      expect(find.text('Cambia copertina'), findsNothing);
      await h.dispose(tester);
    },
  );

  testWidgets(
    'an episode not downloaded has the menu of a streamed row: queue, restart and details only',
    (tester) async {
      final h = await openSheet(
        tester,
        (t) => t.copyWith(
          kind: 1,
          path: 'https://x/e.mp3',
          resumePositionMs: const Value(5000),
        ),
      );
      expect(find.text('Aggiungi in coda'), findsOneWidget);
      expect(find.text('Ricomincia dall’inizio'), findsOneWidget);
      expect(find.text('Dettagli'), findsOneWidget);
      for (final gone in [
        'Modifica info',
        'Invia a un dispositivo',
        'Anteprima 20 s',
        'Aggiungi a playlist…',
        'Scarica',
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      await h.dispose(tester);

      final k = await openSheet(
        tester,
        (t) => t.copyWith(kind: 1, path: 'stream:youtube:v1'),
      );
      expect(find.text('Modifica info'), findsNothing);
      expect(
        find.text('Scarica'),
        findsNothing,
        reason: 'an episode is downloaded from its page',
      );
      await k.dispose(tester);

      final local = await openSheet(
        tester,
        (t) => t.copyWith(kind: 1, path: '/data/podcasts/1/e.mp3'),
      );
      expect(
        find.text('Modifica info'),
        findsOneWidget,
        reason: 'a downloaded episode keeps its menu',
      );
      await local.dispose(tester);
    },
  );

  testWidgets(
    '«Scarica» of a streamed track and «Aggiungi alla libreria» of a queue entry, not of a local one',
    (tester) async {
      var h = await openSheet(tester, (t) => t);
      expect(find.text('Aggiungi alla libreria'), findsNothing);
      await h.dispose(tester);

      h = await openSheet(tester, (t) => t.copyWith(id: -5));
      expect(find.text('Aggiungi alla libreria'), findsOneWidget);
      await h.dispose(tester);

      final downloads = _Downloads();
      h = await openSheet(
        tester,
        (t) => t.copyWith(
          kind: kStreamKind,
          path: 'stream:youtube:abc',
          title: 'Streamed',
        ),
        extra: [downloadsProvider.overrideWith(() => downloads)],
      );
      await tester.tap(find.text('Scarica'));
      await _settle(tester);
      expect(downloads.added.single.id, 'abc');
      expect(downloads.added.single.title, 'Streamed');
      await h.dispose(tester);
    },
  );

  testWidgets('saved stream: the full menu of a local track plus «Scarica»; unsaved shadow row: «Scarica» or «Aggiungi alla libreria», never both', (tester) async {
    var h = await openSheet(tester, (t) => t.copyWith(kind: kStreamKind, path: 'stream:youtube:abc', saved: true));
    for (final t in ['Aggiungi a playlist…', 'Modifica info', 'Scarica', 'Rimuovi dalla libreria']) {
      expect(find.text(t, skipOffstage: false), findsOneWidget, reason: 'saved: $t');
    }
    await h.dispose(tester);

    h = await openSheet(tester, (t) => t.copyWith(kind: kStreamKind, path: 'stream:youtube:abc'), mode: StorageMode.stream);
    expect(find.text('Aggiungi alla libreria'), findsOneWidget);
    expect(find.text('Scarica sul dispositivo'), findsNothing);
    expect(find.text('Modifica info'), findsNothing);
    await h.dispose(tester);

    h = await openSheet(tester, (t) => t.copyWith(kind: kStreamKind, path: 'stream:youtube:abc'));
    expect(find.text('Scarica'), findsOneWidget);
    expect(find.text('Aggiungi alla libreria'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('«Scarica» saves the row too, then downloads (D-695)', (tester) async {
    final downloads = _Downloads();
    final h = await openSheet(
      tester,
      (t) => t.copyWith(kind: kStreamKind, path: 'stream:youtube:abc'),
      extra: [downloadsProvider.overrideWith(() => downloads)],
    );
    await tester.tap(find.text('Scarica'));
    await _settle(tester);
    expect(downloads.added, hasLength(1));
    final row = (await tester.runAsync(() => TrackRepository(h.db).byPath('stream:youtube:abc')))!;
    expect(row.saved, isTrue);
    await h.dispose(tester);
  });

  testWidgets('the open menu of a saved stream swaps «Scarica» away by itself when its key joins the download index', (tester) async {
    final dir = Directory.systemTemp.createTempSync('dl_idx');
    addTearDown(() => dir.deleteSync(recursive: true));
    final index = DownloadIndex(File('${dir.path}/downloads.json'));
    final h = await openSheet(
      tester,
      (t) => t.copyWith(kind: kStreamKind, path: 'stream:youtube:abc', saved: true),
      extra: [downloadIndexProvider.overrideWith((ref) async => index)],
    );
    expect(find.text('Scarica'), findsOneWidget);
    final file = File('${dir.path}/abc.m4a')..writeAsStringSync('x');
    // The download finished: the saved-stream row is promoted to the file, the index knows it.
    await tester.runAsync(() => h.db.customStatement("UPDATE tracks SET kind = 0, saved = 0, path = '${file.path}' WHERE id = (SELECT MIN(id) FROM tracks)"));
    await tester.runAsync(() => index.add('abc', file.path));
    ProviderScope.containerOf(tester.element(find.text('Scarica'))).invalidate(downloadIndexProvider);
    await _settle(tester);
    expect(find.text('Scarica'), findsNothing);
    expect(find.text('Elimina dal dispositivo', skipOffstage: false), findsOneWidget, reason: 'the menu of the file now');
    await h.dispose(tester);
  });

  testWidgets('the open menu keeps following the song after the row that opened it is gone', (tester) async {
    final dir = Directory.systemTemp.createTempSync('dl_idx');
    addTearDown(() => dir.deleteSync(recursive: true));
    final index = DownloadIndex(File('${dir.path}/downloads.json'));
    final opener = ValueNotifier(true);
    final h = await openSheet(
      tester,
      (t) => t.copyWith(kind: kStreamKind, path: 'stream:youtube:abc', saved: true),
      extra: [downloadIndexProvider.overrideWith((ref) async => index)],
      opener: opener,
    );
    expect(find.text('Scarica'), findsOneWidget);
    opener.value = false; // the list changed: the row is unmounted, the sheet stays
    await tester.pump();
    expect(find.text('open'), findsNothing);
    final file = File('${dir.path}/abc.m4a')..writeAsStringSync('x');
    await tester.runAsync(() => h.db.customStatement("UPDATE tracks SET kind = 0, saved = 0, path = '${file.path}' WHERE id = (SELECT MIN(id) FROM tracks)"));
    await tester.runAsync(() => index.add('abc', file.path));
    ProviderScope.containerOf(tester.element(find.text('Scarica'))).invalidate(downloadIndexProvider);
    await _settle(tester);
    expect(find.text('Scarica'), findsNothing);
    expect(find.text('Elimina dal dispositivo', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('«Elimina dal dispositivo» still deletes after the row that opened the menu is gone', (tester) async {
    final opener = ValueNotifier(true);
    final h = await openSheet(tester, (t) => t, opener: opener);
    opener.value = false; // the row is unmounted, the sheet stays
    await tester.pump();
    await tester.ensureVisible(find.text('Elimina dal dispositivo'));
    await tester.pump();
    await tester.tap(find.text('Elimina dal dispositivo'));
    await _settle(tester);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Elimina')));
    await _settle(tester);
    await _settle(tester);
    expect(await tester.runAsync(() => h.db.select(h.db.tracks).get()), isEmpty);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('an action whose label changed while the menu was open still runs, row gone', (tester) async {
    final dir = Directory.systemTemp.createTempSync('dl_idx');
    addTearDown(() => dir.deleteSync(recursive: true));
    final index = DownloadIndex(File('${dir.path}/downloads.json'));
    final opener = ValueNotifier(true);
    final h = await openSheet(
      tester,
      (t) => t.copyWith(kind: kStreamKind, path: 'stream:youtube:abc', saved: true),
      extra: [downloadIndexProvider.overrideWith((ref) async => index)],
      opener: opener,
    );
    opener.value = false;
    await tester.pump();
    final file = File('${dir.path}/abc.m4a')..writeAsStringSync('x');
    await tester.runAsync(() => h.db.customStatement("UPDATE tracks SET kind = 0, saved = 0, path = '${file.path}' WHERE id = (SELECT MIN(id) FROM tracks)"));
    await tester.runAsync(() => index.add('abc', file.path));
    ProviderScope.containerOf(tester.element(find.text('Scarica'))).invalidate(downloadIndexProvider);
    await _settle(tester); // the labels changed: «Scarica» gone, «Elimina dal dispositivo» in
    await tester.ensureVisible(find.text('Elimina dal dispositivo'));
    await tester.pump();
    await tester.tap(find.text('Elimina dal dispositivo'));
    await _settle(tester);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Elimina')));
    await _settle(tester);
    await _settle(tester);
    expect(await tester.runAsync(() => h.db.select(h.db.tracks).get()), isEmpty);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('a late, older row lookup does not undo the newer one', (tester) async {
    final lookups = <Completer<Track?>>[];
    final h = await openSheet(
      tester,
      (t) => t.copyWith(kind: kStreamKind, path: 'stream:youtube:abc', saved: true),
      extra: [trackRowLookupProvider.overrideWithValue((track, key) => (lookups..add(Completer<Track?>())).last.future)],
    );
    ProviderScope.containerOf(tester.element(find.text('Scarica'))).invalidate(downloadIndexProvider); // a newer reload
    await _settle(tester);
    expect(lookups.length, greaterThan(1));
    final row = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!.first;
    final older = lookups.sublist(0, lookups.length - 1);
    lookups.last.complete(row);
    await _settle(tester);
    for (final c in older) {
      c.complete(row.copyWith(kind: kMusicKind, saved: false, path: '/m/file.mp3')); // answer last, but are older
    }
    await _settle(tester);
    expect(find.text('Scarica'), findsOneWidget);
    expect(find.text('Elimina dal dispositivo', skipOffstage: false), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('«Libera spazio» only for a file the app downloaded (it is in the download index)', (tester) async {
    final dir = Directory.systemTemp.createTempSync('dl_idx');
    addTearDown(() => dir.deleteSync(recursive: true));
    final index = DownloadIndex(File('${dir.path}/downloads.json'));
    var h = await openSheet(tester, (t) => t, extra: [downloadIndexProvider.overrideWith((ref) async => index)]);
    expect(find.text('Libera spazio', skipOffstage: false), findsNothing, reason: 'a user file');
    await h.dispose(tester);

    final file = File('${dir.path}/abc.m4a')..writeAsStringSync('x');
    await tester.runAsync(() => index.add('abc', file.path));
    h = await openSheet(
      tester,
      (t) => t.copyWith(path: file.path),
      extra: [downloadIndexProvider.overrideWith((ref) async => index)],
    );
    expect(find.text('Libera spazio', skipOffstage: false), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a saved stream row offers «Rimuovi dalla libreria»: it stops being saved, nothing else', (tester) async {
    final h = await openSheet(tester, (t) => t.copyWith(kind: kStreamKind, path: 'stream:youtube:abc', saved: true));
    await tester.runAsync(
      () => h.db.customStatement("UPDATE tracks SET kind = 2, saved = 1, path = 'stream:youtube:abc' WHERE id = (SELECT MIN(id) FROM tracks)"),
    );
    await tester.tap(find.text('Rimuovi dalla libreria'));
    await _settle(tester);
    final row = (await tester.runAsync(() => TrackRepository(h.db).byPath('stream:youtube:abc')))!;
    expect(row.saved, isFalse);
    await h.dispose(tester);
  });

  testWidgets('an unsaved shadow row in streaming mode offers «Aggiungi alla libreria» and saves it without downloading', (tester) async {
    final downloads = _Downloads();
    final h = await openSheet(
      tester,
      (t) => t.copyWith(kind: kStreamKind, path: 'stream:youtube:abc', title: 'Streamed'),
      mode: StorageMode.stream,
      extra: [downloadsProvider.overrideWith(() => downloads)],
    );
    expect(find.text('Rimuovi dalla libreria'), findsNothing);
    await tester.tap(find.text('Aggiungi alla libreria'));
    await _settle(tester);
    expect(downloads.added, isEmpty);
    final row = (await tester.runAsync(() => TrackRepository(h.db).byPath('stream:youtube:abc')))!;
    expect(row.saved, isTrue);
    await h.dispose(tester);
  });

  testWidgets(
    '«Aggiungi alla libreria» goes away from the open sheet when the entry joins the library (R-93)',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('dl_idx');
      addTearDown(() => dir.deleteSync(recursive: true));
      final index = DownloadIndex(File('${dir.path}/downloads.json'));
      final online = OnlineEntries();
      final id = online.register(
        const YtResult(
          id: 'v1',
          title: 'Streamed',
          channel: 'Chan',
          duration: null,
        ),
      );
      final h = await openSheet(
        tester,
        (_) => online.trackOf(id)!,
        extra: [
          onlineEntriesProvider.overrideWithValue(online),
          downloadIndexProvider.overrideWith((ref) async => index),
        ],
      );
      expect(find.text('Aggiungi alla libreria'), findsOneWidget);
      final file = File('${dir.path}/v1.m4a')..writeAsStringSync('x');
      await tester.runAsync(() => index.add('v1', file.path));
      ProviderScope.containerOf(tester.element(find.text('Aggiungi alla libreria')))
          .invalidate(downloadIndexProvider);
      await _settle(tester);
      expect(find.text('Aggiungi alla libreria'), findsNothing);
      expect(
        find.text('Aggiungi a playlist…'),
        findsOneWidget,
      ); // the sheet is still open
      await h.dispose(tester);
    },
  );

  testWidgets(
    '«Scarica» of a streamed row goes away when its key joins the download index',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('dl_idx');
      addTearDown(() => dir.deleteSync(recursive: true));
      final index = DownloadIndex(File('${dir.path}/downloads.json'));
      final h = await openSheet(
        tester,
        (t) => t.copyWith(kind: kStreamKind, path: 'stream:youtube:v1'),
        extra: [downloadIndexProvider.overrideWith((ref) async => index)],
      );
      expect(find.text('Scarica'), findsOneWidget);
      final file = File('${dir.path}/v1.m4a')..writeAsStringSync('x');
      await tester.runAsync(() => index.add('v1', file.path));
      ProviderScope.containerOf(tester.element(find.text('Scarica')))
          .invalidate(downloadIndexProvider);
      await _settle(tester);
      expect(find.text('Scarica'), findsNothing);
      await h.dispose(tester);
    },
  );

  testWidgets(
    '«Scarica» of a queue entry promoted at once says it joined the library',
    (tester) async {
      final downloads = _Downloads()..instant = true;
      final online = OnlineEntries();
      final id = online.register(
        const YtResult(
          id: 'v1',
          title: 'Streamed',
          channel: 'Chan',
          duration: null,
        ),
      );
      final h = await openSheet(
        tester,
        (_) => online.trackOf(id)!,
        extra: [
          downloadsProvider.overrideWith(() => downloads),
          onlineEntriesProvider.overrideWithValue(online),
        ],
      );
      await tester.tap(find.text('Aggiungi alla libreria'));
      await _settle(tester);
      expect(find.text('Aggiunto alla libreria'), findsOneWidget);
      await h.dispose(tester);
    },
  );

  testWidgets('an online entry keeps its own menu when a library row appears at its file: no «Elimina dal dispositivo»', (tester) async {
    final dir = Directory.systemTemp.createTempSync('dl_idx');
    addTearDown(() => dir.deleteSync(recursive: true));
    final index = DownloadIndex(File('${dir.path}/downloads.json'));
    final online = OnlineEntries();
    final id = online.register(const YtResult(id: 'v1', title: 'Streamed', channel: 'Chan', duration: null));
    final h = await openSheet(
      tester,
      (_) => online.trackOf(id)!,
      extra: [onlineEntriesProvider.overrideWithValue(online), downloadIndexProvider.overrideWith((ref) async => index)],
    );
    final file = File('${dir.path}/v1.m4a')..writeAsStringSync('x');
    await tester.runAsync(() => index.add('v1', file.path));
    await tester.runAsync(() => (h.db.update(h.db.tracks)..where((t) => t.id.equals(1))).write(TracksCompanion(path: Value(file.path))));
    ProviderScope.containerOf(tester.element(find.text('Aggiungi a playlist…'))).invalidate(downloadIndexProvider);
    await _settle(tester);
    expect(find.text('Rimuovi dalla coda', skipOffstage: false), findsOneWidget);
    expect(find.text('Elimina dal dispositivo', skipOffstage: false), findsNothing);
    await h.dispose(tester);
  });

  // A file row of the library the app downloaded: [file] is in the index with its signature.
  Future<Harness> openDownloaded(
    WidgetTester tester, {
    List<Override> extra = const [],
    bool stale = false,
    bool settle = true,
  }) async {
    final dir = Directory.systemTemp.createTempSync('dl_idx');
    addTearDown(() => dir.deleteSync(recursive: true));
    final index = DownloadIndex(File('${dir.path}/downloads.json'));
    final file = File('${dir.path}/abc.m4a')..writeAsStringSync('x');
    await tester.runAsync(() => index.add('abc', file.path));
    if (stale) file.writeAsStringSync('another file');
    return openSheet(
      tester,
      (t) => t.copyWith(path: file.path),
      extra: [downloadIndexProvider.overrideWith((ref) async => index), ...extra],
      settle: settle,
    );
  }

  testWidgets('a saved stream then downloaded (row promoted): «Libera spazio» appears without the row key being watched', (tester) async {
    final dir = Directory.systemTemp.createTempSync('dl_idx');
    addTearDown(() => dir.deleteSync(recursive: true));
    final index = DownloadIndex(File('${dir.path}/downloads.json'));
    final h = await openSheet(
      tester,
      (t) => t.copyWith(kind: kStreamKind, path: 'stream:youtube:abc', saved: true),
      extra: [downloadIndexProvider.overrideWith((ref) async => index)],
    );
    expect(find.text('Libera spazio', skipOffstage: false), findsNothing);
    final file = File('${dir.path}/abc.m4a')..writeAsStringSync('x');
    await tester.runAsync(() => h.db.customStatement("UPDATE tracks SET kind = 0, saved = 0, path = '${file.path}' WHERE id = (SELECT MIN(id) FROM tracks)"));
    await tester.runAsync(() => index.add('abc', file.path));
    ProviderScope.containerOf(tester.element(find.text('Scarica'))).invalidate(downloadIndexProvider);
    await _settle(tester);
    expect(find.text('Libera spazio', skipOffstage: false), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('an online entry saved from the player gets «Scarica sul dispositivo» and the row actions, not «Aggiungi alla libreria»', (tester) async {
    final online = OnlineEntries();
    final id = online.register(const YtResult(id: 'v1', title: 'Streamed', channel: 'Chan', duration: null));
    final h = await openSheet(
      tester,
      (_) => online.trackOf(id)!,
      mode: StorageMode.stream,
      extra: [onlineEntriesProvider.overrideWithValue(online)],
    );
    expect(find.text('Aggiungi alla libreria'), findsOneWidget);
    expect(find.text('Scarica sul dispositivo', skipOffstage: false), findsNothing);
    // «Aggiungi alla libreria» saved the shadow row; the player keeps the negative id.
    await tester.runAsync(() => h.db.customStatement("UPDATE tracks SET kind = 2, saved = 1, path = 'stream:youtube:v1' WHERE id = (SELECT MIN(id) FROM tracks)"));
    h.db.markTablesUpdated({h.db.tracks}); // a raw statement does not notify the watchers
    online.bindRow(id, 1);
    await _settle(tester);
    await _settle(tester);
    expect(find.text('Scarica sul dispositivo', skipOffstage: false), findsOneWidget);
    expect(find.text('Aggiungi alla libreria', skipOffstage: false), findsNothing);
    expect(find.text('Modifica info', skipOffstage: false), findsOneWidget);
    expect(find.text('Rimuovi dalla coda', skipOffstage: false), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('«Libera spazio» asks to confirm, then frees the file', (tester) async {
    final h = await openDownloaded(tester);
    await tester.tap(find.text('Libera spazio'));
    await _settle(tester);
    expect(find.text('Liberare lo spazio?'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Libera spazio')));
    await _settle(tester);
    await _settle(tester);
    final row = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!.first;
    expect(row.kind, kStreamKind);
    await h.dispose(tester);
  });

  testWidgets('«Libera spazio» is there from the first frame of the menu, and a double tap opens one sheet', (tester) async {
    final h = await openDownloaded(tester, settle: false);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100))); // the pre-check (a stat)
    await tester.pump(); // one frame: the sheet's first
    expect(find.text('Libera spazio', skipOffstage: false), findsOneWidget);
    await tester.tapAt(const Offset(5, 5)); // the barrier
    await _settle(tester);
    await tester.tap(find.text('open'));
    await tester.tap(find.text('open'));
    await _settle(tester);
    expect(find.text('Libera spazio', skipOffstage: false), findsOneWidget, reason: 'a second sheet would list it twice');
    await h.dispose(tester);
  });

  testWidgets('two rows tapped within the download check open one sheet', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 2);
    final rows = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
    final loading = Completer<DownloadIndex>();
    await h.pump(
      tester,
      extraOverrides: [downloadIndexProvider.overrideWith((ref) => loading.future)],
      Scaffold(
        body: Consumer(
          builder: (context, ref, _) => Column(
            children: [
              for (final t in rows)
                TextButton(onPressed: () => showTrackActions(context, t), child: Text('open${t.id}')),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('open${rows[0].id}'));
    await tester.tap(find.text('open${rows[1].id}')); // another row, the check of the first still running
    await _settle(tester);
    await _settle(tester); // past the 500 ms timeout
    expect(find.text('Elimina dal dispositivo', skipOffstage: false), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a call from a row already unmounted neither opens a sheet nor locks the menu', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 1);
    final t = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!.first;
    final shown = ValueNotifier(true);
    BuildContext? gone;
    await h.pump(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: shown,
        builder: (_, s, _) => !s
            ? const SizedBox()
            : Consumer(builder: (c, r, _) {
                gone = c;
                return const Text('row');
              }),
      ),
    );
    shown.value = false;
    await tester.pump();
    try {
      await showTrackActions(gone!, t);
    } on Object {
      // either outcome is fine; what matters is below
    }
    await _settle(tester);
    expect(find.text('Elimina dal dispositivo', skipOffstage: false), findsNothing);
    await h.pump(
      tester,
      Scaffold(body: Consumer(builder: (c, r, _) => TextButton(onPressed: () => showTrackActions(c, t), child: const Text('open')))),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    expect(find.text('Elimina dal dispositivo', skipOffstage: false), findsOneWidget, reason: 'the guard was not left taken');
    await h.dispose(tester);
  });

  testWidgets('a row inside a nested overlay opens the sheet, the host stays', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 1);
    final t = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!.first;
    await h.pump(
      tester,
      Scaffold(
        body: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (_) => Consumer(
                builder: (c, r, _) => TextButton(onPressed: () => showTrackActions(c, t), child: const Text('open')),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    expect(find.text('Elimina dal dispositivo', skipOffstage: false), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a failing download index does not lock the menu: it reopens', (tester) async {
    final h = await openSheet(tester, (t) => t, extra: [downloadIndexProvider.overrideWith((ref) async => throw StateError('boom'))]);
    expect(find.text('Elimina dal dispositivo', skipOffstage: false), findsOneWidget);
    await tester.tapAt(const Offset(5, 5)); // the barrier
    await _settle(tester);
    await tester.tap(find.text('open'));
    await _settle(tester);
    expect(find.text('Elimina dal dispositivo', skipOffstage: false), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the row unmounted during the download check: the menu opens anyway', (tester) async {
    final dir = Directory.systemTemp.createTempSync('dl_idx');
    addTearDown(() => dir.deleteSync(recursive: true));
    final index = DownloadIndex(File('${dir.path}/downloads.json'));
    final loading = Completer<DownloadIndex>();
    final opener = ValueNotifier(true);
    final h = await openSheet(
      tester,
      (t) => t,
      extra: [downloadIndexProvider.overrideWith((ref) => loading.future)],
      opener: opener,
      settle: false,
    );
    opener.value = false;
    await tester.pump();
    loading.complete(index);
    await _settle(tester);
    expect(find.text('Elimina dal dispositivo', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('«Libera spazio» is not offered for the playing track nor for a file that is not the downloaded one', (tester) async {
    var h = await openDownloaded(tester, stale: true);
    expect(find.text('Libera spazio', skipOffstage: false), findsNothing, reason: 'signature does not match');
    await h.dispose(tester);

    h = await openDownloaded(tester);
    await tester.runAsync(() => h.handler.playQueue([1], 0));
    ProviderScope.containerOf(tester.element(find.text('Aggiungi a playlist…'))).invalidate(downloadIndexProvider); // rebuilds the menu
    await _settle(tester);
    expect(find.text('Libera spazio', skipOffstage: false), findsNothing, reason: 'it is playing');
    await h.dispose(tester);
  });

  testWidgets('«Libera spazio» is not offered while the index is loading, nor on a stream row whose key is indexed', (tester) async {
    var h = await openSheet(tester, (t) => t, extra: [downloadIndexProvider.overrideWith((ref) => Completer<DownloadIndex>().future)]);
    expect(find.text('Libera spazio', skipOffstage: false), findsNothing);
    await h.dispose(tester);

    final dir = Directory.systemTemp.createTempSync('dl_idx');
    addTearDown(() => dir.deleteSync(recursive: true));
    final index = DownloadIndex(File('${dir.path}/downloads.json'));
    final file = File('${dir.path}/abc.m4a')..writeAsStringSync('x');
    await tester.runAsync(() => index.add('abc', file.path));
    h = await openSheet(
      tester,
      (t) => t.copyWith(kind: kStreamKind, path: 'stream:youtube:abc', saved: true),
      extra: [downloadIndexProvider.overrideWith((ref) async => index)],
    );
    expect(find.text('Libera spazio', skipOffstage: false), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('«Condividi» in the track menu shares through ExternalShare with the row rectangle', (tester) async {
    final fake = FakeShare();
    final h = await openSheet(tester, (t) => t, extra: [externalShareProvider.overrideWithValue(fake)]);
    await tester.tap(find.text('Condividi', skipOffstage: false));
    await _settle(tester);
    expect(fake.texts.single, startsWith('Artist - Song 0'));
    expect(fake.origins.single, tester.getRect(find.byType(TextButton)));
    await h.dispose(tester);
  });

  testWidgets('«Condividi» on a streamed row shares the YouTube Music link', (tester) async {
    final fake = FakeShare();
    final h = await openSheet(
      tester,
      (t) => t.copyWith(kind: kStreamKind, path: 'stream:youtube:abcdefghijk', saved: true),
      extra: [externalShareProvider.overrideWithValue(fake)],
    );
    await tester.tap(find.text('Condividi', skipOffstage: false));
    await _settle(tester);
    expect(fake.texts.single, contains('https://music.youtube.com/watch?v=abcdefghijk'));
    await h.dispose(tester);
  });

  testWidgets('«Condividi» on an online entry not saved yet shares its link, anchored on the row', (tester) async {
    final fake = FakeShare();
    final online = OnlineEntries();
    final id = online.register(const YtResult(id: 'abcdefghijk', title: 'Streamed', channel: 'Chan', duration: null));
    final h = await openSheet(
      tester,
      (_) => online.trackOf(id)!,
      extra: [externalShareProvider.overrideWithValue(fake), onlineEntriesProvider.overrideWithValue(online)],
    );
    await tester.tap(find.text('Condividi', skipOffstage: false));
    await _settle(tester);
    expect(fake.texts.single, contains('https://music.youtube.com/watch?v=abcdefghijk'));
    expect(fake.origins.single, tester.getRect(find.byType(TextButton)));
    await h.dispose(tester);
  });

  testWidgets('«Condividi» that fails copies the text and says so', (tester) async {
    final fake = FakeShare()..error = StateError('no mail client');
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final h = await openSheet(tester, (t) => t, extra: [externalShareProvider.overrideWithValue(fake)]);
    await tester.tap(find.text('Condividi', skipOffstage: false));
    await _settle(tester);
    expect(copied.single, startsWith('Artist - Song 0'));
    expect(find.text('Testo copiato negli appunti'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('without a TrackMenuHost the menu does not open (debug: assert)', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: Text('open'))));
    await expectLater(showTrackActions(tester.element(find.text('open')), _stub()), throwsAssertionError);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('a saved stream row has no «Mostra nella cartella», no preview and no send to a device', (tester) async {
    final h = await openSheet(tester, (t) => t.copyWith(kind: kStreamKind, path: 'stream:youtube:abc', saved: true));
    expect(find.text('Condividi', skipOffstage: false), findsOneWidget);
    for (final t in ['Mostra nella cartella', 'Anteprima 20 s', 'Invia a un dispositivo']) {
      expect(find.text(t, skipOffstage: false), findsNothing, reason: t);
    }
    await h.dispose(tester);
  });

  testWidgets('the menu header shows the download bar while the song downloads', (tester) async {
    final downloads = _Downloads();
    final h = await openSheet(
      tester,
      (t) => t.copyWith(kind: kStreamKind, path: 'stream:youtube:abc', saved: true),
      extra: [downloadsProvider.overrideWith(() => downloads)],
    );
    expect(find.byType(DownloadBar), findsOneWidget);
    expect(find.text('Scarico… 40%'), findsNothing);
    downloads.put(const YtResult(id: 'abc', title: 'S', channel: 'c', duration: null), DownloadStatus.downloading, 0.4);
    await tester.pump();
    expect(find.text('Scarico… 40%'), findsOneWidget);
    await h.dispose(tester);
  });
}

class _Downloads extends DownloadsNotifier {
  final added = <YtResult>[];
  bool instant = false;
  @override
  List<DownloadItem> build() => [];
  void put(YtResult r, DownloadStatus s, [double p = 0]) => state = [DownloadItem(id: 1, result: r, status: s, progress: p)];
  @override
  Future<bool> add(YtResult r, {String? tag}) async {
    added.add(r);
    return instant;
  }
}
