import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../data/repositories/podcast_repository.dart';
import 'episode_downloader.dart';

/// Deletes the files of episodes that were heard long enough ago, for the
/// podcasts whose «delete heard episodes after N days» is on (off by default).
/// Only ever touches files inside the podcast folder, and never an episode that
/// is playing or waiting in the queue.
class PodcastCleanup {
  PodcastCleanup({
    required this.repo,
    required this.downloader,
    required this.baseDir,
    required this.inUse,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final PodcastRepository repo;
  final EpisodeDownloader downloader;

  /// `<appSupportDir>/podcasts`.
  final String baseDir;

  /// Track ids that are playing or queued now.
  final Set<int> Function() inUse;
  final DateTime Function() _now;

  /// Returns how many episode files were deleted.
  Future<int> run() async {
    final nowMs = _now().millisecondsSinceEpoch;
    final busy = inUse();
    var deleted = 0;
    for (final podcast in await repo.allFollowed()) {
      final days = podcast.autoDeleteDays;
      if (days == null || days <= 0) continue;
      final limit = days * Duration.millisecondsPerDay;
      for (final row in await repo.downloadedEpisodes(podcastId: podcast.id)) {
        final e = row.episode;
        final t = row.track!;
        final heardAt = e.playedAt;
        if (!e.played || heardAt == null || nowMs - heardAt < limit) continue;
        if (busy.contains(t.id)) continue;
        if (t.kind != 1 || !p.isWithin(baseDir, t.path)) {
          AppLog.w(
            'podcast cleanup skipped ${t.path}: not an episode file of ours',
          );
          continue;
        }
        await downloader.deleteFile(e.id);
        deleted++;
      }
    }
    return deleted;
  }
}
