import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import '../data/db/app_database.dart' show Track;
import '../data/repositories/track_kinds.dart' show isHttpAddress;
import '../services/podcast/podcast_cover.dart';
import '../services/podcast/podcast_service.dart';
import 'activity_log_providers.dart';
import 'activity_providers.dart';
import 'player_providers.dart';
import 'podcast_discover_providers.dart';
import 'podcast_providers.dart';
import '../services/podcast/podcast_models.dart' show kPodcastSourceYtm;

/// Per-podcast and per-episode user choices.
class PodcastOps {
  PodcastOps(this._ref);

  final Ref _ref;

  /// Reads every feed again: it shows in the Activity centre and leaves a
  /// line in the Registro, failed if any feed (or the whole run) failed.
  Future<RefreshReport> refreshAll() async {
    _ref.read(podcastRefreshingProvider.notifier).set(true);
    var failed = true;
    try {
      final report = await _ref.read(podcastServiceProvider).refreshAll();
      failed = report.failed.isNotEmpty;
      return report;
    } finally {
      _ref.read(podcastRefreshingProvider.notifier).set(false);
      await _ref
          .read(activityLogProvider.notifier)
          .add(
            LogEntry(
              at: DateTime.now(),
              item: ActivityItem(
                kind: ActivityKind.podcastRefresh,
                key: 'podcastRefresh',
                name: null,
                running: false,
                failed: failed,
              ),
            ),
          );
    }
  }

  /// Follows a show of «Scopri» or of the search; null when Apple has no feed for it.
  Future<int?> followListing(PodcastListing item) async {
    if (item.origin == PodcastOrigin.ytm) {
      return _ref.read(ytmPodcastSyncProvider).subscribe(item.ytmId!);
    }
    final service = _ref.read(podcastServiceProvider);
    // A chart row has no feed yet: Apple gives it on request.
    final feed =
        item.feedUrl ?? (await service.apple.lookup(item.appleId!))?.feedUrl;
    return feed == null ? null : service.subscribeFromUrl(feed);
  }

  /// Follows the feed at [url] (typed or picked in the directory).
  Future<int> followUrl(String url) =>
      _ref.read(podcastServiceProvider).subscribeFromUrl(url);

  /// Reads the feed again (only when stale if [onlyIfStale]); the new episodes, null when the network was not asked.
  Future<int?> refresh(int podcastId, {bool onlyIfStale = false}) {
    final svc = _ref.read(podcastServiceProvider);
    return onlyIfStale ? svc.refreshIfStale(podcastId) : svc.refresh(podcastId);
  }

  /// Removes the podcast with its episodes and downloaded files.
  Future<void> unsubscribe(int podcastId) async {
    final rows = await _ref.read(podcastEpisodesProvider(podcastId).future);
    _ref.read(podcastDownloadsProvider.notifier).cancelAll([
      for (final r in rows) r.episode.id,
    ]);
    await _ref.read(podcastServiceProvider).unsubscribe(podcastId);
  }

  Future<void> deleteEpisodeFile(int episodeId) async =>
      (await _ref.read(episodeDownloaderProvider.future)).deleteFile(episodeId);

  /// How many episodes of the podcast are downloaded.
  Future<int> downloadedCount(int podcastId) async =>
      (await _ref
              .read(podcastRepositoryProvider)
              .downloadedEpisodes(podcastId: podcastId))
          .length;

  /// «Segui» / «Segui già»: only the flag changes, heard episodes and bookmarks stay.
  Future<void> setFollowed(int podcastId, bool followed) =>
      _ref.read(podcastRepositoryProvider).setFollowed(podcastId, followed);

  /// Deletes the downloaded files of the podcast, which stays listed (D-470).
  Future<void> deleteDownloads(int podcastId) async {
    final rows = await _ref
        .read(podcastRepositoryProvider)
        .downloadedEpisodes(podcastId: podcastId);
    _ref.read(podcastDownloadsProvider.notifier).cancelAll([
      for (final r in rows) r.episode.id,
    ]);
    for (final r in rows) {
      await deleteEpisodeFile(r.episode.id);
    }
  }

  /// Saves a previewed show with its episodes: followed or for listening only
  /// (an already saved podcast keeps its flag). Returns its id.
  Future<int> save(PodcastPreview d, {required bool followed}) async {
    final repo = _ref.read(podcastRepositoryProvider);
    final id = await repo.subscribe(
      d.feedUrl,
      d.feed,
      now: nowMs(),
      source: d.source,
      sourceId: d.sourceId,
      followed: followed,
    );
    await storePodcastCover(
      repo,
      _ref.read(podcastCoverSaverProvider),
      id,
      d.feed.imageUrl,
    );
    return id;
  }

  /// The track the episode [guid] of a preview plays (its file, else a streaming row), saving
  /// the podcast (not followed) first so the bookmark works without following. Null (and
  /// nothing saved) when the episode has no address to stream from.
  Future<Track?> saveForPlay(PodcastPreview d, String guid) async {
    final info = d.feed.episodes.where((e) => e.guid == guid).firstOrNull;
    if (info == null) return null;
    if (d.source != kPodcastSourceYtm && !isHttpAddress(info.audioUrl)) {
      return null;
    }
    final repo = _ref.read(podcastRepositoryProvider);
    final saved = await repo.byFeedUrl(d.feedUrl);
    var episode = saved == null
        ? null
        : await repo.episodeByGuid(saved.id, guid);
    // The feed is written only when the show or the episode is missing, or the feed has an
    // episode newer than the last time it was read: not at every tap.
    final checked = saved?.lastCheckedAt;
    final newer =
        checked == null ||
        d.feed.episodes.any(
          (e) => (e.publishedAt?.millisecondsSinceEpoch ?? 0) > checked,
        );
    if (saved == null || episode == null || newer) {
      final id = await save(d, followed: false);
      episode = await repo.episodeByGuid(id, guid);
    }
    return episode == null ? null : repo.playableTrack(episode.id);
  }

  Future<bool> _play(Track? track, String podcastTitle) async {
    if (track == null) return false;
    await _ref
        .read(playerControllerProvider)
        .playFromList(
          [track],
          0,
          context: PlayContext(PlayContextKind.podcast, podcastTitle),
        );
    return true;
  }

  /// Plays the episode [guid] of a preview; false when it cannot play yet.
  Future<bool> playEpisode(PodcastPreview d, String guid) async =>
      _play(await saveForPlay(d, guid), d.feed.title);

  /// Plays a saved episode that is not downloaded, in streaming; false when it cannot.
  Future<bool> playStreamed(int episodeId) async {
    final repo = _ref.read(podcastRepositoryProvider);
    final episode = await repo.episodeById(episodeId);
    final podcast = episode == null ? null : await repo.byId(episode.podcastId);
    if (podcast == null) return false;
    return _play(await repo.playableTrack(episodeId), podcast.title);
  }

  Future<void> setAutoDeleteDays(int podcastId, int? days) =>
      _ref.read(podcastRepositoryProvider).setAutoDeleteDays(podcastId, days);

  Future<void> markPlayed(int episodeId, bool played) async {
    final repo = _ref.read(podcastRepositoryProvider);
    await repo.markPlayed(episodeId, played, now: nowMs());
    // The player may have it open: it must not write the place again.
    final trackId = played
        ? (await repo.episodeById(episodeId))?.trackId
        : null;
    if (trackId != null) {
      _ref.read(audioHandlerProvider).episodeHeardByHand(trackId);
    }
  }
}

final podcastOpsProvider = Provider<PodcastOps>(PodcastOps.new);
