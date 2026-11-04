import '../../core/text_utils.dart';
import '../../services/library/rules/rule_parser.dart';
import '../db/app_database.dart';
import 'library_queries.dart';
import 'playlist_repository.dart';

/// What the unified Library search shows for one text.
class LibrarySearchResults {
  const LibrarySearchResults({
    this.tracks = const [],
    this.trackTotal = 0,
    this.artists = const [],
    this.albums = const [],
    this.playlists = const [],
    this.credited = const [],
    this.artistTotal = 0,
    this.albumTotal = 0,
    this.playlistTotal = 0,
  });

  /// First few matching tracks (see `trackLimit` of [searchLibrary]).
  final List<Track> tracks;
  final int trackTotal;
  final List<ArtistSummary> artists;
  final List<AlbumSummary> albums;
  final List<PlaylistSummary> playlists;

  /// Tracks that match only through a credit (writer, producer...).
  final List<Track> credited;

  /// Matches of each kind before `sectionLimit`.
  final int artistTotal, albumTotal, playlistTotal;

  bool get isEmpty =>
      tracks.isEmpty &&
      artists.isEmpty &&
      albums.isEmpty &&
      playlists.isEmpty &&
      credited.isEmpty;
}

// The names of each list, normalised once per list (a new list comes only
// when the library changes), not again at every key typed.
final _artistNames = Expando<List<String>>();
final _albumNames = Expando<List<(String, String)>>();
final _playlistNames = Expando<List<String>>();

List<String> _normalArtists(List<ArtistSummary> list) =>
    _artistNames[list] ??= [for (final a in list) normalize(a.name ?? '')];

List<(String, String)> _normalAlbums(List<AlbumSummary> list) =>
    _albumNames[list] ??= [
      for (final a in list)
        (
          normalize(a.title ?? ''),
          normalize('${a.artist ?? ''} ${a.year ?? ''}'),
        ),
    ];

List<String> _normalPlaylists(List<PlaylistSummary> list) =>
    _playlistNames[list] ??= [for (final p in list) normalize(p.playlist.name)];

bool _hasAll(String haystack, List<String> words) =>
    words.every(haystack.contains);

/// [items] kept in order, those whose [name] equals the text first, then those
/// that start with it, then the rest.
List<T> _ranked<T>(List<(T, String)> items, String needle) {
  int tier(String n) => n == needle ? 0 : (n.startsWith(needle) ? 1 : 2);
  final sorted = [...items]..sort((a, b) => tier(a.$2).compareTo(tier(b.$2)));
  return [for (final i in sorted) i.$1];
}

/// Filters the (small) artist / album / playlist lists in memory (every word
/// of the text must be in the name, accents and case ignored); [tracks] are
/// the matches of the same text. Artists, albums and playlists are cut at
/// `sectionLimit`; the totals say how many matched.
///
/// When the text uses operators (`artista:x anno:1990..`), [tracks] are the
/// matches of the rules and the other sections only look at its plain words;
/// with no plain word they stay empty.
LibrarySearchResults searchLibrary({
  required String text,
  required List<Track> tracks,
  required List<ArtistSummary> artists,
  required List<AlbumSummary> albums,
  required List<PlaylistSummary> playlists,
  List<Track> credited = const [],
  int trackLimit = 4,
  int sectionLimit = 12,
}) {
  final withRules = hasOperators(text);
  final needle = normalize((withRules ? freeTextOf(text) : text).trim());
  if (needle.isEmpty) {
    if (!withRules) return const LibrarySearchResults();
    return LibrarySearchResults(
      tracks: tracks.take(trackLimit).toList(),
      trackTotal: tracks.length,
      credited: credited,
    );
  }
  final words = needle.split(' ');
  final artistNames = _normalArtists(artists);
  final albumNames = _normalAlbums(albums);
  final playlistNames = _normalPlaylists(playlists);
  final matchedArtists = _ranked([
    for (var i = 0; i < artists.length; i++)
      if (artists[i].key.isNotEmpty &&
          artists[i].name != null &&
          _hasAll(artistNames[i], words))
        (artists[i], artistNames[i]),
  ], needle);
  final matchedAlbums = _ranked([
    for (var i = 0; i < albums.length; i++)
      if (_hasAll('${albumNames[i].$1} ${albumNames[i].$2}', words))
        (albums[i], albumNames[i].$1),
  ], needle);
  final matchedPlaylists = [
    for (var i = 0; i < playlists.length; i++)
      if (_hasAll(playlistNames[i], words)) playlists[i],
  ];
  return LibrarySearchResults(
    tracks: tracks.take(trackLimit).toList(),
    trackTotal: tracks.length,
    artists: matchedArtists.take(sectionLimit).toList(),
    albums: matchedAlbums.take(sectionLimit).toList(),
    playlists: matchedPlaylists.take(sectionLimit).toList(),
    credited: credited,
    artistTotal: matchedArtists.length,
    albumTotal: matchedAlbums.length,
    playlistTotal: matchedPlaylists.length,
  );
}
