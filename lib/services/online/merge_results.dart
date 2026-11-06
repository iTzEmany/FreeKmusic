import '../../core/import_row.dart' show ImportRow, LibraryEntryLite;
import '../import/track_matcher.dart' show LibraryIndex, matchKey, matchTitleKey;
import 'query_cleaner.dart';
import 'query_intent.dart' show SearchIntent;
import 'query_match.dart';
import 'youtube_service.dart';

/// One row of the online results: the same song found in one or both sources.
class SmartResult {
  const SmartResult({
    required this.primary,
    required this.sources,
    required this.alternatives,
    required this.confidence,
    required this.hasVideo,
  });

  /// The result shown on the row (and played, downloaded).
  final YtResult primary;
  final Set<MediaKind> sources;

  /// The other uploads of the same song, best first.
  final List<YtResult> alternatives;

  /// The highest of the group.
  final double confidence;

  /// There is also a video (a different one from [primary]) for this song.
  final bool hasVideo;

  /// Every video id the row stands for.
  Iterable<String> get ids sync* {
    yield primary.id;
    for (final a in alternatives) {
      yield a.id;
    }
  }
}

/// Same length within this: services round and cut differently.
const _sameLength = Duration(seconds: 5);

class _Group {
  _Group(this.members);

  final List<ScoredResult> members;

  double get confidence =>
      members.map((m) => m.confidence).reduce((a, b) => a > b ? a : b);

  bool has(MediaKind kind) => members.any((m) => m.source == kind);
}

String _artistOf(YtResult r) {
  if (r.artists.isNotEmpty) return r.artists.first;
  final c = cleanSearchQuery(r.title, r.channel);
  return c.artist.isEmpty ? r.channel : c.artist;
}

String _titleOf(YtResult r) => r.artists.isNotEmpty
    ? r.title
    : cleanSearchQuery(r.title, r.channel).title;

String _key(String title, String artist) =>
    '${matchTitleKey(title)}|${matchKey(extractPrimaryArtist(artist))}';

final _dash = RegExp(r'\s[-–—]\s');

/// What a result may be called: its own title and artist, and for an upload
/// «Artist - Title» from any channel, that split.
Set<String> _songKeys(YtResult r) {
  final keys = {_key(_titleOf(r), _artistOf(r))};
  final m = r.artists.isEmpty ? _dash.firstMatch(r.title) : null;
  if (m != null) {
    keys.add(_key(r.title.substring(m.end), r.title.substring(0, m.start)));
  }
  return keys;
}

bool _sameSong(YtResult a, YtResult b) {
  if (a.id == b.id) return true;
  if (_songKeys(a).intersection(_songKeys(b)).isEmpty) return false;
  final x = a.duration, y = b.duration;
  return x == null || y == null || (x - y).abs() <= _sameLength;
}

bool _fits(_Group g, ScoredResult s) {
  if (g.members.any((m) => m.result.id == s.result.id)) return true;
  // Two uploads of one source are two catalog entries: only the other source
  // is the same song seen twice.
  return !g.has(s.source) && g.members.any((m) => _sameSong(m.result, s.result));
}

int _byConfidence(ScoredResult a, ScoredResult b) {
  final c = b.confidence.compareTo(a.confidence);
  if (c != 0) return c;
  final s = a.source.index.compareTo(b.source.index);
  return s != 0 ? s : a.position.compareTo(b.position);
}

/// Merges the same song of both sources into one row, best first (confidence,
/// then source, then position; equal rows keep their input order).
List<SmartResult> mergeResults(List<ScoredResult> scored) {
  final sorted = [...scored]..sort(_byConfidence);
  final groups = <_Group>[];
  for (final s in sorted) {
    final home = groups.where((g) => _fits(g, s));
    if (home.isEmpty) {
      groups.add(_Group([s]));
    } else {
      home.first.members.add(s);
    }
  }
  return [for (final g in groups) _toResult(g)];
}

SmartResult _toResult(_Group g) {
  // A group holds at most one song and one video: the catalog song, with its
  // album and artist pages, is the one shown.
  final members = [...g.members]..sort((a, b) => a.source.index.compareTo(b.source.index));
  final primary = members.first.result;
  final others = <YtResult>[];
  for (final m in members.skip(1)) {
    if (m.result.id != primary.id) others.add(m.result);
  }
  return SmartResult(
    primary: primary,
    sources: {for (final m in g.members) m.source},
    alternatives: others,
    confidence: g.confidence,
    hasVideo: g.members.any(
        (m) => m.source == MediaKind.ytVideo && m.result.id != primary.id),
  );
}

/// The rows split for the page.
class BestSplit {
  const BestSplit(this.best, this.others, {required this.noneSure});

  /// «Migliori risultati».
  final List<SmartResult> best;

  /// «Altri risultati».
  final List<SmartResult> others;

  /// Nothing reached the threshold: [best] is the top few anyway.
  final bool noneSure;
}

/// How many rows are shown when nothing reaches the threshold.
const kNoneSureCount = 5;

