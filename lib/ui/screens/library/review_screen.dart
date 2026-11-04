import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../data/repositories/review_queries.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/review_providers.dart';
import '../../../providers/second_opinion_providers.dart';
import '../../../providers/selection_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/async_body.dart';
import '../../widgets/confirm.dart' show showUndoSnack;
import '../../widgets/empty_state.dart';
import '../../widgets/selection_bar.dart';
import '../../widgets/track_row.dart';
import '../../widgets/track_row_selection.dart';
import '../enrich_preview_dialog.dart';
import '../../shell/shell_nav.dart';
import 'second_opinion_log_screen.dart';
import '../track_edit_dialog.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/show_msg.dart';
import '../../widgets/cc_app_bar.dart';

/// Library → «Da revisionare»: the songs online enrichment found nothing for,
/// or left without lyrics, cover or album/year/genre.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  static final _key = SelectionKey.review.key;

  /// null = «Tutti».
  ReviewReason? _filter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(reviewActionsProvider).secondOpinionOnOpen();
    });
  }

  String _label(ReviewReason? r) {
    final l = context.l10n;
    return switch (r) {
      null => l.reviewFilterAll,
      ReviewReason.nothingFound => l.reviewFilterNothingFound,
      ReviewReason.noLyrics => l.reviewFilterNoLyrics,
      ReviewReason.noCover => l.reviewFilterNoCover,
      ReviewReason.missingData => l.reviewFilterMissingData,
    };
  }

  Future<void> _retry(Set<int> ids) async {
    final l = context.l10n;
    final result = await ref.read(reviewActionsProvider).retry(ids);
    if (!mounted) return;
    ref.read(selectionProvider(_key).notifier).clear();
    showMsg(
      context,
      result == ReviewRetryResult.busy
          ? l.enrichBusy
          : l.reviewRetryStarted(ids.length),
    );
  }

  Future<void> _dismiss(Set<int> ids) async {
    final l = context.l10n;
    // Read now: the snackbar outlives this screen, whose `ref` will be dead.
    final actions = ref.read(reviewActionsProvider);
    await actions.dismiss(ids);
    if (!mounted) return;
    ref.read(selectionProvider(_key).notifier).clear();
    showUndoSnack(
      context,
      l.reviewDismissed(ids.length),
      () => actions.undismiss(ids),
    );
  }

  /// «Riprova» when nothing was found, else «Cerca» (the preview).
  void _primary(Track t, Set<ReviewReason> reasons) =>
      reasons.contains(ReviewReason.nothingFound)
      ? _retry({t.id})
      : showEnrichPreview(context, t);

  void _rowMenu(Track track) {
    final l = context.l10n;
    final page = context;
    showCcSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) {
        Widget tile(IconData icon, String label, VoidCallback run) => ListTile(
          leading: Icon(icon),
          title: Text(label),
          onTap: () {
            Navigator.of(sheet).pop();
            run();
          },
        );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(
                Icons.travel_explore_rounded,
                l.searchWeb,
                () => showEnrichPreview(page, track),
              ),
              tile(
                Icons.edit_outlined,
                l.editInfo,
                () => showTrackEditDialog(page, track),
              ),
              tile(
                Icons.refresh_rounded,
                l.reviewRetry,
                () => _retry({track.id}),
              ),
              tile(
                Icons.check_circle_outline_rounded,
                l.reviewDismiss,
                () => _dismiss({track.id}),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // The end of a run: say what it did (nothing when it changed nothing).
    ref.listen(secondOpinionJobProvider, (prev, next) {
      if (prev == null || !prev.running || next.running) return;
      final lines = [
        if (next.updated > 0) l.reviewSecondOpinionDone(next.updated),
        if (next.throttled) l.reviewSecondOpinionThrottled,
      ];
      if (lines.isNotEmpty) showMsg(context, lines.join('\n'));
    });
    final job = ref.watch(secondOpinionJobProvider);
    final async = ref.watch(reviewTracksProvider);
    final all = async.value ?? const <Track>[];
    final reasons = {for (final t in all) t.id: reviewReasons(t)};
    final tracks = [
      for (final t in all)
        if (_filter == null || reasons[t.id]!.contains(_filter)) t,
    ];
    final compact = ref.watch(settingsProvider).compactMode;
    final picked = ref.watch(selectionProvider(_key));
    final notifier = ref.read(selectionProvider(_key).notifier);
    final selection = RowSelection(
      listKey: _key,
      visibleIds: [for (final t in tracks) t.id],
    );
    final extent = trackRowExtentOf(context, compact);
    return SelectionScope(
      listKey: _key,
      visibleIds: selection.visibleIds,
      child: Scaffold(
        appBar: picked.active
            ? PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: SelectionBarFrame(
                  count: picked.count,
                  onClose: notifier.clear,
                  onSelectAll: () => notifier.selectAll(selection.visibleIds),
                  actions: [
                    TextButton.icon(
                      key: const ValueKey('review-retry'),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l.reviewRetry),
                      onPressed: () => _retry(picked.ids),
                    ),
                    TextButton.icon(
                      key: const ValueKey('review-dismiss'),
                      icon: const Icon(Icons.visibility_off_outlined),
                      label: Text(l.reviewDismiss),
                      onPressed: () => _dismiss(picked.ids),
                    ),
                  ],
                ),
              )
            : CcAppBar(
                title: l.reviewTitle,
                actions: [
                  if (job.log.isNotEmpty && !job.running)
                    TextButton(
                      key: const ValueKey('review-second-opinion-log'),
                      onPressed: () => ShellNav.open<void>(
                        context,
                        const SecondOpinionLogScreen(),
                      ),
                      child: Text(l.activityLog),
                    ),
                ],
              ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                if (job.running) _SecondOpinionBar(job: job),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      CcDims.margin,
                      0,
                      CcDims.margin,
                      CcDims.gap8,
                    ),
                    child: Text(
                      l.reviewHint,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: context.cc.textMuted),
                    ),
                  ),
                ),
                Expanded(
                  child: AsyncBody<List<Track>>(
                    value: async,
                    rowHeight: extent,
                    onRetry: () => ref.invalidate(reviewTracksProvider),
                    data: (_) => Column(
                      children: [
                        _FilterChips(
                          filter: _filter,
                          label: _label,
                          counts: {
                            null: all.length,
                            for (final r in ReviewReason.values)
                              r: reasons.values
                                  .where((s) => s.contains(r))
                                  .length,
                          },
                          onSelected: (r) {
                            notifier.clear();
                            setState(() => _filter = r);
                          },
                        ),
                        Expanded(
                          child: tracks.isEmpty
                              ? EmptyState(
                                  icon: Icons.fact_check_outlined,
                                  message: l.reviewEmpty,
                                )
                              : _ReviewList(
                                  tracks: tracks,
                                  reasons: reasons,
                                  label: _label,
                                  compact: compact,
                                  extent: extent,
                                  selection: selection,
                                  onRowMenu: _rowMenu,
                                  onPrimary: _primary,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondOpinionBar extends ConsumerWidget {
  const _SecondOpinionBar({required this.job});

  final SecondOpinionState job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CcDims.margin,
        CcDims.gap4,
        CcDims.margin,
        CcDims.gap8,
      ),
      child: Material(
        key: const ValueKey('review-second-opinion'),
        color: cc.surface2,
        borderRadius: BorderRadius.circular(CcDims.rCard),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => ShellNav.open<void>(
                        context,
                        const SecondOpinionLogScreen(),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CcDims.margin,
                          vertical: CcDims.gap12,
                        ),
                        child: Text(
                          l.reviewSecondOpinionProgress(job.done, job.total),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('review-second-opinion-stop'),
                    onPressed: ref
                        .read(secondOpinionJobProvider.notifier)
                        .cancel,
                    child: Text(l.reviewSecondOpinionStop),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: job.total > 0 ? job.done / job.total : null,
                minHeight: 3,
                backgroundColor: Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.filter,
    required this.label,
    required this.counts,
    required this.onSelected,
  });

  final ReviewReason? filter;
  final String Function(ReviewReason?) label;
  final Map<ReviewReason?, int> counts;
  final ValueChanged<ReviewReason?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // The chip grows with the text size; the row must follow it.
      height: MediaQuery.textScalerOf(context).scale(48),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
        children: [
          for (final r in <ReviewReason?>[null, ...ReviewReason.values])
            Padding(
              padding: const EdgeInsetsDirectional.only(end: CcDims.gap8),
              child: Center(
                child: ChoiceChip(
                  key: ValueKey('review-filter-${r?.name ?? 'all'}'),
                  label: Text('${label(r)} ${counts[r]}'),
                  selected: filter == r,
                  onSelected: (_) => onSelected(r),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewList extends StatelessWidget {
  const _ReviewList({
    required this.tracks,
    required this.reasons,
    required this.label,
    required this.compact,
    required this.extent,
    required this.selection,
    required this.onRowMenu,
    required this.onPrimary,
  });

  /// Left inset of the reasons line: under the title, past the cover.
  static const _reasonsInset = 72.0;

  final List<Track> tracks;
  final Map<int, Set<ReviewReason>> reasons;
  final String Function(ReviewReason?) label;
  final bool compact;
  final double extent;
  final RowSelection selection;
  final void Function(Track) onRowMenu;
  final void Function(Track, Set<ReviewReason>) onPrimary;

  static IconData _icon(ReviewReason r) => switch (r) {
    ReviewReason.nothingFound => Icons.search_off_rounded,
    ReviewReason.noLyrics => Icons.lyrics_outlined,
    ReviewReason.noCover => Icons.image_outlined,
    ReviewReason.missingData => Icons.label_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (_, i) {
        final t = tracks[i];
        final rs = reasons[t.id]!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: extent,
              child: LiveTrackRow(
                track: t,
                compact: compact,
                selection: selection,
                onTap: () => onRowMenu(t),
                onMore: () => onRowMenu(t),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _reasonsInset,
                0,
                CcDims.gap8,
                CcDims.gap8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      key: ValueKey('review-reasons-${t.id}'),
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final r in rs)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: cc.surface2,
                              borderRadius: BorderRadius.circular(CcDims.rCard),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_icon(r), size: 14, color: cc.accent),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      label(r),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: ValueKey('review-primary-${t.id}'),
                    onPressed: () => onPrimary(t, rs),
                    child: Text(
                      rs.contains(ReviewReason.nothingFound)
                          ? l.reviewRetry
                          : l.reviewSearch,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
