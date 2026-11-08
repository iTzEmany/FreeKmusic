import 'dart:math';

import '../online/youtube_service.dart';
import '../online/ytm_radio_parser.dart';
import 'radio_gate.dart';
import 'seed_resolver.dart';
import 'suggestion_log.dart';
import 'suggestion_pool.dart';

/// Suggestions from the radios of some seeds, one at a time, under the
/// [RadioGate]. It keeps its state (pool, last artists, radio continuations),
/// so a long session calls [take] again and goes on where it stopped. Errors
/// (`YtException`, network) reach the caller.
class RadioFill {
  RadioFill({
    required this.seeds,
    required this.resolver,
    required this.radioPage,
    required this.log,
    required this.gate,
    required this.inLibrary,
    SuggestionPool? pool,
  }) : pool = pool ?? SuggestionPool();

  final List<RadioSeed> seeds;
  final SeedResolver resolver;
  final Future<RadioPage> Function(String videoId, {String? continuation})
  radioPage;
  final SuggestionLog log;
  final RadioGate gate;
  final bool Function(YtResult r) inLibrary;
  final SuggestionPool pool;

  final List<String> _lastArtists = [];
  bool _radioAsked = false;

  /// Up to [want] suggestions, each as soon as it is found, within
  /// [maxRequests] radio and search requests of this call.
  Stream<SuggestionCandidate> take(
    int want, {
    required bool Function(String videoId) inQueue,
    bool Function()? cancelled,
    int maxRequests = 4,
  }) async* {
    var found = 0;
    var requests = 0;
    while (found < want) {
      final c = pool.take(
        inLibrary: inLibrary,
        inQueue: inQueue,
        log: log,
        lastArtists: _lastArtists,
      );
      if (c != null) {
        found++;
        _lastArtists
          ..add(suggestionArtistKey(c.result))
          ..removeRange(0, max(0, _lastArtists.length - 2));
        yield c;
        continue;
      }
      if (requests >= maxRequests || (cancelled?.call() ?? false)) return;
      final used = await _fetch(maxRequests - requests);
      if (used == 0) return;
      requests += used;
    }
  }

  /// One radio page of the next seed that needs one, within [budget]
  /// requests and what [gate] allows; returns the requests made (searches
  /// included), 0 when none is left or the gate is closed. The first page of
  /// the session is the user's own action: it waits for the 429 pause only,
  /// not for the gap.
  Future<int> _fetch(int budget) async {
    final first = !_radioAsked;
    var used = 0;
    bool closed() => first ? gate.rateLimited : !gate.canAsk;
    for (final s in seeds) {
      if (s.dead || !s.needsPage(pool)) continue;
      if (closed()) return used; // no search for a request that cannot follow
      if (s.videoId == null) {
        used++; // a search, unless the download or the index knows the id
        s.videoId = await resolver.resolve(s.track);
      }
      if (s.videoId == null) {
        s.dead = true;
        continue;
      }
      gate.asked();
      var page = await radioPage(
        s.videoId!,
        continuation: s.fetched ? pool.continuationOf(s.key) : null,
      );
      used++;
      // An online seed has no library song to look up again.
      if (!s.fetched &&
          s.source != null &&
          used < budget &&
          (first || gate.canAsk) &&
          !page.items.any((i) => i.isSeed && i.kind == RadioKind.song)) {
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
      pool.addPage(s.key, s.title, page);
      _radioAsked = true;
      return used;
    }
    return used;
  }
}
