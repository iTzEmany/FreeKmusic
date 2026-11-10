import 'package:dio/dio.dart';

import '../../core/app_log.dart';
import 'credits.dart';
import 'deezer_models.dart';
import 'external_collection.dart';
import 'external_links.dart';
import 'http_client.dart';

/// The request did not get an answer (offline, timeout, non-200): not «no data».
class DeezerNetworkException implements Exception {
  const DeezerNetworkException(this.url);

  final String url;

  @override
  String toString() => 'DeezerNetworkException($url)';
}

/// Metadata only. Deezer answers errors as HTTP 200 with `{"error":{"code":n}}`.
class DeezerClient {
  /// [now] is for tests. shortcut: the 10-minute rest lives here, not in
  /// `sourceCooldownProvider` (its key `MediaKind` has no Deezer), move it there if one is added.
  /// [limiter] and [pause] are for tests (link reading: <= 10 requests/s, D-523).
  DeezerClient(
    this._web, {
    DateTime Function()? now,
    RateLimiter? limiter,
    Future<void> Function(Duration)? pause,
  }) : _now = now ?? DateTime.now,
       _limiter = limiter ?? RateLimiter(minGap: const Duration(milliseconds: 100)),
       _pause = pause ?? Future<void>.delayed;

  static const _base = 'https://api.deezer.com';
  static const cooldown = Duration(minutes: 10);

  final WebClient _web;
  final DateTime Function() _now;
  final RateLimiter _limiter;
  final Future<void> Function(Duration) _pause;
  DateTime? _restUntil;

  bool get isResting => _restUntil?.isAfter(_now()) ?? false;

  Future<DeezerTrack?> trackByIsrc(String isrc, {CancelToken? cancel}) async {
    final j = await _get('$_base/track/isrc:$isrc', cancel: cancel);
    return j == null ? null : DeezerTrack.fromJson(j);
  }

  Future<List<DeezerTrack>> searchTracks(
    String q, {
    int limit = 10,
    CancelToken? cancel,
  }) async {
    final j = await _get(
      '$_base/search',
      query: {'q': q, 'limit': '$limit'},
      cancel: cancel,
    );
    final data = j?['data'];
    return [
      if (data is List)
        for (final t in data)
          if (t is Map) DeezerTrack.fromJson(t),
    ];
  }

  Future<DeezerAlbum?> album(int id, {CancelToken? cancel}) async {
    final j = await _get('$_base/album/$id', cancel: cancel);
    return j == null ? null : DeezerAlbum.fromJson(j);
  }

  /// Several editions of an album, for the cover picker: `(title, big cover url)`.
  Future<List<({String title, String url})>> albumCovers(
    String album,
    String artist, {
    CancelToken? cancel,
  }) async {
    final j = await _get(
      '$_base/search/album',
      query: {'q': '$artist $album'.trim(), 'limit': '8'},
      cancel: cancel,
    );
    final data = j?['data'];
    return [
      if (data is List)
        for (final a in data)
          if (a is Map && a['cover_xl'] is String)
            (title: '${a['title'] ?? ''}', url: a['cover_xl'] as String),
    ];
  }

  /// [album] is an already-read album: it saves the `/album` request.
  Future<TrackDetails?> trackDetails(
    int deezerId, {
    DeezerAlbum? album,
    CancelToken? cancel,
  }) async {
    final j = await _get('$_base/track/$deezerId', cancel: cancel);
    if (j == null) return null;
    final albumId = j['album'] is Map
        ? (j['album'] as Map)['id'] as int?
        : null;
    final alb =
        album ??
        (albumId == null ? null : await this.album(albumId, cancel: cancel));
    final bpm = (j['bpm'] as num?)?.toDouble();
    return TrackDetails(
      bpm: bpm == null || bpm <= 0 ? null : bpm,
      label: alb?.label,
      digitalReleaseDate: alb?.releaseDate ?? j['release_date'] as String?,
      recordType: alb?.recordType,
      rank: (j['rank'] as num?)?.toInt(),
      albumFans: alb?.fans,
      explicit: j['explicit_lyrics'] as bool?,
    );
  }

  Future<DeezerList> playlist(int id, {CancelToken? cancel}) async {
    final j = await _getPaged('$_base/playlist/$id', cancel: cancel);
    final creator = j['creator'];
    return DeezerList(
      title: '${j['title'] ?? ''}',
      coverUrl: j['picture_xl'] as String?,
      owner: creator is Map ? creator['name'] as String? : null,
      declaredTotal: (j['nb_tracks'] as num?)?.toInt(),
      tracks: await _tracks('$_base/playlist/$id/tracks?limit=100', cancel),
    );
  }

  Future<DeezerList> albumTracks(int id, {CancelToken? cancel}) async {
    final j = await _getPaged('$_base/album/$id', cancel: cancel);
    final artist = j['artist'];
    return DeezerList(
      title: '${j['title'] ?? ''}',
      coverUrl: j['cover_xl'] as String?,
      owner: artist is Map ? artist['name'] as String? : null,
      declaredTotal: (j['nb_tracks'] as num?)?.toInt(),
      tracks: await _tracks('$_base/album/$id/tracks?limit=100', cancel),
    );
  }

