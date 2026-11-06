import 'dart:async';
import 'dart:io';


import 'package:codecore/services/online/catalog_cache.dart';
import 'package:codecore/services/online/innertube_client.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_album_search.dart' show YtmAlbumHit;
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/services/online/ytm_catalog.dart';
import 'package:dio/dio.dart' show CancelToken;

/// A catalog whose card lookup is decided by the test; nothing else is used.
class FakeCatalog extends YtmCatalog {
  FakeCatalog(this.onTopArtist)
      : super(InnerTubeClient(), _NoYoutube(),
            CatalogCache(file: () async => File('${Directory.systemTemp.path}/none.json')));

  final Future<YtmArtistRef?> Function(String query) onTopArtist;

  @override
  Future<YtmArtistRef?> topArtist(String query, String hl) => onTopArtist(query);

  @override
  Future<List<YtmArtistRef>> searchArtists(String query, String hl, {CancelToken? cancel}) async =>
      const [];

  @override
  Future<List<YtmAlbumHit>> searchAlbums(String query, String hl, {CancelToken? cancel}) async =>
      const [];

  @override
  Future<TopCard?> topCard(String query, String hl, {CancelToken? cancel}) async {
    final artist = await onTopArtist(query);
    return artist == null ? null : TopArtist(artist);
  }
}

class _NoYoutube implements YoutubeService {
  @override
  Future<List<YtResult>> search(String query) async => const [];
  @override
  Future<List<YtResult>> searchSongs(String query, {int limit = 5}) async => const [];
  @override
  Future<List<YtResult>> searchAlbums(String query, {int limit = 3}) async => const [];
  @override
  Future<List<YtResult>> albumTracks(String albumLink) async => const [];
  @override
  Future<PlaylistListing> listPlaylist(String url, {int limit = 500}) async =>
      const PlaylistListing.empty();
  @override
  Stream<DownloadProgress> download(YtResult r, Directory outDir,
          {CancelToken? cancel, DownloadOptions options = const DownloadOptions()}) =>
      const Stream.empty();
  @override
  Future<String?> toolVersion() async => null;
  @override
  void close() {}
}

/// A song as the artist and album pages list them.
YtResult ytmSong(String id, String title,
        {String artist = 'Pink Floyd', int? seconds, String artistId = 'UCpf'}) =>
    YtResult(
      id: id,
      title: title,
      channel: artist,
      duration: seconds == null ? null : Duration(seconds: seconds),
      artists: [artist],
      artistIds: [artistId],
    );
