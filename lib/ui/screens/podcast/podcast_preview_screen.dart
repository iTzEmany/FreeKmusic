import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/app_log.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/podcast_discover_providers.dart';
import '../../../providers/podcast_ops.dart';
import '../../../providers/podcast_providers.dart';
import '../../../services/podcast/podcast_models.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/error_state.dart';
import '../../widgets/format_utils.dart';
import '../../widgets/net_thumbnail.dart';
import '../../widgets/show_msg.dart';
import '../../widgets/skeleton.dart';
import 'podcast_texts.dart';

/// What to do with the downloads of a show the user stops following (D-470).
enum _KeepDownloads { keep, delete }

/// Stops following the podcast: episodes and bookmarks stay; with downloads it asks
/// whether to keep or delete them (D-470), without downloads it does not ask.
Future<void> unfollowPodcast(BuildContext context, WidgetRef ref, int podcastId) async {
  final l = context.l10n;
  final ops = ref.read(podcastOpsProvider);
  var keep = _KeepDownloads.keep;
    final downloaded = await ops.downloadedCount(podcastId);
    if (downloaded > 0) {
      if (!context.mounted) return;
      final choice = await showDialog<_KeepDownloads>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.podcastUnfollowTitle),
          content: Text(ctx.l10n.podcastUnfollowBody(downloaded)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.cancel)),
            TextButton(onPressed: () => Navigator.pop(ctx, _KeepDownloads.delete), child: Text(ctx.l10n.podcastDeleteDownloads)),
            FilledButton(onPressed: () => Navigator.pop(ctx, _KeepDownloads.keep), child: Text(ctx.l10n.podcastKeepDownloads)),
          ],
        ),
      );
      if (choice == null) return;
      keep = choice;
    }
    await ops.setFollowed(podcastId, false);
    if (keep == _KeepDownloads.delete) await ops.deleteDownloads(podcastId);
    if (context.mounted) showMsg(context, l.podcastUnfollowedMsg);
}

/// A show that is not followed (D-431): its feed is read in memory, episodes play in
/// streaming (nothing is downloaded here), and «Segui» / «Segui già» is the only write
/// until the first play, which saves the show as not followed so the bookmark works.
class PodcastPreviewScreen extends ConsumerWidget {
  const PodcastPreviewScreen({super.key, required this.listing});

  final PodcastListing listing;

  PodcastPreviewKey get _key => (feedUrl: listing.feedUrl, appleId: listing.appleId, ytmId: listing.ytmId);

  Future<void> _toggleFollow(BuildContext context, WidgetRef ref, PodcastPreview data, int? followedId) async {
    final l = context.l10n;
    final ops = ref.read(podcastOpsProvider);
    if (followedId == null) {
      await ops.save(data, followed: true);
      if (context.mounted) showMsg(context, l.podcastFollowedMsg);
      return;
    }
    await unfollowPodcast(context, ref, followedId);
  }

  Future<void> _play(BuildContext context, WidgetRef ref, PodcastPreview data, PodcastEpisodeInfo e) async {
    final ok = await ref.read(podcastOpsProvider).playEpisode(data, e.guid);
    if (!ok && context.mounted) showMsg(context, context.l10n.podcastStreamUnavailable);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final preview = ref.watch(podcastPreviewProvider(_key));
    final podcasts = ref.watch(podcastsProvider).value ?? const [];
    final followedId = PodcastSubscriptions(podcasts).idOf(listing);
    return Scaffold(
      appBar: CcAppBar(title: l.podcastsTitle),
      body: preview.when(
        loading: () => const Skeleton.bigRow(rows: 5),
        error: (e, _) {
          AppLog.w('podcast preview failed', e);
          final kind = e is PodcastException ? e.kind : PodcastErrorKind.network;
          return ErrorState(
            message: podcastErrorText(l, kind),
            onRetry: () => ref.invalidate(podcastPreviewProvider(_key)),
          );
        },
        data: (data) {
          final eps = data.feed.episodes;
          return ListView.builder(
            padding: EdgeInsets.zero.withDock(context),
            itemCount: eps.length + 1,
            itemBuilder: (_, i) => i == 0
                ? _Header(
                    data: data,
                    following: followedId != null,
                    onToggle: () => _toggleFollow(context, ref, data, followedId),
                  )
                : _EpisodeTile(episode: eps[i - 1], onPlay: () => _play(context, ref, data, eps[i - 1])),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data, required this.following, required this.onToggle});

  final PodcastPreview data;
  final bool following;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final feed = data.feed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap8, CcDims.margin, CcDims.gap8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NetThumbnail(url: feed.imageUrl, width: 112, height: 112, icon: Icons.podcasts_rounded, radius: CcDims.rGrid),
              const SizedBox(width: CcDims.gap16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(feed.title, style: theme.titleLarge),
                    if (feed.author != null) Text(feed.author!, style: theme.bodySmall?.copyWith(color: cc.textMuted)),
                    const SizedBox(height: CcDims.gap8),
                    Semantics(
                      button: true,
                      label: following ? l.podcastUnfollowLabel(feed.title) : l.podcastFollowLabel(feed.title),
                      excludeSemantics: true,
                      onTap: onToggle,
                      child: following
                          ? OutlinedButton.icon(
                              key: const ValueKey('follow'),
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                              onPressed: onToggle,
                              icon: const Icon(Icons.check_rounded),
                              label: Text(l.podcastFollowing),
                            )
                          : FilledButton.icon(
                              key: const ValueKey('follow'),
                              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                              onPressed: onToggle,
                              icon: const Icon(Icons.add_rounded),
                              label: Text(l.podcastFollow),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (feed.description != null && feed.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: CcDims.gap8),
              child: Text(feed.description!, maxLines: 4, overflow: TextOverflow.ellipsis, style: theme.bodyMedium?.copyWith(color: cc.textMuted)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: CcDims.gap8),
            child: Text(following ? l.podcastPreviewFollowed : l.podcastPreviewNote, style: theme.bodySmall?.copyWith(color: cc.textMuted)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: CcDims.gap16),
            child: Text(l.podcastEpisodesCount(feed.episodes.length), style: theme.titleSmall),
          ),
        ],
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({required this.episode, required this.onPlay});

  final PodcastEpisodeInfo episode;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final date = episode.publishedAt == null ? null : DateFormat.yMMMd(locale).format(episode.publishedAt!);
    final meta = [?date, if (episode.duration != null) formatDuration(episode.duration!.inMilliseconds)].join(', ');
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.only(left: CcDims.margin, right: CcDims.gap4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(episode.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.bodyLarge),
                  if (meta.isNotEmpty) Text(meta, maxLines: 1, style: theme.bodySmall?.copyWith(color: cc.textMuted)),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('play-${episode.guid}'),
              tooltip: l.podcastPlayStream(episode.title),
              icon: const Icon(Icons.play_circle_rounded),
              onPressed: onPlay,
            ),
          ],
        ),
      ),
    );
  }
}
