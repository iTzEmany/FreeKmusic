import '../../widgets/cc_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/activity_log_providers.dart';
import '../../../providers/activity_providers.dart';
import '../../../providers/duplicate_providers.dart';
import '../../../providers/enrich_completer_providers.dart';
import '../../../providers/import_providers.dart';
import '../../../providers/online_providers.dart';
import '../../../providers/podcast_providers.dart';
import '../../../providers/second_opinion_providers.dart';
import '../../../providers/share_hub.dart';
import '../../../providers/youtube_providers.dart';
import '../../../services/share/offers.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/confirm.dart';
import '../../widgets/format_utils.dart';
import '../../widgets/yt_dlp_outdated_banner.dart';
import '../import/import_detail_screen.dart';
import '../library/second_opinion_log_screen.dart';
import 'activity_log_screen.dart';

/// Everything that runs in the background, with Cancel where it exists.
class ActivitySheet extends ConsumerWidget {
  const ActivitySheet({super.key});

  static Future<void> show(BuildContext context) => showCcSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ActivitySheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final state = ref.watch(activityProvider);

    final log = ref.watch(activityLogProvider.select((e) => e.total));
    // In the Library tab, below the bar: the sheet closes on the way.
    void open(Widget page) => ShellNav.openInLibrary(context, ref, page);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CcDims.margin,
                0,
                CcDims.margin,
                CcDims.gap8,
              ),
              child: Text(l.activityTitle, style: theme.titleMedium),
            ),
            const YtDlpOutdatedBanner(),
            if (state.running.isEmpty)
              Padding(
                padding: const EdgeInsets.all(CcDims.margin),
                child: Text(
                  l.activityNone,
                  style: theme.bodyMedium?.copyWith(color: cc.textMuted),
                ),
              ),
            for (final a in state.running) _ActivityRow(item: a),
            // What ended goes to the Registro, not under the running ones.
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded),
              title: Text(l.activityLog),
              subtitle: Text(l.activityLogCount(log)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => open(const ActivityLogScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _cancelImport(
  BuildContext context,
  WidgetRef ref,
  ActivityItem a,
) async {
  final l = context.l10n;
  final ok = await showConfirm(
    context,
    title: l.csvImportCancelTitle,
    body: l.csvImportCancelBody,
    confirmLabel: l.csvImportCancelGo,
    destructive: true,
  );
  if (ok) {
    await ref.read(playlistImportServiceProvider).cancelChain(a.ref! as int);
  }
}

void _cancel(BuildContext context, WidgetRef ref, ActivityItem a) {
  switch (a.kind) {
    case ActivityKind.enrich:
      ref.read(enrichJobProvider.notifier).cancel();
    case ActivityKind.download:
      final r = a.ref;
      if (r is PodcastDownloadRef) {
        ref.read(podcastDownloadsProvider.notifier).cancel(r.episodeId);
      } else {
        ref.read(downloadsProvider.notifier).cancel(r! as int);
      }
    case ActivityKind.transfer:
      final o = a.ref! as OutgoingOffer;
      final hub = ref.read(shareHubProvider);
      ref
          .read(shareHubProvider.notifier)
          .cancelOutgoing(
            o,
            hub.peers.where((p) => p.id == o.toId).firstOrNull,
          );
    case ActivityKind.cleanup:
      ref.read(duplicateSearchProvider.notifier).cancel();
    case ActivityKind.secondOpinion:
      ref.read(secondOpinionJobProvider.notifier).cancel();
    case ActivityKind.import:
      _cancelImport(context, ref, a);
    case ActivityKind.enrichBackground:
      ref.read(enrichCompleterProvider.notifier).cancel();
    case ActivityKind.scan:
    case ActivityKind.releases:
    case ActivityKind.podcastRefresh:
    case ActivityKind.radio:
    case ActivityKind.genreReread:
    case ActivityKind.artistCountries:
    case ActivityKind.ytDlp:
      break;
  }
}

class _ActivityRow extends ConsumerWidget {
  const _ActivityRow({required this.item});

  final ActivityItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = item;
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    void open(Widget page) => ShellNav.openInLibrary(context, ref, page);

    return InkWell(
      // An import opens the list of its songs, the second opinion its log.
      onTap: switch (a.kind) {
        ActivityKind.import => () => open(
          ImportDetailScreen(importId: a.ref! as int),
        ),
        ActivityKind.secondOpinion => () => open(
          const SecondOpinionLogScreen(),
        ),
        _ => null,
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CcDims.margin,
          vertical: CcDims.gap8,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (a.kind == ActivityKind.import)
                    // Just the name and the songs saved so far; the rest is
                    // in the import's own screen.
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.name ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.bodyLarge,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${a.done}/${a.total}',
                          style: theme.bodyMedium?.copyWith(
                            color: cc.textMuted,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      activityTitle(l, a),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyLarge,
                    ),
                  if (a.running) ...[
                    if (!a.waiting) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: a.progress,
                        // A bare "16" is read otherwise.
                        semanticsValue: a.progress == null
                            ? null
                            : '${(a.progress! * 100).round()} %',
                      ),
                    ],
                  ] else
                    Text(
                      a.failed ? l.offerFailed : l.offerDone,
                      style: theme.bodyMedium?.copyWith(
                        color: a.failed ? cc.error : cc.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (a.kind == ActivityKind.import && a.running)
              IconButton(
                tooltip: a.paused ? l.csvImportResume : l.csvImportPause,
                icon: Icon(
                  a.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
                onPressed: () {
                  final svc = ref.read(playlistImportServiceProvider);
                  final id = a.ref! as int;
                  a.paused ? svc.resumeChain(id) : svc.pauseChain(id);
                },
              ),
            if (a.kind == ActivityKind.enrichBackground)
              IconButton(
                tooltip: a.paused ? l.csvImportResume : l.csvImportPause,
                icon: Icon(
                  a.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
                onPressed: () {
                  final c = ref.read(enrichCompleterProvider.notifier);
                  a.paused ? c.resume() : c.pause();
                },
              ),
            if (a.cancellable)
              IconButton(
                tooltip: l.cancel,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => _cancel(context, ref, a),
              ),
          ],
        ),
      ),
    );
  }
}

/// The line of the Activity centre (and of the Registro) for [a].
String activityTitle(AppLocalizations l, ActivityItem a) => switch (a.kind) {
  ActivityKind.scan =>
    a.total > 0 ? l.activityScan(a.done, a.total) : l.activityScanIdle,
  ActivityKind.enrich => l.activityEnrich(a.done, a.total),
  ActivityKind.download =>
    a.retryDelaySec == null
        ? l.activityDownload(a.name ?? '')
        : l.activityDownloadRetry(
            a.name ?? '',
            a.retryDelaySec!,
            a.done,
            a.total,
          ),
  ActivityKind.transfer => l.activityTransfer(a.name ?? '', a.total),
  ActivityKind.cleanup => l.activityCleanup(a.done, a.total),
  ActivityKind.releases => l.activityReleases,
  ActivityKind.secondOpinion => l.activitySecondOpinion(a.done, a.total),
  ActivityKind.podcastRefresh => l.activityPodcastRefresh,
  ActivityKind.radio => l.activityRadio,
  ActivityKind.ytDlp => l.activityYtDlp,
  ActivityKind.genreReread => l.logGenres,
  ActivityKind.artistCountries => l.logCountries,
  ActivityKind.enrichBackground =>
    a.waiting
        ? l.activityEnrichWaiting
        : l.activityEnrichBackground(a.done, a.total),
  ActivityKind.import =>
    a.paused
        ? l.activityImportPaused(a.name ?? '', a.done, a.total)
        : l.activityImport(a.name ?? '', a.done, a.total) +
              (a.eta == null ? '' : ', ${etaLabel(l, a.eta!)}'),
};
