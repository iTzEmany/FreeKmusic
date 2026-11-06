import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/app_log.dart';
import '../../core/text_utils.dart';
import 'innertube_json.dart';
import 'request_budget.dart';
import 'ytm_lyrics_parser.dart';
import 'ytm_song_parser.dart';
import 'ytm_radio_parser.dart';
import 'youtube_service.dart';

/// The answer of a direct search was not what this client knows how to read
/// (YouTube changed its format, or refused in an unexpected way): the caller
/// searches with yt-dlp instead.
class InnerTubeChanged implements Exception {
  const InnerTubeChanged(this.detail);

  final String detail;

  @override
  String toString() => 'InnerTubeChanged($detail)';
}

/// A `browse` answer that is a known «nothing here»: the artist id does not
/// exist (no content and no header), as opposed to [InnerTubeChanged].
class ArtistNotFound implements Exception {
  const ArtistNotFound(this.id);

  final String id;

  @override
  String toString() => 'ArtistNotFound($id)';
}

/// The search endpoint of YouTube's own pages (InnerTube, the same one yt-dlp
/// and NewPipe call). One request answers in about half a second, where
/// starting yt-dlp takes seconds and its YouTube Music search opens every
/// video. Undocumented: every field is read defensively and anything
/// unexpected becomes [InnerTubeChanged].
class InnerTubeClient {
  InnerTubeClient([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 15),
              validateStatus: (_) => true,
            ));

  final Dio _dio;

  static const webVersion = '2.20250101.00.00';
  static const musicVersion = '1.20250101.01.00';

  /// Search filters as the sites encode them: «Videos» and «Songs».
  static const videosFilter = 'EgIQAQ%3D%3D';
  static const songsFilter = 'EgWKAQIIAWoKEAkQBRAKEAMQBA%3D%3D';

  /// Only the fields the parsers read (Google's field mask): a YouTube answer
  /// shrinks from ~300 KB to ~20 KB, which a slow phone reads much sooner.
  static const videosMask = 'contents.twoColumnSearchResultsRenderer.primaryContents.sectionListRenderer'
      '.contents.itemSectionRenderer.contents.videoRenderer(videoId,title,ownerText,lengthText,longBylineText)';
  static const songsMask = 'contents.tabbedSearchResultsRenderer.tabs.tabRenderer.content.sectionListRenderer'
      '.contents.musicShelfRenderer.contents.musicResponsiveListItemRenderer(flexColumns,playlistItemData,thumbnail)';

  /// Videos for [query], best first, as the YouTube search page lists them.
  Future<List<YtResult>> searchVideos(String query,
          {int limit = 10, CancelToken? cancel}) =>
      _masked(
          (mask) => _post('https://www.youtube.com', 'WEB', webVersion, query,
              videosFilter, cancel, mask: mask),
          (data) => parseVideoSearch(data, limit: limit),
          videosMask);

  /// YouTube Music «Songs» for [query] with credited artists, album and length.
  Future<List<YtResult>> searchSongs(String query,
          {int limit = 5, CancelToken? cancel}) =>
      _masked(
          (mask) => _post('https://music.youtube.com', 'WEB_REMIX', musicVersion,
              query, songsFilter, cancel, mask: mask),
          (data) => parseSongSearch(data, limit: limit),
          songsMask);

  /// Asks with the field mask; nothing back (a real «no results», or fields
  /// that were renamed and so dropped by the mask) is asked again in full.
  Future<List<YtResult>> _masked(Future<Map> Function(String? mask) post,
      List<YtResult> Function(Map data) parse, String mask) async {
    try {
      final results = parse(await post(mask));
      if (results.isNotEmpty) return results;
    } on InnerTubeChanged catch (e) {
      AppLog.d('masked search not readable, asking in full: $e');
    }
    return parse(await post(null));
  }

  /// A YouTube Music `browse` page (artist, album, list) read with [parse].
  /// Same plan as the searches: with [mask] first, in full when the masked
  /// answer is empty ([isEmpty]) or [parse] does not know it ([InnerTubeChanged],
  /// [ArtistNotFound]: a mask whose fields were renamed drops everything).
  Future<T> browseMusic<T>(
    String browseId,
    T Function(Map data) parse, {
    String? params,
    String? continuation,
    String hl = 'en',
    String? mask,
    bool Function(T value)? isEmpty,
    CancelToken? cancel,
  }) =>
      _musicPage(
        'browse',
        continuation != null ? {'continuation': continuation} : {'browseId': browseId, 'params': ?params},
        hl,
        parse,
        mask,
        isEmpty,
        cancel,
      );

  /// A YouTube Music `search` (top result card, artists) read with [parse];
  /// [params] is the filter, none for the mixed list. Masked like [browseMusic].
  Future<T> searchMusic<T>(
    String query,
    T Function(Map data) parse, {
    String? params,
    String hl = 'en',
    String? mask,
    bool Function(T value)? isEmpty,
    CancelToken? cancel,
  }) =>
      _musicPage(
        'search',
        {'query': query, 'params': ?params},
        hl,
        parse,
        mask,
        isEmpty,
        cancel,
      );

  /// The YouTube Music radio of the song [videoId] (the id of the song, not
  /// of a video clip: a clip's radio has no songs), or its next page when
  /// [continuation] is given. Same errors and same full re-ask as the pages.
  Future<RadioPage> radio(String videoId,
          {String? continuation, CancelToken? cancel}) =>
      _musicPage(
        'next',
        continuation != null
            ? {'continuation': continuation}
            : {
                'videoId': videoId,
                'playlistId': 'RDAMVM$videoId',
                'params': 'wAEB',
                'isAudioOnly': true,
                'enablePersistentPlaylistPanel': true,
              },
        'en',
        continuation != null ? parseRadioContinuation : parseRadio,
        continuation != null ? radioContinuationMask : radioMask,
        (RadioPage page) => page.items.isEmpty,
        cancel,
      );

  /// The plain lyrics of the YouTube Music song [videoId] (its «Testo» tab),
  /// null when it has none. Two requests, both unmasked: the answers are small.
  Future<String?> lyrics(String videoId, {CancelToken? cancel}) async {
    final id = await _musicPage('next', {'videoId': videoId}, 'en', lyricsBrowseId, null, null, cancel);
    return id == null ? null : browseMusic(id, parseLyrics, cancel: cancel);
  }

  /// What YouTube Music knows of the video [videoId]: title, artists, album,
  /// length and kind (see [YtmSong]). Unmasked: the answer is small.
  Future<YtmSong> songOf(String videoId, {CancelToken? cancel}) =>
      _musicPage('next', {'videoId': videoId}, 'en', parseYtmSong, null, null, cancel);

  Future<T> _musicPage<T>(
    String endpoint,
    Map<String, Object?> body,
    String hl,
    T Function(Map data) parse,
    String? mask,
    bool Function(T value)? isEmpty,
    CancelToken? cancel,
  ) async {
    Future<Map> post(String? m) => _send('https://music.youtube.com', endpoint,
        'WEB_REMIX', musicVersion, hl, body, cancel, mask: m);
    if (mask != null) {
      try {
        final value = parse(await post(mask));
        if (isEmpty == null || !isEmpty(value)) return value;
      } on InnerTubeChanged catch (e) {
        AppLog.d('masked $endpoint not readable, asking in full: $e');
      } on ArtistNotFound catch (e) {
        AppLog.d('masked $endpoint found nothing, asking in full: $e');
      }
    }
    return parse(await post(null));
  }

  Future<Map> _post(String origin, String client, String version, String query,
          String params, CancelToken? cancel, {String? mask}) =>
      _send(origin, 'search', client, version, 'en',
          {'query': query, 'params': params}, cancel, mask: mask);

  Future<Map> _send(String origin, String endpoint, String client, String version,
      String hl, Map<String, Object?> body, CancelToken? cancel, {String? mask}) async {
    final Response<Object?> res;
    try {
      res = await _dio.post<Object?>(
        '$origin/youtubei/v1/$endpoint',
        queryParameters: const {'prettyPrint': 'false'},
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.json,
          headers: {
            'User-Agent': apiUserAgent,
            'Origin': origin,
            'X-Goog-FieldMask': ?mask,
            Headers.contentTypeHeader: Headers.jsonContentType,
          },
        ),
        data: {
          // No region: YouTube takes it from the address, as for yt-dlp.
          'context': {
            'client': {'clientName': client, 'clientVersion': version, 'hl': hl},
          },
          ...body,
        },
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      // yt-dlp would not reach YouTube either: no point in trying it.
      final offline = switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError => true,
        DioExceptionType.unknown => e.error is IOException,
        _ => false,
      };
      if (offline) throw YtException(YtErrorKind.network, '${e.type}: ${e.message}');
      throw InnerTubeChanged('${e.type}: ${e.error ?? e.message}');
    }
    final code = res.statusCode;
    if (code == 429) throw const YtException(YtErrorKind.rateLimited, 'HTTP 429');
    if (code != 200) throw InnerTubeChanged('HTTP $code');
    final data = res.data;
    if (data is! Map) throw const InnerTubeChanged('not JSON');
    return data;
  }

  void close() => _dio.close();
}

