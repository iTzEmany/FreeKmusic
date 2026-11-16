import '../../data/repositories/track_kinds.dart';
import 'dart:math';

import '../../core/import_row.dart';
import '../../data/db/app_database.dart';
import '../import/track_matcher.dart';
import '../online/download_index.dart';
import '../online/youtube_service.dart';
import 'seed_index.dart';

/// Finds the YouTube Music id of library songs, to start a radio from them.
class SeedResolver {
  SeedResolver({
    required this.downloads,
    required this.index,
    required this.searchSongs,
  });

  final DownloadIndex downloads;
  final SeedIndex index;

  /// YouTube Music «songs» search (`YoutubeService.searchSongs`). Errors
  /// (network, rate limit) propagate and are not remembered.
  final Future<List<YtResult>> Function(String query) searchSongs;

  /// The id of [track] on YouTube Music, or null: (1) the download that made
  /// the file, no network; (2) the index of earlier searches; (3) a search,
  /// accepted only when the match is sure. With [searchOnly] step 1 is skipped
  /// (a download may have come from a video clip, whose radio has no songs).
  Future<String?> resolve(Track track, {bool searchOnly = false}) async {
    if (!searchOnly) {
      final downloaded = downloads.idForPath(track.path);
      if (downloaded != null) return downloaded;
    }
    final key = SeedIndex.keyOf(track.title, track.artist);
    final known = await index.get(key);
    if (known != null) {
      return known.found ? known.id : null;
    }
    final artist = track.artist ?? '';
    final results = await searchSongs('$artist ${track.title}'.trim());
    final row = ImportRow(
      index: 0,
      title: track.title,
      artists: artist.isEmpty ? const [] : [artist],
      album: track.album,
      durationMs: track.durationMs > 0 ? track.durationMs : null,
    );
    final decision = decide(row, results);
    final id = decision.kind == MatchKind.sure ? decision.best!.result.id : '';
    await index.put(key, id);
    return id.isEmpty ? null : id;
  }
}

/// Up to [count] songs of [source] to start radios from, at random. When at
/// least 40 % of the songs share one genre, only that genre is used (the
/// playlist is «a rock one»); otherwise all of them. Missing files and
/// non-music rows never serve.
List<Track> chooseSeeds(List<Track> source, {Random? random, int count = 3}) {
  final usable = [
    for (final t in source)
      if (!t.missing && isLibraryTrack(t)) t,
  ];
  if (usable.isEmpty) return const [];
  final counts = <String, int>{};
  for (final t in usable) {
    final g = _genreOf(t);
    if (g.isNotEmpty) counts[g] = (counts[g] ?? 0) + 1;
  }
  var pool = usable;
  if (counts.isNotEmpty) {
    final top = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    if (top.value >= usable.length * 0.4) {
      pool = [
        for (final t in usable)
          if (_genreOf(t) == top.key) t,
      ];
    }
  }
  return ([...pool]..shuffle(random)).take(count).toList();
}

String _genreOf(Track t) => t.genre?.trim().toLowerCase() ?? '';
