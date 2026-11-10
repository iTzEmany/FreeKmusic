import 'package:codecore/services/online/external_collection.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/short_link_resolver.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers by host: a `Location` to redirect to, or an HTML body.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.pages);
  final Map<String, ResponseBody Function()> pages;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async =>
      pages[o.uri.host]!();

  @override
  void close({bool force = false}) {}
}

ResponseBody Function() _to(String url) =>
    () => ResponseBody.fromString('', 302, headers: {'location': [url]});

ShortLinkResolver _resolver(Map<String, ResponseBody Function()> pages) {
  final dio = Dio(BaseOptions(followRedirects: false, validateStatus: (_) => true))
    ..httpClientAdapter = _Adapter(pages);
  return ShortLinkResolver(dio);
}

void main() {
  test('a 302 to the page ends the chain', () async {
    final r = _resolver({
      'spotify.link': _to('https://open.spotify.com/playlist/abc?si=1'),
    });
    expect(await r.resolve('https://spotify.link/x'), 'https://open.spotify.com/playlist/abc?si=1');
  });

  test('a redirect cycle is not found', () async {
    final r = _resolver({
      'a.test': _to('https://b.test/'),
      'b.test': _to('https://a.test/'),
    });
    await expectLater(r.resolve('https://a.test/'), throwsA(isA<CollectionNotFound>()));
  });

  test('the sixth hop is not followed', () async {
    final r = _resolver({
      for (var i = 1; i <= 6; i++) 'h$i.test': _to('https://h${i + 1}.test/'),
      'h7.test': _to('https://open.spotify.com/album/z'),
    });
    await expectLater(r.resolve('https://h1.test/'), throwsA(isA<CollectionNotFound>()));
  });

  test('five hops are followed', () async {
    final r = _resolver({
      for (var i = 1; i <= 5; i++) 'h$i.test': _to('https://h${i + 1}.test/'),
      'h6.test': _to('https://open.spotify.com/album/z'),
    });
    expect(await r.resolve('https://h1.test/'), 'https://open.spotify.com/album/z');
  });

  test('a 200 page gives the first Spotify link in its body', () async {
    final r = _resolver({
      'spotify.link': () => ResponseBody.fromString(
          '<a href="https://open.spotify.com/playlist/p1">x</a> https://open.spotify.com/track/t', 200),
    });
    expect(await r.resolve('https://spotify.link/x'), 'https://open.spotify.com/playlist/p1');
  });

  test('a relative Location is resolved against the current page', () async {
    final r = _resolver({
      'spotify.link': _to('/playlist/abc'),
      'open.spotify.com': _to('https://open.spotify.com/playlist/abc'),
    });
    expect(await r.resolve('https://open.spotify.com/x'), 'https://open.spotify.com/playlist/abc');
  });

  test('a link in the body that is not a page is skipped', () async {
    final r = _resolver({
      'spotify.link': () => ResponseBody.fromString(
          '<a href="https://open.spotify.com/user/u1">x</a> https://open.spotify.com/album/a1', 200),
    });
    expect(await r.resolve('https://spotify.link/x'), 'https://open.spotify.com/album/a1');
  });

  test('429 is a network error, not not-found', () async {
    final r = _resolver({'spotify.link': () => ResponseBody.fromString('', 429)});
    await expectLater(r.resolve('https://spotify.link/x'), throwsA(isA<WebUnavailableException>()));
  });

  test('a connection error is a network error', () async {
    final r = _resolver({
      'spotify.link': () => throw DioException.connectionError(
          requestOptions: RequestOptions(path: ''), reason: 'offline'),
    });
    await expectLater(r.resolve('https://spotify.link/x'), throwsA(isA<WebUnavailableException>()));
  });
}
