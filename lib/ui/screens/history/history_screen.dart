import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/repositories/play_history_repository.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/track_ops.dart';
import '../../../providers/history_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../theme/app_theme.dart';
import '../../shell/shell_nav.dart';
import '../../widgets/confirm.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/track_row.dart';
import '../settings/settings_screen.dart';
import '../../widgets/show_msg.dart';
import '../../widgets/async_body.dart';
import '../../widgets/cc_app_bar.dart';
import '../../theme/tokens.dart';

const _block = 200;
const _headerExtent = 56.0;

/// What was listened to, newest first, grouped by day. Listens come in blocks
/// of 200 as the list is scrolled.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _scroll = ScrollController();
  int _limit = _block;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _more();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Asks for the next block, but only when the last one came back full.
  void _more() {
    final shown = ref.read(historyProvider(_limit)).value?.length ?? 0;
    if (shown >= _limit) setState(() => _limit += _block);
  }

  String _dayLabel(BuildContext context, DateTime day) {
    final l = context.l10n;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return l.historyToday;
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return l.historyYesterday;
    }
    return DateFormat.yMMMMEEEEd(Localizations.localeOf(context).toString())
        .format(day);
  }

  Future<void> _clear() async {
    final l = context.l10n;
    final ok = await showConfirm(
      context,
      title: l.historyClearTitle,
      body: l.historyClearBody,
      confirmLabel: l.historyClear,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(trackOpsProvider).clearHistory();
    if (!mounted) return;
    showMsg(context, l.historyCleared);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final history = ref.watch(historyProvider(_limit));
    final on = ref.watch(settingsProvider.select((s) => s.recordHistory));
    final compact = ref.watch(settingsProvider).compactMode;
    final ctrl = ref.read(playerControllerProvider);
    final extent = trackRowExtentOf(context, compact);
    final locale = Localizations.localeOf(context).toString();
    final time = DateFormat.Hm(locale);
    return Scaffold(
      appBar: CcAppBar(
        title: l.historyTitle,
        actions: [
          IconButton(
            tooltip: l.historyClear,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: (history.value ?? const []).isEmpty ? null : _clear,
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: AsyncBody(
            value: history,
            onRetry: () => ref.invalidate(historyProvider(_limit)),
            data: (entries) {
              if (entries.isEmpty) {
                return EmptyState(
                  icon: Icons.history_rounded,
                  message: on ? l.historyEmpty : l.historyOff,
                  actionLabel: on ? null : l.openPlaybackSettings,
                  onAction: on
                      ? null
                      : () => ShellNav.open<void>(
                          context,
                          Scaffold(
                            appBar: CcAppBar(title: l.navSettings),
                            body: const SettingsScreen(
                              initial: SettingsPage.playback,
                            ),
                          ),
                        ),
                );
              }
              final items = groupHistoryByDay(entries);
              final tracks = [for (final e in entries) e.track];
              // Position of each entry among the tracks (headers do not count).
              var next = 0;
              final trackIndex = <int, int>{};
              for (var i = 0; i < items.length; i++) {
                if (items[i] is HistoryEntry) trackIndex[i] = next++;
              }
              return ListView.builder(
                controller: _scroll,
                padding: EdgeInsets.zero.withDock(context),
                itemCount: items.length,
                itemExtentBuilder: (i, _) =>
                    items[i] is HistoryEntry ? extent : _headerExtent,
                itemBuilder: (_, i) {
                  final it = items[i];
                  if (it is DateTime) {
                    return SectionHeader(_dayLabel(context, it));
                  }
                  final e = it as HistoryEntry;
                  return LiveTrackRow(
                    track: e.track,
                    compact: compact,
                    subtitleSuffix: time.format(e.at),
                    onTap: () => ctrl.playFromList(
                      tracks,
                      trackIndex[i]!,
                      context: const PlayContext(PlayContextKind.library),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