void _ensureKnown(Map data, String container) {
  final contents = data['contents'];
  if (contents is! Map || !contents.containsKey(container)) {
    throw InnerTubeChanged('no $container');
  }
}

/// Reads a YouTube (WEB client) search answer. A known answer with no videos
/// is a real «no results»; an unknown one throws [InnerTubeChanged].
List<YtResult> parseVideoSearch(Map data, {int limit = 10}) {
  _ensureKnown(data, 'twoColumnSearchResultsRenderer');
  final out = <YtResult>[];
  for (final v in collectRenderers(data['contents'], 'videoRenderer')) {
    final id = v['videoId'];
    final title = runsText(v['title']);
    if (id is! String || id.isEmpty || title.isEmpty) continue;
    final channel = runsText(v['ownerText']).isNotEmpty
        ? runsText(v['ownerText'])
        : runsText(v['longBylineText']);
    out.add(YtResult(
      id: id,
      title: htmlUnescape(title),
      channel: htmlUnescape(channel),
      // Live streams have no length.
      duration: parseClock(runsText(v['lengthText'])),
      thumbnailUrl: smallVideoThumbnail(id),
    ));
    if (out.length >= limit) break;
  }
  return out;
}

/// Reads a YouTube Music «Songs» search answer: title in the first column;
/// `artists • album • length` in the second.
List<YtResult> parseSongSearch(Map data, {int limit = 5}) {
  _ensureKnown(data, 'tabbedSearchResultsRenderer');
  final out = <YtResult>[];
  for (final item in collectRenderers(data['contents'], 'musicResponsiveListItemRenderer')) {
    final columns = [
      for (final c in item['flexColumns'] is List ? item['flexColumns'] as List : const [])
        if (c is Map && c['musicResponsiveListItemFlexColumnRenderer'] is Map)
          (c['musicResponsiveListItemFlexColumnRenderer'] as Map)['text'],
    ];
    if (columns.length < 2) continue;
    final title = runsText(columns[0]);
    final id = _songId(item, columns[0]);
    if (id == null || title.isEmpty) continue;
    // Split the second column on « • » into groups of runs.
    final groups = <List<Map>>[[]];
    final runs = columns[1] is Map ? (columns[1] as Map)['runs'] : null;
    for (final r in runs is List ? runs : const []) {
      if (r is! Map || r['text'] is! String) continue;
      if ((r['text'] as String).trim() == '•') {
        groups.add([]);
      } else {
        groups.last.add(r);
      }
    }
    final artists = <String>[];
    final artistIds = <String>[];
    String? album, albumId;
    Duration? duration;
    for (final (i, g) in groups.indexed) {
      final joined = g.map((r) => r['text'] as String).join().trim();
      final linked = g.where((r) => pageTypeOf(r) == 'MUSIC_PAGE_TYPE_ARTIST');
      final albumRun = g.where((r) => pageTypeOf(r) == 'MUSIC_PAGE_TYPE_ALBUM');
      if (albumRun.isNotEmpty) {
        album = (albumRun.first['text'] as String).trim();
        albumId = browseIdOf(albumRun.first);
      } else if (linked.isNotEmpty || (i == 0 && parseClock(joined) == null)) {
        // The first group is the artists even when they have no page.
        for (final r in g) {
          final name = (r['text'] as String).trim();
          if (name.isEmpty || artistJoiners.contains(name.toLowerCase())) continue;
          artists.add(name);
          artistIds.add(pageTypeOf(r) == 'MUSIC_PAGE_TYPE_ARTIST' ? browseIdOf(r) ?? '' : '');
        }
      } else {
        duration ??= parseClock(joined);
      }
    }
    out.add(YtResult(
      id: id,
      title: htmlUnescape(title),
      // The uploader is not in the answer: the first credited artist stands in.
      channel: artists.isEmpty ? '' : htmlUnescape(artists.first),
      duration: duration,
      thumbnailUrl: pickThumbnail(item['thumbnail']) ?? smallVideoThumbnail(id),
      artists: [for (final a in artists) htmlUnescape(a)],
      album: album == null ? null : htmlUnescape(album),
      artistIds: artistIds,
      albumId: albumId,
    ));
    if (out.length >= limit) break;
  }
  return out;
}

String? _songId(Map item, Object? titleColumn) {
  final data = item['playlistItemData'];
  if (data is Map && data['videoId'] is String) return data['videoId'] as String;
  final runs = titleColumn is Map ? titleColumn['runs'] : null;
  for (final r in runs is List ? runs : const []) {
    final watch = r is Map && r['navigationEndpoint'] is Map
        ? (r['navigationEndpoint'] as Map)['watchEndpoint']
        : null;
    if (watch is Map && watch['videoId'] is String) return watch['videoId'] as String;
  }
  return null;
}
