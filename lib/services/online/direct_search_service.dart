import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/app_log.dart';
import 'innertube_client.dart';
import 'youtube_service.dart';
import 'ytm_catalog.dart';
import 'youtube_urls.dart';

/// Searches YouTube and YouTube Music with one direct request ([client]) and
/// leaves everything else (addresses, albums, playlists,
/// downloads) to yt-dlp ([inner]). When the direct answer cannot be read, the
/// same search is made with yt-dlp, and yt-dlp alone is used for [cooldown].
class DirectSearchService implements YoutubeService {
  DirectSearchService(
    this.inner,
    this.client, {
    this.catalog,
    this.cooldown = const Duration(minutes: 10),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final YoutubeService inner;
  final InnerTubeClient client;

  /// Reads YouTube Music album pages directly; without it yt-dlp does.
  final YtmCatalog? catalog;
  final Duration cooldown;
  final DateTime Function() _now;
  DateTime? _directOffUntil;

  Future<List<YtResult>> _direct(
    String what,
    Future<List<YtResult>> Function() direct,
    Future<List<YtResult>> Function() fallback,
  ) async {
    final off = _directOffUntil;
    if (off != null && _now().isBefore(off)) return fallback();
    try {
      return await direct();
    } on InnerTubeChanged catch (e) {
      AppLog.w('direct $what search unreadable ($e): yt-dlp for '
          '${cooldown.inMinutes} min');
      _directOffUntil = _now().add(cooldown);
      return fallback();
    }
  }

  @override
  Future<List<YtResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    if (isYoutubeUrl(q)) return inner.search(q);
    return _direct('YouTube', () => client.searchVideos(q), () => inner.search(q));
  }

  @override
  Future<List<YtResult>> searchSongs(String query, {int limit = 5}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    return _direct('YouTube Music', () => client.searchSongs(q, limit: limit),
        () => inner.searchSongs(q, limit: limit));
  }

  @override
  Future<List<YtResult>> searchAlbums(String query, {int limit = 3}) =>
      inner.searchAlbums(query, limit: limit);

  @override
  Future<List<YtResult>> albumTracks(String albumLink) async {
    final id = ytmAlbumBrowseId(albumLink);
    final c = catalog;
    if (id == null || c == null) return inner.albumTracks(albumLink);
    // The catalog falls back to yt-dlp itself when the page cannot be read.
    final album = await c.album(id, 'en');
    return [for (final t in album.value.tracks) t.result];
  }

  @override
  Future<PlaylistListing> listPlaylist(String url, {int limit = 500}) =>
      inner.listPlaylist(url, limit: limit);

  @override
  Stream<DownloadProgress> download(YtResult r, Directory outDir,
          {CancelToken? cancel, DownloadOptions options = const DownloadOptions()}) =>
      inner.download(r, outDir, cancel: cancel, options: options);

  @override
  Future<String?> toolVersion() => inner.toolVersion();

  @override
  void close() {
    client.close();
    inner.close();
  }
}
