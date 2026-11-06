import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../data/repositories/podcast_repository.dart';
import '../online/http_client.dart';
import 'apple_podcasts.dart';
import 'podcast_cover.dart';
import 'podcast_models.dart';
import 'ytm_podcast_sync.dart';

/// A podcast is worth refreshing when it was last checked this long ago.
const staleAfter = Duration(hours: 6);

/// What a refresh of every podcast did.
class RefreshReport {
  RefreshReport();

  /// New episodes per podcast id.
  final added = <int, int>{};

  /// Podcasts that could not be refreshed, with the reason.
  final failed = <int, PodcastException>{};

  int get totalAdded => added.values.fold(0, (n, v) => n + v);
}

/// Subscribing, refreshing and searching. The network starts only from here,
/// and only when the user asks (or opens a stale podcast): never on its own.
class PodcastService {
  PodcastService({
    required this.repo,
    required this.fetch,
    required this.parse,
    required this.web,
    this.saveCover,
    this.ytm,
    this.podcastsDir,
    ApplePodcasts? apple,
    RateLimiter? searchLimiter,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        apple = apple ??
            ApplePodcasts(
          web: web,
          limiter: searchLimiter ?? RateLimiter(minGap: const Duration(seconds: 1)),
          now: now ?? DateTime.now,
        );

  final PodcastRepository repo;
  final FeedFetcher fetch;
  final FeedParser parse;
  final WebClient web;

  final PodcastCoverSaver? saveCover;
  /// Reads the shows that come from YouTube Music (D-404).
  final YtmPodcastSync? ytm;

  /// `<appSupportDir>/podcasts`: the only place files are deleted from.
  final String? podcastsDir;
  /// Genres, chart, lookup and search of the Apple directory.
  final ApplePodcasts apple;
  final DateTime Function() _now;

  int get _nowMs => _now().millisecondsSinceEpoch;

  /// An address typed or pasted by the user: trimmed, `feed:` read as https, a
  /// missing scheme as https. Anything that is not http(s) is refused.
  static String normalizeUrl(String input) {
    var t = input.trim();
    if (t.toLowerCase().startsWith('feed://')) {
      t = 'https://${t.substring(7)}';
    } else if (t.toLowerCase().startsWith('feed:')) {
      t = t.substring(5);
    }
    if (!t.contains('://') && t.contains('.') && !t.contains(' ')) t = 'https://$t';
    final u = Uri.tryParse(t);
    if (u == null || !(u.scheme == 'http' || u.scheme == 'https') || u.host.isEmpty) {
      throw PodcastException(PodcastErrorKind.invalidUrl, input);
    }
    return u.toString();
  }

  Future<PodcastFeed> _read(String url) async {
    final String text;
    try {
      text = await fetch(url);
    } on PodcastException {
      rethrow;
    } on Object catch (e, st) {
      AppLog.w('feed fetch failed: $url', e, st);
      throw PodcastException(PodcastErrorKind.network, '$e');
    }
    if (text.length > maxFeedBytes) {
      throw const PodcastException(PodcastErrorKind.tooLarge);
    }
    try {
      return await parse(text);
    } on PodcastException {
      rethrow;
    } on FormatException catch (e) {
      throw PodcastException(PodcastErrorKind.notFeed, e.message);
    }
  }

  /// Subscribes to the feed at [url]. Returns the podcast's id; subscribing
  /// again to the same address just refreshes it.
  Future<int> subscribeFromUrl(String url) async {
    final feedUrl = normalizeUrl(url);
    final feed = await _read(feedUrl);
    final id = await repo.subscribe(feedUrl, feed, now: _nowMs);
    await storePodcastCover(repo, saveCover, id, feed.imageUrl);
    return id;
  }

  /// Removes the podcast and the downloaded episodes: their library rows, and
  /// their files, but only those inside [podcastsDir] (when given).
  Future<void> unsubscribe(int podcastId) async {
    final paths = await repo.unsubscribe(podcastId);
    final root = podcastsDir;
    for (final path in paths) {
      if (root == null || !p.isWithin(root, path)) {
        AppLog.w('unsubscribe: not deleting a file outside the podcast folder: $path');
        continue;
      }
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } on FileSystemException catch (e, st) {
        AppLog.w('could not delete $path', e, st);
      }
    }
    final dir = root == null ? null : Directory(p.join(root, '$podcastId'));
    try {
      if (dir != null && await dir.exists() && (await dir.list().isEmpty)) {
        await dir.delete();
      }
    } on FileSystemException catch (e, st) {
      AppLog.w('could not remove ${dir?.path}', e, st);
    }
  }

  /// Reads the feed again and adds the new episodes. Returns how many.
  Future<int> refresh(int podcastId) async {
    final podcast = await repo.byId(podcastId);
    if (podcast == null) return 0;
    if (podcast.source == kPodcastSourceYtm) {
      final sync = ytm;
      if (sync == null) throw const PodcastException(PodcastErrorKind.network, 'no YouTube Music reader');
      return sync.refresh(podcastId);
    }
    final feed = await _read(podcast.feedUrl);
    final added = await repo.upsertEpisodes(podcastId, feed.episodes);
    await repo.markChecked(podcastId, _nowMs);
    await storePodcastCover(repo, saveCover, podcastId, feed.imageUrl ?? podcast.imageUrl);
    return added;
  }

  /// [refresh] only if the podcast was never checked or not for [staleAfter].
  /// Returns the new episodes, or null when nothing was asked of the network.
  Future<int?> refreshIfStale(int podcastId) async {
    final podcast = await repo.byId(podcastId);
    if (podcast == null) return null;
    final last = podcast.lastCheckedAt;
    if (last != null && _nowMs - last < staleAfter.inMilliseconds) return null;
    return refresh(podcastId);
  }

  /// Every podcast, one after the other; a failure does not stop the rest.
  Future<RefreshReport> refreshAll() async {
    final report = RefreshReport();
    for (final p in await repo.all()) {
      try {
        report.added[p.id] = await refresh(p.id);
      } on PodcastException catch (e) {
        report.failed[p.id] = e;
      }
    }
    return report;
  }

  /// The public podcast directory (iTunes Search API, no key); see [ApplePodcasts].
  Future<List<PodcastSearchHit>> search(String term, {int limit = 10, String? country, String? genreId}) =>
      apple.search(term, limit: limit, country: country, genreId: genreId);
}
