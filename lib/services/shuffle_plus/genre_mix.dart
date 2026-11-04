import 'dart:math';

import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import '../online/youtube_service.dart';
import '../online/ytm_radio_parser.dart';
import 'seed_resolver.dart';
import 'suggestion_log.dart';
import 'suggestion_pool.dart';

/// Why a genre page shows the library only (D-380).
enum GenreMixOff { jam, metered, offline, noTool }

/// The online songs of a genre mix: [suggested] are ready, [incoming] still
/// on their way (skeleton rows); [off] says why there are none.
class GenreMixState {
  const GenreMixState({this.suggested = const [], this.incoming = 0, this.off});

  static const none = GenreMixState();

  final List<YtResult> suggested;
  final int incoming;
  final GenreMixOff? off;
}

/// One online song every [genreMixEvery] library songs.
const genreMixEvery = 2;

/// Most suggestions of a page: the radio is asked a few times, not per row.
const genreMixMax = 9;

/// Radio pages asked for at most.
const _maxPages = 6;

/// Suggestions for the genre page, the way Shuffle+ makes them (seeds from
/// the genre's songs, their radios, the same pool rules) but outside the
/// queue: emits [GenreMixState.incoming] first, then each song as it is found.
/// A failure keeps what was found and stops (it goes to `AppLog`).
Stream<GenreMixState> genreMix({
  required List<Track> tracks,
  required Future<GenreMixOff?> Function() offReason,
  required SeedResolver resolver,
  required Future<RadioPage> Function(String videoId, {String? continuation}) radioPage,
  required SuggestionLog log,
  required Future<bool Function(YtResult r)> Function() loadInLibrary,
  Random? random,
  SuggestionPool? pool,
}) async* {
  final want = min(genreMixMax, tracks.length ~/ genreMixEvery);
  if (want == 0) return;
  final off = await offReason();
  if (off != null) {
    yield GenreMixState(off: off);
    return;
  }
  yield GenreMixState(incoming: want);
  final found = <YtResult>[];
  final lastArtists = <String>[];
  final seeds = [for (final t in chooseSeeds(tracks, random: random)) _Seed(t)];
  final queue = pool ?? SuggestionPool();
  var pages = 0;
  try {
    await log.load();
    final inLibrary = await loadInLibrary();
    while (found.length < want) {
      final c = queue.take(
        inLibrary: inLibrary,
        inQueue: (id) => found.any((r) => r.id == id),
        log: log,
        lastArtists: lastArtists,
      );
      if (c != null) {
        found.add(c.result);
        lastArtists
          ..add(suggestionArtistKey(c.result))
          ..removeRange(0, max(0, lastArtists.length - 2));
        yield GenreMixState(suggested: List.of(found), incoming: want - found.length);
        continue;
      }
      if (pages++ >= _maxPages || !await _fetch(seeds, queue, resolver, radioPage)) break;
    }
  } on Object catch (e, st) {
    AppLog.w('genre mix stopped', e, st);
  }
  yield GenreMixState(suggested: List.of(found));
}

class _Seed {
  _Seed(this.track);

  final Track track;
  String? videoId;
  bool fetched = false, dead = false;
  String get key => '${track.id}';
}

/// One radio page of the next seed that needs one; false when none is left.
Future<bool> _fetch(
  List<_Seed> seeds,
  SuggestionPool pool,
  SeedResolver resolver,
  Future<RadioPage> Function(String videoId, {String? continuation}) radioPage,
) async {
  for (final s in seeds) {
    if (s.dead) continue;
    final more = pool.pending(s.key) == 0 && pool.continuationOf(s.key) != null;
    if (s.fetched && !more) continue;
    s.videoId ??= await resolver.resolve(s.track);
    if (s.videoId == null) {
      s.dead = true;
      continue;
    }
    var page = await radioPage(s.videoId!, continuation: s.fetched ? pool.continuationOf(s.key) : null);
    if (!s.fetched && !page.items.any((i) => i.isSeed && i.kind == RadioKind.song)) {
      // The id was a video clip's: look the song up and ask again.
      s.videoId = await resolver.resolve(s.track, searchOnly: true);
      if (s.videoId == null) {
        s.dead = true;
        continue;
      }
      page = await radioPage(s.videoId!);
    }
    s.fetched = true;
    pool.addPage(s.key, s.track.title, page);
    return true;
  }
  return false;
}
