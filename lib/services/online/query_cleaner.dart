import '../../core/text_utils.dart';
import '../../core/artist_key.dart';

class CleanQuery {
  const CleanQuery(this.title, this.artist, {this.tagged});

  final String title, artist;

  /// The query as the tags say it, set only when «A - B» was read as
  /// «uploader / Artist - Title»: a legit «Symphony No. 5 - I. Allegro» is
  /// still found by retrying with it.
  final CleanQuery? tagged;

  @override
  String toString() => 'CleanQuery($title | $artist)';
}

final _ext = RegExp(r'\.(mp3|m4a|flac|wav|ogg|aac|wma)$', caseSensitive: false);
final _prefix = RegExp(r'^(mix|audio|video|mashup)\s+', caseSensitive: false);
final _numbering = RegExp(r'^\d{1,3}[\s._-]+');
final _noiseGroup = RegExp(
  r'[\(\[\{][^\)\]\}]*(official|video|audio|remaster|hd|4k|hq|lyric|visualizer|clip|deluxe|bonus)[^\)\]\}]*[\)\]\}]',
  caseSensitive: false,
);

/// «- Remastered 2011», «- 2009 Remaster», «- Remaster»: a tail that says
/// nothing about which song it is.
final _remasterTail = RegExp(
  r'\s*[-–—]\s*(?:\d{4}\s+)?remaster(?:ed)?(?:\s+(?:version|edition))?(?:\s+\d{4})?\s*$',
  caseSensitive: false,
);

/// «Song (2)»: the copy number a file manager adds to a duplicate.
final _copyNumber = RegExp(r'\s*\(\d{1,2}\)\s*$');

final _noisePhrase = RegExp(
  r'\b(official video|official audio|lyric video|4k remaster|remastered)\b',
  caseSensitive: false,
);
final _separator = RegExp(r' [-–—] ');

/// B of «A - B» that is a version of the song, not its title («Song - Live»);
/// read outside brackets, so «Believer (Romy Wave Cover)» is still a title.
/// Mirrors `otherVersions` (track_matcher imports this file, so no import).
final _versionTail = RegExp(
  r'\b(live|cover|karaoke|remix|mix|edit|radio|extended|original|version|acoustic|demo|instrumental|remaster(?:ed)?|unplugged|slowed|sped up|nightcore|reverb|mashup|from|feat|ft)\b',
  caseSensitive: false,
);

/// Pictographs, dingbats and joiners that YouTube titles decorate with.
final _emoji = RegExp(
  '[\\u{1F000}-\\u{1FAFF}\\u{2600}-\\u{27BF}\\u{2B00}-\\u{2BFF}\\uFE0F\\u200D]',
  unicode: true,
);
final _cjkBrackets = RegExp('【[^】]*】');
final _emptyPiece = RegExp(r'^\s*$|^\s*[-–—]\s|\s[-–—]\s*$');
final _squareGroup = RegExp(r'\[[^\]]*\]');
final _ostTag = RegExp(r'[\(\[]\s*ost\s*[\)\]]', caseSensitive: false);

/// Channel numbering «No.19»: only bracketed, or leading/trailing around a
/// separator, so «Symphony No. 5 - I. Allegro» keeps its number.
final _channelNo = RegExp(
  r'[\(\[]\s*no\.?\s*\d+\s*[\)\]]|^no\.?\s*\d+\s*[-–—|:]\s*|\s[-–—|]\s*no\.?\s*\d+\s*$',
  caseSensitive: false,
);

/// «"Song" by X» / «_Song_ by X»: only after a closing quote or underscore,
/// so «Stand by Me» is not split.
final _byArtist = RegExp(r'(?<=["”_])\s+by\s+([^"”_]+)$', caseSensitive: false);
final _bracketGroup = RegExp(r'[\(\[\{][^\)\]\}]*[\)\]\}]');
final _artistSuffix = RegExp(
  r'\s*(?:-\s*)?(official|vevo|topic)$',
  caseSensitive: false,
);

String _fixQuotes(String s) => s
    .replaceAll(RegExp('["“”`]'), '')
    .replaceAll('’', "'")
    .replaceAll('‘', "'");

bool isGenericArtist(String artist) {
  final a = artist.trim().toLowerCase();
  return a.isEmpty ||
      a.contains('sconosciuto') ||
      a.contains('unknown') ||
      a.endsWith(' official') ||
      a.endsWith('vevo') ||
      a.endsWith(' - topic');
}

/// Longer input is cut: the regexes below are quadratic on pathological text.
const _maxInput = 300;
String _cut(String s) => s.length > _maxInput ? s.substring(0, _maxInput) : s;

