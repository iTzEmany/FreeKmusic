import 'external_links.dart';
import 'youtube_urls.dart';
import 'ytm_artist.dart';
import '../../core/artist_key.dart';

/// What the text typed in the online search is.
enum QueryKind { listing, video, album, text, external }

class ClassifiedQuery {
  const ClassifiedQuery(this.kind, [this.url, this.browseId, this.link]);

  final QueryKind kind;

  /// The address to list for [QueryKind.listing] (`listingUrl`).
  final String? url;

  /// The `MPREb_…` id for [QueryKind.album].
  final String? browseId;

  /// For [QueryKind.external]: the Deezer/Spotify page, or null when [url] is
  /// a short link still to resolve.
  final ExternalLink? link;
}

/// A playlist or channel address, a video address, or words to search.
ClassifiedQuery classifyQuery(String text) {
  final link = parseExternalLink(text);
  if (link != null) {
    return ClassifiedQuery(QueryKind.external, null, null, link);
  }
  if (isShortLink(text)) {
    return ClassifiedQuery(QueryKind.external, text.trim());
  }
  final listing = listingUrl(text);
  if (listing != null) return ClassifiedQuery(QueryKind.listing, listing);
  final albumId = ytmAlbumBrowseId(text);
  if (albumId != null) return ClassifiedQuery(QueryKind.album, null, albumId);
  if (classifyYoutubeUrl(text) == YoutubeLinkKind.video) {
    return const ClassifiedQuery(QueryKind.video);
  }
  return const ClassifiedQuery(QueryKind.text);
}

/// What the search page shows first.
enum SearchIntent {
  /// The phrase is (the start of) an artist's name: big card, then their songs.
  artistPage,

  /// An artist and more words: small card, songs first.
  artistAndSongs,
  album,

  /// The top result is a catalog song: it goes first.
  song,
  songs,
}

String _nameKey(String s) {
  final key = matchKey(s);
  return key.startsWith('the ') ? key.substring(4) : key;
}

/// A prefix of the name only counts from this many letters («vasco» yes,
/// «va» no), and only on whole words.
const _minPrefixLetters = 4;

SearchIntent intentOf(String query, TopCard? card) {
  switch (card) {
    case TopArtist(:final artist):
      final phrase = _nameKey(query), name = _nameKey(artist.name);
      final isName =
          phrase == name ||
          (phrase.replaceAll(' ', '').length >= _minPrefixLetters &&
              name.startsWith('$phrase '));
      return isName ? SearchIntent.artistPage : SearchIntent.artistAndSongs;
    case TopAlbum():
      return SearchIntent.album;
    case TopSong():
      return SearchIntent.song;
    case TopVideo() || null:
      return SearchIntent.songs;
  }
}
