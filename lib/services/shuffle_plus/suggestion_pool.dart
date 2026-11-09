import '../../data/db/app_database.dart' show Track;
import '../import/track_matcher.dart' show LibraryIndex;
import '../online/merge_results.dart' show libraryMatchOf;
import '../online/youtube_service.dart';
import '../online/ytm_radio_parser.dart';
import 'suggestion_gate.dart';
import 'suggestion_log.dart';
import '../../core/artist_key.dart';

/// A song picked to be suggested, with the seed it came from.
class SuggestionCandidate {
  const SuggestionCandidate(this.result, this.seedTitle, this.kind);

  final YtResult result;
  final String seedTitle;
  final RadioKind kind;
}

/// The artist as compared between suggestions («A feat. B» is A).
String suggestionArtistKey(YtResult r) {
  final name = r.artists.isEmpty ? r.channel : r.artists.first;
  return artistKey(name);
}

/// Whether a suggestion is a song the user already has: downloaded, or found
/// in the library by title and artist (the duration only matters when one
/// artist credit merely contains the other, D-389). Shared by Shuffle+ and the
/// genre mix. [library] may be null before the first read.
bool Function(YtResult r) inLibraryTest({
  required bool Function(String videoId) hasDownload,
  required LibraryIndex? library,
}) =>
    (r) => hasDownload(r.id) || (library != null && libraryMatchOf(r, library) != null);

/// A song whose radio feeds a [SuggestionPool]: a library song, or an online
/// one by its video id ([RadioSeed.online]).
class RadioSeed {
  RadioSeed(Track track)
    : source = track,
      title = track.title,
      key = '${track.id}';

  RadioSeed.online(String this.videoId, this.title) : source = null, key = videoId;

  /// The library song, null for an online seed.
  final Track? source;

  /// The library song; only for seeds that have one (no video id yet).
  Track get track => source!;

  final String title;
  String? videoId;
  bool fetched = false;
  bool searchOnly = false;
  bool dead = false;

  /// Key of the seed in the pool.
  final String key;

  /// Whether [pool] has no page of this seed, or has used up the last one
  /// and the radio has more.
  bool needsPage(SuggestionPool pool) =>
      !fetched || (pool.pending(key) == 0 && pool.continuationOf(key) != null);
}

/// Radio pages of the seeds, served one row per seed in turn so the
/// suggestions mix the seeds. Pure: no network, no clock.
class SuggestionPool {
  SuggestionPool({
    this.minDuration = const Duration(seconds: 60),
    this.maxDuration = const Duration(minutes: 12),
  });

  final Duration minDuration, maxDuration;

  final Map<String, List<RadioItem>> _queues = {};
  final Map<String, String> _titles = {};
  final Map<String, String?> _continuations = {};
  final Set<String> _used = {};
  // Rows seen per seed, and where each song stood in each seed's radio (1-based,
  // seed row not counted). Kept after a row leaves the queue: a blocked song
  // dropped from one seed still counts when another seed's page brings it.
  final Map<String, int> _rows = {};
  final Map<String, Map<String, int>> _positions = {};
  int _turn = 0;

  /// Rows waiting, all seeds together.
  int get length => _queues.values.fold(0, (a, q) => a + q.length);

  bool get isEmpty => length == 0;

  /// Seed keys that have a page.
  Iterable<String> get seeds => _queues.keys;

  /// Where the next page of [seedKey]'s radio starts, null at its end.
  String? continuationOf(String seedKey) => _continuations[seedKey];

  /// Rows of [seedKey] still waiting.
  int pending(String seedKey) => _queues[seedKey]?.length ?? 0;

  /// Where [videoId] stood in the radio of each seed that had it.
  Iterable<int> positionsOf(String videoId) => [
    for (final m in _positions.values) ?m[videoId],
  ];

  /// Adds a radio page of the seed [seedKey] (its video id) named [seedTitle].
  void addPage(String seedKey, String seedTitle, RadioPage page) {
    _titles[seedKey] = seedTitle;
    _continuations[seedKey] = page.continuation;
    final queue = _queues.putIfAbsent(seedKey, () => []);
    final known = {for (final i in queue) i.result.id};
    final rows = _positions.putIfAbsent(seedKey, () => {});
    for (final i in page.items) {
      if (i.isSeed) continue;
      rows.putIfAbsent(
        i.result.id,
        () => _rows[seedKey] = (_rows[seedKey] ?? 0) + 1,
      );
      if (known.add(i.result.id)) queue.add(i);
    }
  }

  void clear() {
    _queues.clear();
    _titles.clear();
    _continuations.clear();
    _used.clear();
    _rows.clear();
    _positions.clear();
    _turn = 0;
  }

  bool _fits(YtResult r) {
    final d = r.duration;
    return d != null && d >= minDuration && d <= maxDuration;
  }

  /// The next suggestion, or null when no row qualifies (another page is
  /// needed). Songs come first; artist videos only when no song qualifies.
  /// Rows that can never qualify (too short or long, uploads, in the library,
  /// suggested in the last 30 days, blocked by [filter]: a blocked song below
  /// its threshold is dropped too, as its positions are kept for when another
  /// seed's page brings it back) are dropped; rows that may
  /// qualify later (in the queue now, same artist as one of [lastArtists])
  /// stay.
  SuggestionCandidate? take({
    required bool Function(YtResult r) inLibrary,
    required bool Function(String videoId) inQueue,
    required SuggestionLog log,
    required SuggestionGate filter,
    List<String> lastArtists = const [],
  }) {
    for (final kind in [RadioKind.song, RadioKind.artistVideo]) {
      final c = _takeKind(kind, inLibrary, inQueue, log, filter, lastArtists);
      if (c != null) return c;
    }
    return null;
  }

  SuggestionCandidate? _takeKind(
    RadioKind kind,
    bool Function(YtResult r) inLibrary,
    bool Function(String videoId) inQueue,
    SuggestionLog log,
    SuggestionGate filter,
    List<String> lastArtists,
  ) {
    final keys = _queues.keys.toList();
    for (var n = 0; n < keys.length; n++) {
      final seed = keys[(_turn + n) % keys.length];
      final queue = _queues[seed]!;
      for (var i = 0; i < queue.length;) {
        final item = queue[i];
        final r = item.result;
        final never = item.kind == RadioKind.upload ||
            !_fits(r) ||
            _used.contains(r.id) ||
            log.recentlySuggested(r.id) ||
            !filter.allows(r.id, suggestionArtistKey(r), positionsOf(r.id)) ||
            inLibrary(r);
        if (never) {
          queue.removeAt(i);
          continue;
        }
        if (item.kind != kind ||
            inQueue(r.id) ||
            lastArtists.contains(suggestionArtistKey(r))) {
          i++;
          continue;
        }
        queue.removeAt(i);
        _used.add(r.id);
        _turn = (_turn + n + 1) % keys.length;
        return SuggestionCandidate(r, _titles[seed] ?? '', item.kind);
      }
    }
    return null;
  }
}
