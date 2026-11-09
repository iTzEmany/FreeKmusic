import '../../widgets/cc_sheet.dart';
import '../../../providers/podcast_ops.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/db/app_database.dart';
import '../../../data/repositories/podcast_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/podcast_providers.dart';
import '../../../services/podcast/podcast_models.dart';
import '../../theme/tokens.dart';
import '../../widgets/collection_header.dart';
import '../../widgets/confirm.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/format_utils.dart';
import '../../widgets/segmented_blocks.dart';
import '../../widgets/speed_button.dart';
import 'podcast_texts.dart';
import '../../widgets/show_msg.dart';
import '../../../core/app_log.dart';

/// One podcast: its header, and its episodes (newest first) with what each one
/// is doing. Opening it refreshes the feed only if it is older than 6 hours.
class PodcastDetailScreen extends ConsumerStatefulWidget {
  const PodcastDetailScreen({super.key, required this.podcastId});

  final int podcastId;

  @override
  ConsumerState<PodcastDetailScreen> createState() => _PodcastDetailScreenState();
}

class _PodcastDetailScreenState extends ConsumerState<PodcastDetailScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _refresh(onlyIfStale: true));
  }

  Future<void> _refresh({bool onlyIfStale = false}) async {
    if (_refreshing) return;
    final ops = ref.read(podcastOpsProvider);
    setState(() => _refreshing = true);
    try {
      final added = await ops.refresh(widget.podcastId, onlyIfStale: onlyIfStale);
      if (added != null && mounted && !onlyIfStale) {
        showMsg(context, context.l10n.podcastRefreshed(added));
      }
    } on PodcastException catch (e) {
      AppLog.w('podcast refresh failed', e);
      if (mounted) {
        showMsg(context, podcastFailureText(context, context.l10n, e.kind, e.yt));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// The downloaded episodes oldest first, so listening goes forward in time,
  /// starting at the one tapped.
  Future<void> _play(List<EpisodeRow> rows, EpisodeRow tapped, String podcastTitle) async {
    final downloaded = [
      for (final r in rows)
        if (r.downloaded) r,
    ]..sort((a, b) => (a.episode.publishedAt ?? 0).compareTo(b.episode.publishedAt ?? 0));
    final index = downloaded.indexWhere((r) => r.episode.id == tapped.episode.id);
    if (index < 0) return;
    await ref.read(playerControllerProvider).playFromList(
          [for (final r in downloaded) r.track!],
          index,
          context: PlayContext(PlayContextKind.podcast, podcastTitle),
        );
  }

  Future<void> _unsubscribe(Podcast p, int downloadedCount) async {
    final l = context.l10n;
    final ok = await showConfirm(
      context,
      title: l.podcastUnsubscribeTitle,
      body: l.podcastUnsubscribeBody(downloadedCount),
      confirmLabel: l.podcastUnsubscribe,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(podcastOpsProvider).unsubscribe(p.id);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final podcast = ref.watch(podcastProvider(widget.podcastId)).value;
    final rows = ref.watch(podcastEpisodesProvider(widget.podcastId)).value ?? const <EpisodeRow>[];
    final running = {for (final d in ref.watch(podcastDownloadsProvider)) d.episodeId: d};
    if (podcast == null) return const Scaffold();
    final downloadedCount = rows.where((r) => r.downloaded).length;
    final checked = podcast.lastCheckedAt;
    final when = checked == null
        ? l.podcastNeverChecked
        : l.podcastLastChecked(
            DateFormat.yMMMd(Localizations.localeOf(context).toString())
                .add_Hm()
                .format(DateTime.fromMillisecondsSinceEpoch(checked)),
          );
    return CollectionScaffold(
      title: podcast.title,
      name: podcast.title,
      cover: (size) => CoverImage(coverKey: podcast.coverKey, size: size, radius: CcDims.rGrid),
      subtitle: podcast.author == null ? null : Text(podcast.author!),
      meta: when,
      menu: const SpeedButton(),
      barActions: [
        if (_refreshing)
          const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          IconButton(
            key: const ValueKey('refresh'),
            tooltip: l.podcastRefresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        IconButton(
          key: const ValueKey('podcast-menu'),
          tooltip: l.moreActions,
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () async {
            final v = await showCcActionSheet<_PodcastAction>(
              context: context,
              title: podcast.title,
              groups: [
                [
                  CcAction(
                    icon: Icons.unsubscribe_outlined,
                    label: l.podcastUnsubscribe,
                    value: _PodcastAction.unsubscribe,
                    destructive: true,
                  ),
                ],
              ],
            );
            if (v == _PodcastAction.unsubscribe) _unsubscribe(podcast, downloadedCount);
          },
        ),
      ],
      slivers: [
        SliverToBoxAdapter(child: _AutoDelete(podcast: podcast)),
        if (rows.isEmpty)
          SliverToBoxAdapter(child: EmptyState(icon: Icons.podcasts_rounded, message: l.podcastNoEpisodes))
        else
          SliverFixedExtentList.builder(
            itemExtent: 84,
            itemCount: rows.length,
            itemBuilder: (_, i) => _EpisodeTile(
              row: rows[i],
              download: running[rows[i].episode.id],
              onPlay: () => _play(rows, rows[i], podcast.title),
            ),
          ),
      ],
    );
  }
}

/// The auto-delete choice of one podcast.
class _AutoDelete extends ConsumerWidget {
  const _AutoDelete({required this.podcast});

  final Podcast podcast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final days = const [1, 7, 30].contains(podcast.autoDeleteDays) ? podcast.autoDeleteDays : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CcDims.margin, 0, CcDims.margin, CcDims.gap8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.podcastAutoDelete, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          SegmentedBlocks<int?>(
            key: const ValueKey('auto-delete'),
            selected: days,
            onChanged: (d) => ref.read(podcastOpsProvider).setAutoDeleteDays(podcast.id, d),
            items: [
              BlockItem(value: null, icon: Icons.block_rounded, label: l.podcastAutoDeleteNever),
              for (final d in const [1, 7, 30])
                BlockItem(value: d, icon: Icons.auto_delete_outlined, label: l.podcastAutoDeleteAfter(d)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EpisodeTile extends ConsumerWidget {
  const _EpisodeTile({required this.row, required this.download, required this.onPlay});

  final EpisodeRow row;
  final EpisodeDownload? download;
  final VoidCallback onPlay;

  String _status(BuildContext context, AppLocalizations l) {
    final d = download;
    if (d != null && d.active) {
      return l.podcastStateDownloading(((d.progress ?? 0) * 100).round());
    }
    if (d != null && d.status == EpisodeDownloadStatus.failed && d.error != null) {
      return podcastFailureText(context, l, d.error!, d.ytError);
    }
    if (row.episode.played) return l.podcastStateHeard;
    final t = row.track;
    final resume = t?.resumePositionMs;
    if (t != null && resume != null && t.durationMs > resume) {
      return l.podcastStateRemaining(etaLabel(l, Duration(milliseconds: t.durationMs - resume)));
    }
    return row.downloaded ? l.podcastStateDownloaded : '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final e = row.episode;
    final locale = Localizations.localeOf(context).toString();
    final date = e.publishedAt == null
        ? null
        : DateFormat.yMMMd(locale).format(DateTime.fromMillisecondsSinceEpoch(e.publishedAt!));
    final status = _status(context, l);
    final podcastOps = ref.read(podcastOpsProvider);
    final busy = download?.active ?? false;
    final failedYt = download?.status == EpisodeDownloadStatus.failed && download?.ytError != null;
    final Widget action;
    if (busy) {
      action = IconButton(
        key: ValueKey('cancel-${e.id}'),
        tooltip: l.cancel,
        icon: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5, value: download?.progress),
        ),
        onPressed: () => ref.read(podcastDownloadsProvider.notifier).cancel(e.id),
      );
    } else if (row.downloaded) {
      action = IconButton(
        key: ValueKey('play-${e.id}'),
        tooltip: l.play,
        icon: const Icon(Icons.play_circle_rounded),
        onPressed: onPlay,
      );
    } else {
      action = IconButton(
        key: ValueKey('download-${e.id}'),
        tooltip: failedYt ? l.retry : l.ytDownload,
        icon: const Icon(Icons.download_rounded),
        onPressed: failedYt && !podcastCanRetry(download?.ytError) ? null : () => ref.read(podcastDownloadsProvider.notifier).add(e.id, e.title),
      );
    }
    return InkWell(
      onTap: row.downloaded && !busy ? onPlay : null,
      child: Padding(
        padding: const EdgeInsets.only(left: CcDims.margin, right: CcDims.gap4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodyLarge?.copyWith(color: e.played ? cc.textMuted : null),
                  ),
                  Text(
                    [
                      ?date,
                      if (e.durationMs != null) formatDuration(e.durationMs!),
                      if (status.isNotEmpty) status,
                    ].join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodySmall?.copyWith(color: cc.textMuted),
                  ),
                ],
              ),
            ),
            action,
            IconButton(
              key: ValueKey('menu-${e.id}'),
              tooltip: l.moreActions,
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () async {
                final v = await showCcActionSheet<_EpisodeAction>(
                  context: context,
                  title: e.title,
                  groups: [
                    [
                      CcAction(
                        icon: e.played ? Icons.radio_button_unchecked_rounded : Icons.check_circle_outline_rounded,
                        label: e.played ? l.podcastMarkNotHeard : l.podcastMarkHeard,
                        value: _EpisodeAction.heard,
                      ),
                      if (row.downloaded)
                        CcAction(
                          icon: Icons.delete_outline_rounded,
                          label: l.podcastDeleteFile,
                          value: _EpisodeAction.delete,
                          destructive: true,
                        ),
                    ],
                  ],
                );
                switch (v) {
                  case _EpisodeAction.heard:
                    await podcastOps.markPlayed(e.id, !e.played);
                  case _EpisodeAction.delete:
                    await podcastOps.deleteEpisodeFile(e.id);
                  case null:
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum _PodcastAction { unsubscribe }

enum _EpisodeAction { heard, delete }
