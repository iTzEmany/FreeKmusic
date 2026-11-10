enum ExternalService { deezer, spotify }

enum ExternalLinkKind { playlist, album, track, artist }

/// A Deezer or Spotify page address, taken apart.
class ExternalLink {
  const ExternalLink(this.service, this.kind, this.id);

  final ExternalService service;
  final ExternalLinkKind kind;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is ExternalLink &&
      other.service == service &&
      other.kind == kind &&
      other.id == id;

  @override
  int get hashCode => Object.hash(service, kind, id);

  @override
  String toString() => 'ExternalLink($service, $kind, $id)';
}

const _deezerHosts = {'deezer.com', 'www.deezer.com'};
const _shortHosts = {'link.deezer.com', 'deezer.page.link', 'spotify.link'};

final _deezerPath = RegExp(
    r'^/(?:[a-z]{2}(?:-[a-z]{2})?/)?(playlist|album|track|artist)/(\d+)/?$');
final _spotifyPath = RegExp(
    r'^/(?:intl-[a-z]{2}(?:-[a-z]{2})?/)?(playlist|album|track|artist)/([A-Za-z0-9]+)/?$');

Uri? _web(String input) {
  final u = Uri.tryParse(input.trim());
  if (u == null || (u.scheme != 'http' && u.scheme != 'https')) return null;
  return u;
}

/// A Deezer or Spotify playlist, album, track or artist link; null otherwise.
ExternalLink? parseExternalLink(String input) {
  final u = _web(input);
  if (u == null) return null;
  final spotify = u.host == 'open.spotify.com';
  if (!spotify && !_deezerHosts.contains(u.host)) return null;
  final m = (spotify ? _spotifyPath : _deezerPath).firstMatch(u.path);
  if (m == null) return null;
  return ExternalLink(
    spotify ? ExternalService.spotify : ExternalService.deezer,
    ExternalLinkKind.values.byName(m.group(1)!),
    m.group(2)!,
  );
}

/// A share link that only redirects to the real page.
bool isShortLink(String input) {
  final u = _web(input);
  return u != null && _shortHosts.contains(u.host) && u.path.length > 1;
}
