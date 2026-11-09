import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/podcast_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/podcast_discover_providers.dart';
import 'package:codecore/providers/podcast_providers.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/youtube_service.dart' show YtErrorKind;
import 'package:codecore/services/podcast/episode_downloader.dart';
import 'package:codecore/services/podcast/podcast_models.dart';
import 'package:codecore/services/podcast/podcast_service.dart';
import 'package:codecore/services/tags/tag_reader.dart';
import 'package:codecore/ui/screens/podcast/podcast_detail_screen.dart';
import 'package:codecore/ui/screens/podcast/podcasts_screen.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

class _Web implements WebClient {
  Object? json;
  @override
  Future<Object?> getJson(
    String url, {
    Map<String, String>? query,
    CancelToken? cancel,
    bool strict = false,
  }) async => json;
  @override
  Future<List<int>?> getBytes(
    String url, {
    int maxBytes = 5 * 1024 * 1024,
    CancelToken? cancel,
  }) async => null;
}

/// «Scopri» never asks the network in these tests (podcast_discover_test covers it).
final _noDiscover = [
  podcastGenresProvider.overrideWith((ref) async => const []),
  podcastChartProvider.overrideWith((ref, genre) async => const []),
];

class _NoTags implements TagReader {
  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async =>
      const TagInfo();
}

class _Downloads extends PodcastDownloadsNotifier {
  final added = <int>[];
  final cancelled = <int>[];
  List<EpisodeDownload> Function()? initial;
  @override
  List<EpisodeDownload> build() => initial?.call() ?? const [];
  @override
  void add(int episodeId, String title) => added.add(episodeId);
  @override
  void cancel(int episodeId) => cancelled.add(episodeId);
}

PodcastEpisodeInfo _ep(
  String guid,
  String title, {
  DateTime? at,
  int seconds = 1200,
}) => PodcastEpisodeInfo(
  guid: guid,
  title: title,
  audioUrl: 'https://x/$guid.mp3',
  publishedAt: at,
  duration: Duration(seconds: seconds),
);

