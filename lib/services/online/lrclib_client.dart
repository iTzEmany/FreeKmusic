import 'package:dio/dio.dart';

import 'http_client.dart';
import 'query_cleaner.dart';
import '../../core/artist_key.dart';

class LyricsResult {
  const LyricsResult({this.plain, this.synced});

  final String? plain, synced;

  bool get isEmpty =>
      (plain == null || plain!.isEmpty) && (synced == null || synced!.isEmpty);
}

class LrclibClient {
  LrclibClient(this._web);

  final WebClient _web;

  static const _base = 'https://lrclib.net/api';

  Future<LyricsResult?> find({
    required String title,
    required String artist,
    String? album,
    int? durationSec,
    CancelToken? cancel,
    bool strict = false,
  }) async {
    if (artist.trim().isEmpty) return null;
    final primary = extractPrimaryArtist(artist);
    final core = coreTitle(title);
    final attempts = <(String, String)>[(artist, title)];
    if (primary != artist || core != title) attempts.add((primary, core));
    for (final (a, t) in attempts) {
      final get = await _web.getJson('$_base/get',
          query: {
            'artist_name': a,
            'track_name': t,
            if (album != null && album.isNotEmpty) 'album_name': album,
            if (durationSec != null) 'duration': '$durationSec',
          },
          cancel: cancel,
          strict: strict);
      final direct = _validated(get, artist, durationSec);
      if (direct != null) return direct;
    }
    for (final (a, t) in attempts) {
      final search = await _web.getJson('$_base/search',
          query: {'track_name': t, 'artist_name': a}, cancel: cancel, strict: strict);
      if (search is List) {
        for (final item in search) {
          final ok = _validated(item, artist, durationSec);
          if (ok != null) return ok;
        }
      }
    }
    return null;
  }

  LyricsResult? _validated(Object? item, String artist, int? durationSec) {
    if (item is! Map) return null;
    final by = '${item['artistName'] ?? ''}'.toLowerCase().trim();
    final want = artist.toLowerCase().trim();
    if (by.isEmpty || !(by == want || by.contains(want) || want.contains(by))) {
      return null;
    }
    final d = item['duration'];
    if (durationSec != null && d is num) {
      if ((d - durationSec).abs() > 3) return null;
    }
    final result = LyricsResult(
      plain: item['plainLyrics'] as String?,
      synced: item['syncedLyrics'] as String?,
    );
    return result.isEmpty ? null : result;
  }
}
