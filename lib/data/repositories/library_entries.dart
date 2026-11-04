import '../../core/text_utils.dart';
import '../db/app_database.dart';
import 'library_queries.dart';
import 'playlist_repository.dart';

enum LibraryKind { playlist, album, artist }

enum LibrarySort { recent, alpha, added }

/// One row/tile of the Library: a playlist, an album or an artist.
class LibraryEntry {
  const LibraryEntry({
    required this.kind,
    required this.id,
    required this.title,
    required this.count,
    this.coverKey,
    this.coverKeys = const [],
    this.artist,
    this.variousArtists = false,
    this.lastPlayedAt,
    this.addedAt = 0,
    this.album,
    this.artistSummary,
    this.playlist,
    this.smart,
  });

  final LibraryKind kind;

  /// Unique inside its kind (album key, artist key, playlist id).
  final String id;
  final String? title;

  /// Tracks (album / playlist) or albums-and-tracks owner count.
  final int count;
  final String? coverKey;
  final List<String> coverKeys;

  /// Album artist (albums only).
  final String? artist;
  final bool variousArtists;
  final int? lastPlayedAt;
  final int addedAt;

  final AlbumSummary? album;
  final ArtistSummary? artistSummary;
  final PlaylistSummary? playlist;

  /// Set for a smart playlist (its [kind] is `playlist` too).
  final SmartPlaylist? smart;
}

/// Accent-folded; digits and symbols («#») come before the letters, so each
/// initial is one contiguous block.
String sortKeyOf(LibraryEntry e) {
  final t = normalize(e.title ?? '');
  return (RegExp(r'^[a-z]').hasMatch(t) ? 'b' : 'a') + t;
}

/// Mixes the three collections, filters by [kind] (null = everything) and
/// orders them. Ties always fall back to the alphabetical order.
List<LibraryEntry> buildLibraryEntries({
  required List<PlaylistSummary> playlists,
  required List<AlbumSummary> albums,
  required List<ArtistSummary> artists,
  List<SmartPlaylist> smart = const [],
  LibraryKind? kind,
  LibrarySort sort = LibrarySort.recent,
}) {
  final all = <LibraryEntry>[
    if (kind == null || kind == LibraryKind.playlist)
      for (final p in playlists)
        LibraryEntry(
          kind: LibraryKind.playlist,
          id: '${p.playlist.id}',
          title: p.playlist.name,
          count: p.trackCount,
          coverKey: p.coverKey,
          lastPlayedAt: p.lastPlayedAt,
          addedAt: p.addedAt,
          playlist: p,
        ),
    if (kind == null || kind == LibraryKind.playlist)
      for (final s in smart)
        LibraryEntry(
          kind: LibraryKind.playlist,
          id: 'smart:${s.id}',
          title: s.name,
          count: 0,
          addedAt: s.createdAt,
          smart: s,
        ),
    if (kind == null || kind == LibraryKind.album)
      for (final a in albums)
        LibraryEntry(
          kind: LibraryKind.album,
          id: a.albumKey,
          title: a.title,
          count: a.trackCount,
          coverKey: a.coverKey,
          artist: a.artist,
          variousArtists: a.variousArtists,
          lastPlayedAt: a.lastPlayedAt,
          addedAt: a.addedAt,
          album: a,
        ),
    if (kind == null || kind == LibraryKind.artist)
      for (final a in artists)
        LibraryEntry(
          kind: LibraryKind.artist,
          id: a.key,
          title: a.name,
          count: a.trackCount,
          coverKey: a.coverKey,
          lastPlayedAt: a.lastPlayedAt,
          addedAt: a.addedAt,
          artistSummary: a,
        ),
  ];
  // Keys computed once per entry, not once per comparison.
  final keys = Map<LibraryEntry, String>.identity();
  for (final e in all) {
    keys[e] = sortKeyOf(e);
  }
  int alpha(LibraryEntry a, LibraryEntry b) => keys[a]!.compareTo(keys[b]!);
  switch (sort) {
    case LibrarySort.alpha:
      all.sort(alpha);
    case LibrarySort.recent:
      // Played ones first (latest first), then the never-played alphabetically.
      all.sort((a, b) {
        final pa = a.lastPlayedAt, pb = b.lastPlayedAt;
        if (pa != null && pb != null) {
          final c = pb.compareTo(pa);
          return c != 0 ? c : alpha(a, b);
        }
        if (pa != null) return -1;
        if (pb != null) return 1;
        return alpha(a, b);
      });
    case LibrarySort.added:
      all.sort((a, b) {
        final c = b.addedAt.compareTo(a.addedAt);
        return c != 0 ? c : alpha(a, b);
      });
  }
  return all;
}
