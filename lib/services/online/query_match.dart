import '../../core/import_row.dart';
import '../import/track_matcher.dart';
import 'query_cleaner.dart';
import 'youtube_service.dart';
import 'ytm_artist.dart';

/// Where a result of the online search comes from.
enum MediaKind { ytmSong, ytVideo }

/// Results with at least this confidence are the «Migliori risultati».
const kBestThreshold = 0.55;

/// A free search has no length to compare: [scoreCandidate] gives the neutral
/// 0.5 × 0.45 for it, which is taken off before stretching to 0..1.
const _neutralDuration = 0.225;
const _scoreRange = 0.55;

/// Versions the phrase may ask for; a result without it is a different recording.
const _askedVersionPenalty = 0.7;
/// Studio leftovers: a different recording unless the phrase asks for it.
const _alternateTakes = ['take', 'demo', 'alternate', 'outtake', 'rehearsal'];
const _alternateTakePenalty = 0.8;
const _tooShort = Duration(seconds: 60);
const _tooLong = Duration(minutes: 20);
const _shortPenalty = 0.5;
const _longPenalty = 0.5;
const _otherArtistPenalty = 0.8;
const _rankBonus = [0.05, 0.03];
const _cardSongBonus = 0.10;

/// The artist is in the phrase but none of the words asked for as title is in
/// the result: it is another song of theirs.
const _noTitleWordPenalty = 0.6;

/// A phrase with no artist: a result by an artist the user has in the library
/// gets this much more, but only when it already scores at least
/// [_affinityFloor] (so it reorders near-ties and never lifts junk).
const _affinityBonus = 0.2;
const _affinityFloor = 0.45;

/// Phrases that ask for a long recording: no penalty for a result over 20 min.
const _longAsks = ['mix', 'set', 'live', 'concerto', 'full album'];

final _channelNoise = RegExp(r'\s*[-–]?\s*(topic|vevo|official)$');

class ScoredResult {
  const ScoredResult(this.result, this.confidence, this.source, this.position);

  final YtResult result;

  /// 0..1: how likely it is what the phrase asks for.
  final double confidence;
  final MediaKind source;

  /// Place in its source's list, 0 first.
  final int position;

  ScoredResult withConfidence(double c) => ScoredResult(result, c, source, position);
}

/// The name [r] credits (artists, the one in «Artist - Title», the channel
/// without «- Topic»/VEVO/Official) that is in the phrase, longest first:
/// [name] as credited, [typed] as it stands in the phrase.
typedef _Recognized = ({String name, String typed});

_Recognized? _recognizedArtist(String queryKey, YtResult r) {
  final clean = cleanSearchQuery(r.title, r.channel);
  final names = <String>{
    ...r.artists,
    clean.artist,
    matchKey(r.channel).replaceFirst(_channelNoise, '').trim(),
  };
  _Recognized? best;
  for (final n in names) {
    final key = matchKey(n);
    if (key.length < 2) continue;
    final typed = hasPhrase(queryKey, key) ? key : _typedStartOf(queryKey, key);
    if (typed == null) continue;
    if (best == null || typed.length > best.typed.length) best = (name: key, typed: typed);
  }
  return best;
}

/// People drop the tail of a band name («jimi hendrix» for «The Jimi Hendrix
/// Experience»): the words of the phrase that start the name (without «the»),
/// at least two of them.
String? _typedStartOf(String queryKey, String name) {
  final words = (name.startsWith('the ') ? name.substring(4) : name).split(' ');
  for (var n = words.length - 1; n >= 2; n--) {
    final start = words.take(n).join(' ');
    if (hasPhrase(queryKey, start)) return start;
  }
  return null;
}

String _without(String queryKey, String phrase) {
  final words = queryKey.split(' '), drop = phrase.split(' ');
  for (var i = 0; i + drop.length <= words.length; i++) {
    if (words.sublist(i, i + drop.length).join(' ') == phrase) {
      return [...words.sublist(0, i), ...words.sublist(i + drop.length)].join(' ');
    }
  }
  return queryKey;
}

/// The key under which a library artist is compared with a result's artist:
/// primary artist only, without a leading «the».
String libraryArtistKey(String name) {
  final key = artistKey(name);
  return key.startsWith('the ') ? key.substring(4) : key;
}

