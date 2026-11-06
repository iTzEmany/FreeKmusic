import 'dart:convert';
import 'dart:io';

import 'package:codecore/core/constants.dart' show kEnableYoutube;
import 'package:codecore/data/repositories/podcast_repository.dart';
import 'package:codecore/providers/podcast_providers.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/ytm_podcasts.dart';
import 'package:codecore/services/podcast/podcast_models.dart';
import 'package:codecore/services/podcast/podcast_service.dart';
import 'package:codecore/services/podcast/ytm_podcast_sync.dart';
import 'package:codecore/ui/screens/podcast/podcasts_screen.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Object _fixture(String name) => jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Object;

/// Answers by address: the Apple fixtures, or whatever a test put in [answers].
class _Web implements WebClient {
  final answers = <String, Object?>{};
  bool down = false;
  final asked = <String>[];

  @override
  Future<Object?> getJson(String url, {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async {
    asked.add(url);
    if (down) throw WebUnavailableException(url, 503);
    for (final e in answers.entries) {
      if (url.contains(e.key)) return e.value;
    }
    return switch (url) {
      final u when u.contains('ws/genres') => _fixture('apple_genres'),
      final u when u.contains('toppodcasts') => _fixture('apple_top_podcasts_it'),
      final u when u.contains('lookup') => _fixture('apple_lookup'),
      final u when u.contains('/search') => _fixture('apple_search_it_comedy'),
      _ => null,
    };
  }

  @override
  Future<List<int>?> getBytes(String url, {int maxBytes = 5 * 1024 * 1024, CancelToken? cancel}) async => null;
}

class _Ytm implements YtmPodcasts {
  var hits = <YtmShowHit>[];
  var asked = 0;
  bool fail = false;
  @override
  Future<List<YtmShowHit>> searchShows(String query, {String hl = 'en', CancelToken? cancel}) async {
    asked++;
    if (fail) throw StateError('down');
    return hits;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Sync implements YtmPodcastSync {
  _Sync(this.repo);
  @override
  final PodcastRepository repo;
  @override
  Future<int> subscribe(String showId) => repo.subscribe(
        'ytm:$showId',
        const PodcastFeed(title: 'Tintoria', author: 'OnePodcast - The Comedy Club', episodes: []),
        now: 1,
        source: kPodcastSourceYtm,
        sourceId: showId,
      );

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  late Harness h;
  late PodcastRepository repo;
  late _Web web;
  late _Ytm ytm;
  final feeds = <String, PodcastFeed>{};

  Future<void> open(WidgetTester tester, {Future<void> Function()? before}) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester, tracks: 1);
    repo = PodcastRepository(h.db);
    web = _Web();
    ytm = _Ytm();
    feeds.clear();
    await tester.runAsync(() async => before?.call());
    final service = PodcastService(
      repo: repo,
      fetch: (url) async => url,
      parse: (text) async => feeds[text] ?? (throw const FormatException('not rss')),
      web: web,
      searchLimiter: RateLimiter(minGap: Duration.zero),
    );
    await h.pump(tester, const PodcastsScreen(), extraOverrides: [
      podcastServiceProvider.overrideWithValue(service),
      ytmPodcastsProvider.overrideWithValue(ytm),
      ytmPodcastSyncProvider.overrideWithValue(_Sync(repo)),
    ]);
    await _settle(tester);
  }

  Future<void> search(WidgetTester tester, String term) async {
    await tester.tap(find.byKey(const ValueKey('podcast-lens')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), term);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _settle(tester);
  }

  Future<void> subscribeTo(String title, String author, {String url = 'https://x/f'}) =>
      repo.subscribe(url, PodcastFeed(title: title, author: author, episodes: const []), now: 1);

  group('Scopri', () {
    testWidgets('the Italian chart lists the shows; followed ones say «Iscritto», the others «Iscriviti»', (tester) async {
      await open(tester, before: () => subscribeTo('Lo Zoo di 105', 'Radio 105'));
      expect(find.text('Classifica italiana di Apple Podcasts'), findsOneWidget);
      expect(find.text('Tintoria'), findsOneWidget);
      expect(find.text('Iscritto'), findsOneWidget);
      expect(find.text('Iscriviti'), findsNWidgets(2));
      await h.dispose(tester);
    });

    testWidgets('a genre chip loads that genre chart', (tester) async {
      await open(tester);
      web.answers['genre=1303'] = {
        'feed': {
          'entry': {
            'id': {'attributes': {'im:id': '7'}},
            'im:name': {'label': 'Solo comici'},
            'im:artist': {'label': 'Qualcuno'},
          },
        },
      };
      expect(find.text('Comicità'), findsOneWidget, reason: 'Apple Comedy, in the app language');
      await tester.tap(find.byKey(const ValueKey('genre-1303')));
      await _settle(tester);
      expect(find.text('Solo comici'), findsOneWidget);
      expect(find.text('Lo Zoo di 105'), findsNothing);
      await h.dispose(tester);
    });

    testWidgets('«Iscriviti» on a chart row asks Apple for the feed, then subscribes', (tester) async {
      await open(tester);
      feeds['https://feeds.simplecast.com/EmVW7VGp'] = const PodcastFeed(title: 'Lo Zoo di 105', author: 'Radio 105', episodes: []);
      await tester.tap(find.byKey(const ValueKey('subscribe-apple-1591647170')));
      await _settle(tester);
      expect(web.asked.any((u) => u.contains('lookup')), isTrue);
      expect(find.byKey(const ValueKey('subscribed-apple-1591647170')), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('a chart that does not answer says so and «Riprova» brings it back', (tester) async {
      await open(tester);
      web.down = true;
      await tester.tap(find.byKey(const ValueKey('genre-1303')));
      await _settle(tester);
      expect(find.textContaining('La classifica non risponde'), findsOneWidget);
      expect(find.text('Riprova'), findsOneWidget);
      web.down = false;
      await tester.tap(find.text('Riprova'));
      await _settle(tester);
      expect(find.textContaining('La classifica non risponde'), findsNothing);
      expect(find.text('Lo Zoo di 105'), findsOneWidget);
      await h.dispose(tester);
    });
  });

  group('search', () {
    testWidgets('Apple and YouTube Music merged, one row per show, each with its origin', (tester) async {
      await open(tester);
      ytm.hits = const [
        YtmShowHit(id: 'MPSPa', title: 'tintoria!', author: 'OnePodcast - The Comedy Club'),
        YtmShowHit(id: 'MPSPb', title: 'Solo su YouTube', author: 'Rai'),
      ];
      await search(tester, 'tintoria');
      expect(find.text('Tintoria'), findsOneWidget, reason: 'same title and author: kept once');
      expect(find.text('Solo su YouTube'), findsOneWidget);
      expect(find.text('Apple Podcasts'), findsNWidgets(3));
      expect(find.text('YouTube Music'), findsOneWidget);
      await h.dispose(tester);
    }, skip: !kEnableYoutube);

    testWidgets('the same show twice keeps the one already followed', (tester) async {
      await open(tester, before: () async {
        await _Sync(repo).subscribe('MPSPa');
      });
      ytm.hits = const [YtmShowHit(id: 'MPSPa', title: 'Tintoria', author: 'OnePodcast - The Comedy Club')];
      await search(tester, 'tintoria');
      expect(find.byKey(const ValueKey('subscribed-ytm-MPSPa')), findsOneWidget);
      expect(find.text('Tintoria'), findsOneWidget);
      expect(find.text('Iscritto'), findsOneWidget);
      await h.dispose(tester);
    }, skip: !kEnableYoutube);

    testWidgets('a YouTube Music row subscribes through the YouTube Music sync and turns «Iscritto»', (tester) async {
      await open(tester);
      ytm.hits = const [YtmShowHit(id: 'MPSPz', title: 'Solo su YouTube', author: 'Rai')];
      await search(tester, 'rai');
      await tester.tap(find.byKey(const ValueKey('subscribe-ytm-MPSPz')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('subscribed-ytm-MPSPz')), findsOneWidget);
      await h.dispose(tester);
    }, skip: !kEnableYoutube);

    testWidgets('lite build: Apple only, YouTube Music never asked and never named', (tester) async {
      await open(tester);
      await search(tester, 'tintoria');
      expect(ytm.asked, 0);
      expect(find.text('YouTube Music'), findsNothing);
      expect(find.text('Apple Podcasts'), findsNWidgets(3));
      await h.dispose(tester);
    }, skip: kEnableYoutube);

    testWidgets('both sources failing gives the network error with «Riprova»', (tester) async {
      await open(tester);
      web.down = true;
      ytm.fail = true;
      await search(tester, 'tintoria');
      expect(find.text('Non riesco a raggiungere il server.'), findsOneWidget);
      expect(find.text('Riprova'), findsOneWidget);
      await h.dispose(tester);
    });
  });

  testWidgets('a11y: every control is labelled and at least 48 dp', (tester) async {
    final sem = tester.ensureSemantics();
    try {
      await open(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester.getSize(find.byKey(const ValueKey('subscribe-apple-1591647170'))).height, greaterThanOrEqualTo(48));
      await h.dispose(tester);
    } finally {
      sem.dispose();
    }
  });
}