void main() {
  late Harness h;
  late Directory dir;
  late String base;
  late PodcastRepository repo;
  late _Web web;
  late _Downloads downloads;
  late DateTime clock;
  final feeds = <String, PodcastFeed>{};
  final fetched = <String>[];

  late PodcastService service;

  /// Everything but the screen: the database is filled before the screen opens,
  /// because a write while a stream is listening waits for timers that only
  /// `pump` fires.
  Future<void> setup(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester, tracks: 2);
    dir = Directory.systemTemp.createTempSync('podui');
    addTearDown(() => dir.deleteSync(recursive: true));
    base = p.join(dir.path, 'podcasts');
    repo = PodcastRepository(h.db);
    web = _Web();
    downloads = _Downloads();
    clock = DateTime.utc(2026, 10, 17, 12);
    feeds.clear();
    fetched.clear();
    service = PodcastService(
      repo: repo,
      fetch: (url) async {
        fetched.add(url);
        return url;
      },
      parse: (text) async =>
          feeds[text] ?? (throw const FormatException('not rss')),
      web: web,
      podcastsDir: base,
      now: () => clock,
    );
  }

  Future<void> show(WidgetTester tester, Widget screen) async {
    await h.pump(
      tester,
      screen,
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
        podcastDownloadsProvider.overrideWith(() => downloads),
        ..._noDiscover,
      ],
    );
    await _settle(tester);
  }

  Future<void> open(WidgetTester tester, Widget screen) async {
    await setup(tester);
    await show(tester, screen);
  }

  Future<int> subscribe(
    String title,
    List<PodcastEpisodeInfo> eps, {
    String? author,
    String url = 'https://x/feed',
    int? checkedAt,
  }) async {
    final id = await repo.subscribe(
      url,
      PodcastFeed(title: title, author: author, episodes: eps),
      now: checkedAt ?? clock.millisecondsSinceEpoch,
    );
    return id;
  }

  /// Makes an episode "downloaded": a real file and a kind-1 track linked to it.
  Future<(int, String)> download(
    int podcastId,
    String guid, {
    int durationMs = 1200000,
    int? resumeMs,
  }) async {
    final e =
        await (h.db.select(h.db.podcastEpisodes)..where(
              (x) => x.podcastId.equals(podcastId) & x.guid.equals(guid),
            ))
            .getSingle();
    final file = File(p.join(base, '$podcastId', '$guid.mp3'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    final t = await h.db
        .into(h.db.tracks)
        .insert(
          TracksCompanion.insert(
            path: file.path,
            title: e.title,
            albumKey: 'podcast|$podcastId',
            format: 'mp3',
            sizeBytes: 3,
            mtimeMs: 1,
            addedAt: 1,
            artist: const Value('Show'),
            album: const Value('Show'),
            durationMs: Value(durationMs),
            resumePositionMs: Value(resumeMs),
            kind: const Value(1),
          ),
        );
    await repo.setTrackId(e.id, t);
    return (e.id, file.path);
  }

  group('the list', () {
    testWidgets(
      'empty: only «Scopri», nothing to refresh, and «+» offers to add one',
      (tester) async {
        await open(tester, const PodcastsScreen());
        expect(find.text('Podcast'), findsOneWidget);
        expect(find.text('I tuoi podcast'), findsNothing);
        expect(find.text('Scopri'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('refresh-all')),
          findsNothing,
          reason: 'nothing to refresh',
        );

        await tester.tap(find.byKey(const ValueKey('add-podcast')));
        await _settle(tester);
        expect(find.text('URL del feed'), findsOneWidget);
        expect(
          fetched,
          isEmpty,
          reason: 'opening anything asked nothing of the network',
        );
        await h.dispose(tester);
      },
    );

    testWidgets(
      '«I tuoi podcast»: a row by name, saying how many downloaded episodes wait, and the note that nothing updates by itself',
      (tester) async {
        await open(tester, const PodcastsScreen());
        final b = await subscribe(
          'beta show',
          [_ep('1', 'One'), _ep('2', 'Two')],
          author: 'Ann',
          url: 'https://x/b',
        );
        await subscribe('Alpha show', [_ep('1', 'Solo')], url: 'https://x/a');
        await download(b, '1');
        await show(tester, const PodcastsScreen());

        expect(find.text('I tuoi podcast'), findsOneWidget);
        expect(
          find.textContaining('I podcast si aggiornano solo quando lo chiedi.'),
          findsOneWidget,
        );
        final alpha = tester.getTopLeft(find.text('Alpha show')).dx;
        final beta = tester.getTopLeft(find.text('beta show')).dx;
        expect(alpha, lessThan(beta));
        expect(
          find.text('1 da ascoltare'),
          findsOneWidget,
          reason: 'only beta has a downloaded episode left',
        );
        await h.dispose(tester);
      },
    );

    testWidgets(
      '«Aggiorna tutti» refreshes each podcast and tells how many episodes came and what failed',
      (tester) async {
        await setup(tester);
        await subscribe('A', [_ep('1', 'One')], url: 'https://a/f');
        await subscribe('B', [_ep('1', 'One')], url: 'https://b/f');
        feeds['https://a/f'] = PodcastFeed(
          title: 'A',
          episodes: [_ep('1', 'One'), _ep('2', 'Two'), _ep('3', 'Three')],
        );
        // b has no feed prepared: the reader says «not rss».
        await show(tester, const PodcastsScreen());

        await tester.tap(find.byKey(const ValueKey('refresh-all')));
        await _settle(tester);
        for (var i = 0; i < 10 && fetched.length < 2; i++) {
          await _settle(tester);
        }

        expect(fetched, containsAll(['https://a/f', 'https://b/f']));
        expect(find.textContaining('2 episodi nuovi'), findsOneWidget);
        expect(find.textContaining('1 podcast non aggiornato'), findsOneWidget);
        expect(
          find.textContaining('Questo indirizzo non è un feed di podcast.'),
          findsOneWidget,
        );
        await h.dispose(tester);
      },
    );
  });

  group('subscribing', () {
    Future<void> openSheet(WidgetTester tester) async {
      await open(tester, const PodcastsScreen());
      await tester.tap(find.byKey(const ValueKey('add-podcast')));
      await _settle(tester);
    }

    testWidgets(
      'from an address: the show is saved, the sheet closes and a note says so',
      (tester) async {
        await openSheet(tester);
        feeds['https://feeds.example.org/show'] = PodcastFeed(
          title: 'My Show',
          episodes: [_ep('1', 'One')],
        );
        expect(
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('feed-go')))
              .onPressed,
          isNull,
          reason: 'nothing typed yet',
        );

        await tester.enterText(
          find.byKey(const ValueKey('feed-url')),
          'feeds.example.org/show',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('feed-go')));
        await _settle(tester);

        expect(fetched, ['https://feeds.example.org/show']);
        expect((await tester.runAsync(() => repo.all()))!.map((x) => x.title), [
          'My Show',
        ]);
        expect(
          find.text('URL del feed'),
          findsNothing,
          reason: 'the sheet closed',
        );
        expect(find.textContaining('Iscritto a'), findsOneWidget);
        await h.dispose(tester);
      },
    );

    testWidgets(
      'a wrong address and a page that is not a feed give a readable error and the sheet stays',
      (tester) async {
        await openSheet(tester);
        await tester.enterText(
          find.byKey(const ValueKey('feed-url')),
          'ftp://x/feed',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('feed-go')));
        await _settle(tester);
        expect(
          find.text('Questo non sembra un indirizzo web valido.'),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const ValueKey('feed-url')),
          'https://x/page.html',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('feed-go')));
        await _settle(tester);
        expect(
          find.text('Questo indirizzo non è un feed di podcast.'),
          findsOneWidget,
        );
        expect(find.text('URL del feed'), findsOneWidget);
        expect(await tester.runAsync(() => repo.all()), isEmpty);
        await h.dispose(tester);
      },
    );

    testWidgets('by name: the directory results can be picked', (tester) async {
      await openSheet(tester);
      web.json = {
        'results': [
          {
            'collectionName': 'Radiolab',
            'artistName': 'WNYC Studios',
            'feedUrl': 'https://feeds.simplecast.com/x',
            'trackCount': 871,
          },
          {'collectionName': 'No feed here'},
        ],
      };
      feeds['https://feeds.simplecast.com/x'] = PodcastFeed(
        title: 'Radiolab',
        episodes: [_ep('1', 'One')],
      );

      await tester.enterText(
        find.byKey(const ValueKey('podcast-search')),
        'radiolab',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);
      expect(find.text('Radiolab'), findsOneWidget);
      expect(find.text('No feed here'), findsNothing);
      expect(find.textContaining('WNYC Studios, 871 episodi'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('hit-https://feeds.simplecast.com/x')),
      );
      await _settle(tester);
      expect((await tester.runAsync(() => repo.all()))!.map((x) => x.title), [
        'Radiolab',
      ]);
      await h.dispose(tester);
    });

    testWidgets('a search with no results says so', (tester) async {
      await openSheet(tester);
      web.json = {'results': <Object>[]};
      await tester.enterText(
        find.byKey(const ValueKey('podcast-search')),
        'zzz',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);
      expect(find.text('Nessun podcast trovato'), findsOneWidget);
      await h.dispose(tester);
    });
  });

  group('one podcast', () {
    late int pid;
    final ids = <String, int>{};

    /// Subscribes, runs [seed] (downloads, heard marks...) and only then opens
    /// the page.
    Future<void> openDetail(
      WidgetTester tester, {
      int checkedHoursAgo = 1,
      Future<void> Function()? seed,
      List<PodcastEpisodeInfo>? episodes,
    }) async {
      await setup(tester);
      pid = await subscribe(
        'Show',
        episodes ??
            [
              _ep('new', 'Newest episode', at: DateTime.utc(2026, 10, 1)),
              _ep('mid', 'Middle episode', at: DateTime.utc(2026, 9, 1)),
              _ep('old', 'Oldest episode', at: DateTime.utc(2026, 8, 1)),
            ],
        author: 'Ann Author',
        checkedAt: clock.millisecondsSinceEpoch - checkedHoursAgo * 3600000,
      );
      for (final e in await h.db.select(h.db.podcastEpisodes).get()) {
        ids[e.guid] = e.id;
      }
      await seed?.call();
      await show(tester, PodcastDetailScreen(podcastId: pid));
    }

    testWidgets(
      'header and episodes newest first; opening it does not touch the network when it is fresh',
      (tester) async {
        await openDetail(tester);
        expect(find.text('Ann Author'), findsOneWidget);
        expect(find.textContaining('Aggiornato'), findsOneWidget);
        final y = [
          for (final t in [
            'Newest episode',
            'Middle episode',
            'Oldest episode',
          ])
            tester.getTopLeft(find.text(t)).dy,
        ];
        expect(y, orderedEquals([...y]..sort()));
        expect(fetched, isEmpty, reason: 'checked an hour ago: not stale');
        await h.dispose(tester);
      },
    );

    testWidgets(
      'a podcast not checked for over 6 hours refreshes when opened',
      (tester) async {
        await setup(tester);
        feeds['https://x/feed'] = PodcastFeed(
          title: 'Show',
          episodes: [_ep('a', 'A'), _ep('b', 'Brand new')],
        );
        pid = await subscribe('Show', [
          _ep('a', 'A'),
        ], checkedAt: clock.millisecondsSinceEpoch - 7 * 3600000);
        await show(tester, PodcastDetailScreen(podcastId: pid));
        for (
          var i = 0;
          i < 10 && find.text('Brand new').evaluate().isEmpty;
          i++
        ) {
          await _settle(tester);
        }
        expect(fetched, ['https://x/feed']);
        expect(find.text('Brand new'), findsOneWidget);
        await h.dispose(tester);
      },
    );

    testWidgets(
      'each episode says what it is: not downloaded, downloaded, left to hear, heard',
      (tester) async {
        await openDetail(
          tester,
          seed: () async {
            await download(pid, 'mid', resumeMs: 480000);
            await download(pid, 'old');
            await repo.markPlayed(ids['old']!, true, now: 1);
          },
        );

        expect(
          find.textContaining('Mancano circa 12 min'),
          findsOneWidget,
          reason: '20 min long, left at 8: 12 to go',
        );
        expect(find.byKey(ValueKey('play-${ids['mid']}')), findsOneWidget);
        expect(find.textContaining('Ascoltato'), findsOneWidget);
        expect(
          find.byKey(ValueKey('download-${ids['new']}')),
          findsOneWidget,
          reason: 'not downloaded: a download button',
        );
        expect(find.byKey(ValueKey('download-${ids['mid']}')), findsNothing);
        await h.dispose(tester);
      },
    );

    testWidgets(
      'a YouTube Music download failure speaks the YouTube words; «Riprova» only when trying again can help',
      (tester) async {
        await openDetail(
          tester,
          seed: () async {
            downloads.initial = () => [
              EpisodeDownload(
                episodeId: ids['new']!,
                title: 'x',
                status: EpisodeDownloadStatus.failed,
                error: PodcastErrorKind.network,
                ytError: YtErrorKind.unavailable,
              ),
            ];
          },
        );
        expect(find.textContaining('Video non disponibile'), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                find.byKey(ValueKey('download-${ids['new']}')),
              )
              .onPressed,
          isNull,
        );
        await h.dispose(tester);
      },
    );

    testWidgets('a YouTube Music network failure offers «Riprova»', (
      tester,
    ) async {
      await openDetail(
        tester,
        seed: () async {
          downloads.initial = () => [
            EpisodeDownload(
              episodeId: ids['new']!,
              title: 'x',
              status: EpisodeDownloadStatus.failed,
              error: PodcastErrorKind.network,
              ytError: YtErrorKind.network,
            ),
          ];
        },
      );
      final b = tester.widget<IconButton>(
        find.byKey(ValueKey('download-${ids['new']}')),
      );
      expect(b.onPressed, isNotNull);
      expect(b.tooltip, 'Riprova');
      await h.dispose(tester);
    });

    testWidgets('a rate-limited YouTube Music download can be retried', (
      tester,
    ) async {
      await openDetail(
        tester,
        seed: () async {
          downloads.initial = () => [
            EpisodeDownload(
              episodeId: ids['new']!,
              title: 'x',
              status: EpisodeDownloadStatus.failed,
              error: PodcastErrorKind.network,
              ytError: YtErrorKind.rateLimited,
            ),
          ];
        },
      );
      final b = tester.widget<IconButton>(
        find.byKey(ValueKey('download-${ids['new']}')),
      );
      expect(b.onPressed, isNotNull);
      expect(b.tooltip, 'Riprova');
      await h.dispose(tester);
    });

    testWidgets('«scarica» asks for the download', (tester) async {
      await openDetail(tester);
      await tester.tap(find.byKey(ValueKey('download-${ids['new']}')));
      await tester.pump();
      expect(downloads.added, [ids['new']]);
      await h.dispose(tester);
    });

    testWidgets(
      '«play» queues the downloaded episodes oldest first, from the tapped one, in the podcast\'s name',
      (tester) async {
        await openDetail(
          tester,
          seed: () async {
            await download(pid, 'old');
            await download(pid, 'mid');
            await download(pid, 'new');
          },
        );

        await tester.tap(find.byKey(ValueKey('play-${ids['mid']}')));
        await _settle(tester);

        expect(h.handler.currentTrack?.title, 'Middle episode');
        final titles = await tester.runAsync(
          () async => [
            for (final id in h.handler.queueIds)
              (await TrackRepository(h.db).getById(id))!.title,
          ],
        );
        expect(titles, ['Oldest episode', 'Middle episode', 'Newest episode']);
        final ctx = ProviderScope.containerOf(
          tester.element(find.byType(PodcastDetailScreen)),
        ).read(playContextProvider);
        expect(ctx?.kind, PlayContextKind.podcast);
        expect(ctx?.name, 'Show');
        await h.dispose(tester);
      },
    );

    testWidgets(
      'the ⋮ menu marks an episode as heard and back, and deletes its file but keeps it listed',
      (tester) async {
        late String path;
        await openDetail(
          tester,
          seed: () async {
            path = (await download(pid, 'mid')).$2;
          },
        );
        final epId = ids['mid']!;

        await tester.tap(find.byKey(ValueKey('menu-$epId')));
        await _settle(tester);
        await tester.tap(find.text('Segna come ascoltato'));
        await _settle(tester);
        expect(
          (await tester.runAsync(() => repo.episodeById(epId)))!.played,
          isTrue,
        );
        expect(find.textContaining('Ascoltato'), findsOneWidget);

        await tester.tap(find.byKey(ValueKey('menu-$epId')));
        await _settle(tester);
        expect(find.text('Segna come da ascoltare'), findsOneWidget);
        await tester.tap(find.text('Elimina il file'));
        for (var i = 0; i < 10 && File(path).existsSync(); i++) {
          await _settle(tester);
        }
        await _settle(tester);
        await _settle(tester);
        expect(File(path).existsSync(), isFalse);
        expect(
          find.text('Middle episode'),
          findsOneWidget,
          reason: 'still listed',
        );
        expect(find.byKey(ValueKey('play-$epId')), findsNothing);
        await h.dispose(tester);
      },
    );

    testWidgets('the cleaning setting is saved per podcast', (tester) async {
      await openDetail(tester);
      expect(
        (await tester.runAsync(() => repo.byId(pid)))!.autoDeleteDays,
        isNull,
      );
      await tester.tap(find.text('7 giorni'));
      await _settle(tester);
      expect((await tester.runAsync(() => repo.byId(pid)))!.autoDeleteDays, 7);
      await h.dispose(tester);
    });

    testWidgets(
      'unsubscribing asks first, then removes the show and its downloaded files',
      (tester) async {
        late String path;
        await openDetail(
          tester,
          seed: () async {
            path = (await download(pid, 'mid')).$2;
          },
        );

        await tester.tap(find.byKey(const ValueKey('podcast-menu')));
        await _settle(tester);
        await tester.tap(find.text('Elimina podcast'));
        await _settle(tester);
        expect(find.text('Eliminare il podcast?'), findsOneWidget);
        expect(find.textContaining('1 episodio scaricato'), findsOneWidget);
        await tester.tap(find.text('Annulla'));
        await _settle(tester);
        expect(
          (await tester.runAsync(() => repo.all()))!,
          hasLength(1),
          reason: 'cancelled: nothing happened',
        );

        await tester.tap(find.byKey(const ValueKey('podcast-menu')));
        await _settle(tester);
        await tester.tap(find.text('Elimina podcast'));
        await _settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Elimina podcast'));
        for (var i = 0; i < 10 && File(path).existsSync(); i++) {
          await _settle(tester);
        }
        expect(await tester.runAsync(() => repo.all()), isEmpty);
        expect(File(path).existsSync(), isFalse);
        final episodeTracks = await tester.runAsync(
          () => h.db
              .select(h.db.tracks)
              .get()
              .then((r) => r.where((t) => t.kind == 1).toList()),
        );
        expect(episodeTracks, isEmpty);
        await h.dispose(tester);
      },
    );
  });

  testWidgets(
    'the Library has a «Podcast» entry with the number of shows, which opens the section',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      h = await Harness.create(tester, tracks: 2);
      dir = Directory.systemTemp.createTempSync('podlib');
      addTearDown(() => dir.deleteSync(recursive: true));
      base = p.join(dir.path, 'podcasts');
      repo = PodcastRepository(h.db);
      await repo.subscribe(
        'https://x/a',
        const PodcastFeed(title: 'A', episodes: []),
        now: 1,
      );
      await repo.subscribe(
        'https://x/b',
        const PodcastFeed(title: 'B', episodes: []),
        now: 1,
      );
      await h.pump(
        tester,
        const AppShell(),
        extraOverrides: [
          podcastsDirProvider.overrideWith((ref) async => base),
          ..._noDiscover,
        ],
      );
      await tester.tap(find.text('Libreria'));
      await _settle(tester);

      expect(find.text('Podcast'), findsOneWidget);
      expect(find.bySemanticsLabel('Podcast, 2'), findsOneWidget);
      await tester.tap(find.text('Podcast'));
      await _settle(tester);
      expect(
        find.text('I podcast si aggiornano solo quando lo chiedi.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(PodcastsScreen),
          matching: find.text('A'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(PodcastsScreen),
          matching: find.text('B'),
        ),
        findsOneWidget,
      );
      await h.dispose(tester);
    },
  );
}
