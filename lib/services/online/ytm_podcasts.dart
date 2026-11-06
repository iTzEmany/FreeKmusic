import 'package:dio/dio.dart' show CancelToken;

import '../../core/text_utils.dart';
import 'innertube_client.dart';
import 'innertube_json.dart';
import 'request_budget.dart';
import 'source_cooldown.dart' show SourceCooldown;
import 'youtube_service.dart' show YtErrorKind, YtException;
import 'query_match.dart' show MediaKind;

/// YouTube Music search filter: «Podcasts» (shows). Checked live 2026-11-06:
/// 20 rows of `MUSIC_PAGE_TYPE_PODCAST_SHOW_DETAIL_PAGE`.
const podcastsFilter = 'EgWKAQJQAWoMEA4QChADEAQQCRAF';

const _showPageType = 'MUSIC_PAGE_TYPE_PODCAST_SHOW_DETAIL_PAGE';
const _episodeType = 'MUSIC_VIDEO_TYPE_PODCAST_EPISODE';

/// A show of the search: [id] is the `MPSP…` page id.
class YtmShowHit {
  const YtmShowHit({required this.id, required this.title, this.author, this.thumbnailUrl});

  final String id, title;
  final String? author, thumbnailUrl;
}

class YtmEpisode {
  const YtmEpisode({
    required this.videoId,
    required this.title,
    this.publishedAt,
    this.duration,
    this.description,
  });

  final String videoId, title;
  final DateTime? publishedAt;
  final Duration? duration;
  final String? description;

  /// What yt-dlp is given to download the episode.
  String get watchUrl => 'https://music.youtube.com/watch?v=$videoId';
}

class YtmShowPage {
  const YtmShowPage({
    required this.id,
    required this.title,
    required this.episodes,
    this.author,
    this.description,
    this.thumbnailUrl,
    this.continuation,
  });

  final String id, title;
  final String? author, description, thumbnailUrl;

  /// Newest first; the first page has 20.
  final List<YtmEpisode> episodes;

  /// Token of the next page of episodes, null when there is none.
  final String? continuation;
}

/// The shows of a YouTube Music search filtered on podcasts, best first.
List<YtmShowHit> parseShowSearch(Map data) {
  final contents = data['contents'];
  if (contents is! Map || !contents.containsKey('tabbedSearchResultsRenderer')) {
    throw const InnerTubeChanged('no tabbedSearchResultsRenderer');
  }
  final out = <YtmShowHit>[];
  for (final item in collectRenderers(contents, 'musicResponsiveListItemRenderer')) {
    final nav = {'navigationEndpoint': item['navigationEndpoint']};
    final id = browseIdOf(nav);
    if (pageTypeOf(nav) != _showPageType || id == null) continue;
    final columns = [
      for (final c in item['flexColumns'] is List ? item['flexColumns'] as List : const [])
        if (c is Map && c['musicResponsiveListItemFlexColumnRenderer'] is Map)
          (c['musicResponsiveListItemFlexColumnRenderer'] as Map)['text'],
    ];
    final title = columns.isEmpty ? '' : htmlUnescape(runsText(columns[0]));
    if (title.isEmpty) continue;
    final author = columns.length > 1 ? htmlUnescape(runsText(columns[1])).trim() : '';
    out.add(YtmShowHit(
      id: id,
      title: title,
      author: author.isEmpty ? null : author,
      thumbnailUrl: pickThumbnail(item['thumbnail'], minWidth: 120),
    ));
  }
  return out;
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12, //
};

/// `Oct 28` (this year, or last when that would be in the future) or
/// `Oct 28, 2024`, as the page answers with `hl=en`; anything else is null.
DateTime? parseEpisodeDate(String text, DateTime now) {
  final m = RegExp(r'^([A-Za-z]{3})[a-z]*\.? (\d{1,2})(?:, (\d{4}))?$').firstMatch(text.trim());
  final month = m == null ? null : _months[m.group(1)!.toLowerCase()];
  if (m == null || month == null) return null;
  final day = int.parse(m.group(2)!);
  final year = m.group(3);
  if (year != null) return DateTime.utc(int.parse(year), month, day);
  // Compared in local time with a margin: the page's «today» may be a day ahead of us.
  final future = DateTime(now.year, month, day).isAfter(now.add(const Duration(days: 2)));
  return DateTime.utc(future ? now.year - 1 : now.year, month, day);
}

/// `46 min`, `1 hr 2 min`, `7 min 37 sec`; anything else is null.
Duration? parseEpisodeLength(String text) {
  var seconds = 0;
  var any = false;
  for (final m in RegExp(r'(\d+)\s*(hrs?|h|mins?|m|secs?|s)\b').allMatches(text)) {
    any = true;
    final n = int.parse(m.group(1)!);
    seconds += n * switch (m.group(2)![0]) { 'h' => 3600, 'm' => 60, _ => 1 };
  }
  return any ? Duration(seconds: seconds) : null;
}

