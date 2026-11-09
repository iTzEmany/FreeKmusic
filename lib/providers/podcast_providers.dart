import 'package:dio/dio.dart' show CancelToken;
import '../services/podcast/rss_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/app_log.dart';
import '../core/paths.dart';
import '../data/db/app_database.dart';
import '../data/repositories/podcast_repository.dart';
import '../services/covers/cover_store.dart';
import '../services/online/http_client.dart';
import '../services/online/youtube_service.dart' show YtErrorKind;
import '../services/podcast/episode_downloader.dart';
import '../services/podcast/apple_podcasts.dart';
import '../services/podcast/feed_fetcher.dart';
import '../services/podcast/podcast_cleanup.dart';
import '../services/podcast/podcast_cover.dart';
import '../services/podcast/podcast_models.dart';
import '../services/podcast/podcast_service.dart';
import '../services/online/ytm_podcasts.dart';
import '../services/podcast/ytm_podcast_sync.dart' show YtmPodcastSync, kPodcastSourceYtm, ytmShowFeedUrl;
import 'database_providers.dart';
import 'library_providers.dart';
import 'player_providers.dart';
import 'smart_search_providers.dart' show sourceCooldownProvider;
import 'startup_providers.dart' show startupSettledProvider;
import 'youtube_providers.dart';

final podcastRepositoryProvider = Provider<PodcastRepository>(
  (ref) => PodcastRepository(ref.watch(databaseProvider)),
);

/// The albumKey every episode of a podcast shares (its cover hangs on it).
String podcastAlbumKey(int podcastId) => podcastAlbumKeyOf(podcastId);

/// True while all the podcasts are being read again: it shows in the Activity centre.
class PodcastRefreshing extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool on) => state = on;
}

final podcastRefreshingProvider = NotifierProvider<PodcastRefreshing, bool>(PodcastRefreshing.new);

/// One Apple directory client for the whole app: its cache and rate limit
/// must outlive a rebuild of [podcastServiceProvider].
final applePodcastsProvider = Provider<ApplePodcasts>((ref) => ApplePodcasts(
      web: DioWebClient(),
      limiter: RateLimiter(minGap: const Duration(seconds: 1)),
      now: DateTime.now,
    ));

/// Stores a podcast cover (downloaded from its address) under the podcast's album key.
final podcastCoverSaverProvider = Provider<PodcastCoverSaver>((ref) {
  final web = DioWebClient();
  final covers = ref.watch(coverStoreProvider);
  return (id, url) async {
    final bytes = await web.getBytes(url, maxBytes: CoverStore.maxBytes);
    if (bytes == null) return null;
    return covers.saveFromBytes(podcastAlbumKey(id), bytes, url);
  };
});

final podcastServiceProvider = Provider<PodcastService>((ref) {
  final web = DioWebClient();
  // The folder is known a moment after start-up; until then nothing is deleted.
  final dir = ref.watch(podcastsDirProvider).value;
  return PodcastService(
    repo: ref.watch(podcastRepositoryProvider),
    fetch: dioFeedFetcher(),
    parse: parseFeed,
    web: web,
    podcastsDir: dir,
    ytm: ref.watch(ytmPodcastSyncProvider),
    apple: ref.watch(applePodcastsProvider),
    saveCover: ref.watch(podcastCoverSaverProvider),
  );
});

final podcastsProvider = StreamProvider<List<PodcastSummary>>(
  (ref) => ref.watch(podcastRepositoryProvider).watchPodcasts(),
);

final podcastProvider = StreamProvider.family<Podcast?, int>(
  (ref, id) => ref.watch(podcastRepositoryProvider).watchById(id),
);

final podcastEpisodesProvider = StreamProvider.family<List<EpisodeRow>, int>(
  (ref, id) => ref.watch(podcastRepositoryProvider).watchEpisodes(id),
);

/// A show read in memory, not saved: where it comes from and what its feed says.
class PodcastPreview {
  const PodcastPreview({required this.feedUrl, required this.feed, this.source = 0, this.sourceId});

