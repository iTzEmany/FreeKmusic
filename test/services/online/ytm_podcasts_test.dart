import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/online/innertube_client.dart';
import 'package:codecore/services/online/request_budget.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_podcasts.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Map fixture(String name) =>
    jsonDecode(File('test/fixtures/innertube/$name.json').readAsStringSync()) as Map;

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status);
  int status;
  final sent = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    sent.add(options);
    final body = options.path.endsWith('/search') ? fixture('ytm_podcast_search') : fixture('ytm_podcast_show');
    return ResponseBody.fromString(jsonEncode(status == 200 ? body : {}), status,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

YtmPodcasts podcasts(HttpClientAdapter a, {WindowLimiter? limiter}) {
  final dio = Dio(BaseOptions(validateStatus: (_) => true))..httpClientAdapter = a;
  return YtmPodcasts(InnerTubeClient(dio), limiter: limiter ?? WindowLimiter(perMinute: 100));
}

void main() {
  test('the podcast search is read: show id, title, author, cover', () {
    final hits = parseShowSearch(fixture('ytm_podcast_search'));
    expect(hits, hasLength(20));
    expect(hits.first.id, startsWith('MPSPP'));
    expect(hits.first.title, 'Untold History Stories');
    expect(hits.first.author, 'History After Dark');
    expect(hits.first.thumbnailUrl, isNotNull);
    expect(() => parseShowSearch({'contents': {}}), throwsA(isA<InnerTubeChanged>()));
  });

  test('the show page gives header and episodes with videoId, title, date and length', () {
    final page = parseShowPage(fixture('ytm_podcast_show'), 'MPSPPLx', now: DateTime.utc(2026, 11, 6));
    expect(page.title, 'Il Prof di Storia');
    expect(page.author, 'Il Prof di Storia');
    expect(page.description, startsWith('Mi chiamo Paolo'));
    expect(page.episodes, hasLength(20));
    final first = page.episodes.first;
    expect(first.videoId, 'B2Tep-eGwmQ');
    expect(first.title, startsWith('Budapest e Suez'));
    expect(first.publishedAt, DateTime.utc(2026, 10, 28));
    expect(first.duration, const Duration(minutes: 46));
    expect(page.episodes[5].duration, const Duration(hours: 1, minutes: 2));
    expect(page.episodes[12].duration, const Duration(minutes: 7, seconds: 37));
    expect(first.watchUrl, 'https://music.youtube.com/watch?v=B2Tep-eGwmQ');
    expect(() => parseShowPage({'contents': {}}, 'x'), throwsA(isA<InnerTubeChanged>()));
  });

  test('dates without a year are this year, or last when that is the future', () {
    final now = DateTime.utc(2026, 2, 1);
    expect(parseEpisodeDate('Jan 5', now), DateTime.utc(2026, 1, 5));
    expect(parseEpisodeDate('Dec 30', now), DateTime.utc(2025, 12, 30));
    expect(parseEpisodeDate('Mar 3, 2023', now), DateTime.utc(2023, 3, 3));
    expect(parseEpisodeDate('2 days ago', now), isNull);
  });

  test('the client asks with the podcasts filter and a 429 pauses the shows', () async {
    final a = _Adapter(200);
    final y = podcasts(a);
    await y.searchShows('history');
    expect(a.sent.single.data['params'], podcastsFilter);
    final page = await y.show('MPSPPLGqhp239bqQz08jpYYsrXdCXAxqD9fXP4');
    expect(page.episodes, isNotEmpty);
    expect(a.sent.last.data['browseId'], 'MPSPPLGqhp239bqQz08jpYYsrXdCXAxqD9fXP4');

    final limited = _Adapter(429);
    final y2 = podcasts(limited);
    await expectLater(y2.searchShows('x'), throwsA(isA<YtException>()));
    final calls = limited.sent.length;
    await expectLater(y2.show('MPSPPx'),
        throwsA(isA<YtException>().having((e) => e.kind, 'kind', YtErrorKind.rateLimited)));
    expect(limited.sent.length, calls, reason: 'paused: nothing was asked');
  });
}
