import '../../data/db/app_database.dart' show Track;
import '../../data/repositories/library_queries.dart' show ArtistSummary;
import '../import/track_matcher.dart' show libraryTitleKey;
import 'youtube_service.dart' show YtResult;
import '../../core/artist_key.dart';

/// The library artist that is [name] on YouTube Music: same main artist once
/// case, accents and «feat.» are ignored («PINK FLOYD» = «Pink Floyd»). With
/// several (spelled differently in the tags) the one with most tracks.
ArtistSummary? localArtistFor(String name, List<ArtistSummary> artists) {
  final want = artistKey(name);
  if (want.isEmpty) return null;
  ArtistSummary? best;
  for (final a in artists) {
    final n = a.name;
    if (n == null || artistKey(n) != want) continue;
    if (best == null || a.trackCount > best.trackCount) best = a;
  }
  return best;
}

/// The songs of one artist's library, to tell which online songs are already
/// there even when they came from a file or from another video.
class LibraryOverlap {
  LibraryOverlap(Iterable<Track> artistTracks)
    : _titles = {for (final t in artistTracks) libraryTitleKey(t.title)};

  final Set<String> _titles;

  /// Same title (remaster, feat. and edition tags ignored): the artist is
  /// already the same, so the length does not matter (D-389).
  bool owns(YtResult r) => _titles.contains(libraryTitleKey(r.title));
}

/// Whether [r] is one of [artistTracks] (see [LibraryOverlap.owns]).
bool ownedIn(List<Track> artistTracks, YtResult r) =>
    LibraryOverlap(artistTracks).owns(r);