/// [merged] must be best first, as [mergeResults] gives it.
BestSplit splitBest(List<SmartResult> merged, double threshold, {int maxBest = 15}) {
  final sure = merged.where((r) => r.confidence >= threshold).toList();
  if (sure.isEmpty) {
    return BestSplit(merged.take(kNoneSureCount).toList(),
        merged.skip(kNoneSureCount).toList(),
        noneSure: merged.isNotEmpty);
  }
  final best = sure.take(maxBest).toSet();
  return BestSplit(
    [for (final r in merged) if (best.contains(r)) r],
    [for (final r in merged) if (!best.contains(r)) r],
    noneSure: false,
  );
}


/// D-400: the library has its say only when a song is what was asked for
/// (also with the artist), not when the phrase is an artist or an album.
bool libraryAppliesTo(SearchIntent intent) =>
    intent == SearchIntent.song ||
    intent == SearchIntent.songs ||
    intent == SearchIntent.artistAndSongs;

ImportRow _asRow(String title, List<String> artists, Duration? length) => ImportRow(
      index: 0,
      title: title,
      artists: artists,
      durationMs: length?.inMilliseconds,
    );

/// The library track one result is already (the single rule of «already mine»
/// by title and artist, shared with Shuffle+): title and artist as the library
/// compares them, whatever the length (D-389); for a plain upload also its
/// «Artist - Title» split.
LibraryEntryLite? libraryMatchOf(YtResult r, LibraryIndex library) {
  final artists = r.artists.isNotEmpty ? r.artists : [_artistOf(r)];
  final hit = library.find(_asRow(_titleOf(r), artists, r.duration));
  if (hit != null) return hit;
  final m = r.artists.isEmpty ? _dash.firstMatch(r.title) : null;
  return m == null
      ? null
      : library.find(
          _asRow(r.title.substring(m.end), [r.title.substring(0, m.start)], r.duration));
}

/// A song the library already has; [track] is the library track it stands for,
/// null when it is only known as a download whose file the library has not read.
typedef OwnedHit = ({LibraryEntryLite? track});

/// Whether the row is already mine: any upload of it downloaded
/// ([downloadPath] gives the file of a result, null when there is none; the
/// library track of that file is the match, else the title rule's), or found in
/// the library by [libraryMatchOf].
OwnedHit? ownedMatch(
  SmartResult row,
  LibraryIndex library, {
  String? Function(YtResult r)? downloadPath,
}) {
  var downloaded = false;
  for (final r in [row.primary, ...row.alternatives]) {
    final path = downloadPath?.call(r);
    if (path != null) {
      final file = library.findByPath(path);
      if (file != null) return (track: file);
      downloaded = true;
    }
    final hit = libraryMatchOf(r, library);
    if (hit != null) return (track: hit);
  }
  return downloaded ? (track: null) : null;
}

bool ownedByLibrary(SmartResult row, LibraryIndex library) => ownedMatch(row, library) != null;

typedef WithoutOwned = ({
  List<SmartResult> kept,
  List<SmartResult> hiddenRows,
  List<LibraryEntryLite> matches,
});

/// [rows] without the songs the library already has, order kept; [hiddenRows]
/// are the ones taken out and [matches] the library tracks they stand for
/// (each once). Linear in the rows (the index lookup is O(1)), on the index
/// already in memory.
WithoutOwned withoutOwned(
  List<SmartResult> rows,
  LibraryIndex library, {
  String? Function(YtResult r)? downloadPath,
}) {
  final kept = <SmartResult>[], hiddenRows = <SmartResult>[];
  final matches = <int, LibraryEntryLite>{};
  for (final r in rows) {
    final m = ownedMatch(r, library, downloadPath: downloadPath);
    if (m == null) {
      kept.add(r);
    } else {
      hiddenRows.add(r);
      final t = m.track;
      if (t != null) matches[t.id] = t;
    }
  }
  return (kept: kept, hiddenRows: hiddenRows, matches: matches.values.toList());
}

/// The page's rows without what the library has, worked out once per result
/// (see `ownedSplitProvider`), not at every build.
class OwnedSplit {
  OwnedSplit(
    List<SmartResult> best,
    List<SmartResult> others,
    LibraryIndex library, {
    String? Function(YtResult r)? downloadPath,
  }) : this._(
          withoutOwned(best, library, downloadPath: downloadPath),
          withoutOwned(others, library, downloadPath: downloadPath),
        );

  OwnedSplit._(WithoutOwned b, WithoutOwned o)
      : best = b.kept,
        others = o.kept,
        hiddenRows = [...b.hiddenRows, ...o.hiddenRows],
        // The tracks of the hidden rows, so «Nella tua libreria» always has
        // what «N nascosti» refers to.
        matchIds = {for (final m in [...b.matches, ...o.matches]) m.id}.toList();

  final List<SmartResult> best, others;

  /// The rows taken out of the lists, best block first.
  final List<SmartResult> hiddenRows;
  final List<int> matchIds;

  int get hidden => hiddenRows.length;
}
