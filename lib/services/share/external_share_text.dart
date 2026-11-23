import '../../core/app_log.dart';
import '../../data/db/app_database.dart' show Track;
import '../export/playlist_exporter.dart' show streamUrlOf;
import 'share_fragment.dart';

/// The page that opens a shared link (D-702); the fragment after `#` carries the tracks.
const kSharePageUrl = 'https://itzemany.github.io/FreeKmusic/';

/// Rows named in the text before the "…" (the page and the links carry the rest).
const _maxListed = 10;

final _videoId = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// The YouTube video id of each streamed row; a local file has none and is left out, and so is an invalid id.
List<String> sharedIds(List<Track> tracks) => [
  for (final t in tracks)
    if (Uri.tryParse(streamUrlOf(t) ?? '')?.queryParameters['v'] case final id? when _videoId.hasMatch(id)) id,
];

/// True when the tracks do not fit one link (D-702): share an m3u8 file instead.
bool exceedsShareLimit(List<Track> tracks) => sharedIds(tracks).length > kMaxSharedTracks;

String _label(Track t) => (t.artist ?? '').isEmpty ? t.title : '${t.artist} - ${t.title}';

/// Readable text for a track, album or playlist, within [kMaxSharedTracks] linked tracks:
/// the names, the YouTube Music links and the page link. Local files appear as text only.
String buildShareText(SharedKind kind, String title, List<Track> tracks, {String? subtitle}) {
  final ids = sharedIds(tracks);
  final lines = <String>[];
  if (kind == SharedKind.track && tracks.isNotEmpty) {
    lines.add(_label(tracks.first));
    if (ids.isNotEmpty) lines.add('https://music.youtube.com/watch?v=${ids.first}');
  } else {
    lines.add((subtitle ?? '').isEmpty ? title : '$title - $subtitle');
    for (var i = 0; i < tracks.length && i < _maxListed; i++) {
      lines.add('${i + 1}. ${_label(tracks[i])}');
    }
    if (tracks.length > _maxListed) lines.add('…');
    final browseId = tracks.map((t) => t.albumBrowseId).nonNulls.firstOrNull;
    if (kind == SharedKind.album && browseId != null) lines.add('https://music.youtube.com/browse/$browseId');
  }
  if (ids.isNotEmpty) {
    try {
      lines.add('$kSharePageUrl#${encodeShareFragment(SharedFragment(kind, title, ids))}');
    } on Object catch (e, st) {
      AppLog.w('share: page link not built, text only', e, st);
    }
  }
  return lines.join('\n');
}
