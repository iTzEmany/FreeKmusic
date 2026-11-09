import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../data/repositories/podcast_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/podcast_discover_providers.dart';
import '../../../providers/podcast_ops.dart';
import '../../../providers/podcast_providers.dart';
import '../../../services/podcast/podcast_models.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/cc_search_field.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/error_state.dart';
import '../../widgets/net_thumbnail.dart';
import '../../widgets/section_header.dart';
import '../../widgets/show_msg.dart';
import '../../widgets/skeleton.dart';
import 'podcast_detail_screen.dart';
import 'podcast_preview_screen.dart';
import 'podcast_subscribe_sheet.dart';
import 'podcast_texts.dart';

/// Library → Podcast: «I tuoi podcast» on top, «Scopri» (genres and the Italian
/// chart) below, and one search from the lens that merges Apple and YouTube
/// Music. Opening it tidies up (interrupted downloads, heard episodes past
/// their limit) but only the user's taps go to the network.
class PodcastsScreen extends ConsumerStatefulWidget {
  const PodcastsScreen({super.key});

  @override
  ConsumerState<PodcastsScreen> createState() => _PodcastsScreenState();
}

class _PodcastsScreenState extends ConsumerState<PodcastsScreen> {
  final _term = TextEditingController();
  bool _refreshing = false;
  bool _searching = false;
  String _query = '';
  String? _genreId;
  final _busy = <String>{};

  @override
  void dispose() {
    _term.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    final l = context.l10n;
    setState(() => _refreshing = true);
    final report = await ref.read(podcastOpsProvider).refreshAll();
    if (!mounted) return;
    setState(() => _refreshing = false);
    final text = report.failed.isEmpty
        ? l.podcastRefreshed(report.totalAdded)
        : '${l.podcastRefreshed(report.totalAdded)}, '
              '${l.podcastRefreshFailed(report.failed.length)}: '
              '${podcastFailureText(context, l, report.failed.values.first.kind, report.failed.values.first.yt)}';
    showMsg(context, text);
  }

  void _closeSearch() {
    _term.clear();
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  Future<void> _subscribe(PodcastListing item) async {
    final l = context.l10n;
    setState(() => _busy.add(item.key));
    try {
      final id = await ref.read(podcastOpsProvider).followListing(item);
      if (id == null) {
        if (mounted) showMsg(context, l.podcastNoFeed);
        return;
      }
      if (mounted) showMsg(context, l.podcastSubscribed(item.title));
    } on PodcastException catch (e) {
      AppLog.w('podcast subscribe failed', e);
      if (mounted) showMsg(context, podcastFailureText(context, l, e.kind, e.yt));
    } finally {
      if (mounted) setState(() => _busy.remove(item.key));
    }
  }

  PodcastListingRow _row(PodcastListing item, PodcastSubscriptions subs, {int? rank, bool origin = false}) {
    final id = subs.idOf(item);
    return PodcastListingRow(
      key: ValueKey('listing-${item.key}'),
      item: item,
      rank: rank,
      showOrigin: origin,
      subscribed: id != null,
      busy: _busy.contains(item.key),
      onSubscribe: () => _subscribe(item),
      onOpen: () => ShellNav.open<void>(
        context,
        id == null ? PodcastPreviewScreen(listing: item) : PodcastDetailScreen(podcastId: id),
      ),
    );
  }

  List<Widget> _discover(AppLocalizations l, PodcastSubscriptions subs) {
    final genres = ref.watch(podcastGenresProvider).value ?? const [];
    final chart = ref.watch(podcastChartProvider(_genreId));
    return [
      SectionHeader(l.podcastDiscover),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
        child: Text(l.podcastChartTitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.cc.textMuted)),
      ),
      SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: CcDims.margin, vertical: CcDims.gap4),
          children: [
            _chip(l.podcastGenreAll, null),
            for (final g in genres) _chip(podcastGenreName(l, g), g.id),
          ],
        ),
      ),
      ...chart.when(
        loading: () => const [Skeleton.bigRow(rows: 5)],
        error: (e, _) {
          AppLog.w('podcast chart failed', e);
          return [
            ErrorState(
              message: l.podcastChartError,
              onRetry: () {
                ref.invalidate(podcastGenresProvider);
                ref.invalidate(podcastChartProvider(_genreId));
              },
            ),
          ];
        },
        data: (items) => [for (final (i, e) in items.indexed) _row(e, subs, rank: i + 1)],
      ),
    ];
  }

  Widget _chip(String label, String? id) => Padding(
    padding: const EdgeInsets.only(right: CcDims.gap8),
    child: ChoiceChip(
      key: ValueKey('genre-${id ?? 'all'}'),
      label: Text(label),
      selected: _genreId == id,
      onSelected: (_) => setState(() => _genreId = id),
    ),
  );

  List<Widget> _results(AppLocalizations l, PodcastSubscriptions subs) {
    final arg = (query: _query, hl: Localizations.localeOf(context).languageCode);
    return ref.watch(podcastSearchProvider(arg)).when(
      loading: () => const [Skeleton.bigRow(rows: 5)],
      error: (e, _) => [
        ErrorState(
          message: podcastErrorText(l, PodcastErrorKind.network),
          onRetry: () => ref.invalidate(podcastSearchProvider(arg)),
        ),
      ],
      data: (items) {
        final merged = mergeListings(items, subs);
        if (merged.isEmpty) {
          return [Padding(padding: const EdgeInsets.all(CcDims.margin), child: Text(l.podcastSearchNone))];
        }
        return [for (final e in merged) _row(e, subs, origin: true)];
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    // Watching keeps the maintenance alive while the page is open.
    ref.watch(podcastMaintenanceProvider);
    final podcasts = ref.watch(podcastsProvider).value ?? const <PodcastSummary>[];
    final subs = PodcastSubscriptions(podcasts);
    final searchingNow = _searching && _query.isNotEmpty;
    return Scaffold(
      appBar: CcAppBar(
        title: _searching ? null : l.podcastsTitle,
        titleWidget: _searching
            ? CcSearchField(
                key: const ValueKey('podcast-lens-field'),
                controller: _term,
                hint: l.podcastSearchHint,
                autofocus: true,
                onQuery: (q) => setState(() => _query = q),
                onCloseEmpty: _closeSearch,
              )
            : null,
        actions: [
          if (!_searching) ...[
            IconButton(
              key: const ValueKey('podcast-lens'),
              tooltip: l.podcastSearchLens,
              icon: const Icon(Icons.search_rounded),
              onPressed: () => setState(() => _searching = true),
            ),
            if (podcasts.isNotEmpty)
              _refreshing
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      key: const ValueKey('refresh-all'),
                      tooltip: l.podcastRefreshAll,
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _refreshAll,
                    ),
            IconButton(
              key: const ValueKey('add-podcast'),
              tooltip: l.podcastAdd,
              icon: const Icon(Icons.add_rounded),
              onPressed: () => PodcastSubscribeSheet.show(context),
            ),
          ] else
            IconButton(
              key: const ValueKey('podcast-lens-close'),
              tooltip: l.close,
              icon: const Icon(Icons.close_rounded),
              onPressed: _closeSearch,
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: EdgeInsets.zero.withDock(context),
            children: [
              if (!searchingNow && podcasts.isNotEmpty) ...[
                SectionHeader(l.podcastYours),
                SizedBox(
                  height: 176,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
                    itemCount: podcasts.length,
                    itemBuilder: (_, i) => _YourPodcast(podcasts[i]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap8, CcDims.margin, 0),
                  child: Text(l.podcastsNotice, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cc.textMuted)),
                ),
              ],
              ...searchingNow ? _results(l, subs) : _discover(l, subs),
              const SizedBox(height: CcDims.gap24),
            ],
          ),
        ),
      ),
    );
  }
}

