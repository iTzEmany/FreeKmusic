import 'dart:math';

import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import '../online/youtube_service.dart';
import '../online/ytm_radio_parser.dart';
import 'radio_gate.dart';
import 'seed_resolver.dart';
import 'suggestion_log.dart';
import 'suggestion_pool.dart';

/// Why a genre page shows the library only (D-380).
enum GenreMixOff { jam, metered, offline, noTool, rateLimited }

/// The online songs of a genre mix: [suggested] are ready, [incoming] still
/// on their way (skeleton rows); [off] says why there are none. [seedTitles]:
/// the library song each suggestion came from, by video id.
class GenreMixState {
  const GenreMixState({this.suggested = const [], this.seedTitles = const {}, this.incoming = 0, this.off});

  static const none = GenreMixState();

  final List<YtResult> suggested;
  final Map<String, String> seedTitles;
  final int incoming;
  final GenreMixOff? off;
}

/// One online song every [genreMixEvery] library songs.
const genreMixEvery = 2;

/// Most suggestions of a page: the radio is asked a few times, not per row.
const genreMixMax = 9;

/// Radio and search requests at most; the [RadioGate] still allows one radio
/// request a minute and none while it is tripped.
const _maxRequests = 4;

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
  required RadioGate gate,
  required Future<bool Function(YtResult r)> Function() loadInLibrary,
  bool Function()? cancelled,
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
  final seedTitles = <String, String>{};
  final lastArtists = <String>[];
  final seeds = [for (final t in chooseSeeds(tracks, random: random)) _Seed(t)];
  final queue = pool ?? SuggestionPool();
  var requests = 0;
  var radioAsked = false;
  GenreMixOff? stopped;
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
        seedTitles[c.result.id] = c.seedTitle;
        lastArtists
          ..add(suggestionArtistKey(c.result))
          ..removeRange(0, max(0, lastArtists.length - 2));
        yield GenreMixState(suggested: List.of(found), seedTitles: Map.of(seedTitles), incoming: want - found.length);
        continue;
      }
      if (requests >= _maxRequests || (cancelled?.call() ?? false)) break;
      final r = await _fetch(seeds, queue, resolver, radioPage, gate, _maxRequests - requests, first: !radioAsked);
      if (r.used == 0) break;
      requests += r.used;
      radioAsked |= r.asked;
    }
  } on YtException catch (e, st) {
    AppLog.w('genre mix stopped', e, st);
    if (e.kind == YtErrorKind.rateLimited) {
      gate.trip();
      stopped = GenreMixOff.rateLimited;
    }
  } on Object catch (e, st) {
    AppLog.w('genre mix stopped', e, st);
  }
  yield GenreMixState(suggested: List.of(found), seedTitles: Map.of(seedTitles), off: stopped);
}

class _Seed {
  _Seed(this.track);

  final Track track;
  String? videoId;
  bool fetched = false, dead = false;
  String get key => '${track.id}';
}

/// One radio page of the next seed that needs one, within [budget] requests
/// and what [gate] allows; returns the requests made (searches included), 0
/// when none is left or the gate is closed, and whether a radio page was asked.
/// The [first] page of a mix is the user's own action: it waits for the 429
/// pause only, not for the gap.
Future<({int used, bool asked})> _fetch(
  List<_Seed> seeds,
  SuggestionPool pool,
  SeedResolver resolver,
  Future<RadioPage> Function(String videoId, {String? continuation}) radioPage,
  RadioGate gate,
  int budget, {
  required bool first,
}) async {
  var used = 0;
  bool closed() => first ? gate.rateLimited : !gate.canAsk;
  for (final s in seeds) {
    if (s.dead) continue;
    final more = pool.pending(s.key) == 0 && pool.continuationOf(s.key) != null;
    if (s.fetched && !more) continue;
    if (closed()) return (used: used, asked: false); // no search for a request that cannot follow
    if (s.videoId == null) {
      used++; // a search, unless the download or the index knows the id
      s.videoId = await resolver.resolve(s.track);
    }
    if (s.videoId == null) {
      s.dead = true;
      continue;
    }
    gate.asked();
    var page = await radioPage(s.videoId!, continuation: s.fetched ? pool.continuationOf(s.key) : null);
    used++;
    if (!s.fetched && used < budget && (first || gate.canAsk) && !page.items.any((i) => i.isSeed && i.kind == RadioKind.song)) {
      // The id was a video clip's: look the song up and ask again.
      s.videoId = await resolver.resolve(s.track, searchOnly: true);
      if (s.videoId == null) {
        s.dead = true;
        continue;
      }
      gate.asked();
      page = await radioPage(s.videoId!);
      used++;
    }
    s.fetched = true;
    pool.addPage(s.key, s.track.title, page);
    return (used: used, asked: true);
  }
  return (used: used, asked: false);
}
