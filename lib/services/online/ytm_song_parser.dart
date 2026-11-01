/// Reader for the `next` answer of one YouTube Music video: what kind of
/// video it is (the studio «Topic» upload, the official clip, anyone's upload).
library;

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'innertube_client.dart' show InnerTubeChanged;
import 'innertube_json.dart';

class YtmSong {
  const YtmSong({
    required this.title,
    required this.artists,
    this.album,
    this.durationMs,
    required this.videoType,
  });

  /// [artists] is empty for an upload by a plain channel (the channel is not
  /// the artist); [videoType] is `MUSIC_VIDEO_TYPE_ATV`, `_OMV`, `_UGC`, ….
  final String title, videoType;
  final List<String> artists;
  final String? album;
  final int? durationMs;

  /// Studio audio (ATV) or official clip (OMV).
  bool get official => videoType == 'MUSIC_VIDEO_TYPE_ATV' || videoType == 'MUSIC_VIDEO_TYPE_OMV';
}

/// The first item of the queue (the asked video). Throws [InnerTubeChanged]
/// when there is none or it has no title or video type.
YtmSong parseYtmSong(Map next) {
  final item = collectRenderers(next, 'playlistPanelVideoRenderer').firstOrNull;
  if (item == null) throw const InnerTubeChanged('no playlistPanelVideoRenderer');
  final title = runsText(item['title']);
  final type = collectRenderers(item, 'watchEndpointMusicConfig').firstOrNull?['musicVideoType'];
  if (title.isEmpty || type is! String) throw const InnerTubeChanged('song without title or musicVideoType');
  final runs = (item['longBylineText'] as Map?)?['runs'];
  final artists = <String>[];
  String? album;
  if (runs is List) {
    for (final r in runs) {
      if (r is! Map || r['text'] is! String) continue;
      final pageType = pageTypeOf(r);
      if (pageType == 'MUSIC_PAGE_TYPE_ARTIST') artists.add(r['text'] as String);
      if (pageType == 'MUSIC_PAGE_TYPE_ALBUM') album = r['text'] as String;
    }
  }
  return YtmSong(
    title: title,
    artists: artists,
    album: album,
    durationMs: clockMs(runsText(item['lengthText'])),
    videoType: type,
  );
}

/// «m:ss» or «h:mm:ss» in milliseconds, null when it is not a time.
@visibleForTesting
int? clockMs(String text) {
  final parts = text.split(':').map(int.tryParse).toList();
  if (parts.length > 3 || parts.contains(null)) return null;
  // Every field after the first is seconds or minutes: 0..59.
  if (parts.skip(1).any((p) => p! < 0 || p > 59) || parts.first! < 0) return null;
  return parts.fold<int>(0, (a, p) => a * 60 + p!) * 1000;
}
