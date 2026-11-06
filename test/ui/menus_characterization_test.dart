// Characterization (38.5): the PopupMenuButton menus of lib/ui, one enum per menu (42.5);
// the values read are the enum names. Whoever changes a menu updates its test in the same step.
//
// The podcast «podcast-menu», the episode menu and the tag-backups menu are
// driven for real by podcast_screens_test.dart and tag_write_options_test.dart
// (heard, unsubscribe, restore, delete); here only their value lists are
// pinned. Of the other menus, one item is driven (named in each test) and the
// rest are only listed.
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/podcast_repository.dart';
import 'package:codecore/providers/podcast_providers.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/podcast/episode_downloader.dart';
import 'package:codecore/services/podcast/podcast_models.dart';
import 'package:codecore/services/podcast/podcast_service.dart';
import 'package:codecore/services/tags/tag_backups.dart';
import 'package:codecore/services/tags/tag_reader.dart';
import 'package:codecore/ui/screens/cleanup/tag_backups_screen.dart';
import 'package:codecore/ui/screens/podcast/podcast_detail_screen.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:path/path.dart' as p;
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/smart_playlist_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/ui/screens/library/album_detail_screen.dart';
import 'package:codecore/ui/screens/library/folders_sheet.dart';
import 'package:codecore/ui/screens/library/library_screen.dart';
import 'package:codecore/ui/screens/playlists/playlist_detail_screen.dart';
import 'package:codecore/ui/screens/settings/missing_tracks_screen.dart';
import 'package:codecore/ui/screens/smart/smart_playlist_screen.dart';
import 'package:codecore/ui/shell/desktop_sidebar.dart';
import 'package:drift/drift.dart'
    show BooleanExpressionOperators, OrderingTerm, Value;
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/selection_providers.dart';
import 'package:codecore/providers/sleep_timer_provider.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/ui/screens/jam/jam_screen.dart';
import 'package:codecore/ui/screens/library/favorites_screen.dart';
import 'package:codecore/ui/screens/library/library_toolbar.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_screen.dart';
import 'package:codecore/ui/screens/now_playing/queue_sheet.dart';
import 'package:codecore/ui/screens/now_playing/suggestions_screen.dart';
import 'package:codecore/ui/widgets/selection_bar.dart';
import 'package:codecore/ui/widgets/track_actions.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:codecore/ui/widgets/track_row_selection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/menu_support.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

// ---- How a menu is opened and read: the ONLY part phase 61 changes. ----

/// The entries shown now, in order (PopupMenu or action sheet).
List<String> _shown(WidgetTester tester) => shownMenuEntries(
  tester,
  named: (v) => v is TrackAction ? v.label : menuEntryName(v, null),
);

/// Opens the menu behind [button] and returns its entries, in order.
Future<List<String>> _open(WidgetTester tester, Finder button) async {
  await tester.tap(button);
  await _settle(tester);
  return _shown(tester);
}

