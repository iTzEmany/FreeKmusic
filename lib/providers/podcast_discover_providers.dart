import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../core/constants.dart' show kEnableYoutube;
import '../data/repositories/podcast_repository.dart';
import '../services/podcast/apple_podcasts.dart';
import '../services/podcast/podcast_models.dart';
import 'podcast_providers.dart';
import '../core/artist_key.dart';

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

  String get key => origin == PodcastOrigin.ytm
      ? 'ytm-$ytmId'
      : 'apple-${feedUrl ?? appleId}';

  /// Same show on two sources: same normalized title, and the same author unless one side has none.
  bool isSameShow(String titleKey, String authorKey) =>
      _showKey(title) == titleKey &&
      (authorKey.isEmpty ||
          _showKey(author ?? '').isEmpty ||
          _showKey(author ?? '') == authorKey);
}

/// The project's `matchKey` (case, accents, punctuation) after dropping combining marks, so
/// composed and decomposed accents agree; a text with no letters (only emoji) keeps its raw self.
String _showKey(String s) {
  final k = matchKey(s.replaceAll(RegExp('[\u0300-\u036f]'), ''));
  return k.isEmpty ? s.trim().toLowerCase() : k;
}

/// What the user already follows, to tell «Iscriviti» from «Iscritto».
class PodcastSubscriptions {
  PodcastSubscriptions(List<PodcastSummary> all)
    : _feeds = {for (final s in all) s.podcast.feedUrl: s.podcast.id},
      _ytm = {
        for (final s in all)
          if (s.podcast.source == kPodcastSourceYtm &&
              s.podcast.sourceId != null)
            s.podcast.sourceId!: s.podcast.id,
      },
      _shows = [
        for (final s in all)
          (
            title: _showKey(s.podcast.title),
            author: _showKey(s.podcast.author ?? ''),
            id: s.podcast.id,
          ),
      ];

  final Map<String, int> _feeds, _ytm;
  final List<({String title, String author, int id})> _shows;

  int? _showId(PodcastListing l) {
    for (final s in _shows) {
      if (l.isSameShow(s.title, s.author)) return s.id;
    }
    return null;
  }

  /// The podcast id when [l] is already followed (by feed, YouTube Music id or same show).
  int? idOf(PodcastListing l) =>
      _feeds[l.feedUrl] ?? _ytm[l.ytmId] ?? _showId(l);

  /// 2: followed through this very source, 1: followed through the same show elsewhere, 0: not followed.
  int _score(PodcastListing l) =>
      _feeds.containsKey(l.feedUrl) || _ytm.containsKey(l.ytmId)
      ? 2
      : _showId(l) != null
      ? 1
      : 0;
}

/// Apple results first, then YouTube Music; one row per show, the followed one kept.
List<PodcastListing> mergeListings(
  List<PodcastListing> all,
  PodcastSubscriptions subs,
) {
  final out = <PodcastListing>[];
  for (final l in all) {
    final i = out.indexWhere(
      (o) => o.isSameShow(_showKey(l.title), _showKey(l.author ?? '')),
    );
    if (i < 0) {
      out.add(l);
    } else if (subs._score(l) > subs._score(out[i])) {
      out[i] = l;
    }
  }
  return out;
}

Duration? _noRetry(int _, Object _) => null;

/// Top-level genres of the Apple directory (names in English).
final podcastGenresProvider = FutureProvider.autoDispose<List<PodcastGenre>>(
  (ref) => ref.read(podcastServiceProvider).apple.genres(),
  retry: _noRetry,
);

/// The Italian chart, for a genre or (null) all podcasts.
final podcastChartProvider = FutureProvider.autoDispose
    .family<List<PodcastListing>, String?>((ref, genreId) async {
      final entries = await ref
          .read(podcastServiceProvider)
          .apple
          .chart(genreId: genreId);
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
    }, retry: _noRetry);

/// One search over Apple and (when the build has it) YouTube Music. One source
/// failing is logged and the other still answers; both failing is an error.
final podcastSearchProvider = FutureProvider.autoDispose
    .family<List<PodcastListing>, ({String query, String hl})>((ref, q) async {
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
        fromApple().then<List<PodcastListing>?>(
          (v) => v,
          onError: (Object e, StackTrace st) {
            AppLog.w('podcast search (Apple) failed', e, st);
            return null;
          },
        ),
        if (ytm != null)
          fromYtm().then<List<PodcastListing>?>(
            (v) => v,
            onError: (Object e, StackTrace st) {
              AppLog.w('podcast search (YouTube Music) failed', e, st);
              return null;
            },
          ),
      ]);
      if (results.every((r) => r == null)) {
        throw const PodcastException(PodcastErrorKind.network, 'search');
      }
      return [for (final r in results) ...?r];
    }, retry: _noRetry);
