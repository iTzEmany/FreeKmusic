import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/online/download_queue.dart';
import '../services/online/retry_policy.dart';
import '../services/share/offers.dart';
import 'duplicate_providers.dart';
import 'enrich_completer_providers.dart';
import 'import_providers.dart';
import 'library_providers.dart';
import 'online_providers.dart';
import 'podcast_providers.dart';
import 'radio_providers.dart' show radioCheckingProvider;
import 'releases_providers.dart' show manualReleaseCheckProvider;
import 'second_opinion_providers.dart';
import 'share_hub.dart';
import 'youtube_providers.dart';
import 'yt_dlp_update_providers.dart';
import '../services/import/playlist_import_service.dart';

enum ActivityKind {
  scan,
  enrich,
  download,
  transfer,
  import,
  cleanup,
  releases,
  secondOpinion,
  podcastRefresh,
  radio,
  enrichBackground,
  genreReread,
  artistCountries,
  ytDlp,
  playbackFailed,
}

/// One line of the Activity centre. [progress] is 0..1, null = indeterminate.
class ActivityItem {
  const ActivityItem({
    required this.kind,
    required this.key,
    required this.name,
    this.done = 0,
    this.total = 0,
    this.progress,
    this.running = true,
    this.failed = false,
    this.paused = false,
    this.waiting = false,
    this.ref,
    this.retryDelaySec,
    this.eta,
  });

  final ActivityKind kind;
  final String key;

  /// Download title / device name (null for scan and enrichment).
  final String? name;
  final int done, total;
  final double? progress;
  final bool running, failed;

  /// A CSV import waiting for the user (still listed among the running ones).
  final bool paused;

  /// The background completion waiting for the user to leave the app alone.
  final bool waiting;

  /// The download id, the [OutgoingOffer] or the import id, used to cancel.
  final Object? ref;

  /// A download waiting to retry: [done] is the attempt, [total] the maximum.
  final int? retryDelaySec;

  /// An import's estimated time left (null = unknown).
  final Duration? eta;

  bool get cancellable =>
      running &&
      (kind == ActivityKind.download ||
          kind == ActivityKind.transfer ||
          kind == ActivityKind.import ||
          kind == ActivityKind.cleanup ||
          kind == ActivityKind.secondOpinion ||
          kind == ActivityKind.enrichBackground ||
          kind == ActivityKind.enrich);
}

/// The duplicate search, while it reads files.
class CleanupProgress {
  const CleanupProgress(this.done, this.total);

  final int done, total;
}

/// The background completion, while it runs or is paused by hand.
class EnrichBackgroundProgress extends CleanupProgress {
  const EnrichBackgroundProgress(super.done, super.total, {this.paused = false, this.waiting = false});

  final bool paused, waiting;
}

/// The completion as a line of the Activity centre (null: not shown).
EnrichBackgroundProgress? enrichBackgroundOf(EnrichCompleterState c) =>
    c.visible
        ? EnrichBackgroundProgress(c.complete, c.total, paused: c.paused, waiting: c.waiting)
        : null;

class ActivityState {
  const ActivityState(this.running, this.completed);

  final List<ActivityItem> running, completed;

  bool get isEmpty => running.isEmpty && completed.isEmpty;
}

