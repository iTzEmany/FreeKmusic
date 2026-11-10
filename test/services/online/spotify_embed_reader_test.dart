import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/online/external_collection.dart';
import 'package:codecore/services/online/external_links.dart';
import 'package:codecore/services/online/spotify_embed_reader.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:codecore/services/online/http_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _Web implements WebClient {
  _Web(this.page);

  /// null mimics a 404.
  final String? page;
  final urls = <String>[];

  @override
  Future<List<int>?> getBytes(String url, {int maxBytes = 0, CancelToken? cancel}) async {
    urls.add(url);
    return page == null ? null : utf8.encode(page!);
  }

  @override
  Future<Object?> getJson(String url,
          {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async =>
      null;
}

String _page(String name) => File('test/fixtures/spotify_embed/$name.html').readAsStringSync();

ExternalLink _link(ExternalLinkKind k) => ExternalLink(ExternalService.spotify, k, 'abc');

void main() {
  Future<ExternalCollection> read(String? page, ExternalLinkKind k) =>
      SpotifyEmbedReader(_Web(page)).read(_link(k));

  test('playlist: title, cover, tracks with split artists', () async {
    final web = _Web(_page('playlist'));
    final c = await SpotifyEmbedReader(web).read(_link(ExternalLinkKind.playlist));
    expect(web.urls, ['https://open.spotify.com/embed/playlist/abc']);
    expect(c.title, 'Today’s Top Hits');
    expect(c.tracks.length, 50);
    expect(c.coverUrl, startsWith('https://i.scdn.co/'));
    expect(c.tracks.first.title, 'Stop The Wedding!');
    expect(c.tracks.first.durationMs, 198840);
    expect(c.truncated, isFalse);
  });

  test('album: artists split on the comma', () async {
    final c = await read(_page('album'), ExternalLinkKind.album);
    expect(c.kind, CollectionKind.album);
    expect(c.tracks.first.artists, ['Pitbull', 'Sensato']);
    expect(c.coverUrl, endsWith('0000b2732c5b24ecfa39523a75c993c4'));
  });

  test('artist: top tracks', () async {
    final c = await read(_page('artist'), ExternalLinkKind.artist);
    expect(c.title, 'Pitbull');
    expect(c.tracks.first.artists, ['Pitbull', 'AFROJACK', 'Ne-Yo', 'Nayer']);
  });

  test('track: one song from the artists list', () async {
    final c = await read(_page('track'), ExternalLinkKind.track);
    expect(c.tracks.single.title, 'Never Gonna Give You Up');
    expect(c.tracks.single.artists, ['Rick Astley']);
    expect(c.tracks.single.durationMs, 213573);
  });

  test('no trackList: unreadable', () async {
    await expectLater(
      read(_page('no_track_list'), ExternalLinkKind.artist),
      throwsA(isA<CollectionUnreadable>()),
    );
  });

  test('no __NEXT_DATA__: unreadable', () async {
    await expectLater(
      read('<html></html>', ExternalLinkKind.playlist),
      throwsA(isA<CollectionUnreadable>()),
    );
  });

  test('404: not found', () async {
    await expectLater(
      read(null, ExternalLinkKind.playlist),
      throwsA(isA<CollectionNotFound>()),
    );
  });

  test('a playlist at the embed limit says more exist', () async {
    final c = await read(_page('playlist_big'), ExternalLinkKind.playlist);
    expect(c.tracks.length, SpotifyEmbedReader.embedLimit);
    expect(c.truncated, isTrue);
  });
}
