import '../../core/app_log.dart';
import '../online/http_client.dart';
import 'podcast_models.dart';

/// A podcast category of the Apple directory (name as Apple gives it).
class PodcastGenre {
  const PodcastGenre(this.id, this.name);
  final String id, name;
}

/// A row of the Apple chart. No feed address: [ApplePodcasts.lookup] gets it.
class PodcastChartEntry {
  const PodcastChartEntry({required this.appleId, required this.name, this.author, this.artworkUrl, this.summary});
  final String appleId, name;
  final String? author, artworkUrl, summary;
}

/// The Apple directory (`itunes.apple.com` only): genres, chart, lookup, search.
/// Genres and charts are kept in memory for [cacheFor]; a valid cache asks nothing.
/// Every failure is a [PodcastException] of kind `network` (the UI offers «Riprova»).
class ApplePodcasts {
  ApplePodcasts({required this.web, required this.limiter, required DateTime Function() now})
      : _now = now; // ignore: prefer_initializing_formals

  final WebClient web;
  final RateLimiter limiter;
  final DateTime Function() _now;

  static const cacheFor = Duration(hours: 4);
  static const _host = 'https://itunes.apple.com';
  static const _podcastsGenre = '26';

  final _cache = <String, ({DateTime at, Object value})>{};

  /// The country each chart show came from: its lookup asks the same store.
  final _countryOf = <String, String>{};

  static String? _s(Object? v) => v is String ? v : null;
  static Map<dynamic, dynamic>? _m(Object? v) => v is Map ? v : null;

  Future<T> _cached<T extends Object>(String key, Future<T> Function() load) async {
    final hit = _cache[key];
    if (hit != null && _now().difference(hit.at) < cacheFor) return hit.value as T;
    final value = await load();
    _cache[key] = (at: _now(), value: value);
    return value;
  }

  Future<Map<dynamic, dynamic>> _getMap(String url, [Map<String, String>? query]) async {
    await limiter.wait();
    final Object? json;
    try {
      json = await web.getJson(url, query: query, strict: true);
    } on WebUnavailableException catch (e) {
      AppLog.w('Apple directory unavailable: $e');
      throw PodcastException(PodcastErrorKind.network, 'HTTP ${e.statusCode}');
    } on RateLimitedException catch (e) {
      AppLog.w('Apple directory rate limited: $e');
      throw PodcastException(PodcastErrorKind.network, 'HTTP ${e.statusCode}');
    }
    if (json is! Map) {
      AppLog.w('Apple directory: unexpected answer from $url');
      throw const PodcastException(PodcastErrorKind.network, 'bad answer');
    }
    return json;
  }

  /// The top-level categories of Podcasts.
  Future<List<PodcastGenre>> genres() => _cached('genres', () async {
        final json = await _getMap('$_host/WebObjects/MZStoreServices.woa/ws/genres', {'id': _podcastsGenre});
        final sub = _m(json[_podcastsGenre])?['subgenres'];
        if (sub is! Map) throw const PodcastException(PodcastErrorKind.network, 'genres');
        return [
          for (final g in sub.values)
            if (g is Map && _s(g['id']) != null && _s(g['name']) != null) PodcastGenre(_s(g['id'])!, _s(g['name'])!),
        ];
      });

  /// The chart of [country] (two letters), for [genreId] or all podcasts.
  Future<List<PodcastChartEntry>> chart({String country = 'it', String? genreId, int limit = 25}) =>
      _cached('chart:$country:${genreId ?? ''}:$limit', () async {
        final g = genreId == null ? '' : '/genre=$genreId';
        final json = await _getMap('$_host/$country/rss/toppodcasts/limit=$limit$g/json');
        final entries = _m(json['feed'])?['entry'];
        // One entry comes as a bare map, none as nothing.
        final list = entries is List ? entries : (entries is Map ? [entries] : const []);
        final out = <PodcastChartEntry>[];
        for (final e in list) {
          if (e is! Map) continue;
          final id = _s(_m(_m(e['id'])?['attributes'])?['im:id']);
          final name = _s(_m(e['im:name'])?['label']);
          if (id == null || name == null) continue;
          _countryOf[id] = country;
          final images = e['im:image'];
          out.add(PodcastChartEntry(
            appleId: id,
            name: name,
            author: _s(_m(e['im:artist'])?['label']),
            artworkUrl: images is List && images.isNotEmpty ? _s(_m(images.last)?['label']) : null,
            summary: _s(_m(e['summary'])?['label']),
          ));
        }
        return out;
      });

  /// The show with this Apple id, with its feed address; null when Apple has
  /// no feed for it. Not cached: it is asked once, when the user subscribes.
  /// [country] defaults to the chart the show was seen in, else Italy.
  Future<PodcastSearchHit?> lookup(String appleId, {String? country}) async {
    final json = await _getMap('$_host/lookup', {'id': appleId, 'country': country ?? _countryOf[appleId] ?? 'it'});
    final hits = _hits(json['results']);
    return hits.isEmpty ? null : hits.first;
  }

  /// Search; [country] (two letters) and [genreId] narrow it.
  Future<List<PodcastSearchHit>> search(String term, {int limit = 10, String? country, String? genreId}) async {
    final t = term.trim();
    if (t.isEmpty) return const [];
    final json = await _getMap('$_host/search', {
      'media': 'podcast',
      'term': t,
      'limit': '$limit',
      'country': ?country,
      'genreId': ?genreId,
    });
    if (json['results'] is! List) throw const PodcastException(PodcastErrorKind.network, 'search');
    return _hits(json['results']);
  }

  /// Results without a feed address are dropped.
  List<PodcastSearchHit> _hits(Object? results) {
    final out = <PodcastSearchHit>[];
    for (final r in results is List ? results : const []) {
      if (r is! Map) continue;
      final feed = _s(r['feedUrl']);
      final name = _s(r['collectionName']) ?? _s(r['trackName']);
      if (feed == null || feed.isEmpty || name == null) continue;
      final count = r['trackCount'];
      out.add(PodcastSearchHit(
        name: name,
        feedUrl: feed,
        author: _s(r['artistName']),
        artworkUrl: _s(r['artworkUrl600']) ?? _s(r['artworkUrl100']),
        episodeCount: count is int ? count : null,
      ));
    }
    return out;
  }
}
