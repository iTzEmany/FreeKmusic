import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/activity_log_providers.dart';
import '../../../providers/activity_providers.dart';
import '../../../services/import/playlist_import_service.dart';
import '../../../services/recognition/track_identity.dart' show RecogSource;
import '../../theme/tokens.dart';
import '../../widgets/empty_state.dart';
import '../library/second_opinion_log_screen.dart';
import '../../shell/shell_nav.dart';
import 'activity_sheet.dart';
import 'enrich_round_screen.dart';
import '../../widgets/cc_app_bar.dart';

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
/// other jobs), newest first, with the time and how it went.
class ActivityLogScreen extends ConsumerWidget {
  const ActivityLogScreen({super.key});

  String _outcome(AppLocalizations l, LogEntry e) => switch (e.event) {
    null =>
      e.failed
          ? l.offerFailed
          : e.stopped
          ? l.activityStopped
          : l.offerDone,
    ImportEventKind.completed => l.offerDone,
    ImportEventKind.planned => l.csvImportPlanned,
    ImportEventKind.rateLimited => l.ytErrRateLimited,
    ImportEventKind.network => l.ytErrNetwork,
    ImportEventKind.toolMissing => l.ytErrToolMissing,
    ImportEventKind.toolOutdated => l.ytErrToolOutdated,
    ImportEventKind.failing => l.csvImportFailing,
  };

  IconData _icon(LogEntry e) {
    if (e.failed) return Icons.error_outline_rounded;
    return switch (e.item?.kind) {
      ActivityKind.transfer => Icons.send_rounded,
      ActivityKind.secondOpinion => Icons.fact_check_outlined,
      ActivityKind.download => Icons.download_done_rounded,
      null => Icons.playlist_add_check_rounded,
      _ => Icons.task_alt_rounded,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final log = ref.watch(activityLogProvider);
    final entries = log.entries;
    final time = DateFormat.Hm(Localizations.localeOf(context).toLanguageTag());
    return Scaffold(
      appBar: CcAppBar(
        title: l.activityLog,
        actions: [
          if (entries.isNotEmpty)
            TextButton(
              onPressed: ref.read(activityLogProvider.notifier).clear,
              child: Text(l.activityClear),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: entries.isEmpty
              ? EmptyState(
                  icon: Icons.receipt_long_rounded,
                  message: l.activityLogEmpty,
                )
              : ListView.builder(
                  itemExtent: 64,
                  itemCount: entries.length,
                  itemBuilder: (_, i) {
                    if (i == entries.length - 1 && log.hasMore) {
                      Future.microtask(
                        ref.read(activityLogProvider.notifier).loadMore,
                      );
                    }
                    final e = entries[i];
                    final item = e.item;
                    final src = recogSourcesLine(l, e.detail);
                    return ListTile(
                      onTap: switch (item?.kind) {
                        ActivityKind.secondOpinion => () => ShellNav.open<void>(
                          context,
                          const SecondOpinionLogScreen(),
                        ),
                        ActivityKind.enrichBackground => () =>
                            ShellNav.open<void>(
                              context,
                              EnrichRoundScreen(entry: e),
                            ),
                        _ => null,
                      },
                      leading: Icon(
                        _icon(e),
                        color: e.failed ? cc.error : cc.accentSoft,
                      ),
                      title: Text(
                        item != null
                            ? (item.kind == ActivityKind.scan && item.total == 0
                                  ? l.activityScanEnded
                                  : item.kind == ActivityKind.enrich && item.failed
                                  ? l.enrichInterrupted(
                                      e.detail?['updated'] as int? ?? 0,
                                      e.detail?['notFound'] as int? ?? 0,
                                    )
                                  : item.kind == ActivityKind.enrichBackground
                                  ? (e.detail?['noAnswer'] == true)
                                        ? l.logEnrichStopped
                                        : item.failed && item.done == 0 && item.total == 0
                                        ? l.logEnrichFailed
                                        : l.logEnrichRound(item.done, item.total)
                                  : activityTitle(l, item))
                            : l.logImport(e.importName ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${time.format(e.at)}, ${_outcome(l, e)}${src == null ? '' : ', $src'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodyMedium?.copyWith(
                          color: e.failed ? cc.error : null,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