CleanQuery cleanSearchQuery(String rawTitle, String rawArtist) {
  rawTitle = _cut(rawTitle);
  rawArtist = _cut(rawArtist);
  var title = rawTitle.trim().replaceFirst(_ext, '');
  title = title.replaceFirst(_prefix, '');
  title = title.replaceFirst(_numbering, '');
  title = title.replaceFirst(_copyNumber, '').replaceFirst(_remasterTail, '');
  var genericArtist = isGenericArtist(rawArtist);
  var artist = rawArtist.trim();

  title = title.replaceAll(_noiseGroup, ' ').replaceAll(_noisePhrase, ' ');
  title = title
      .replaceAll(_emoji, ' ')
      .replaceAll(_cjkBrackets, ' ')
      .replaceAll(_ostTag, ' ')
      .replaceAll(_channelNo, ' ');
  final noSquare = title.replaceAllMapped(
    _squareGroup,
    (m) => _versionTail.hasMatch(m[0]!) ? m[0]! : ' ',
  );
  // «[Intro]» or «Artist - [Intro]» is all title: keep the brackets then.
  if (!_emptyPiece.hasMatch(noSquare)) title = noSquare;
  final by = _byArtist.firstMatch(title);
  if (by != null) {
    var song = title.substring(0, by.start);
    // The quoted song is the last « - » piece: «Game - OST - _Song_».
    final i = song.lastIndexOf(_separator);
    if (genericArtist && i >= 0) song = song.substring(i + 3);
    song = _fixQuotes(song.replaceAll('_', ' ')).trim();
    // An empty song keeps the title as it was; the by-artist only fills a generic tag.
    if (song.isNotEmpty) {
      title = song;
      final who = _fixQuotes(by[1]!).replaceFirst(_artistSuffix, '').trim();
      if (genericArtist && who.isNotEmpty) {
        artist = who;
        genericArtist = false;
      }
    }
  }
  title = _fixQuotes(title).replaceAll(RegExp(r'\s+'), ' ').trim();
  artist = _fixQuotes(artist);

  CleanQuery? tagged;
  final m = _separator.firstMatch(title);
  if (m != null) {
    final a = title.substring(0, m.start).trim();
    final b = title.substring(m.end).trim();
    if (a.isNotEmpty && b.isNotEmpty) {
      if (genericArtist) {
        (artist, title) = _creditSplit(a, b);
      } else {
        final tag = normalize(artist.replaceFirst(_artistSuffix, ''));
        if (normalize(a) == tag) {
          title = b;
        } else if (tag.isNotEmpty &&
            !normalize(a).contains(tag) &&
            !normalize(b).contains(tag) &&
            !_versionTail.hasMatch(b.replaceAll(_bracketGroup, ' '))) {
          // The tagged artist is the YouTube uploader: «Real Artist - Title».
          tagged = CleanQuery(
            title,
            artist.replaceFirst(_artistSuffix, '').trim(),
          );
          (artist, title) = _creditSplit(a, b);
        }
      }
    }
  }
  artist = artist.replaceFirst(_artistSuffix, '');
  return CleanQuery(title.trim(), artist.trim(), tagged: tagged);
}

/// (artist, title) of «a - b» when the artist is not known.
(String, String) _creditSplit(String a, String b) {
  // «Fueled By Ramen and twenty one pilots - twenty one pilots Stressed
  // Out»: when the title repeats one side of an «and», that side is the
  // artist and the other is a label or a guest.
  for (final side
      in a.split(RegExp(r'\s+(?:and|&)\s+', caseSensitive: false)).reversed) {
    final sideTrim = side.trim();
    if (sideTrim.isNotEmpty &&
        sideTrim != a &&
        b.toLowerCase().startsWith('${sideTrim.toLowerCase()} ')) {
      return (sideTrim, b.substring(sideTrim.length).trim());
    }
  }
  return (a, b);
}

/// The names of [artist] in order, each with the separator text that follows it
/// ('' for the last); empty pieces are dropped.
List<({String name, String sep})> splitArtists(String artist) {
  final out = <({String name, String sep})>[];
  var pos = 0;
  void add(String raw, String sep) {
    final name = raw.trim();
    if (name.isNotEmpty) out.add((name: name, sep: sep));
  }

  for (final m in artistSplit.allMatches(artist)) {
    add(artist.substring(pos, m.start), m.group(0)!);
    pos = m.end;
  }
  add(artist.substring(pos), '');
  if (out.isNotEmpty) out[out.length - 1] = (name: out.last.name, sep: '');
  return out;
}

final _coreNoise = RegExp(
  r'[\(\[\{][^\)\]\}]*(live|unplugged|acoustic|version|session|edit|from the series)[^\)\]\}]*[\)\]\}]',
  caseSensitive: false,
);

String coreTitle(String title) =>
    title.replaceAll(_coreNoise, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
