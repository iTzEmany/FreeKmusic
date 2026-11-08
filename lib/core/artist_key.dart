import 'text_utils.dart';

final _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// Apostrophe-like marks that Unicode files as letters (the Hawaiian ʻokina of
/// «Kamakawiwoʻole», the modifier apostrophe ʼ): they count as punctuation,
/// like the plain ' they stand for.
final _letterApostrophes = RegExp('[\u02B9-\u02BF]');

/// Lower-case, no accents, no punctuation. Used to compare two spellings of
/// the same name.
String matchKey(String s) => normalize(s.replaceAll('&', ' and '))
    .replaceAll(_letterApostrophes, ' ')
    .replaceAll(_nonWord, ' ')
    .trim();

/// Single artist key: [matchKey] of the primary artist (null -> '').
// Persistent format (artist_countries, artist_infos, artist_lookups, dislikes.json, backup): changing it needs a data migration.
String artistKey(String? artist) => matchKey(extractPrimaryArtist(artist ?? ''));

/// Splits a credit line like «A, B feat. C» into its artists.
final artistSplit =
    RegExp(r'\s*(?:,|&|/)\s*|\s+(?:feat|ft)\.?\s+', caseSensitive: false);

/// First name of a credit line («A, B feat. C» -> «A»).
String extractPrimaryArtist(String artist) {
  final first = artist.split(artistSplit).first.trim();
  return first.isEmpty ? artist : first;
}
