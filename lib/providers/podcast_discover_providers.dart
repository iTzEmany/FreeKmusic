import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../core/constants.dart' show kEnableYoutube;
import '../data/repositories/podcast_repository.dart';
import '../services/podcast/apple_podcasts.dart';
import '../services/podcast/podcast_models.dart';
import '../services/podcast/ytm_podcast_sync.dart' show kPodcastSourceYtm;
import 'podcast_providers.dart';

enum PodcastOrigin { apple, ytm }

/// A show in «Scopri» or in the search: from the Apple chart or search, or from YouTube Music.
class PodcastListing {
  const PodcastListing({
    required this.origin,
    required this.title,
    this.author,
    this.artworkUrl,
    this.feedUrl,
    this.appleId,
    this.ytmId,
  });

  final PodcastOrigin origin;
  final String title;
  final String? author, artworkUrl;

  /// Apple search: known. Apple chart: null until [ApplePodcasts.lookup].
  final String? feedUrl, appleId;
  final String? ytmId;

  String get key => origin == PodcastOrigin.ytm ? 'ytm-$ytmId' : 'apple-${feedUrl ?? appleId}';

  /// Same show on two sources: same title and author, ignoring case and punctuation.
  String get sameShow => '${_norm(title)}|${_norm(author ?? '')}';
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

/// What the user already follows, to tell «Iscriviti» from «Iscritto».
class PodcastSubscriptions {
  PodcastSubscriptions(List<PodcastSummary> all)
      : _feeds = {for (final s in all) s.podcast.feedUrl: s.podcast.id},
        _ytm = {
          for (final s in all)
            if (s.podcast.source == kPodcastSourceYtm && s.podcast.sourceId != null) s.podcast.sourceId!: s.podcast.id,
        },
        _shows = {
          for (final s in all) '${_norm(s.podcast.title)}|${_norm(s.podcast.author ?? '')}': s.podcast.id,
        };

  final Map<String, int> _feeds, _ytm, _shows;

  /// The podcast id when [l] is already followed (by feed, YouTube Music id or same show).
  int? idOf(PodcastListing l) => _feeds[l.feedUrl] ?? _ytm[l.ytmId] ?? _shows[l.sameShow];

  /// 2: followed through this very source, 1: followed through the same show elsewhere, 0: not followed.
  int _score(PodcastListing l) => _feeds.containsKey(l.feedUrl) || _ytm.containsKey(l.ytmId)
      ? 2
      : _shows.containsKey(l.sameShow)
          ? 1
          : 0;
}

/// Apple results first, then YouTube Music; one row per show, the followed one kept.
List<PodcastListing> mergeListings(List<PodcastListing> all, PodcastSubscriptions subs) {
  final byShow = <String, PodcastListing>{};
  for (final l in all) {
    final old = byShow[l.sameShow];
    if (old == null || subs._score(l) > subs._score(old)) byShow[l.sameShow] = l;
  }
  return byShow.values.toList();
}

Duration? _noRetry(int _, Object _) => null;

/// Top-level genres of the Apple directory (names in English).
final podcastGenresProvider = FutureProvider.autoDispose<List<PodcastGenre>>(
  (ref) => ref.read(podcastServiceProvider).apple.genres(),
  retry: _noRetry,
);

/// The Italian chart, for a genre or (null) all podcasts.
final podcastChartProvider = FutureProvider.autoDispose.family<List<PodcastListing>, String?>(
  (ref, genreId) async {
    final entries = await ref.read(podcastServiceProvider).apple.chart(genreId: genreId);
    return [
      for (final e in entries)
        PodcastListing(
          origin: PodcastOrigin.apple,
          title: e.name,
          author: e.author,
          artworkUrl: e.artworkUrl,
          appleId: e.appleId,
        ),
    ];
  },
  retry: _noRetry,
);

/// One search over Apple and (when the build has it) YouTube Music. One source
/// failing is logged and the other still answers; both failing is an error.
final podcastSearchProvider = FutureProvider.autoDispose.family<List<PodcastListing>, ({String query, String hl})>(
  (ref, q) async {
    final apple = ref.read(podcastServiceProvider).apple;
    final ytm = kEnableYoutube ? ref.read(ytmPodcastsProvider) : null;
    Future<List<PodcastListing>> fromApple() async => [
          for (final h in await apple.search(q.query, country: 'it'))
            PodcastListing(
              origin: PodcastOrigin.apple,
              title: h.name,
              author: h.author,
              artworkUrl: h.artworkUrl,
              feedUrl: h.feedUrl,
            ),
        ];
    Future<List<PodcastListing>> fromYtm() async => [
          for (final h in await ytm!.searchShows(q.query, hl: q.hl))
            PodcastListing(
              origin: PodcastOrigin.ytm,
              title: h.title,
              author: h.author,
              artworkUrl: h.thumbnailUrl,
              ytmId: h.id,
            ),
        ];
    final results = await Future.wait([
      fromApple().then<List<PodcastListing>?>((v) => v, onError: (Object e, StackTrace st) {
        AppLog.w('podcast search (Apple) failed', e, st);
        return null;
      }),
      if (ytm != null)
        fromYtm().then<List<PodcastListing>?>((v) => v, onError: (Object e, StackTrace st) {
          AppLog.w('podcast search (YouTube Music) failed', e, st);
          return null;
        }),
    ]);
    if (results.every((r) => r == null)) {
      throw const PodcastException(PodcastErrorKind.network, 'search');
    }
    return [for (final r in results) ...?r];
  },
  retry: _noRetry,
);