/// A show page `MPSP…` with its first episodes. A page with no header is
/// [InnerTubeChanged]; one with a header and no episodes is a real empty show.
YtmShowPage parseShowPage(Map data, String id, {DateTime? now}) {
  final headers = collectRenderers(data['contents'], 'musicResponsiveHeaderRenderer');
  final title = headers.isEmpty ? '' : htmlUnescape(runsText(headers.first['title']));
  if (title.isEmpty) throw const InnerTubeChanged('no show header');
  final header = headers.first;
  final descriptions = collectRenderers(header['description'], 'musicDescriptionShelfRenderer');
  final description =
      descriptions.isEmpty ? '' : htmlUnescape(runsText(descriptions.first['description'])).trim();
  final author = htmlUnescape(runsText(header['straplineTextOne'])).trim();
  final clock = now ?? DateTime.now();
  final episodes = _episodes(data['contents'], clock);
  return YtmShowPage(
    id: id,
    title: title,
    author: author.isEmpty ? null : author,
    description: description.isEmpty ? null : description,
    thumbnailUrl: pickThumbnail(header['thumbnail'], minWidth: 120),
    episodes: episodes,
    continuation: _continuationOf(data['contents']),
  );
}

String? _continuationOf(Object? node) {
  final c = collectRenderers(node, 'nextContinuationData');
  final token = c.isEmpty ? null : c.first['continuation'];
  return token is String && token.isNotEmpty ? token : null;
}

List<YtmEpisode> _episodes(Object? contents, DateTime clock) {
  final episodes = <YtmEpisode>[];
  for (final r in collectRenderers(contents, 'musicMultiRowListItemRenderer')) {
    final watch = (r['onTap'] is Map ? (r['onTap'] as Map)['watchEndpoint'] : null);
    if (watch is! Map || watch['videoId'] is! String) continue;
    final config = watch['watchEndpointMusicSupportedConfigs'];
    final type = config is Map && config['watchEndpointMusicConfig'] is Map
        ? (config['watchEndpointMusicConfig'] as Map)['musicVideoType']
        : null;
    final epTitle = htmlUnescape(runsText(r['title']));
    if (type != _episodeType || epTitle.isEmpty) continue;
    final dates = bulletGroups(r['subtitle']);
    final progress = r['playbackProgress'] is Map
        ? (r['playbackProgress'] as Map)['musicPlaybackProgressRenderer']
        : null;
    final length = progress is Map ? groupText(bulletGroups(progress['durationText']).lastOrNull ?? const []) : '';
    final desc = htmlUnescape(runsText(r['description'])).trim();
    episodes.add(YtmEpisode(
      videoId: watch['videoId'] as String,
      title: epTitle,
      publishedAt: dates.isEmpty ? null : parseEpisodeDate(groupText(dates.last), clock),
      duration: parseEpisodeLength(length),
      description: desc.isEmpty ? null : desc,
    ));
  }
  return episodes;
}

/// The next page of episodes of a show (`continuationContents`): the episodes
/// and the token of the one after, if any.
(List<YtmEpisode>, String?) parseShowContinuation(Map data, {DateTime? now}) {
  final c = data['continuationContents'];
  if (c is! Map || c['musicShelfContinuation'] is! Map) {
    throw const InnerTubeChanged('no musicShelfContinuation');
  }
  return (_episodes(c, now ?? DateTime.now()), _continuationOf(c));
}

/// Search and show pages of YouTube Music podcasts. Same rules as the other
/// YouTube Music calls: [InnerTubeClient] turns a 429 into
/// `YtException(rateLimited)`, which here also pauses the shows for a while
/// (every call in the pause throws it again, without asking); [limiter] keeps
/// refreshes of many shows from going out in a burst.
class YtmPodcasts {
  YtmPodcasts(this.client, {WindowLimiter? limiter, SourceCooldown? cooldown})
      : _limiter = limiter ?? WindowLimiter(perMinute: kPodcastRequestsPerMinute),
        _cooldown = cooldown ?? SourceCooldown();

  final InnerTubeClient client;
  final WindowLimiter _limiter;
  final SourceCooldown _cooldown;

  /// Shows matching [query], best first. Not cached.
  Future<List<YtmShowHit>> searchShows(String query, {String hl = 'en', CancelToken? cancel}) {
    final q = query.trim();
    if (q.isEmpty) return Future.value(const []);
    return _guarded(() => client.searchMusic(q, parseShowSearch,
        params: podcastsFilter, hl: hl, cancel: cancel));
  }

  /// The show [id] (`MPSP…`) with its newest episodes. Asked with `hl=en`
  /// (the date and length texts are read in English).
  ///
  /// With [known] (the video ids already saved) one more page is read when
  /// every episode of the first is new: a refresh after a long pause. At most
  /// two pages, ~40 episodes. shortcut: older ones are never fetched, so a
  /// show that published 40+ since the last refresh loses the oldest of them.
  Future<YtmShowPage> show(String id, {Set<String> known = const {}, CancelToken? cancel}) async {
    final page = await _guarded(() =>
        client.browseMusic(id, (data) => parseShowPage(data, id), cancel: cancel));
    final token = page.continuation;
    if (token == null || page.episodes.isEmpty || page.episodes.any((e) => known.contains(e.videoId))) {
      return page;
    }
    final (more, _) = await _guarded(() => client.browseMusic(
        '', parseShowContinuation, continuation: token, cancel: cancel));
    return YtmShowPage(
      id: page.id,
      title: page.title,
      author: page.author,
      description: page.description,
      thumbnailUrl: page.thumbnailUrl,
      episodes: [...page.episodes, ...more],
    );
  }

  Future<T> _guarded<T>(Future<T> Function() call) async {
    if (_cooldown.isPaused(MediaKind.ytmSong)) {
      throw const YtException(YtErrorKind.rateLimited, 'podcasts paused');
    }
    await _limiter.acquire();
    try {
      return await call();
    } on YtException catch (e) {
      if (e.kind == YtErrorKind.rateLimited) _cooldown.trip(MediaKind.ytmSong);
      rethrow;
    }
  }
}
