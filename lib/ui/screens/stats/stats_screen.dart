import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/repositories/stats_queries.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/history_providers.dart';
import '../../theme/tokens.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/segmented_blocks.dart';
import 'stats_charts.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/async_body.dart';

/// «3 h 20 min», or «45 min» under an hour.
String formatListened(AppLocalizations l, int ms) {
  final minutes = (ms / 60000).round();
  if (minutes < 60) return l.durationMinutes(minutes);
  return l.statsHoursMinutes(minutes ~/ 60, minutes % 60);
}

/// What was listened to in a month or a year: totals, the bars, the favourite
/// hour and the most played tracks, artists and albums.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key, this.now});

  /// For tests: the date that counts as today.
  final DateTime? now;

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  late DateTime _now;
  late StatsPeriod _period;

  /// The last month looked at, so Anno then Mese comes back to it (D-363).
  late int _lastMonth;

  /// The last loaded stats, shown dimmed while the next period loads.
  PeriodStats? _shown;

  @override
  void initState() {
    super.initState();
    _now = widget.now ?? DateTime.now();
    _period = StatsPeriod.containing(_now, year: false);
    _lastMonth = _now.month;
  }

  void _go(StatsPeriod p) => setState(() {
    _period = p;
    if (!p.isYear) _lastMonth = p.start.month;
  });

  void _setYear(bool year) {
    if (year) return _go(StatsPeriod.year(_period.start.year));
    var m = StatsPeriod.month(_period.start.year, _lastMonth);
    if (!m.start.isBefore(_now)) m = StatsPeriod.containing(_now, year: false);
    _go(m);
  }

  bool get _canGoNext => _period.next.start.isBefore(_now);

  String _title(String locale) => _period.isYear
      ? '${_period.start.year}'
      : DateFormat.yMMMM(locale).format(_period.start);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final locale = Localizations.localeOf(context).toString();
    final stats = ref.watch(
      periodStatsProvider((
        year: _period.isYear,
        y: _period.start.year,
        m: _period.start.month,
      )),
    );
    final cur = stats.value;
    if (cur != null && !cur.isEmpty) _shown = cur;
    // While the next period loads, the last one stays, dimmed and inert.
    final stale = cur == null && stats.isLoading ? _shown : null;
    return Scaffold(
      appBar: CcAppBar(title: l.statsTitle),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CcDims.margin,
                  CcDims.gap4,
                  CcDims.margin,
                  0,
                ),
                child: SegmentedBlocks<bool>(
                  items: [
                    BlockItem(
                      value: false,
                      icon: Icons.calendar_view_month_rounded,
                      label: l.statsMonth,
                    ),
                    BlockItem(
                      value: true,
                      icon: Icons.date_range_rounded,
                      label: l.statsYear,
                    ),
                  ],
                  selected: _period.isYear,
                  onChanged: _setYear,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: l.statsPrevious,
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => _go(_period.previous),
                  ),
                  Flexible(
                    child: Text(
                      _title(locale),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: l.statsNext,
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: _canGoNext
                        ? () => _go(_period.next)
                        : null,
                  ),
                ],
              ),
              Expanded(
                child: stale != null || (cur != null && !cur.isEmpty)
                    ? Opacity(
                        opacity: stale != null ? 0.5 : 1,
                        child: IgnorePointer(
                          ignoring: stale != null,
                          child: ExcludeSemantics(
                            excluding: stale != null,
                            child: _Body(
                              stats: stale ?? cur!,
                              locale: locale,
                              cc: cc,
                              now: _now,
                            ),
                          ),
                        ),
                      )
                    : AsyncBody(
                        value: stats,
                        onRetry: () => ref.invalidate(periodStatsProvider),
                        isEmpty: (s) => s.isEmpty,
                        empty: EmptyState(
                          icon: Icons.bar_chart_rounded,
                          message: l.statsEmpty,
                        ),
                        loading: const Padding(
                          padding: EdgeInsets.all(CcDims.margin),
                          child: Skeleton.bars(),
                        ),
                        data: (s) => const SizedBox.shrink(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.stats,
    required this.locale,
    required this.cc,
    required this.now,
  });

  final PeriodStats stats;
  final String locale;
  final CcColors cc;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final p = stats.period;
    final starts = p.bucketStarts;
    final axis = [
      for (final d in starts)
        p.isYear
            ? DateFormat.MMMM(locale).format(d).substring(0, 1).toUpperCase()
            : '${d.day}',
    ];
    // «12 mar, 2 h 14 min» / «Marzo, 41 h»; a bar after today is not selectable.
    final values = [
      for (var i = 0; i < starts.length; i++)
        if (!starts[i].isBefore(now))
          null
        else
          l.statsBarValue(
            p.isYear
                ? toBeginningOfSentenceCase(DateFormat.MMMM(locale).format(starts[i]))
                : DateFormat.MMMd(locale).format(starts[i]),
            formatListened(l, stats.msPerBucket[i]),
          ),
    ];

    final fav = stats.favouriteHour;
    return ListView(
      padding: EdgeInsets.zero.withDock(context),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CcDims.margin,
            CcDims.gap16,
            CcDims.margin,
            CcDims.gap4,
          ),
          child: Text(
            formatListened(l, stats.playedMs),
            style: theme.displaySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CcDims.margin,
            0,
            CcDims.margin,
            CcDims.gap16,
          ),
          child: Text(
            '${l.statsPlays(stats.plays)}, ${l.statsDistinct(stats.distinctTracks)}',
            style: theme.bodyMedium?.copyWith(color: cc.textMuted),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
          child: StatsBars(
            key: ValueKey((p.isYear, p.start)),
            values: stats.msPerBucket,
            axisOf: axis,
            steps: p.isYear ? const [1, 2, 3, 4, 6] : const [1, 5, 10],
            // Months: Jan, Mar…; days: 1, 5, 10… (the first always).
            showAxis: (i, n) => p.isYear ? i % n == 0 : n == 1 || i == 0 || (i + 1) % n == 0,
            valueOf: values,
            semanticsLabel:
                '${formatListened(l, stats.playedMs)}, ${l.statsPlays(stats.plays)}',
          ),
        ),
        const SizedBox(height: 8),
        if (fav != null)
          _Fact(
            l.statsFavouriteHour,
            '${fav.toString().padLeft(2, '0')}:00–${((fav + 1) % 24).toString().padLeft(2, '0')}:00',
          ),
        if (stats.firstTitle != null && stats.firstAt != null)
          _Fact(
            l.statsFirstListen,
            l.statsFirstValue(
              stats.firstTitle!,
              DateFormat.MMMd(locale).format(stats.firstAt!),
            ),
          ),
        _Ranking(l.statsTopTracks, stats.topTracks, cover: true),
        _Ranking(l.statsTopArtists, stats.topArtists),
        _Ranking(l.statsTopAlbums, stats.topAlbums, cover: true),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.title, this.value);

  final String title, value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CcDims.margin,
        vertical: 6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.bodyMedium?.copyWith(color: context.cc.textMuted),
          ),
          Text(value, style: theme.bodyLarge),
        ],
      ),
    );
  }
}

class _Ranking extends StatelessWidget {
  const _Ranking(this.title, this.items, {this.cover = false});

  final String title;
  final List<RankedItem> items;
  final bool cover;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title),
        for (var i = 0; i < items.length; i++)
          // minHeight, so two lines at a large text size do not overflow.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: theme.titleMedium?.copyWith(color: cc.textMuted),
                    ),
                  ),
                ),
                if (cover) ...[
                  CoverImage(
                    coverKey: items[i].coverKey,
                    size: 40,
                    radius: CcDims.rList,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].name ?? l.unknownAlbum,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodyLarge,
                      ),
                      Text(
                        [
                          if (items[i].artist != null) items[i].artist!,
                          l.statsPlays(items[i].plays),
                        ].join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: CcDims.margin),
              ],
            ),
          ),
      ],
    );
  }
}
