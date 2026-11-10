import 'dart:convert';

import 'package:dio/dio.dart';

import 'external_collection.dart';
import 'external_links.dart';
import 'http_client.dart';

/// Reads a Spotify link from its public embed page (no account, no API).
/// One GET, no retry (D-521): a failure is the user's to retry.
class SpotifyEmbedReader implements ExternalReader {
  SpotifyEmbedReader(this._web);

  final WebClient _web;

  /// The embed lists at most this many songs, and does not say the real total.
  static const embedLimit = 100;

  static final _nextData = RegExp(
    r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>',
    dotAll: true,
  );

  @override
  Future<ExternalCollection> read(ExternalLink link, {CancelToken? cancelToken}) async {
    if (link.service != ExternalService.spotify) throw const CollectionNotFound();
    final url = 'https://open.spotify.com/embed/${link.kind.name}/${link.id}';
    final List<int>? bytes;
    try {
      bytes = await _web.getBytes(url, cancel: cancelToken);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      throw WebUnavailableException(url, e.response?.statusCode);
    } on RateLimitedException catch (e) {
      throw WebUnavailableException(url, e.statusCode);
    }
    if (bytes == null) throw const CollectionNotFound();
    final json = _nextData.firstMatch(utf8.decode(bytes, allowMalformed: true))?.group(1);
    final Object? data;
    try {
      data = json == null ? null : jsonDecode(json);
    } on FormatException catch (e) {
      throw CollectionUnreadable(e);
    }
    // A missing or private playlist is still HTTP 200, with the status inside the page.
    if (_path(data, ['props', 'pageProps', 'status']) == 404) throw const CollectionNotFound();
    final entity = _path(data, ['props', 'pageProps', 'state', 'data', 'entity']);
    if (entity is! Map) throw const CollectionUnreadable('no __NEXT_DATA__ entity');
    return link.kind == ExternalLinkKind.track
        ? _single(entity, link)
        : _list(entity, link);
  }

  ExternalCollection _list(Map entity, ExternalLink link) {
    final list = entity['trackList'];
    if (list is! List) throw const CollectionUnreadable('no trackList');
    final tracks = [
      for (final t in list)
        if (t is Map && t['title'] is String)
          ExternalTrack(
            title: t['title'] as String,
            artists: _artists('${t['subtitle'] ?? ''}'),
            durationMs: _ms(t['duration']),
            key: '${t['uri'] ?? t['title']}',
          ),
    ];
    final declared = (entity['declaredTotal'] as num?)?.toInt();
    return ExternalCollection(
      title: '${entity['title'] ?? entity['name'] ?? ''}',
      kind: link.kind == ExternalLinkKind.album ? CollectionKind.album : CollectionKind.playlist,
      tracks: tracks,
      sourceUrl: 'https://open.spotify.com/${link.kind.name}/${link.id}',
      coverUrl: _cover(entity),
      owner: link.kind == ExternalLinkKind.playlist ? entity['subtitle'] as String? : null,
      declaredTotal: declared,
      // The embed stops at [embedLimit] without saying how many are left.
      truncated: declared != null ? declared > tracks.length : tracks.length >= embedLimit,
    );
  }

  ExternalCollection _single(Map entity, ExternalLink link) {
    final title = entity['title'];
    if (title is! String) throw const CollectionUnreadable('no title');
    final artists = entity['artists'];
    return ExternalCollection(
      title: title,
      kind: CollectionKind.playlist,
      sourceUrl: 'https://open.spotify.com/track/${link.id}',
      coverUrl: _cover(entity),
      tracks: [
        ExternalTrack(
          title: title,
          artists: [
            if (artists is List)
              for (final a in artists)
                if (a is Map && a['name'] is String) a['name'] as String,
          ],
          durationMs: _ms(entity['duration']),
          key: link.id,
        ),
      ],
    );
  }

  /// The subtitle joins artists with a comma and a no-break space.
  /// Without the no-break space the comma belongs to a name («Tyler, The Creator»).
  static List<String> _artists(String subtitle) => [
    for (final a in subtitle.split(',\u00A0')) if (a.trim().isNotEmpty) a.trim(),
  ];

  static int? _ms(Object? v) => v is num && v > 0 ? v.toInt() : null;

  /// Playlists carry `coverArt`; albums, artists and tracks only the image set.
  static String? _cover(Map entity) {
    final art = _path(entity, ['coverArt', 'sources', 0, 'url']);
    if (art is String) return art;
    final images = _path(entity, ['visualIdentity', 'image']);
    if (images is! List) return null;
    Map? best;
    for (final i in images) {
      if (i is Map && i['url'] is String &&
          (best == null || ((i['maxWidth'] as num?) ?? 0) > ((best['maxWidth'] as num?) ?? 0))) {
        best = i;
      }
    }
    return best?['url'] as String?;
  }

  static Object? _path(Object? node, List<Object> keys) {
    for (final k in keys) {
      node = switch ((node, k)) {
        (final Map m, final String s) => m[s],
        (final List l, final int i) => i < l.length ? l[i] : null,
        _ => null,
      };
    }
    return node;
  }
}