/// Right click on [target] (desktop context menu) and returns the entries.
Future<List<String>> _openContext(WidgetTester tester, Finder target) async {
  final g = await tester.startGesture(
    tester.getCenter(target),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await g.up();
  await _settle(tester);
  return _shown(tester);
}

/// Taps the entry named [label] in the menu now open.
Future<void> _choose(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await _settle(tester);
}

Future<List<Track>> _tracks(WidgetTester tester, Harness h) async =>
    (await tester.runAsync(
      () => (h.db.select(
        h.db.tracks,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get(),
    ))!;

Future<List<String>> _playlistNames(WidgetTester tester, Harness h) async =>
    (await tester.runAsync(
      () async => [
        for (final p in await h.db.select(h.db.playlists).get()) p.name,
      ],
    ))!;

class _Web implements WebClient {
  @override
  Future<Object?> getJson(
    String url, {
    Map<String, String>? query,
    CancelToken? cancel, bool strict = false,
  }) async => null;
  @override
  Future<List<int>?> getBytes(
    String url, {
    int maxBytes = 5 * 1024 * 1024,
    CancelToken? cancel,
  }) async => null;
}

class _NoTags implements TagReader {
  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async =>
      const TagInfo();
}

class _FakeStore extends TagBackupStore {
  _FakeStore(this.items) : super(Directory.systemTemp);
  final List<TagBackup> items;
  @override
  Future<List<TagBackup>> list() async => List.of(items);
}


const _selKey = 'menus-sel';

class _SelPage extends ConsumerWidget {
  const _SelPage(this.tracks);
  final List<Track> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = [for (final t in tracks) t.id];
    final active = ref.watch(
      selectionProvider(_selKey).select((s) => s.active),
    );
    return SelectionScope(
      listKey: _selKey,
      visibleIds: ids,
      child: Scaffold(
        appBar: active
            ? SelectionBar(listKey: _selKey, tracks: tracks)
            : AppBar(title: const Text('List')),
        body: ListView(
          children: [
            for (final t in tracks)
              SizedBox(
                height: 64,
                child: LiveTrackRow(
                  track: t,
                  onTap: () {},
                  selection: RowSelection(listKey: _selKey, visibleIds: ids),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FakeJam extends JamController {
  _FakeJam(this.initial);
  final JamUiState initial;
  final sent = <JamCommand>[];
  @override
  JamUiState build() => initial;
  @override
  Future<JamError?> send(JamCommand cmd) async {
    sent.add(cmd);
    return null;
  }
}

JamUiState _jam({required bool host}) => JamUiState(
  phase: JamPhase.active,
  role: host ? JamRole.host : JamRole.guest,
  peerName: 'Telefono',
  jam: const JamState(
    version: 3,
    items: [
      JamItem(id: 1, ownerDeviceId: 'host', title: 'Prima', ext: 'mp3'),
      JamItem(
        id: 2,
        ownerDeviceId: 'peer',
        title: 'Seconda',
        ext: 'mp3',
        artist: 'Band',
      ),
    ],
    currentIndex: 0,
    hostDeviceId: 'host',
    outputDeviceId: 'host',
  ),
);

// ---- Expected entries, in order: they stay the same in phase 61. ----
const _newMenu = ['create', 'smart', 'csv'];
const _sleepIdle = ['15', '30', '45', '60', '-1'];
const _sleepActive = ['15', '30', '45', '60', '-1', '0'];
const _librarySort = ['recent', 'alpha', 'added'];
const _favoritesSort = [
  'defaultOrder', 'title', 'artist', 'album', 'year', 'addedAt', 'duration',
];
const _queueMenu = ['Suggeriti di recente'];
const _jamHostRow = ['Salta qui', 'Vai all’artista', 'Rimuovi'];
const _jamGuestRow = ['Salta qui', 'Vai all’artista'];
// The context menu has the actions of the sheet, without its header; "Mostra nella cartella" is desktop-only (the test runs on Linux, like the CI).
const _contextMenu = [
  'Anteprima 20 s',
  'Riproduci dopo',
  'Aggiungi in coda',
  'Preferito',
  'Aggiungi a playlist…',
  'Etichette…',
  'Vai all’album',
  'Vai all’artista',
  'Artista su YouTube Music',
  'Cambia copertina',
  'Modifica info',
  'Cerca info sul web',
  'Condividi…',
  'Dettagli',
  'Mostra nella cartella',
  'Elimina dal dispositivo',
];
const _selectionMenu = [
  'Riproduci',
  'Riproduci dopo',
  'Aggiungi in coda',
  'Aggiungi ai preferiti',
  'Aggiungi a playlist…',
  'Aggiungi etichetta…',
  'Togli etichetta…',
  'Sposta in un nuovo album…',
  'Elimina dal dispositivo',
];

void main() {
  testWidgets(
    'desktop sidebar «+»: new, smart, csv; «new» asks a name and creates the playlist',
    (tester) async {
      _phone(tester);
      final h = await Harness.create(tester);
      await h.pump(
        tester,
        const Scaffold(
          body: SizedBox(width: 280, child: DesktopSidebar(collapsed: false)),
        ),
      );
      await _settle(tester);
      expect(await _open(tester, find.byTooltip('Nuova playlist')), _newMenu);
      await tester.tap(find.text('Nuova playlist').last);
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'Dal menu');
      await tester.tap(find.text('Crea'));
      await _settle(tester);
      expect(await _playlistNames(tester, h), ['Dal menu']);
      await h.dispose(tester);
    },
  );

  testWidgets(
    'library «+»: the same three values as the sidebar; «new» creates the playlist',
    (tester) async {
      _phone(tester);
      final h = await Harness.create(tester);
      await h.pump(tester, const Scaffold(body: LibraryScreen()));
      await _settle(tester);
      expect(await _open(tester, find.byTooltip('Nuova playlist')), _newMenu);
      await tester.tap(find.text('Nuova playlist').last);
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'Dalla libreria');
      await tester.tap(find.text('Crea'));
      await _settle(tester);
      expect(await _playlistNames(tester, h), ['Dalla libreria']);
      await h.dispose(tester);
    },
  );

  testWidgets(
    'library «more»: folders, scan, share, exportAll; «folders» opens the sheet',
    (tester) async {
      _phone(tester);
      final h = await Harness.create(tester);
      await h.pump(tester, const Scaffold(body: LibraryScreen()));
      await _settle(tester);
      expect(await _open(tester, find.byTooltip('Altre azioni')), [
        'folders',
        'scan',
        'share',
        'exportAll',
      ]);
      await tester.tap(find.text('Cartelle musicali'));
      await _settle(tester);
      expect(find.byType(FoldersSheet), findsOneWidget);
      await h.dispose(tester);
    },
  );

  testWidgets(
    'playlist page: edit, add, cover, export, rename, delete («clear» only with a custom cover); «rename» renames',
    (tester) async {
      _phone(tester);
      final h = await Harness.create(tester, tracks: 2);
      final playlist = (await tester.runAsync(() async {
        final repo = PlaylistRepository(h.db);
        final id = await repo.create('Notte');
        await repo.addTracks(id, [1, 2]);
        return (await h.db.select(h.db.playlists).get()).single;
      }))!;
      await h.pump(tester, PlaylistDetailScreen(playlist: playlist));
      await _settle(tester);
      expect(await _open(tester, find.byTooltip('Altre azioni')), [
        'edit',
        'add',
        'cover',
        'export',
        'rename',
        'delete',
      ]);
      await tester.tap(find.text('Rinomina'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'Giorno');
      await tester.tap(find.text('Salva'));
      await _settle(tester);
      expect(await _playlistNames(tester, h), ['Giorno']);
      expect(find.text('Giorno'), findsWidgets);
      await h.dispose(tester);
    },
  );

  testWidgets(
    'album page: queue, playlist, share, enrich, cover, merge; «queue» adds the album and says so',
    (tester) async {
      _phone(tester);
      final h = await Harness.create(tester, tracks: 4);
      final album = (await tester.runAsync(
        () => LibraryQueries(h.db).watchAlbums().first,
      ))!.firstWhere((a) => a.title == 'Album 0');
      await h.pump(tester, AlbumDetailScreen(album: album));
      await _settle(tester);
      expect(await _open(tester, find.byTooltip('Altre azioni')), [
        'queue',
        'playlist',
        'share',
        'enrich',
        'cover',
        'merge',
      ]);
      await tester.tap(find.text('Aggiungi in coda'));
      await _settle(tester);
      expect(find.text('Aggiunto in coda'), findsOneWidget);
      expect(h.handler.queueIds, hasLength(2));
      await h.dispose(tester);
    },
  );

  testWidgets('smart playlist page: edit, convert, delete', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 2);
    final id = (await tester.runAsync(
      () => SmartPlaylistRepository(h.db, TrackRepository(h.db)).create(
        name: 'Tutti',
        rules: 'artista:artist',
        sort: SmartSort.title,
        limit: null,
      ),
    ))!;
    await h.pump(tester, SmartPlaylistScreen(id: id));
    await _settle(tester);
    expect(await _open(tester, find.byTooltip('Altre azioni')), [
      'edit',
      'convert',
      'delete',
    ]);
    await h.dispose(tester);
  });

  testWidgets(
    'missing tracks, row menu: ignore, remove; «ignore» hides the row and keeps the track',
    (tester) async {
      _phone(tester);
      final h = await Harness.create(tester, tracks: 2);
      final rows = await _tracks(tester, h);
      await tester.runAsync(
        () => TrackRepository(h.db).markMissing({rows[0].path}, true),
      );
      await h.pump(tester, const MissingTracksScreen());
      await _settle(tester);
      expect(find.text('Song 0'), findsOneWidget);
      expect(
        await _open(
          tester,
          menuButton(),
        ),
        ['ignore', 'remove'],
      );
      await tester.tap(find.text('Ignora'));
      await _settle(tester);
      expect(find.text('Song 0'), findsNothing);
      expect(
        (await _tracks(tester, h)),
        hasLength(2),
        reason: 'only hidden from this list',
      );
      await h.dispose(tester);
    },
  );

  testWidgets(
    'podcast page «podcast-menu» and the episode menus: unsubscribe; heard (+ delete once downloaded)',
    (tester) async {
      _phone(tester);
      final h = await Harness.create(tester, tracks: 1);
      final dir = Directory.systemTemp.createTempSync('menus');
      addTearDown(() => dir.deleteSync(recursive: true));
      final base = p.join(dir.path, 'podcasts');
      final repo = PodcastRepository(h.db);
      final service = PodcastService(
        repo: repo,
        fetch: (url) async => url,
        parse: (text) async => throw const FormatException('not rss'),
        web: _Web(),
        podcastsDir: base,
        now: () => DateTime.utc(2026, 10, 17, 12),
      );
      final pid = (await tester.runAsync(() async {
        final id = await repo.subscribe(
          'https://x/feed',
          PodcastFeed(
            title: 'Show',
            episodes: [
              for (final g in ['1', '2'])
                PodcastEpisodeInfo(
                  guid: g,
                  title: 'Ep $g',
                  audioUrl: 'https://x/$g.mp3',
                  duration: const Duration(minutes: 20),
                ),
            ],
          ),
          now: 1,
        );
        final e =
            await (h.db.select(h.db.podcastEpisodes)
                  ..where((x) => x.podcastId.equals(id) & x.guid.equals('2')))
                .getSingle();
        final file = File(p.join(base, '$id', '2.mp3'))
          ..createSync(recursive: true)
          ..writeAsBytesSync([1, 2, 3]);
        final t = await h.db
            .into(h.db.tracks)
            .insert(
              TracksCompanion.insert(
                path: file.path,
                title: 'Ep 2',
                albumKey: 'podcast|$id',
                format: 'mp3',
                sizeBytes: 3,
                mtimeMs: 1,
                addedAt: 1,
                durationMs: const Value(1200000),
                kind: const Value(1),
              ),
            );
        await repo.setTrackId(e.id, t);
        return id;
      }))!;
      await h.pump(
        tester,
        PodcastDetailScreen(podcastId: pid),
        extraOverrides: [
          podcastServiceProvider.overrideWithValue(service),
          podcastsDirProvider.overrideWith((ref) async => base),
          episodeDownloaderProvider.overrideWith(
            (ref) async => EpisodeDownloader(
              repo: repo,
              tracks: TrackRepository(h.db),
              tags: _NoTags(),
              baseDir: base,
              readTagsInIsolate: false,
            ),
          ),
        ],
      );
      await _settle(tester);
      expect(await _open(tester, find.byKey(const ValueKey('podcast-menu'))), [
        'unsubscribe',
      ]);
      await tester.tapAt(const Offset(5, 5));
      await _settle(tester);
      final eps = await tester.runAsync(
        () => h.db.select(h.db.podcastEpisodes).get(),
      );
      final by = {for (final e in eps!) e.guid: e.id};
      expect(await _open(tester, find.byKey(ValueKey('menu-${by['1']}'))), [
        'heard',
      ], reason: 'not downloaded');
      await tester.tapAt(const Offset(5, 5));
      await _settle(tester);
      expect(await _open(tester, find.byKey(ValueKey('menu-${by['2']}'))), [
        'heard',
        'delete',
      ], reason: 'downloaded');
      await h.dispose(tester);
    },
  );

  testWidgets('tag backups row menu: restore, delete', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester);
    final store = _FakeStore([
      TagBackup(
        id: '1',
        path: '/m/song.mp3',
        createdAt: DateTime(2026, 10, 19),
        sizeBytes: 1024,
      ),
    ]);
    await h.pump(
      tester,
      const TagBackupsScreen(),
      extraOverrides: [
        tagBackupStoreProvider.overrideWith((ref) async => store),
      ],
    );
    await _settle(tester);
    expect(
      await _open(tester, menuButton()),
      ['restore', 'delete'],
    );
    await h.dispose(tester);
  });

  testWidgets('sleep timer (moon): 15/30/45/60/end of track; «15» starts it, then «cancel» appears', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 2);
    final rows = await _tracks(tester, h);
    await tester.runAsync(() => h.handler.playQueue([rows.first.id], 0));
    await h.pump(tester, const NowPlayingScreen(desktop: false));
    await _settle(tester);
    final chip = find.byKey(const Key('np-sleep-chip'));
    expect(await _open(tester, chip), _sleepIdle);
    await _choose(tester, '15 minuti');
    final c = ProviderScope.containerOf(tester.element(chip));
    expect(c.read(sleepTimerProvider).endsAt, isNotNull);
    expect(await _open(tester, chip), _sleepActive);
    await _choose(tester, 'Annulla timer');
    expect(c.read(sleepTimerProvider).active, isFalse);
    await h.dispose(tester);
  });

  testWidgets('library sort: recent, alpha, added; «A–Z» becomes the shown order', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 2);
    await h.pump(tester, const Scaffold(body: LibraryScreen()));
    await _settle(tester);
    expect(await _open(tester, find.text('Ascoltati di recente')), _librarySort);
    await _choose(tester, 'A–Z');
    expect(
      find.descendant(
        of: find.byType(LibraryToolbar),
        matching: find.text('A–Z'),
      ),
      findsOneWidget,
    );
    await h.dispose(tester);
  });

  testWidgets('library sort: the current order is marked in the sheet', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 2);
    await h.pump(tester, const Scaffold(body: LibraryScreen()));
    await _settle(tester);
    await tester.tap(find.text('Ascoltati di recente'));
    await _settle(tester);
    final marked = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byWidgetPredicate((w) => w is ListTile && w.selected),
    );
    expect(marked, findsOneWidget);
    expect(
      find.descendant(of: marked, matching: find.text('Ascoltati di recente')),
      findsOneWidget,
    );
    await h.dispose(tester);
  });

  testWidgets('favourites sort: seven orders; «Titolo» sets the query sort', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 2);
    await h.pump(tester, const FavoritesScreen());
    await _settle(tester);
    expect(await _open(tester, find.byTooltip('Ordina per')), _favoritesSort);
    await _choose(tester, 'Titolo');
    final c = ProviderScope.containerOf(tester.element(find.byType(FavoritesScreen)));
    expect(c.read(trackQueryProvider(true)).sort, SortOption.title);
    await h.dispose(tester);
  });

  testWidgets('desktop right click on a row (showTrackContextMenu): same actions as the sheet; first one is driven', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 2);
    final rows = await _tracks(tester, h);
    await h.pump(tester, _SelPage(rows));
    await _settle(tester);
    final labels = await _openContext(tester, find.text('Song 0'));
    expect(labels, _contextMenu);
    await _choose(tester, 'Aggiungi in coda');
    expect(h.handler.queueIds, [rows[0].id]);
    await h.dispose(tester);
  });

  testWidgets('selection bar ⋮: the bulk actions of the picked rows; «Aggiungi in coda» queues them', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 4);
    final rows = await _tracks(tester, h);
    await h.pump(tester, _SelPage(rows));
    await _settle(tester);
    await tester.longPress(find.text('Song 0'));
    await _settle(tester);
    await tester.tap(find.text('Song 2'));
    await _settle(tester);
    expect(find.text('2 selezionati'), findsOneWidget);
    expect(await _open(tester, find.byTooltip('Azioni')), _selectionMenu);
    await _choose(tester, 'Aggiungi in coda');
    expect(h.handler.queueIds, [rows[0].id, rows[2].id]);
    await h.dispose(tester);
  });

  testWidgets('queue sheet: direct button «Suggeriti di recente» (no menu), opens the suggestions page', (tester) async {
    _phone(tester);
    final h = await Harness.create(tester, tracks: 3);
    final rows = await _tracks(tester, h);
    await tester.runAsync(() => h.handler.playQueue([for (final t in rows) t.id], 0));
    final sc = ScrollController();
    addTearDown(sc.dispose);
    await h.pump(tester, Scaffold(body: QueueSheet(scrollController: sc)));
    await _settle(tester);
    expect(find.byType(PopupMenuButton), findsNothing);
    expect(
      find.widgetWithText(TextButton, _queueMenu.single),
      findsOneWidget,
    );
    await _choose(tester, _queueMenu.single);
    expect(find.byType(SuggestionsScreen), findsOneWidget);
    await h.dispose(tester);
  });

  for (final host in [true, false]) {
    testWidgets('jam queue row ⋮ as ${host ? 'host' : 'guest'}: ${host ? 'jump, artist, remove' : 'jump, artist'}; «Salta qui» sends jump', (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester);
      final fake = _FakeJam(_jam(host: host));
      await h.pump(
        tester,
        const JamScreen(),
        extraOverrides: [
          jamProvider.overrideWith(() => fake),
          jamTrackCoverProvider.overrideWith((ref, id) async => null),
        ],
      );
      // The shared queue opens from «Coda».
      await tester.tap(find.text('Coda'));
      await _settle(tester);
      expect(
        await _open(tester, find.byTooltip('Altre azioni').last),
        host ? _jamHostRow : _jamGuestRow,
      );
      await _choose(tester, 'Salta qui');
      expect(fake.sent.single.type, JamCommandType.jump);
      expect(fake.sent.single.itemId, 2);
      await h.dispose(tester);
    });
  }
}
