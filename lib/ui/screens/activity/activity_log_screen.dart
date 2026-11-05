import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/activity_log_providers.dart';
import '../../../data/db/app_database.dart' show Track;
import '../../../providers/activity_providers.dart' show ActivityKind;
import '../../../providers/recognition_providers.dart';
import '../../../services/recognition/track_identity.dart' show Recognition, RecogSource;
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/cc_tile.dart';
import '../../widgets/confirm.dart';
import '../../widgets/empty_state.dart';
import '../library/second_opinion_log_screen.dart';
import '../now_playing/proposal_card.dart' show identLabel;
import 'activity_log_entry.dart';
import 'enrich_round_screen.dart';
import 'proposals_screen.dart';

/// «Recognized: AcoustID 3, text 5» from the `sources` of a round's `detail`.
@visibleForTesting
String? recogSourcesLine(AppLocalizations l, Map<String, Object?>? detail) {
  final raw = detail?['sources'];
  if (raw is! Map) return null;
  final shown = [
    for (final s in RecogSource.values)
      if (raw[s.name] case final int n when n > 0)
        '${switch (s) {
          RecogSource.tags => l.recogSrcTags,
          RecogSource.ytid => l.recogSrcVideo,
          RecogSource.text => l.recogSrcText,
          RecogSource.acoustid => 'AcoustID',
          RecogSource.ytm => 'YouTube Music',
        }} $n',
  ];
  return shown.isEmpty ? null : l.logRecogSources(shown.join(', '));
}