/// A followed show in the top row.
class _YourPodcast extends StatelessWidget {
  const _YourPodcast(this.summary);

  final PodcastSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = summary.podcast;
    final theme = Theme.of(context).textTheme;
    return SizedBox(
      width: 104,
      child: InkWell(
        key: ValueKey('podcast-${p.id}'),
        borderRadius: BorderRadius.circular(CcDims.rGrid),
        onTap: () => ShellNav.open<void>(context, PodcastDetailScreen(podcastId: p.id)),
        child: Padding(
          padding: const EdgeInsets.all(CcDims.gap4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoverImage(coverKey: p.coverKey, size: 96, radius: CcDims.rGrid),
              const SizedBox(height: CcDims.gap4),
              Text(p.title, style: theme.labelLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (summary.toListen > 0)
                Text(
                  l.podcastToListen(summary.toListen),
                  style: theme.bodySmall?.copyWith(color: context.cc.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One show of the chart or of the search: cover, name, author, where it comes
/// from (search only) and «Iscriviti» / «Iscritto».
class PodcastListingRow extends StatelessWidget {
  const PodcastListingRow({
    super.key,
    required this.item,
    required this.subscribed,
    required this.busy,
    required this.onSubscribe,
    this.onOpen,
    this.rank,
    this.showOrigin = false,
  });

  final PodcastListing item;
  final bool subscribed, busy, showOrigin;
  final int? rank;
  final VoidCallback onSubscribe;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final origin = item.origin == PodcastOrigin.ytm ? l.searchSourceYoutubeMusic : l.podcastOriginApple;
    return InkWell(
      onTap: onOpen,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CcDims.margin, vertical: CcDims.gap8),
          child: Row(
            children: [
              if (rank != null)
                SizedBox(width: 28, child: Text('$rank', style: theme.titleSmall?.copyWith(color: cc.textMuted))),
              NetThumbnail(url: item.artworkUrl, width: 56, height: 56, icon: Icons.podcasts_rounded, radius: CcDims.rGrid),
              const SizedBox(width: CcDims.gap12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: theme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (item.author != null)
                      Text(item.author!, style: theme.bodySmall?.copyWith(color: cc.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (showOrigin)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: cc.surface2, borderRadius: BorderRadius.circular(4)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Text(origin, key: ValueKey('origin-${item.key}'), style: theme.labelSmall),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: CcDims.gap8),
              if (subscribed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: CcDims.gap8),
                  child: Text(l.podcastSubscribedLabel, key: ValueKey('subscribed-${item.key}'), style: theme.labelLarge?.copyWith(color: cc.textMuted)),
                )
              else
                Semantics(
                  button: true,
                  enabled: !busy,
                  label: l.podcastSubscribeTo(item.title),
                  excludeSemantics: true,
                  onTap: busy ? null : onSubscribe,
                  child: OutlinedButton(
                    key: ValueKey('subscribe-${item.key}'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: busy ? null : onSubscribe,
                    child: Text(l.podcastSubscribe),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