  Future<DeezerList> artistTop(int id, {CancelToken? cancel}) async {
    final j = await _getPaged('$_base/artist/$id', cancel: cancel);
    return DeezerList(
      title: '${j['name'] ?? ''}',
      coverUrl: j['picture_xl'] as String?,
      tracks: await _tracks('$_base/artist/$id/top?limit=50', cancel),
    );
  }

  Future<DeezerTrack> track(int id, {CancelToken? cancel}) async =>
      DeezerTrack.fromJson(await _getPaged('$_base/track/$id', cancel: cancel));

  Future<List<DeezerTrack>> _tracks(String first, CancelToken? cancel) async {
    final out = <DeezerTrack>[];
    String? url = first;
    // The page cap guards against a `next` that loops.
    for (var page = 0; url != null && page < 50; page++) {
      final j = await _getPaged(url, cancel: cancel);
      final data = j['data'];
      if (data is List) {
        out.addAll([for (final t in data) if (t is Map) DeezerTrack.fromJson(t)]);
      }
      final next = j['next'];
      url = next is String && next.startsWith('$_base/') ? next : null;
    }
    return out;
  }

  /// Link reading: paced, and a quota error (code 4) waits 5 s and tries again
  /// (3 times) without the 10-minute rest of the enrichment.
  Future<Map<dynamic, dynamic>> _getPaged(String url, {CancelToken? cancel}) async {
    for (var attempt = 0;; attempt++) {
      await _limiter.wait();
      final Object? body;
      try {
        body = await _web.getJson(url, cancel: cancel);
      } on RateLimitedException {
        throw DeezerNetworkException(url);
      }
      // Null is the network (Deezer never answers a bare 404).
      if (body is! Map) throw DeezerNetworkException(url);
      final err = body['error'];
      if (err is! Map) return body;
      final code = err['code'];
      if (code == 800 || code == 403 || code == 200 || code == 300) throw const CollectionNotFound();
      if (code == 4 && attempt < 3) {
        AppLog.w('Deezer quota exceeded while reading a link: retry in 5 s');
        await _pause(const Duration(seconds: 5));
        continue;
      }
      if (code == 4 || code == 100 || code == 700) throw DeezerNetworkException(url);
      throw CollectionUnreadable('Deezer error $code');
    }
  }

  Future<Map<dynamic, dynamic>?> _get(
    String url, {
    Map<String, String>? query,
    CancelToken? cancel,
  }) async {
    if (isResting) throw const RateLimitedException(429);
    final body = await _web.getJson(url, query: query, cancel: cancel);
    // WebClient maps every failure (timeout, offline, non-200) to null; Deezer
    // never answers a bare 404, so null here is the network, not «no data».
    if (body is! Map) throw DeezerNetworkException(url);
    final err = body['error'];
    if (err is Map) {
      final code = err['code'];
      if (code == 800) return null;
      if (code == 4) {
        _restUntil = _now().add(cooldown);
        AppLog.w(
          'Deezer quota exceeded: resting for ${cooldown.inMinutes} min',
        );
        throw const RateLimitedException(429);
      }
      AppLog.w('Deezer error $code: ${err['message']}');
      // Quota (100) and busy service (700) are transient: unknown, not «no result».
      if (code == 100 || code == 700) throw DeezerNetworkException(url);
      return null;
    }
    return body;
  }
}

/// Reads a Deezer playlist, album, artist or track link.
class DeezerCollectionReader implements ExternalReader {
  DeezerCollectionReader(this._client);

  final DeezerClient _client;

  @override
  Future<ExternalCollection> read(ExternalLink link, {CancelToken? cancelToken}) async {
    final id = int.tryParse(link.id);
    if (link.service != ExternalService.deezer || id == null) {
      throw const CollectionNotFound();
    }
    final DeezerList l;
    switch (link.kind) {
      case ExternalLinkKind.playlist:
        l = await _client.playlist(id, cancel: cancelToken);
      case ExternalLinkKind.album:
        l = await _client.albumTracks(id, cancel: cancelToken);
      case ExternalLinkKind.artist:
        l = await _client.artistTop(id, cancel: cancelToken);
      case ExternalLinkKind.track:
        final t = await _client.track(id, cancel: cancelToken);
        l = DeezerList(title: t.title, coverUrl: t.album?.coverXl, owner: t.artist, tracks: [t]);
    }
    final total = l.declaredTotal;
    return ExternalCollection(
      title: l.title,
      kind: link.kind == ExternalLinkKind.album ? CollectionKind.album : CollectionKind.playlist,
      sourceUrl: 'https://www.deezer.com/${link.kind.name}/${link.id}',
      coverUrl: l.coverUrl,
      owner: l.owner,
      declaredTotal: total,
      truncated: total != null && l.tracks.length < total,
      tracks: [
        for (final t in l.tracks)
          ExternalTrack(
            title: t.title,
            artists: [if (t.artist.isNotEmpty) t.artist],
            durationMs: t.duration > 0 ? t.duration * 1000 : null,
            isrc: t.isrc,
            key: '${t.id}',
          ),
      ],
    );
  }
}
