import '../../core/text_utils.dart';
import '../db/app_database.dart';

const _dayMs = 86400000;

/// «Recenti»: played or added within this many days.
const recentDays = 30;

/// One track with its searchable texts normalised once (accents and case
/// stripped), so a key typed costs a scan of plain string comparisons.
class SearchEntry {
  SearchEntry(this.track, List<String> tags)
      : title = normalize(track.title),
        artist = normalize(track.artist ?? ''),
        album = normalize(track.album ?? ''),
        genre = normalize(track.genre ?? ''),
        year = track.year?.toString() ?? '',
        tags = [for (final t in tags) normalize(t)];

  final Track track;
  final String title, artist, album, genre, year;
  final List<String> tags;
}

/// The whole visible library, ready for [smartSearch].
class SearchIndex {
  SearchIndex(List<Track> tracks, Map<int, List<String>> tagsByTrack)
      : entries = [
          for (final t in tracks) SearchEntry(t, tagsByTrack[t.id] ?? const []),
        ];

  final List<SearchEntry> entries;
}

// Whole-text tiers, best first: exact title, title starts with, exact artist,
// album, partial title, then genre / year / tag. Anything made of words
// spread over several fields stays below (see [_wordsScore]).
const _tierTitleExact = 100;
const _tierTitleStarts = 90;
const _tierArtistExact = 80;
const _tierArtistContains = 72;
const _tierAlbumExact = 70;
const _tierAlbumContains = 66;
const _tierTitleContains = 62;
const _tierOther = 50;
const _maxWordsScore = 49;

/// How well one [word] matches [e], or 0 for no match at all. A 4-digit word
/// is also a year (exact), a known genre or a tag is matched by name.
int _wordScore(SearchEntry e, String word) {
  var best = 0;
  void take(int s) {
    if (s > best) best = s;
  }

  int field(String f, int starts, int inside) {
    if (f.isEmpty) return 0;
    if (f.startsWith(word) || f.contains(' $word')) return starts;
    return f.contains(word) ? inside : 0;
  }

  take(field(e.title, 12, 8));
  take(field(e.artist, 10, 7));
  take(field(e.album, 9, 6));
  take(field(e.genre, 5, 5));
  if (e.year == word) take(5);
  for (final t in e.tags) {
    take(field(t, 4, 4));
  }
  return best;
}

int _score(SearchEntry e, String query, List<String> words) {
  var sum = 0;
  for (final w in words) {
    final s = _wordScore(e, w);
    if (s == 0) return 0; // every word has to match some field
    sum += s;
  }
  if (e.title == query) return _tierTitleExact;
  if (e.title.startsWith(query)) return _tierTitleStarts;
  if (e.artist == query) return _tierArtistExact;
  if (e.artist.contains(query)) return _tierArtistContains;
  if (e.album == query) return _tierAlbumExact;
  if (e.album.contains(query)) return _tierAlbumContains;
  if (e.title.contains(query)) return _tierTitleContains;
  if (e.genre.contains(query) || e.year == query || e.tags.any((t) => t.contains(query))) {
    return _tierOther;
  }
  return sum > _maxWordsScore ? _maxWordsScore : sum;
}

/// The most recent of «last played» and «added».
int _recency(Track t) {
  final p = t.lastPlayedAt ?? 0;
  return p > t.addedAt ? p : t.addedAt;
}

/// True when [t] was played or added in the last [recentDays] days.
bool isRecent(Track t, int nowMs) => _recency(t) >= nowMs - recentDays * _dayMs;

/// The tracks of [index] matching the free [text]: every word has to match the
/// title, artist, album, genre, year or a tag (accents and case ignored, in
/// any order), best match first. An empty text lists everything the quick
/// filters let through, newest activity first when [recent] is on.
List<Track> smartSearch(
  SearchIndex index,
  String text, {
  bool favorites = false,
  bool recent = false,
  required int nowMs,
}) {
  final query = normalize(text);
  final words = query.isEmpty ? const <String>[] : query.split(' ');
  if (words.isEmpty && !favorites && !recent) return const [];
  final scored = <(int, Track)>[];
  for (final e in index.entries) {
    final t = e.track;
    if (favorites && !t.isFavorite) continue;
    if (recent && !isRecent(t, nowMs)) continue;
    final s = words.isEmpty ? 1 : _score(e, query, words);
    if (s > 0) scored.add((s, t));
  }
  scored.sort((a, b) {
    final byScore = b.$1.compareTo(a.$1);
    if (byScore != 0) return byScore;
    if (recent && words.isEmpty) {
      final byRecent = _recency(b.$2).compareTo(_recency(a.$2));
      if (byRecent != 0) return byRecent;
    }
    final byPlays = b.$2.playCount.compareTo(a.$2.playCount);
    if (byPlays != 0) return byPlays;
    final byTitle = a.$2.title.toLowerCase().compareTo(b.$2.title.toLowerCase());
    // Dart's sort is not stable: the id keeps equal titles in one order.
    return byTitle != 0 ? byTitle : a.$2.id.compareTo(b.$2.id);
  });
  return [for (final s in scored) s.$2];
}
