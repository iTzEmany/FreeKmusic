import 'package:dio/dio.dart';

import '../../core/app_log.dart';
import '../../core/text_utils.dart';
import 'http_client.dart';
import 'lrclib_client.dart';
import 'query_cleaner.dart';
import '../../core/artist_key.dart';

/// Synchronised lyrics from NetEase Cloud Music (fallback after LRCLIB, D-111).
/// A hit counts only for the same song: same cleaned title, a shared artist, no
/// extra live/remix tag and a length within [maxGapSec] seconds (K-AR-08, D-120).
class NeteaseLyricsClient {
  NeteaseLyricsClient(this._web);

  final WebClient _web;

  static const _base = 'https://music.163.com/api';
  static const timeout = Duration(seconds: 8);
  static const maxGapSec = 3;

  static final _variant = RegExp(r'\b(live|remix|acoustic|demo|instrumental|karaoke)\b', caseSensitive: false);

  static Set<String> _tags(String s) => _variant.allMatches(s).map((m) => m[0]!.toLowerCase()).toSet();

  /// NetEase answers 200 with its own `code` (e.g. -460 when blocked).
  static void _checkCode(Object? body, String url) {
    if (body is Map && body['code'] != null && body['code'] != 200) {
      AppLog.w('netease: code ${body['code']} from $url');
      throw WebUnavailableException(url, body['code'] is int ? body['code'] as int : null);
    }
  }

  /// Null when nothing matches or the lyric is empty; throws when the service fails.
  Future<LyricsResult?> find({
    required String title,
    required String artist,
    required int? durationSec,
    CancelToken? cancel,
  }) async {
    if (durationSec == null || artist.trim().isEmpty) return null;
    final search = await _web
        .getJson('$_base/search/get',
            query: {'s': '$title ${extractPrimaryArtist(artist)}', 'type': '1', 'limit': '10'},
            cancel: cancel,
            strict: true)
        .timeout(timeout);
    _checkCode(search, '$_base/search/get');
    final songs = search is Map && search['result'] is Map ? (search['result'] as Map)['songs'] : null;
    if (songs is! List) return null;
    final wantTitle = normalize(title);
    final wantArtists = {for (final a in splitArtists(artist)) normalize(a.name)};
    final myTags = _tags(title);
    for (final s in songs) {
      if (s is! Map || s['id'] is! num || s['duration'] is! num || s['name'] is! String) continue;
      if (((s['duration'] as num) / 1000 - durationSec).abs() > maxGapSec) continue;
      if (_tags(s['name'] as String).difference(myTags).isNotEmpty) continue;
      final artists = s['artists'];
      if (artists is! List) continue;
      final same = artists.any((a) {
        if (a is! Map || a['name'] is! String) return false;
        final c = cleanSearchQuery(s['name'] as String, a['name'] as String);
        return normalize(c.title) == wantTitle &&
            splitArtists(c.artist).any((x) => wantArtists.contains(normalize(x.name)));
      });
      if (!same) continue;
      final lyric = await _web
          .getJson('$_base/song/lyric',
              query: {'id': '${s['id']}', 'lv': '1'}, cancel: cancel, strict: true)
          .timeout(timeout);
      _checkCode(lyric, '$_base/song/lyric');
      final lrc = lyric is Map && lyric['lrc'] is Map ? (lyric['lrc'] as Map)['lyric'] : null;
      return lrc is String && lrc.trim().isNotEmpty ? LyricsResult(synced: lrc) : null;
    }
    return null;
  }
}
