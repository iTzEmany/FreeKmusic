import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/online/apple_rss_client.dart';
import 'package:codecore/services/online/chart_genres.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';

class _Web implements WebClient {
  _Web(this.answer);

  final Object? answer;
  String? url;

  @override
  Future<Object?> getJson(String u, {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async {
    url = u;
    return answer;
  }

  @override
  Future<List<int>?> getBytes(String u, {int maxBytes = 0, CancelToken? cancel}) async => null;
}

Object _fixture(String n) => jsonDecode(File('test/fixtures/apple_rss/$n.json').readAsStringSync()) as Object;

void main() {
  test('keeps the songs of the genre in chart order, by id even when names are localized', () async {
    final web = _Web(_fixture('most_played_it'));
    final latin = chartGenres.firstWhere((g) => g.id == 'latin');
    final songs = await AppleRssClient(web).mostPlayed('IT', genreIds: latin.appleGenreIds);
    expect(web.url, 'https://rss.marketingtools.apple.com/api/v2/it/music/most-played/100/songs.json');
    expect(songs, hasLength(7)); // «Latina» in the Italian feed
    expect(songs!.every((s) => s.genreIds.contains('12') && s.title.isNotEmpty), isTrue);
  });

  test('no genre filter returns the whole feed; an unreadable feed is null', () async {
    expect(await AppleRssClient(_Web(_fixture('most_played_us'))).mostPlayed('us'), hasLength(100));
    expect(await AppleRssClient(_Web(null)).mostPlayed('us'), isNull);
  });
}