bool _byLibraryArtist(YtResult r, Set<String> library) {
  final String name;
  if (r.artists.isNotEmpty) {
    name = r.artists.first;
  } else {
    final clean = cleanSearchQuery(r.title, r.channel).artist;
    name = clean.isNotEmpty
        ? clean
        : matchKey(r.channel).replaceFirst(_channelNoise, '').trim();
  }
  final key = libraryArtistKey(name);
  return key.isNotEmpty && library.contains(key);
}

/// How likely [r] is what [query] asks for, 0..1. [rank] is the place among
/// the YouTube Music songs (the first two get a small bonus), -1 for a video;
/// [fromTopCard] marks the song the top card points to. [libraryArtists]
/// ([libraryArtistKey] of each) give a small bonus to their results; pass it
/// only for a phrase that names no artist (see [scoreAll]).
double queryConfidence(String query, YtResult r,
    {int rank = -1,
    bool fromTopCard = false,
    Set<String> libraryArtists = const {}}) {
  final queryKey = matchKey(query);
  final artist = _recognizedArtist(queryKey, r);
  // With only the artist in the phrase the title cannot tell results apart:
  // every song of theirs fits, and the version words are not compared.
  final rest = artist == null ? queryKey : _without(queryKey, artist.typed);
  final row = ImportRow(
    index: 0,
    title: rest.isEmpty ? r.title : rest,
    artists: artist == null ? const [] : [artist.name],
  );
  var c = (scoreCandidate(row, r) - _neutralDuration) / _scoreRange;

  final gotTitle = matchTitleKey(r.title);
  final gotWords = gotTitle.split(' ').toSet();
  if (artist != null &&
      rest.isNotEmpty &&
      !rest.split(' ').any(gotWords.contains)) {
    c *= _noTitleWordPenalty;
  }
  if (otherVersions.any((w) => hasPhrase(queryKey, w) && !hasPhrase(gotTitle, w))) {
    c *= _askedVersionPenalty;
  }
  if (_alternateTakes.any((w) => !hasPhrase(queryKey, w) && hasPhrase(gotTitle, w))) {
    c *= _alternateTakePenalty;
  }
  final length = r.duration;
  if (length != null && length < _tooShort) c *= _shortPenalty;
  if (rank >= 0 && rank < _rankBonus.length) c += _rankBonus[rank];
  if (fromTopCard) c += _cardSongBonus;
  if (artist == null && queryKey.split(' ').any((w) => !gotWords.contains(w))) {
    c *= _otherArtistPenalty;
  }
  if (libraryArtists.isNotEmpty &&
      c >= _affinityFloor &&
      _byLibraryArtist(r, libraryArtists)) {
    c += _affinityBonus;
  }
  return c.clamp(0.0, 1.0).toDouble();
}

/// Scores every result of both sources. A result over 20 minutes is cut down
/// when the phrase looks for a song (YouTube Music has one above the
/// threshold) and does not ask for a mix, a set or a concert. With
/// [libraryArtists] and a phrase that names no artist (none of the results
/// credits one that is in it), results by those artists get a small bonus.
List<ScoredResult> scoreAll(
  String query, {
  required List<YtResult> songs,
  required List<YtResult> videos,
  TopCard? card,
  Set<String> libraryArtists = const {},
}) {
  final phraseKey = matchKey(query);
  final namesArtist = libraryArtists.isNotEmpty &&
      [...songs, ...videos].any((r) => _recognizedArtist(phraseKey, r) != null);
  final affinity = namesArtist ? const <String>{} : libraryArtists;
  final cardSong = card is TopSong ? card.videoId : null;
  final out = <ScoredResult>[
    for (final (i, r) in songs.indexed)
      ScoredResult(r,
          queryConfidence(query, r,
              rank: i, fromTopCard: r.id == cardSong, libraryArtists: affinity),
          MediaKind.ytmSong, i),
    for (final (i, r) in videos.indexed)
      ScoredResult(
          r, queryConfidence(query, r, libraryArtists: affinity), MediaKind.ytVideo, i),
  ];
  final queryKey = matchKey(query);
  final asksLong = _longAsks.any((w) => hasPhrase(queryKey, w));
  final looksForSong = out.any(
      (s) => s.source == MediaKind.ytmSong && s.confidence >= kBestThreshold);
  if (asksLong || !looksForSong) return out;
  return [
    for (final s in out)
      (s.result.duration ?? Duration.zero) > _tooLong
          ? s.withConfidence(s.confidence * _longPenalty)
          : s,
  ];
}
