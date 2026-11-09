import 'dart:convert';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/podcast_repository.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/podcast/feed_fetcher.dart';
import 'package:codecore/services/podcast/podcast_models.dart';
import 'package:codecore/services/podcast/podcast_service.dart';
import 'package:codecore/services/online/innertube_client.dart';
import 'package:codecore/services/online/ytm_podcasts.dart';
import 'package:codecore/services/podcast/ytm_podcast_sync.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _Web implements WebClient {
  Object? json;
  final queries = <Map<String, String>?>[];

  @override
  Future<Object?> getJson(
    String url, {
    Map<String, String>? query,
    CancelToken? cancel,
    bool strict = false,
  }) async {
    queries.add(query);
    return json;
  }

  @override
  Future<List<int>?> getBytes(
    String url, {
    int maxBytes = 5 * 1024 * 1024,
    CancelToken? cancel,
  }) async => null;
}

PodcastEpisodeInfo _ep(String guid) => PodcastEpisodeInfo(
  guid: guid,
  title: 'Ep $guid',
  audioUrl: 'https://x/$guid.mp3',
);

class _Ytm implements HttpClientAdapter {
  _Ytm(this.page);
  final Map page;
  final Map more = jsonDecode(
    File('test/fixtures/innertube/ytm_podcast_show_more.json')
        .readAsStringSync(),
  ) as Map;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<List<int>>? r,
    Future<void>? c,
  ) async => ResponseBody.fromString(
    jsonEncode((o.data as Map).containsKey('continuation') ? more : page),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase db;
  late PodcastRepository repo;
  late _Web web;
  late DateTime clock;
  // What each address "serves": the parsed feed, or an exception to throw.
  final feeds = <String, Object>{};
  final fetched = <String>[];
  final covers = <String>[];

  YtmPodcastSync? ytm;

  PodcastService build({bool withCovers = true}) => PodcastService(
    repo: repo,
    ytm: ytm,
    fetch: (url) async {
      fetched.add(url);
      final f = feeds[url];
      if (f is Exception) throw f;
      return url; // the "text" is the address: the parser looks it up
    },
    parse: (text) async {
      final f = feeds[text];
      if (f is PodcastFeed) return f;
      throw const FormatException('not rss');
    },
    web: web,
    saveCover: withCovers
        ? (id, url) async {
            covers.add('$id:$url');
            return 'cover$id';
          }
        : null,
    searchLimiter: RateLimiter(minGap: Duration.zero),
    now: () => clock,
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PodcastRepository(db);
    web = _Web();
    clock = DateTime.utc(2026, 10, 17, 12);
    feeds.clear();
    fetched.clear();
    covers.clear();
    ytm = null;
  });
  tearDown(() => db.close());

  group('subscribing', () {
    test(
      'saves the show, the episodes and the cover; the address is normalised',
      () async {
        feeds['https://x.org/feed'] = PodcastFeed(
          title: 'Show',
          imageUrl: 'https://x.org/c.jpg',
          episodes: [_ep('a'), _ep('b')],
        );
        final id = await build().subscribeFromUrl('  feed://x.org/feed  ');

        expect(fetched, ['https://x.org/feed']);
        final p = (await repo.byId(id))!;
        expect(p.title, 'Show');
        expect(p.feedUrl, 'https://x.org/feed');
        expect(p.coverKey, 'cover$id');
        expect(covers, ['$id:https://x.org/c.jpg']);
        expect(p.lastCheckedAt, clock.millisecondsSinceEpoch);
        expect(await repo.watchEpisodes(id).first, hasLength(2));
      },
    );

    test(
      'subscribing twice is one podcast, and the cover is fetched once',
      () async {
        feeds['https://x.org/feed'] = PodcastFeed(
          title: 'Show',
          imageUrl: 'https://x.org/c.jpg',
          episodes: [_ep('a')],
        );
        final svc = build();
        final a = await svc.subscribeFromUrl('https://x.org/feed');
        final b = await svc.subscribeFromUrl('https://x.org/feed');
        expect(b, a);
        expect(covers, hasLength(1));
      },
    );

    test('a cover that fails does not fail the subscription', () async {
      feeds['https://x.org/feed'] = PodcastFeed(
        title: 'Show',
        imageUrl: 'https://x.org/c.jpg',
        episodes: const [],
      );
      final svc = PodcastService(
        repo: repo,
        fetch: (u) async => u,
        parse: (t) async => feeds[t]! as PodcastFeed,
        web: web,
        saveCover: (id, url) async => throw StateError('disk full'),
      );
      final id = await svc.subscribeFromUrl('https://x.org/feed');
      expect((await repo.byId(id))!.coverKey, isNull);
    });

    test(
      'a bare host is read as https; anything that is not http(s) is refused',
      () async {
        expect(
          PodcastService.normalizeUrl('feeds.example.com/rss'),
          'https://feeds.example.com/rss',
        );
        expect(PodcastService.normalizeUrl('http://a.org/x'), 'http://a.org/x');
        expect(
          PodcastService.normalizeUrl('feed:https://a.org/x'),
          'https://a.org/x',
        );
        for (final bad in [
          'ftp://a.org/x',
          'file:///etc/passwd',
          'javascript:alert(1)',
          'not a url',
          '',
          'https://',
        ]) {
          expect(
            () => PodcastService.normalizeUrl(bad),
            throwsA(
              isA<PodcastException>().having(
                (e) => e.kind,
                'kind',
                PodcastErrorKind.invalidUrl,
              ),
            ),
            reason: bad,
          );
        }
      },
    );

    test(
      'a broken or missing feed gives a readable error and saves nothing',
      () async {
        final svc = build();
        feeds['https://x.org/html'] = const PodcastFeed(
          title: 'x',
          episodes: [],
        );
        feeds.remove('https://x.org/html'); // the parser will say «not rss»
        await expectLater(
          svc.subscribeFromUrl('https://x.org/html'),
          throwsA(
            isA<PodcastException>().having(
              (e) => e.kind,
              'kind',
              PodcastErrorKind.notFeed,
            ),
          ),
        );
        feeds['https://x.org/down'] = const SocketException('unreachable');
        await expectLater(
          svc.subscribeFromUrl('https://x.org/down'),
          throwsA(
            isA<PodcastException>().having(
              (e) => e.kind,
              'kind',
              PodcastErrorKind.network,
            ),
          ),
        );
        feeds['https://x.org/big'] = const PodcastException(
          PodcastErrorKind.tooLarge,
          '30 MB',
        );
        await expectLater(
          svc.subscribeFromUrl('https://x.org/big'),
          throwsA(
            isA<PodcastException>().having(
              (e) => e.kind,
              'kind',
              PodcastErrorKind.tooLarge,
            ),
          ),
        );
        expect(await repo.all(), isEmpty);
      },
    );
  });

  group('refreshing', () {
    test('adds only the new episodes and notes the time', () async {
      feeds['https://x.org/feed'] = PodcastFeed(
        title: 'Show',
        episodes: [_ep('a')],
      );
      final svc = build();
      final id = await svc.subscribeFromUrl('https://x.org/feed');
      feeds['https://x.org/feed'] = PodcastFeed(
        title: 'Show',
        episodes: [_ep('a'), _ep('b'), _ep('c')],
      );
      clock = clock.add(const Duration(hours: 10));

      expect(await svc.refresh(id), 2);
      expect(
        (await repo.byId(id))!.lastCheckedAt,
        clock.millisecondsSinceEpoch,
      );
      expect(await svc.refresh(id), 0);
    });

    test('only when stale: nothing is asked of the network for a podcast checked an hour ago', () async {
      feeds['https://x.org/feed'] = PodcastFeed(
        title: 'Show',
        episodes: [_ep('a')],
      );
      final svc = build();
      final id = await svc.subscribeFromUrl('https://x.org/feed');
      fetched.clear();

      clock = clock.add(const Duration(hours: 1));
      expect(await svc.refreshIfStale(id), isNull);
      expect(fetched, isEmpty);

      clock = clock.add(const Duration(hours: 6));
      feeds['https://x.org/feed'] = PodcastFeed(
        title: 'Show',
        episodes: [_ep('a'), _ep('b')],
      );
      expect(await svc.refreshIfStale(id), 1);
      expect(fetched, hasLength(1));
    });

    test(
      'a podcast never checked is refreshed; an unknown id does nothing',
      () async {
        feeds['https://x.org/feed'] = PodcastFeed(
          title: 'Show',
          episodes: const [],
        );
        final svc = build();
        final id = await svc.subscribeFromUrl('https://x.org/feed');
        await db.customUpdate('UPDATE podcasts SET last_checked_at = NULL');
        fetched.clear();
        expect(await svc.refreshIfStale(id), 0);
        expect(fetched, hasLength(1));
        expect(await svc.refresh(9999), 0);
        expect(await svc.refreshIfStale(9999), isNull);
      },
    );

    test(
      'refreshAll goes one by one and a failure does not stop the others',
      () async {
        feeds['https://a.org/f'] = PodcastFeed(
          title: 'A',
          episodes: [_ep('1')],
        );
        feeds['https://b.org/f'] = PodcastFeed(
          title: 'B',
          episodes: [_ep('1')],
        );
        feeds['https://c.org/f'] = PodcastFeed(
          title: 'C',
          episodes: [_ep('1')],
        );
        final svc = build();
        final a = await svc.subscribeFromUrl('https://a.org/f');
        final b = await svc.subscribeFromUrl('https://b.org/f');
        final c = await svc.subscribeFromUrl('https://c.org/f');
        feeds['https://a.org/f'] = PodcastFeed(
          title: 'A',
          episodes: [_ep('1'), _ep('2')],
        );
        feeds['https://b.org/f'] = const SocketException('down');
        feeds['https://c.org/f'] = PodcastFeed(
          title: 'C',
          episodes: [_ep('1'), _ep('2'), _ep('3')],
        );
        fetched.clear();

        final r = await svc.refreshAll();

        expect(fetched, [
          'https://a.org/f',
          'https://b.org/f',
          'https://c.org/f',
        ]);
        expect(r.added, {a: 1, c: 2});
        expect(r.failed.keys, [b]);
        expect(r.failed[b]!.kind, PodcastErrorKind.network);
        expect(r.totalAdded, 3);
      },
    );

    test(
      'refreshAll leaves a show that is only listened to (not followed) alone',
      () async {
        feeds['https://a.org/f'] = PodcastFeed(
          title: 'A',
          episodes: [_ep('1')],
        );
        feeds['https://b.org/f'] = PodcastFeed(
          title: 'B',
          episodes: [_ep('1')],
        );
        final svc = build();
        await svc.subscribeFromUrl('https://a.org/f');
        final b = await svc.subscribeFromUrl('https://b.org/f');
        await repo.setFollowed(b, false);
        fetched.clear();
        final r = await svc.refreshAll();
        expect(fetched, ['https://a.org/f']);
        expect(r.failed, isEmpty);
      },
    );
  });

  group('YouTube Music shows', () {
    test('refresh and refreshAll read a YouTube Music show through its reader and leave the feed address alone', () async {
      final page = jsonDecode(
        File('test/fixtures/innertube/ytm_podcast_show.json')
            .readAsStringSync(),
      ) as Map;
      final dio = Dio(BaseOptions(validateStatus: (_) => true))
        ..httpClientAdapter = _Ytm(page);
      ytm = YtmPodcastSync(repo: repo, ytm: YtmPodcasts(InnerTubeClient(dio)));
      feeds['https://a.org/f'] = PodcastFeed(title: 'A', episodes: [_ep('1')]);
      final svc = build();
      final rss = await svc.subscribeFromUrl('https://a.org/f');
      final show = await ytm!.subscribe('MPSPPx');
      fetched.clear();
      feeds['https://a.org/f'] = PodcastFeed(
        title: 'A',
        episodes: [_ep('1'), _ep('2')],
      );

      final r = await svc.refreshAll();

      expect(fetched, [
        'https://a.org/f',
      ], reason: 'the YouTube Music show is not fetched as a feed');
      expect(r.added, {rss: 1, show: 0});
      expect(r.failed, isEmpty);
    });

    test(
      'a YouTube Music show without a reader fails gently, the RSS ones go on',
      () async {
        final id = await repo.subscribe(
          'https://music.youtube.com/browse/MPSPPx',
          const PodcastFeed(title: 'Y', episodes: []),
          now: 1,
          source: kPodcastSourceYtm,
          sourceId: 'MPSPPx',
        );
        final r = await build().refreshAll();
        expect(r.failed[id]!.kind, PodcastErrorKind.network);
      },
    );
  });

  group('searching the directory', () {
    test('real answer: hits with feed, cover and count; asks for podcasts, ten at most', () async {
      web.json = jsonDecode(
        File('test/fixtures/itunes_podcast_search.json').readAsStringSync(),
      );
      final hits = await build().search('radiolab');

      expect(web.queries.single, {
        'media': 'podcast',
        'term': 'radiolab',
        'limit': '10',
      });
      expect(hits, hasLength(3));
      expect(hits.first.name, 'Radiolab');
      expect(hits.first.author, 'WNYC Studios');
      expect(hits.first.feedUrl, 'https://feeds.simplecast.com/EmVW7VGp');
      expect(hits.first.artworkUrl, startsWith('https://'));
      expect(hits.first.episodeCount, greaterThan(100));
    });

    test('a result without a feed address is dropped', () async {
      web.json = {
        'results': [
          {'collectionName': 'No feed', 'artistName': 'x'},
          {'collectionName': 'Empty feed', 'feedUrl': ''},
          {'collectionName': 'Blank feed', 'feedUrl': '  '},
          {
            'collectionName': 'Fine',
            'feedUrl': 'https://x/f',
            'artworkUrl100': 'https://x/a.jpg',
          },
        ],
      };
      final hits = await build().search('x');
      expect(hits.map((h) => h.name), ['Fine']);
      expect(
        hits.single.artworkUrl,
        'https://x/a.jpg',
        reason: 'the 100 px one when there is no 600',
      );
    });

    test(
      'a blank search asks nothing; an unreadable answer is a network error',
      () async {
        final svc = build();
        expect(await svc.search('   '), isEmpty);
        expect(web.queries, isEmpty);
        web.json = null;
        await expectLater(
          svc.search('x'),
          throwsA(
            isA<PodcastException>().having(
              (e) => e.kind,
              'kind',
              PodcastErrorKind.network,
            ),
          ),
        );
      },
    );
  });

  group('the real fetcher against a local server', () {
    late HttpServer server;
    final hits = <String>[];
    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      hits.clear();
      server.listen((req) async {
        hits.add('${req.uri.path} ${req.headers.value('user-agent')}');
        final res = req.response;
        switch (req.uri.path) {
          case '/ok':
            res.headers.contentType = ContentType(
              'application',
              'rss+xml',
              charset: 'utf-8',
            );
            res.write('<rss>perché</rss>');
          case '/missing':
            res.statusCode = 404;
          case '/big':
            res.write('x' * 5000);
          case '/redirect':
            res.statusCode = 302;
            res.headers.set('location', '/ok');
        }
        await res.close();
      });
    });
    tearDown(() => server.close(force: true));

    String url(String path) =>
        'http://${server.address.host}:${server.port}$path';

    test(
      'reads the text as UTF-8 (and follows a redirect), saying who it is',
      () async {
        final fetch = dioFeedFetcher();
        expect(await fetch(url('/ok')), '<rss>perché</rss>');
        expect(await fetch(url('/redirect')), '<rss>perché</rss>');
        expect(hits.first, contains('Codecore'));
      },
    );

    test('an error answer is a network error', () async {
      await expectLater(
        dioFeedFetcher()(url('/missing')),
        throwsA(
          isA<PodcastException>().having(
            (e) => e.kind,
            'kind',
            PodcastErrorKind.network,
          ),
        ),
      );
    });

    test('a feed past the limit is refused, declared or not', () async {
      await expectLater(
        dioFeedFetcher(maxBytes: 1000)(url('/big')),
        throwsA(
          isA<PodcastException>().having(
            (e) => e.kind,
            'kind',
            PodcastErrorKind.tooLarge,
          ),
        ),
      );
      expect(
        await dioFeedFetcher(maxBytes: 10000)(url('/big')),
        hasLength(5000),
      );
    });

    test('an unreachable server is a network error', () async {
      final dead = url('/ok');
      await server.close(force: true);
      await expectLater(
        dioFeedFetcher()(dead),
        throwsA(
          isA<PodcastException>().having(
            (e) => e.kind,
            'kind',
            PodcastErrorKind.network,
          ),
        ),
      );
    });
  });
}