/// Pure aggregation of what the app is doing in the background.
ActivityState buildActivity({
  required ScanState scan,
  required EnrichJobState enrich,
  required List<DownloadItem> downloads,
  required List<OutgoingOffer> outgoing,
  List<ImportProgress> imports = const [],
  CleanupProgress? cleanup,
  List<EpisodeDownload> episodes = const [],
  bool releases = false,
  CleanupProgress? secondOpinion,
  bool podcastRefresh = false,
  bool radio = false,
  double? ytDlp,
  EnrichBackgroundProgress? enrichBackground,
}) {
  final running = <ActivityItem>[];
  final completed = <ActivityItem>[];

  if (scan.running) {
    final p = scan.progress;
    running.add(
      ActivityItem(
        kind: ActivityKind.scan,
        key: 'scan',
        name: null,
        done: p?.done ?? 0,
        total: p?.total ?? 0,
        progress: (p == null || p.total == 0) ? null : p.done / p.total,
      ),
    );
  }
  if (enrich.running) {
    final p = enrich.progress;
    running.add(
      ActivityItem(
        kind: ActivityKind.enrich,
        key: 'enrich',
        name: null,
        done: p?.done ?? 0,
        total: p?.total ?? 0,
        progress: (p == null || p.total == 0) ? null : p.done / p.total,
      ),
    );
  }
  if (cleanup != null) {
    running.add(
      ActivityItem(
        kind: ActivityKind.cleanup,
        key: 'cleanup',
        name: null,
        done: cleanup.done,
        total: cleanup.total,
        progress: cleanup.total == 0 ? null : cleanup.done / cleanup.total,
      ),
    );
  }
  if (secondOpinion != null) {
    running.add(
      ActivityItem(
        kind: ActivityKind.secondOpinion,
        key: 'secondOpinion',
        name: null,
        done: secondOpinion.done,
        total: secondOpinion.total,
        progress: secondOpinion.total == 0 ? null : secondOpinion.done / secondOpinion.total,
      ),
    );
  }
  if (releases) {
    running.add(const ActivityItem(
        kind: ActivityKind.releases, key: 'releases', name: null));
  }
  if (podcastRefresh) {
    running.add(const ActivityItem(
        kind: ActivityKind.podcastRefresh, key: 'podcastRefresh', name: null));
  }
  if (radio) {
    running.add(const ActivityItem(kind: ActivityKind.radio, key: 'radio', name: null));
  }
  if (ytDlp != null) {
    running.add(ActivityItem(
        kind: ActivityKind.ytDlp, key: 'ytDlp', name: null, progress: ytDlp > 0 ? ytDlp : null));
  }
  if (enrichBackground != null) {
    running.add(
      ActivityItem(
        kind: ActivityKind.enrichBackground,
        key: 'enrichBackground',
        name: null,
        done: enrichBackground.done,
        total: enrichBackground.total,
        progress: enrichBackground.total == 0 || enrichBackground.waiting
            ? null
            : enrichBackground.done / enrichBackground.total,
        paused: enrichBackground.paused,
        waiting: enrichBackground.waiting,
      ),
    );
  }
  for (final i in imports) {
    running.add(
      ActivityItem(
        kind: ActivityKind.import,
        key: 'imp-${i.blockIds.firstOrNull ?? i.id}',
        name: i.name,
        // Songs saved so far; the bar follows every row handled.
        done: i.saved,
        total: i.total,
        progress: i.fraction,
        paused: i.paused,
        eta: i.eta,
        ref: i.id,
      ),
    );
  }
  for (final d in downloads) {
    final waiting = d.status == DownloadStatus.waitingRetry;
    final active = d.status == DownloadStatus.queued ||
        d.status == DownloadStatus.downloading ||
        waiting;
    // The songs of an import are counted in its one item, not one by one.
    if (parseImportTag(d.tag) != null) continue;
    final item = ActivityItem(
      kind: ActivityKind.download,
      key: 'dl-${d.id}',
      name: d.result.title,
      progress: d.status == DownloadStatus.downloading ? d.progress : null,
      done: waiting ? d.attempt : 0,
      total: waiting ? RetryPolicy().maxRetries : 0,
      retryDelaySec: waiting ? d.retryDelay?.inSeconds : null,
      running: active,
      failed: d.status == DownloadStatus.failed,
      ref: d.id,
    );
    (active ? running : completed).add(item);
  }
  for (final e in episodes) {
    final item = ActivityItem(
      kind: ActivityKind.download,
      key: 'pod-${e.episodeId}-${e.serial}',
      name: e.title,
      progress: e.status == EpisodeDownloadStatus.downloading ? e.progress : null,
      running: e.active,
      failed: e.status == EpisodeDownloadStatus.failed,
      ref: PodcastDownloadRef(e.episodeId),
    );
    (e.active ? running : completed).add(item);
  }
  for (final o in outgoing) {
    final item = ActivityItem(
      kind: ActivityKind.transfer,
      key: 'tx-${o.offerId}',
      name: o.toName,
      total: o.entries.length,
      progress: null,
      running: o.open,
      failed:
          o.status == OfferStatus.failed ||
          o.status == OfferStatus.declined ||
          o.status == OfferStatus.expired,
      ref: o,
    );
    (o.open ? running : completed).add(item);
  }
  return ActivityState(running, completed);
}

final activityProvider = Provider<ActivityState>((ref) {
  return buildActivity(
    scan: ref.watch(scanStateProvider),
    enrich: ref.watch(enrichJobProvider),
    downloads: ref.watch(downloadsProvider),
    outgoing: ref.watch(shareHubProvider.select((h) => h.outgoing)),
    imports: ref.watch(importProgressProvider),
    episodes: ref.watch(podcastDownloadsProvider),
    releases: ref.watch(manualReleaseCheckProvider),
    podcastRefresh: ref.watch(podcastRefreshingProvider),
    radio: ref.watch(radioCheckingProvider),
    ytDlp: ref.watch(ytDlpUpdateProvider.select(
        (s) => s.phase == YtDlpUpdatePhase.working ? s.progress : null)),
    secondOpinion: ref.watch(
      secondOpinionJobProvider.select(
        (j) => j.running ? CleanupProgress(j.done, j.total) : null,
      ),
    ),
    enrichBackground: ref.watch(
      enrichCompleterProvider.select(enrichBackgroundOf),
    ),
    cleanup: ref.watch(
      duplicateSearchProvider.select(
        (d) => d.running ? CleanupProgress(d.done, d.total) : null,
      ),
    ),
  );
});
