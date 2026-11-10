/// What a pasted YouTube address points to.
enum YoutubeLinkKind { video, playlist, channel, album, other }

const _hosts = {'youtube.com', 'www.youtube.com', 'm.youtube.com', 'youtu.be'};

// Lists that are not a fixed set of videos: mixes, the user's own «liked» and
// «watch later», auto-generated ones. A playlist link to one of these is left
// to the normal single-video download.
bool _isDynamicList(String id) =>
    id == 'LL' ||
    id == 'WL' ||
    id.startsWith('RD') ||
    id.startsWith('UL') ||
    id.startsWith('TL');

String? _listId(Uri u) {
  final id = u.queryParameters['list'];
  return id == null || id.isEmpty || _isDynamicList(id) ? null : id;
}

List<String> _segments(Uri u) => [
  for (final s in u.pathSegments)
    if (s.isNotEmpty) s,
];

/// The channel part of the path (`@name`, `channel/UC…`, `c/name`,
/// `user/name`) without its tab, or null.
String? _channelBase(Uri u) {
  final s = _segments(u);
  if (s.isEmpty) return null;
  if (s.first.startsWith('@') && s.first.length > 1) return s.first;
  if (s.length >= 2 && const {'channel', 'c', 'user'}.contains(s.first)) {
    return '${s[0]}/${s[1]}';
  }
  return null;
}

Uri? _parse(String input) {
  final u = Uri.tryParse(input.trim());
  if (u == null || !u.hasScheme || !(u.scheme == 'http' || u.scheme == 'https')) {
    return null;
  }
  final music = u.host == 'music.youtube.com';
  if (!_hosts.contains(u.host) && !music) return null;
  return u;
}

final _albumPath = RegExp(r'^/browse/(MPREb_[\w-]+)/?$');

/// `MPREb_…` of a `music.youtube.com/browse/…` album link (query parameters
/// are ignored), else null.
String? ytmAlbumBrowseId(String link) {
  final u = _parse(link);
  if (u == null || u.host != 'music.youtube.com') return null;
  return _albumPath.firstMatch(u.path)?.group(1);
}

YoutubeLinkKind classifyYoutubeUrl(String input) {
  final u = _parse(input);
  if (u == null) return YoutubeLinkKind.other;
  if (_listId(u) != null) return YoutubeLinkKind.playlist;
  if (ytmAlbumBrowseId(input) != null) return YoutubeLinkKind.album;
  // music.youtube.com is only understood for its playlists and albums.
  if (u.host == 'music.youtube.com') return YoutubeLinkKind.other;
  if (u.host == 'youtu.be') {
    return _segments(u).isEmpty ? YoutubeLinkKind.other : YoutubeLinkKind.video;
  }
  if (_channelBase(u) != null) return YoutubeLinkKind.channel;
  final s = _segments(u);
  if (u.queryParameters['v'] != null ||
      (s.isNotEmpty && const {'shorts', 'live', 'embed'}.contains(s.first))) {
    return YoutubeLinkKind.video;
  }
  return YoutubeLinkKind.other;
}

/// The video id of a [YoutubeLinkKind.video] address, else null.
String? youtubeVideoId(String input) {
  final u = _parse(input);
  if (u == null || classifyYoutubeUrl(input) != YoutubeLinkKind.video) return null;
  final s = _segments(u);
  return u.host == 'youtu.be' ? s.first : u.queryParameters['v'] ?? s[1];
}

/// The address to hand to `yt-dlp --flat-playlist`: a playlist by its id (a
/// `watch?v=…&list=…` link becomes the playlist page), a channel by its
/// Videos tab. Null when [input] is neither.
String? listingUrl(String input) {
  final u = _parse(input);
  if (u == null) return null;
  switch (classifyYoutubeUrl(input)) {
    case YoutubeLinkKind.playlist:
      return 'https://www.youtube.com/playlist?list=${Uri.encodeQueryComponent(_listId(u)!)}';
    case YoutubeLinkKind.channel:
      return 'https://www.youtube.com/${_channelBase(u)}/videos';
    case YoutubeLinkKind.video:
    case YoutubeLinkKind.album:
    case YoutubeLinkKind.other:
      return null;
  }
}
