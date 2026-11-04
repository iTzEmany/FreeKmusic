import 'dart:io';

import 'package:codecore/services/online/youtube_service.dart';
import 'package:dio/dio.dart' show CancelToken;

import 'fake_ytm.dart';

/// Answers each kind of search differently and remembers what was asked.
class FakeYoutube implements YoutubeService {
  final calls = <String>[];

  @override
  Future<List<YtResult>> search(String query) async {
    calls.add('youtube:$query');
    return [
      const YtResult(
        id: 'y1',
        title: 'From YouTube',
        channel: 'Chan',
        duration: Duration(minutes: 3),
      ),
    ];
  }

  @override
  Future<List<YtResult>> searchSongs(String query, {int limit = 5}) async {
    calls.add('music:$query:$limit');
    return [
      ytmSong('m1', 'From YouTube Music', artist: 'Daft Punk', seconds: 180),
    ];
  }

  @override
  Future<PlaylistListing> listPlaylist(String url, {int limit = 500}) async =>
      const PlaylistListing.empty();

  @override
  Future<List<YtResult>> searchAlbums(String query, {int limit = 3}) async =>
      const [];
  @override
  Future<List<YtResult>> albumTracks(String albumLink) async => const [];
  @override
  Stream<DownloadProgress> download(
    YtResult r,
    Directory outDir, {
    CancelToken? cancel,
    DownloadOptions options = const DownloadOptions(),
  }) => const Stream.empty();
  @override
  Future<String?> toolVersion() async => null;
  @override
  void close() {}
}
