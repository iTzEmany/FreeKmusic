import '../../data/db/app_database.dart' show Track;
import '../stream/stream_key.dart';

export 'karaoke_video_source.dart';

const _youtube = 'youtube:';

/// The YouTube video id of a track streamed from YouTube (`online:youtube:<id>` or its shadow row
/// `stream:youtube:<id>`); null for a local or downloaded file and any other source.
String? karaokeVideoId(Track track) {
  final path = track.path;
  final key = path.startsWith('online:') ? path.substring(7) : keyOfStreamPath(path);
  return key != null && key.startsWith(_youtube) && key.length > _youtube.length
      ? key.substring(_youtube.length)
      : null;
}

/// A karaoke video (D-634, D-646): streamed from YouTube with «karaoke» in the title.
/// shortcut: YouTube Music and video share the `youtube:` key, so a YTM «… karaoke» counts too (D-646).
bool isKaraokeVideo(Track track) =>
    karaokeVideoId(track) != null && track.title.toLowerCase().contains('karaoke');
