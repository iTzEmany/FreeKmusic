import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/podcast/apple_podcasts.dart';
import 'package:codecore/services/podcast/podcast_models.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';

class _Web implements WebClient {
  final answers = <String, Object?>{}; // by URL path suffix
  Object? error;
  final calls = <(String, Map<String, String>?)>[];

  @override
  Future<Object?> getJson(String url, {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async {
    calls.add((url, query));
    if (error != null) throw error!;
    return answers.entries.firstWhere((e) => url.endsWith(e.key)).value;
  }

  @override
  Future<List<int>?> getBytes(String url, {int maxBytes = 5 * 1024 * 1024, CancelToken? cancel}) async => null;
}

Object? _fx(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync());

void main() {
  late _Web web;
  late DateTime clock;
  late ApplePodcasts apple;

  setUp(() {
    web = _Web()
      ..answers['/ws/genres'] = _fx('apple_genres.json')
      ..answers['/json'] = _fx('apple_top_podcasts_it.json')
      ..answers['/lookup'] = _fx('apple_lookup.json')
      ..answers['/search'] = _fx('apple_search_it_comedy.json');
    clock = DateTime.utc(2026, 11, 6, 12);
    apple = ApplePodcasts(web: web, limiter: RateLimiter(minGap: Duration.zero), now: () => clock);
  });

  test('genres: the top-level categories of Podcasts', () async {
    final g = await apple.genres();
    expect(g.map((e) => e.id), ['1301', '1321', '1303', '1304']);
    expect(g.first.name, 'Arts');
    expect(web.calls.single.$1, 'https://itunes.apple.com/WebObjects/MZStoreServices.woa/ws/genres');
    expect(web.calls.single.$2, {'id': '26'});
  });

  test('chart: entries with id, name, author and the biggest cover; URL of the Italian genre chart', () async {
    final c = await apple.chart(genreId: '1303', limit: 3);
    expect(web.calls.single.$1, 'https://itunes.apple.com/it/rss/toppodcasts/limit=3/genre=1303/json');
    expect(c, hasLength(3));
    expect(c.first.appleId, '1591647170');
    expect(c.first.name, 'Lo Zoo di 105');
    expect(c.first.author, 'Radio 105');
    expect(c.first.artworkUrl, endsWith('170x170bb.png'));
  });

  test('lookup: the feed address of a chart entry; none when Apple has no show', () async {
    final h = await apple.lookup('152249110');
    expect(h!.feedUrl, 'https://feeds.simplecast.com/EmVW7VGp');
    expect(web.calls.single.$2, {'id': '152249110', 'country': 'it'});
    web.answers['/lookup'] = {'resultCount': 0, 'results': []};
    expect(await apple.lookup('1'), isNull);
  });

  test('lookup asks the store the show was seen in', () async {
    final c = await apple.chart(country: 'us');
    await apple.lookup(c.first.appleId);
    expect(web.calls.last.$2!['country'], 'us');
    await apple.lookup(c.first.appleId, country: 'de');
    expect(web.calls.last.$2!['country'], 'de');
  });

  test('fields of the wrong type are skipped, never a TypeError', () async {
    web.answers['/json'] = {
      'feed': {
        'entry': [
          {'id': {'attributes': 'x'}, 'im:name': {'label': 'A'}},
          {'id': {'attributes': {'im:id': '7'}}, 'im:name': {'label': 'B'}, 'im:artist': 'oops', 'im:image': ['x'], 'summary': 3},
        ]
      }
    };
    final c = await apple.chart();
    expect(c.single.name, 'B');
    expect(c.single.author, isNull);
    web.answers['/lookup'] = {
      'results': [
        {'feedUrl': 'https://f', 'collectionName': 'N', 'artistName': 5, 'artworkUrl600': 1},
      ]
    };
    final h = await apple.lookup('7');
    expect(h!.author, isNull);
    expect(h.artworkUrl, isNull);
  });

  test('search: country and genre are passed only when given', () async {
    final hits = await apple.search('comedy', limit: 3, country: 'it', genreId: '1303');
    expect(hits, hasLength(3));
    expect(web.calls.single.$2, {'media': 'podcast', 'term': 'comedy', 'limit': '3', 'country': 'it', 'genreId': '1303'});
    await apple.search('comedy');
    expect(web.calls.last.$2!.keys, isNot(contains('country')));
  });

  test('a valid cache asks nothing; an old one asks again', () async {
    await apple.genres();
    await apple.chart();
    await apple.genres();
    await apple.chart();
    expect(web.calls, hasLength(2));
    await apple.chart(genreId: '1303');
    expect(web.calls, hasLength(3), reason: 'another genre is another chart');
    clock = clock.add(ApplePodcasts.cacheFor + const Duration(minutes: 1));
    await apple.genres();
    expect(web.calls, hasLength(4));
  });

  test('a 502, a rate limit or a bad answer is a network error, and is not cached', () async {
    Matcher network() => throwsA(isA<PodcastException>().having((e) => e.kind, 'kind', PodcastErrorKind.network));
    web.error = const WebUnavailableException('u', 502);
    await expectLater(apple.genres(), network());
    web.error = const RateLimitedException(429);
    await expectLater(apple.chart(), network());
    web.error = null;
    web.answers['/ws/genres'] = 'not a map';
    await expectLater(apple.genres(), network());
    web.answers['/ws/genres'] = _fx('apple_genres.json');
    expect(await apple.genres(), isNotEmpty);
  });
}
