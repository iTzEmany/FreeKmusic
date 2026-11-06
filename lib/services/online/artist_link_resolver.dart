import '../../data/db/app_database.dart';
import '../../data/repositories/library_queries.dart';
import '../audio/online_entries.dart' show isOnlineId;
import '../../data/repositories/track_kinds.dart';
import 'query_cleaner.dart';
import 'youtube_service.dart';
import 'ytm_artist.dart';
import 'ytm_artist_resolver.dart';

/// A credited artist: [sep] is the original text that follows the name
/// ('' for the last one), [ytmId] the YouTube Music page when known.
class ArtistName {
  const ArtistName(this.name, {this.ytmId, this.sep = ''});

  final String name;
  final String? ytmId;
  final String sep;
}

/// Whether [name] is a library artist, from the already loaded [artists].
bool Function(String) isLibraryArtistIn(List<ArtistSummary> artists) {
  final keys = {for (final a in artists) a.key.toLowerCase()};
  return (name) => keys.contains(name.trim().toLowerCase());
}

/// The artists of a credit line, with their original separators. A credit that
/// is itself a library artist stays one name only when it has no comma and no
/// feat./ft. («AC/DC», «Simon & Garfunkel») and not every piece is a library artist.
List<ArtistName> creditedArtists(String credit,
    {bool Function(String name)? isLibraryArtist}) {
  final parts = splitArtists(credit);
  if (isLibraryArtist != null &&
      isLibraryArtist(credit) &&
      !RegExp(r',|\b(feat|ft)\b', caseSensitive: false).hasMatch(credit) &&
      !parts.every((p) => isLibraryArtist(p.name))) {
    return [ArtistName(credit.trim())];
  }
  return [for (final a in parts) ArtistName(a.name, sep: a.sep)];
}

/// The artists of a library track, with their original separators.
List<ArtistName> libraryArtists(Track t,
        {bool Function(String name)? isLibraryArtist}) =>
    creditedArtists(t.artist ?? '', isLibraryArtist: isLibraryArtist);

/// The artists credited on an online result; [ytmId] only where the id is not empty.
List<ArtistName> onlineArtists(YtResult r) {
  if (r.artists.isEmpty) {
    return [
      for (final a in splitArtists(r.channel)) ArtistName(a.name, sep: a.sep),
    ];
  }
  return [
    for (var i = 0; i < r.artists.length; i++)
      ArtistName(
        r.artists[i],
        ytmId: r.artistIds.length > i && r.artistIds[i].isNotEmpty
            ? r.artistIds[i]
            : null,
        sep: i == r.artists.length - 1 ? '' : ', ',
      ),
  ];
}

/// The artists of [t]: the online ones when it is streamed and [online] is
/// known, otherwise its own `artist` text.
List<ArtistName> artistsOfTrack(Track t, YtResult? online,
        {bool Function(String name)? isLibraryArtist}) =>
    online != null && (isOnlineId(t.id) || t.kind == kStreamKind)
        ? onlineArtists(online)
        : libraryArtists(t, isLibraryArtist: isLibraryArtist);

sealed class ArtistLink {
  const ArtistLink();
}

class LibraryArtist extends ArtistLink {
  const LibraryArtist(this.artist);
  final ArtistSummary artist;
}

class OnlineArtist extends ArtistLink {
  const OnlineArtist(this.artist);
  final YtmArtistRef artist;
}

class ChooseArtists extends ArtistLink {
  const ChooseArtists(this.artists);
  final List<YtmArtistRef> artists;
}

class NoArtistLink extends ArtistLink {
  const NoArtistLink();
}

/// Library first, then the artist's YouTube Music page. The network is used
/// only when the library has nobody and there is no [ytmId]; its errors propagate.
class ArtistLinkResolver {
  const ArtistLinkResolver({required this.library, required this.search, this.aliases});

  final Future<ArtistSummary?> Function(String name) library;
  final Future<List<YtmArtistRef>> Function(String name) search;

  /// Alias id -> main id of the merged artists (D-402); a group opens its main profile.
  final Future<Map<String, String>> Function()? aliases;

  Future<ArtistLink> resolve(String name, {String? ytmId}) async {
    final local = await library(name);
    if (local != null) return LibraryArtist(local);
    if (ytmId != null && ytmId.isNotEmpty) {
      return OnlineArtist(YtmArtistRef(id: ytmId, name: name));
    }
    return switch (pickYtmArtist(name, await search(name), aliases: await aliases?.call() ?? const {})) {
      ExactArtist(:final artist) => OnlineArtist(artist),
      ChooseArtist(:final artists) => ChooseArtists(artists),
      NoArtist() => const NoArtistLink(),
    };
  }
}