/// What ended in the background (downloads, transfers, imports, scans and
/// other jobs), newest first, by day, with filters. On a wide window the line
/// picked is shown in a side panel.
class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  LogFilter _filter = LogFilter.all;
  /// Days whose downloads are shown one by one (the day is a key that outlives a new download).
  final _open = <DateTime>{};
  int? _selectedKey;

  /// A line keeps its time to the millisecond (the database's) across reloads.
  static int _key(LogEntry e) => e.at.millisecondsSinceEpoch;

  /// Wide: the line picked if it is still shown, else the first one shown.
  LogEntry? _selected(List<LogDay> days) {
    final shown = [for (final d in days) for (final r in d.rows) r.entry];
    return shown.firstWhereOrNull((e) => _key(e) == _selectedKey) ?? shown.firstOrNull;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(ref.read(activityLogProvider.notifier).reload);
  }

  /// Where a line leads on its own, if it does.
  VoidCallback? _opener(LogEntry e) => switch (e.item?.kind) {
    ActivityKind.secondOpinion => () => ShellNav.open<void>(context, const SecondOpinionLogScreen()),
    ActivityKind.enrichBackground => () => ShellNav.open<void>(context, EnrichRoundScreen(entry: e)),
    _ => null,
  };

  void _tap(LogRow row, DateTime day, bool wide) {
    final e = row.entry;
    if (row.group.isNotEmpty) {
      setState(() => _open.contains(day) ? _open.remove(day) : _open.add(day));
    } else if (wide) {
      setState(() => _selectedKey = _key(e));
    } else if (_opener(e) case final open?) {
      open();
    } else {
      showCcSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => SafeArea(child: LogDetail(e, sources: recogSourcesLine(context.l10n, e.detail))),
      );
    }
  }

  Future<void> _clear() async {
    final l = context.l10n;
    final ok = await showConfirm(
      context,
      title: l.logClearTitle,
      body: l.logClearBody,
      confirmLabel: l.logClearConfirm,
      destructive: true,
    );
    if (!ok || !mounted) return;
    await ref.read(activityLogProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final wide = MediaQuery.sizeOf(context).width >= CcDims.wideBreakpoint;
    final log = ref.watch(activityLogProvider);
    final days = groupLog(log.entries, _filter);
    // A filter may show nothing of the first page: read on until it does.
    if (days.isEmpty && log.entries.isNotEmpty && log.hasMore) {
      Future.microtask(ref.read(activityLogProvider.notifier).loadMore);
    }
    final list = _list(context, log, days, wide, wide ? _selected(days) : null);
    final sel = wide ? _selected(days) : null;
    return Scaffold(
      appBar: CcAppBar(
        title: l.activityLog,
        actions: [
          if (log.entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: MaterialLocalizations.of(context).showMenuTooltip,
              onPressed: () => showCcActionSheet<void>(
                context: context,
                groups: [
                  [CcAction(icon: Icons.delete_sweep_outlined, label: l.logClearMenu, destructive: true, onTap: _clear)],
                ],
              ),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 1240 : 960),
          child: wide
              ? Row(
                  children: [
                    Expanded(child: list),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 400,
                      child: sel == null
                          ? EmptyState(icon: Icons.receipt_long_rounded, message: l.logPickEntry)
                          : LogDetail(
                              sel,
                              sources: recogSourcesLine(l, sel.detail),
                              onOpen: _opener(sel),
                            ),
                    ),
                  ],
                )
              : list,
        ),
      ),
    );
  }

  Widget _list(BuildContext context, ActivityLogState log, List<LogDay> days, bool wide, LogEntry? sel) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs());
    final proposals = ref.watch(proposalsProvider).value ?? const [];
    final showPending = proposals.isNotEmpty && (_filter == LogFilter.all || _filter == LogFilter.correction);
    return CustomScrollView(
      slivers: [
        if (log.entries.isNotEmpty)
          SliverToBoxAdapter(
            child: _Filters(
              counts: log.counts,
              selected: _filter,
              onSelected: (f) => setState(() => _filter = f),
            ),
          ),
        if (showPending) SliverToBoxAdapter(child: _Pending(proposals)),
        if (days.isEmpty)
          SliverToBoxAdapter(
            child: log.entries.isEmpty
                ? EmptyState(icon: Icons.receipt_long_rounded, message: l.activityLogEmpty)
                : Padding(
                    padding: const EdgeInsets.all(CcDims.margin),
                    child: Text(l.logNoMatch, style: theme.bodyMedium),
                  ),
          ),
        for (final (di, day) in days.indexed)
          SliverMainAxisGroup(
            slivers: [
              PinnedHeaderSliver(child: _DayHeader(logDayLabel(l, locale, day.day, now), day)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
                sliver: SliverList.separated(
                  itemCount: day.rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    if (di == days.length - 1 && i == day.rows.length - 1 && log.hasMore) {
                      Future.microtask(ref.read(activityLogProvider.notifier).loadMore);
                    }
                    final row = day.rows[i];
                    return LogEntryCard(
                      row: row,
                      expanded: _open.contains(day.day),
                      selected: wide && row.group.isEmpty ? identical(sel, row.entry) : null,
                      onTap: () => _tap(row, day.day, wide),
                    );
                  },
                ),
              ),
            ],
          ),
        if (log.entries.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(CcDims.margin),
              child: Text(l.logRetention, style: theme.bodySmall?.copyWith(color: context.cc.textMuted)),
            ),
          ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label, this.day);

  final String label;
  final LogDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final n = day.rows.fold(0, (a, r) => a + (r.group.isEmpty ? 1 : r.group.length));
    return ColoredBox(
      color: context.cc.bg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(CcDims.margin, 12, CcDims.margin, 6),
        child: Row(
          children: [
            Expanded(
              child: Semantics(header: true, child: Text(label, style: theme.titleSmall)),
            ),
            Text(
              context.l10n.logDayCount(n),
              style: theme.bodySmall?.copyWith(color: context.cc.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.counts, required this.selected, required this.onSelected});

  final Map<LogFilter, int> counts;
  final LogFilter selected;
  final ValueChanged<LogFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    String name(LogFilter f) => switch (f) {
      LogFilter.all => l.logFilterAll,
      LogFilter.download => l.logFilterDownload,
      LogFilter.library => l.logFilterLibrary,
      LogFilter.enrich => l.logFilterEnrich,
      LogFilter.correction => l.logFilterCorrections,
      LogFilter.errors => l.logFilterErrors,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: CcDims.margin, vertical: 8),
      child: Row(
        children: [
          for (final f in LogFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: f == LogFilter.errors ? const Icon(Icons.error_outline_rounded, size: 18) : null,
                label: Text('${name(f)} ${counts[f]}'),
                selected: selected == f,
                onSelected: (_) => onSelected(f),
              ),
            ),
        ],
      ),
    );
  }
}

/// «Da confermare (N)»: two of the proposals and the way to the rest.
class _Pending extends StatelessWidget {
  const _Pending(this.proposals);

  final List<({Track track, Recognition rec})> proposals;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final title = l.recogToConfirm(proposals.length);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CcDims.margin, vertical: 4),
      child: CcTile(
        key: const ValueKey('to-confirm'),
        semanticsLabel: '$title. ${l.logPendingSub}',
        onTap: () => ShellNav.open<void>(context, const ProposalsScreen()),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rule_rounded, color: cc.accentSoft),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.titleSmall),
                        Text(l.logPendingSub, style: theme.bodyMedium?.copyWith(color: cc.textMuted)),
                      ],
                    ),
                  ),
                  Text(l.logPendingReview, style: theme.labelLarge?.copyWith(color: cc.accentSoft)),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              for (final p in proposals.take(2))
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        identLabel(l, p.track.title, p.track.artist),
                        style: theme.bodyMedium?.copyWith(
                          color: cc.textMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      Text(
                        identLabel(l, p.rec.identity!.title, p.rec.identity!.artist),
                        style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              if (proposals.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 36),
                  child: Text(l.logPendingMore(proposals.length - 2), style: theme.bodySmall),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
