import '../../core/app_log.dart';
import '../../data/repositories/podcast_repository.dart';

/// Downloads and stores the cover at the address; returns its cover key.
typedef PodcastCoverSaver = Future<String?> Function(int podcastId, String imageUrl);

/// Fetches the cover of [id] once (it keeps the one it has). A missing cover
/// must never fail a subscription or a refresh.
Future<void> storePodcastCover(PodcastRepository repo, PodcastCoverSaver? save, int id, String? imageUrl) async {
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
