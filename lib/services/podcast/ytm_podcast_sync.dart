import '../../core/app_log.dart';
import '../../data/repositories/podcast_repository.dart';
import '../online/youtube_service.dart' show YtException;
import '../online/ytm_podcasts.dart';
import 'podcast_models.dart';

/// `Podcasts.source` of a YouTube Music show (0 is an RSS feed).
const kPodcastSourceYtm = 1;

/// The address a YouTube Music show is stored under (`feedUrl` is unique).
String ytmShowFeedUrl(String showId) => 'https://music.youtube.com/browse/$showId';

/// Subscribing to YouTube Music shows and reading their new episodes: the
/// same as the RSS feeds, with the show page in place of the feed (D-404).
class YtmPodcastSync {
  YtmPodcastSync({
    required this.repo,
    required this.ytm,
    this.saveCover,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final PodcastRepository repo;
  final YtmPodcasts ytm;

  /// Downloads and stores the cover at the address; returns its cover key.
  final Future<String?> Function(int podcastId, String imageUrl)? saveCover;
  final DateTime Function() _now;

  int get _nowMs => _now().millisecondsSinceEpoch;

  Future<YtmShowPage> _read(String showId) async {
    try {
      return await ytm.show(showId);
    } on YtException catch (e, st) {
      AppLog.w('YouTube Music show failed: $showId', e, st);
      throw PodcastException(PodcastErrorKind.network, '$e');
    } on Object catch (e, st) {
      // A page this client cannot read (InnerTubeChanged) is not a feed either.
      AppLog.w('YouTube Music show not readable: $showId', e, st);
      throw PodcastException(PodcastErrorKind.notFeed, '$e');
    }
  }

  PodcastFeed _feed(YtmShowPage page) => PodcastFeed(
        title: page.title,
        author: page.author,
        description: page.description,
        imageUrl: page.thumbnailUrl,
        episodes: [
          for (final e in page.episodes)
            PodcastEpisodeInfo(
              guid: e.videoId,
              title: e.title,
              audioUrl: e.watchUrl,
              publishedAt: e.publishedAt,
              duration: e.duration,
              description: e.description,
            ),
        ],
      );

  /// Subscribes to the show [showId]; again to the same one just refreshes it.
  Future<int> subscribe(String showId) async {
    final page = await _read(showId);
    final id = await repo.subscribe(ytmShowFeedUrl(showId), _feed(page),
        now: _nowMs, source: kPodcastSourceYtm, sourceId: showId);
    await _cover(id, page.thumbnailUrl);
    return id;
  }

  /// Reads the show page again and adds the new episodes. Returns how many;
  /// 0 for a podcast that is not a YouTube Music one.
  Future<int> refresh(int podcastId) async {
    final podcast = await repo.byId(podcastId);
    final showId = podcast?.sourceId;
    if (podcast == null || podcast.source != kPodcastSourceYtm || showId == null) return 0;
    final page = await _read(showId);
    final added = await repo.upsertEpisodes(podcastId, _feed(page).episodes);
    await repo.markChecked(podcastId, _nowMs);
    await _cover(podcastId, page.thumbnailUrl ?? podcast.imageUrl);
    return added;
  }

  Future<void> _cover(int id, String? imageUrl) async {
    final save = saveCover;
    if (save == null || imageUrl == null) return;
    final podcast = await repo.byId(id);
    if (podcast == null || podcast.coverKey != null) return;
    try {
      final key = await save(id, imageUrl);
      if (key != null) await repo.setCoverKey(id, key);
    } on Object catch (e, st) {
      AppLog.w('podcast cover failed: $imageUrl', e, st);
    }
  }
}
