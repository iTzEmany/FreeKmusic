import '../../core/text_utils.dart';
import '../db/app_database.dart';
import 'library_queries.dart';
import 'playlist_repository.dart';

enum LibraryKind { playlist, album, artist }

/// `recent`, `alpha` and `added` keep their saved names (D-396).
enum LibrarySort {
  recent,
  added,
  alpha,
  artist,
  year,
  plays,
  duration,
  trackCount;

  /// Direction a criterion starts with: latest and most first.
  bool get defaultAscending => switch (this) {
    recent || added || plays => false,
    _ => true,
  };

  /// «Numero di brani» makes no sense for artists (D-410).
  static List<LibrarySort> forKind(LibraryKind? kind) => [
    for (final s in values)
      if (s != trackCount || kind != LibraryKind.artist) s,
  ];
}

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
    this.year,
    this.playCount,
    this.durationMs,
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
  final int? year, playCount, durationMs;

  final AlbumSummary? album;
  final ArtistSummary? artistSummary;
  final PlaylistSummary? playlist;

  /// Set for a smart playlist (its [kind] is `playlist` too).
  final SmartPlaylist? smart;
}

/// Accent-folded; digits and symbols («#») come before the letters, so each
/// initial is one contiguous block.
String sortKeyOf(LibraryEntry e) => sortKeyOfText(e.title ?? '');

String sortKeyOfText(String text) {
  final t = normalize(text);
  return (RegExp(r'^[a-z]').hasMatch(t) ? 'b' : 'a') + t;
}

/// Mixes the three collections, filters by [kind] (null = everything) and
/// orders them ([ascending] null = the criterion's own direction). Entries
/// without the value (never played, no year, no artist) come last whatever
/// the direction; ties always fall back to the alphabetical order.
List<LibraryEntry> buildLibraryEntries({
  required List<PlaylistSummary> playlists,
  required List<AlbumSummary> albums,
  required List<ArtistSummary> artists,
  List<SmartPlaylist> smart = const [],
  LibraryKind? kind,
  LibrarySort sort = LibrarySort.recent,
  bool? ascending,
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
          playCount: p.playCount,
          durationMs: p.durationMs,
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
          year: a.year,
          playCount: a.playCount,
          durationMs: a.durationMs,
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
          playCount: a.playCount,
          durationMs: a.durationMs,
          artistSummary: a,
        ),
  ];
  // Keys computed once per entry, not once per comparison.
  final keys = Map<LibraryEntry, String>.identity();
  for (final e in all) {
    keys[e] = sortKeyOf(e);
  }
  int alpha(LibraryEntry a, LibraryEntry b) => keys[a]!.compareTo(keys[b]!);
  final asc = ascending ?? sort.defaultAscending;
  Comparable<dynamic>? value(LibraryEntry e) => switch (sort) {
    LibrarySort.alpha => keys[e],
    LibrarySort.recent => e.lastPlayedAt,
    LibrarySort.added => e.addedAt == 0 ? null : e.addedAt,
    LibrarySort.artist => switch (e.kind) {
      LibraryKind.artist => e.artistSummary?.key == '' ? null : keys[e],
      LibraryKind.album =>
        e.variousArtists || e.artist == null || e.artist!.trim().isEmpty
            ? null
            : sortKeyOfText(e.artist!),
      LibraryKind.playlist => null,
    },
    LibrarySort.year => e.year,
    LibrarySort.plays => e.playCount,
    LibrarySort.duration => e.durationMs,
    LibrarySort.trackCount => e.smart != null ? null : e.count,
  };
  final values = Map<LibraryEntry, Comparable<dynamic>?>.identity();
  for (final e in all) {
    values[e] = value(e);
  }
  all.sort((a, b) {
    final va = values[a], vb = values[b];
    if (va == null || vb == null) {
      return va == vb ? alpha(a, b) : (va == null ? 1 : -1);
    }
    final c = va.compareTo(vb);
    return c != 0 ? (asc ? c : -c) : alpha(a, b);
  });
  return all;
}
