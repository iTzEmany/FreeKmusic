import '../../data/db/app_database.dart' show Track;
import '../export/playlist_exporter.dart' show streamUrlOf;
import 'share_fragment.dart';

/// Rows named in the text before the "…" (the page and the links carry the rest).
const _maxListed = 10;

/// The row of [t] in the shared link (D-713): its YouTube video id (from a streamed row's address, which
/// wins as `videoId` may be old after a demote; else kept at download), else its artist + title for a search.
/// An invalid id counts as none.
SharedRow shareRowOf(Track t) {
  final id = Uri.tryParse(streamUrlOf(t) ?? '')?.queryParameters['v'] ?? t.videoId;
  return id != null && isVideoId(id) ? SharedRow.id(id) : SharedRow.search(t.artist ?? '', t.title);
}

/// The page link the app's scanner opens (D-713): [kSharePageUrl] and the fragment of [tracks].
String shareLink(SharedKind kind, String title, List<Track> tracks) =>
    '$kSharePageUrl#${encodeShareFragment(SharedFragment(kind, title, [for (final t in tracks) shareRowOf(t)]))}';

/// The short text sent with the share card: the name and the page link (no link without tracks).
String buildShareCaption(SharedKind kind, String title, List<Track> tracks) {
  final name = title.trim().isEmpty ? untitledShare : title;
  return tracks.isEmpty ? name : '$name\n${shareLink(kind, title, tracks)}';
}

/// Longest link that is still shared as a link; above it an m3u8 file goes instead. Chosen so that
/// 50 tracks with ids fit and a long list of titles does not turn into a link a chat app may cut.
const _maxLinkChars = 2000;

/// Longest link whose QR a phone reads from a picture seen on another phone: 412 bytes is QR version 15
/// at level M (77 modules, about 6 px each at the card's 480 px). Version 20 left about 3.7 px per module. Above it the card has no QR.
const _maxQrLinkChars = 412;

/// True when a QR of [link] stays readable (the card shows it only then, D-713).
bool shareLinkFitsQr(String link) => link.length <= _maxQrLinkChars;

/// The link the card's QR holds: the page link, or null when there are no tracks or it is too long for a QR.
String? shareCardLink(SharedKind kind, String title, List<Track> tracks) {
  if (tracks.isEmpty) return null;
  final link = shareLink(kind, title, tracks);
  return shareLinkFitsQr(link) ? link : null;
}

/// True when the tracks do not fit one link (D-702, D-713): more than [kMaxSharedTracks] of them
/// (local files count too) or a link above [_maxLinkChars]. Share an m3u8 file instead.
bool exceedsShareLimit(List<Track> tracks, {SharedKind kind = SharedKind.playlist, String title = ''}) =>
    tracks.length > kMaxSharedTracks || (tracks.isNotEmpty && shareLink(kind, title, tracks).length > _maxLinkChars);

String _label(Track t) => (t.artist ?? '').isEmpty ? t.title : '${t.artist} - ${t.title}';

/// Readable text for a track, album or playlist, within [kMaxSharedTracks] linked tracks:
/// the names, the YouTube Music links and the page link (a track without a video id is searched by name).
String buildShareText(SharedKind kind, String title, List<Track> tracks, {String? subtitle}) {
  final ids = [for (final r in tracks.map(shareRowOf)) ?r.id];
  final lines = <String>[];
  if (kind == SharedKind.track && tracks.isNotEmpty) {
    lines.add(_label(tracks.first));
    if (ids.isNotEmpty) lines.add('https://music.youtube.com/watch?v=${ids.first}');
  } else {
    final name = title.trim().isEmpty ? untitledShare : title;
    lines.add((subtitle ?? '').isEmpty ? name : '$name - $subtitle');
    for (var i = 0; i < tracks.length && i < _maxListed; i++) {
      lines.add('${i + 1}. ${_label(tracks[i])}');
    }
    if (tracks.length > _maxListed) lines.add('…');
    final browseId = tracks.map((t) => t.albumBrowseId).nonNulls.firstOrNull;
    if (kind == SharedKind.album && browseId != null) lines.add('https://music.youtube.com/browse/$browseId');
  }
  if (tracks.isNotEmpty) lines.add(shareLink(kind, title, tracks));
  return lines.join('\n');
}