  final String feedUrl;
  final PodcastFeed feed;

  /// See `Podcasts.source`; [sourceId] is the YouTube Music show id.
  final int source;
  final String? sourceId;
}

/// Which show to preview: a feed (Apple search), an Apple id (chart: the feed comes on request) or a YouTube Music id.
typedef PodcastPreviewKey = ({String? feedUrl, String? appleId, String? ytmId});

/// The feed of a show not followed, kept in memory while its preview is open.
final podcastPreviewProvider = FutureProvider.autoDispose.family<PodcastPreview, PodcastPreviewKey>((ref, key) async {
  final ytmId = key.ytmId;
  if (ytmId != null) {
    final feed = await ref.read(ytmPodcastSyncProvider).peek(ytmId);
    return PodcastPreview(feedUrl: ytmShowFeedUrl(ytmId), feed: feed, source: kPodcastSourceYtm, sourceId: ytmId);
  }
  final service = ref.read(podcastServiceProvider);
  final url = key.feedUrl ?? (await service.apple.lookup(key.appleId!))?.feedUrl;
  if (url == null) throw const PodcastException(PodcastErrorKind.notFeed);
  return PodcastPreview(feedUrl: url, feed: await service.peek(url));
}, retry: (_, _) => null);

/// `<appSupportDir>/podcasts`: where episodes live, outside every music folder.
final podcastsDirProvider = FutureProvider<String>(
  (ref) async => p.join(await appSupportDir(), 'podcasts'),
);

final episodeDownloaderProvider = FutureProvider<EpisodeDownloader>((ref) async {
  return EpisodeDownloader(
    repo: ref.watch(podcastRepositoryProvider),
    tracks: ref.watch(trackRepositoryProvider),
    tags: ref.watch(tagReaderProvider),
    baseDir: await ref.watch(podcastsDirProvider.future),
    youtube: ref.watch(ytDlpServiceProvider),
  );
});

/// YouTube Music shows: subscribing and reading their new episodes (D-404).
final ytmPodcastsProvider = Provider<YtmPodcasts>(
  (ref) => YtmPodcasts(ref.watch(innerTubeClientProvider), cooldown: ref.watch(sourceCooldownProvider)),
);

final ytmPodcastSyncProvider = Provider<YtmPodcastSync>((ref) => YtmPodcastSync(
      repo: ref.watch(podcastRepositoryProvider),
      ytm: ref.watch(ytmPodcastsProvider),
      saveCover: ref.watch(podcastCoverSaverProvider),
    ));

enum EpisodeDownloadStatus { queued, downloading, done, failed }

/// One episode on its way (or just arrived) shown in the Activity centre.
class EpisodeDownload {
  const EpisodeDownload({
    required this.episodeId,
    required this.title,
    this.serial = 0,
    this.status = EpisodeDownloadStatus.queued,
    this.progress,
    this.error,
    this.ytError,
  });

  final int episodeId;
  final String title;

  /// Tells two downloads of the same episode apart (for «Pulisci»).
  final int serial;
  final EpisodeDownloadStatus status;

  /// 0..1, null while nobody knows the size.
  final double? progress;
  final PodcastErrorKind? error;

  /// Set when YouTube Music / yt-dlp failed: show `ytErrorText` of it, and offer
  /// «Riprova» only for `network` (or none).
  final YtErrorKind? ytError;

  bool get active =>
      status == EpisodeDownloadStatus.queued ||
      status == EpisodeDownloadStatus.downloading;

  EpisodeDownload copyWith({EpisodeDownloadStatus? status, double? progress, PodcastErrorKind? error, YtErrorKind? ytError}) =>
      EpisodeDownload(
        episodeId: episodeId,
        title: title,
        serial: serial,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        error: error ?? this.error,
        ytError: ytError ?? this.ytError,
      );
}

/// What the Activity centre needs to cancel an episode download.
class PodcastDownloadRef {
  const PodcastDownloadRef(this.episodeId);

  final int episodeId;
}

