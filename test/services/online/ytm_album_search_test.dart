import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/online/catalog_cache.dart';
import 'package:codecore/services/online/innertube_client.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_album_search.dart';
import 'package:codecore/services/online/ytm_artist_parser.dart';
import 'package:codecore/services/online/ytm_catalog.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Map fixture(String name) =>
    jsonDecode(File('test/fixtures/innertube/$name.json').readAsStringSync()) as Map;

class _Adapter implements HttpClientAdapter {
  final sent = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream,
      Future<void>? cancelFuture) async {
    sent.add(options);
    return ResponseBody.fromString(jsonEncode(fixture('ytm_albums')), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('albums, singles and EPs are read from the live answer, in order', () {
    final hits = parseAlbumSearch(fixture('ytm_albums'));
    expect(hits, hasLength(20));
    final first = hits.first;
    expect(first.release.browseId, 'MPREb_nHbCAGX6uUL');
    expect(first.release.title, 'The Dark Side of the Moon');
    expect(first.release.subtitle, 'Album • 1973');
    expect(first.release.thumbnailUrl, contains('=w120-h120'));
    expect(first.artist?.id, 'UCO6LS_5W7vqG9mALDNzSFug');
    expect(first.artist?.name, 'Pink Floyd');
    final single = hits.firstWhere((h) => h.release.title.startsWith('Sheep'));
    expect(single.release.subtitle, 'Single • 2026');
  });

  test('the artists filter answer is read by the existing parser, not as albums', () {
    expect(parseArtistSearch(fixture('ytm_artists')), isNotEmpty);
    expect(parseAlbumSearch(fixture('ytm_artists')), isEmpty);
    expect(parseArtistSearch(fixture('ytm_albums')), isEmpty);
  });

  test('an answer of another page is not read as «no albums»', () {
    expect(() => parseAlbumSearch({'contents': {}}), throwsA(isA<InnerTubeChanged>()));
  });

  test('the catalog asks YouTube Music with the albums filter and the shelf mask', () async {
    final dir = Directory.systemTemp.createTempSync('cc_albums');
    final adapter = _Adapter();
    final cache = CatalogCache(file: () async => File('${dir.path}/c.json'));
    final catalog = YtmCatalog(
        InnerTubeClient(Dio()..httpClientAdapter = adapter), _NoYtDlp(), cache);
    final hits = await catalog.searchAlbums('pink floyd', 'en');
    await cache.dispose();
    dir.deleteSync(recursive: true);

    expect(hits, hasLength(20));
    final sent = adapter.sent.single;
    expect((sent.data as Map)['params'], albumsFilter);
    expect(sent.headers['X-Goog-FieldMask'], albumsMask);
  });
}

class _NoYtDlp implements YoutubeService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}
