import 'dart:io';

import 'package:codecore/data/db/app_database.dart' show Track;
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/repositories/track_kinds.dart' show kStreamKind;
import 'package:codecore/providers/player_providers.dart'
    show onlineEntriesProvider;
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/online/download_queue.dart' show DownloadItem;
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

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

/// The ⋯ of a row (a long press now starts a selection).
Future<void> _openMenu(WidgetTester tester, String title) => tester.tap(
  find
      .descendant(
        of: find.widgetWithText(TrackRow, title).first,
        matching: find.byTooltip('Altre opzioni'),
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
  }) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 1);
    final t = edit(
      (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!.first,
    );
    await h.pump(
      tester,
      extraOverrides: extra,
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showTrackActions(context, ref, t),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    return h;
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
        'Condividi…',
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
    '«Scarica»: in the menu of a streamed track, not of a local one',
    (tester) async {
      var h = await openSheet(tester, (t) => t);
      expect(find.text('Scarica'), findsNothing);
      await h.dispose(tester);

      h = await openSheet(tester, (t) => t.copyWith(id: -5));
      expect(find.text('Scarica'), findsOneWidget);
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

  testWidgets(
    '«Scarica» goes away from the open sheet when the entry joins the library (R-93)',
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
      expect(find.text('Scarica'), findsOneWidget);
      final file = File('${dir.path}/v1.m4a')..writeAsStringSync('x');
      await tester.runAsync(() => index.add('v1', file.path));
      ProviderScope.containerOf(tester.element(find.text('Scarica')))
          .invalidate(downloadIndexProvider);
      await _settle(tester);
      expect(find.text('Scarica'), findsNothing);
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
      await tester.tap(find.text('Scarica'));
      await _settle(tester);
      expect(find.text('Aggiunto alla libreria'), findsOneWidget);
      await h.dispose(tester);
    },
  );
}

class _Downloads extends DownloadsNotifier {
  final added = <YtResult>[];
  bool instant = false;
  @override
  List<DownloadItem> build() => [];
  @override
  Future<bool> add(YtResult r, {String? tag}) async {
    added.add(r);
    return instant;
  }
}