/// Downloads episodes a few at a time, only when the user asks for one.
class PodcastDownloadsNotifier extends Notifier<List<EpisodeDownload>> {
  static const maxParallel = 2;
  final _tokens = <int, CancelToken>{};
  var _serial = 0;

  @override
  List<EpisodeDownload> build() => const [];

  void add(int episodeId, String title) {
    if (state.any((d) => d.episodeId == episodeId && d.active)) return;
    state = [
      for (final d in state)
        if (d.episodeId != episodeId) d,
      EpisodeDownload(episodeId: episodeId, title: title, serial: ++_serial),
    ];
    _pump();
  }

  void cancel(int episodeId) => _tokens[episodeId]?.cancel();

  /// Cancels the running downloads of these episodes (the podcast is going away).
  void cancelAll(Iterable<int> episodeIds) => episodeIds.forEach(cancel);

  /// Forgets the finished ones («Pulisci»).
  void clearFinished() => state = [
        for (final d in state)
          if (d.active) d,
      ];

  void _set(int id, EpisodeDownload Function(EpisodeDownload) f) {
    state = [for (final d in state) d.episodeId == id ? f(d) : d];
  }

  void _pump() {
    final running = state.where((d) => d.status == EpisodeDownloadStatus.downloading).length;
    final waiting = state.where((d) => d.status == EpisodeDownloadStatus.queued).toList();
    for (var i = 0; i < maxParallel - running && i < waiting.length; i++) {
      _start(waiting[i].episodeId);
    }
  }

  Future<void> _start(int id) async {
    final token = _tokens[id] = CancelToken();
    _set(id, (d) => d.copyWith(status: EpisodeDownloadStatus.downloading));
    try {
      final downloader = await ref.read(episodeDownloaderProvider.future);
      final trackId = await downloader.download(
        id,
        cancel: token,
        onProgress: (received, total) {
          if (total > 0) _set(id, (d) => d.copyWith(progress: received / total));
        },
      );
      if (trackId == null) {
        // Cancelled: nothing to show.
        state = [for (final d in state) if (d.episodeId != id) d];
      } else {
        _set(id, (d) => d.copyWith(status: EpisodeDownloadStatus.done, progress: 1));
      }
    } on PodcastException catch (e) {
      AppLog.w('episode $id not downloaded', e);
      _set(id, (d) => d.copyWith(status: EpisodeDownloadStatus.failed, error: e.kind, ytError: e.yt));
    } on Object catch (e, st) {
      AppLog.e('episode $id download crashed', e, st);
      _set(id, (d) => d.copyWith(status: EpisodeDownloadStatus.failed, error: PodcastErrorKind.network));
    } finally {
      _tokens.remove(id);
      _pump();
    }
  }
}

final podcastDownloadsProvider =
    NotifierProvider<PodcastDownloadsNotifier, List<EpisodeDownload>>(
  PodcastDownloadsNotifier.new,
);

/// Once the app has settled: orphan podcast rows and folders go (watched from the root).
final podcastOrphansStartProvider = FutureProvider<void>((ref) async {
  await ref.watch(startupSettledProvider.future);
  try {
    final downloader = await ref.read(episodeDownloaderProvider.future);
    await downloader.removeOrphans();
  } on Object catch (e, st) {
    AppLog.w('podcast orphan cleanup failed', e, st);
  }
});

/// Run when the Podcast section opens: leftovers of interrupted downloads go,
/// then the episodes heard longer ago than each podcast allows. Returns how
/// many episode files were deleted.
final podcastMaintenanceProvider = FutureProvider.autoDispose<int>((ref) async {
  final downloader = await ref.watch(episodeDownloaderProvider.future);
  final base = await ref.watch(podcastsDirProvider.future);
  final handler = ref.read(audioHandlerProvider);
  await downloader.removeOrphanParts();
  return PodcastCleanup(
    repo: ref.read(podcastRepositoryProvider),
    downloader: downloader,
    baseDir: base,
    inUse: () => {
      ...handler.queueIds,
      ?handler.currentTrack?.id,
    },
  ).run();
});
