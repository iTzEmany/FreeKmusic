import 'package:dio/dio.dart';

import 'http_client.dart';

/// A row of Apple's most-played feed (no duration there).
class AppleSong {
  const AppleSong({required this.title, required this.artist, required this.genreIds});

  final String title, artist;
  final List<String> genreIds;
}

/// Apple Marketing Tools RSS: the country's most-played songs, no key needed.
class AppleRssClient {
  AppleRssClient(this._web);

  final WebClient _web;

  static const _base = 'https://rss.marketingtools.apple.com/api/v2';

  /// The country's top 100 in chart order, keeping only songs with one of
  /// [genreIds] (all when empty). Null when the feed could not be read.
  Future<List<AppleSong>?> mostPlayed(
    String country, {
    Iterable<String> genreIds = const [],
    CancelToken? cancel,
  }) async {
    final body = await _web.getJson(
        '$_base/${country.toLowerCase()}/music/most-played/100/songs.json',
        cancel: cancel);
    final results = body is Map && body['feed'] is Map ? (body['feed'] as Map)['results'] : null;
    if (results is! List) return null;
    final want = genreIds.toSet();
    final out = <AppleSong>[];
    for (final r in results) {
      if (r is! Map) continue;
      final ids = [
        if (r['genres'] is List)
          for (final g in r['genres'] as List)
            if (g is Map) '${g['genreId']}',
      ];
      if (want.isNotEmpty && !ids.any(want.contains)) continue;
      out.add(AppleSong(title: '${r['name'] ?? ''}', artist: '${r['artistName'] ?? ''}', genreIds: ids));
    }
    return out;
  }
}
