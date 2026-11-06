import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/platform.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/activity_log_providers.dart';
import '../../../providers/activity_providers.dart';
import '../../../providers/online_providers.dart' show trackCorrectionsProvider;
import '../../../services/import/playlist_import_service.dart';
import '../../../services/tags/tag_writer.dart' show TagWriteReason;
import '../../theme/tokens.dart';
import '../../widgets/tag_write_ui.dart' show tagReasonText;
import '../../widgets/cc_tile.dart';
import '../import/import_labels.dart' show importStopText;
import '../../widgets/action_button.dart';
import '../now_playing/proposal_card.dart' show identLabel;

/// What a line of the Registro says, in words for a person: a short title, one
/// line of detail, numbers as chips and, for a failure, the steps to take.
class LogText {
  const LogText(
    this.title,
    this.detail, {
    this.chips = const [],
    this.how = const [],
    this.tech,
  });

  final String title, detail;
  final List<String> chips;
  final List<String> how;

  /// The exact message (it may name a command), only in the detail.
  final String? tech;
}

LogText logText(AppLocalizations l, LogEntry e) {
  final i = e.item;
  if (e.revertible) return LogText(l.logCorrectionTitle, '');
  if (e.correction != null) {
    final why = TagWriteReason.values.asNameMap()[e.file];
    return LogText(
      l.logFileTitle,
      e.correction!.name,
      how: switch (why) {
        TagWriteReason.unsupported => const [],
        TagWriteReason.notFound => [l.logHowFileMissing],
        TagWriteReason.readOnly => [l.logHowFileReadOnly],
        _ => [l.logHowFileRetry],
      },
      tech: why == null ? null : tagReasonText(l, why),
    );
  }
  if (i == null) return _importText(l, e);
  final d = e.detail;
  int n(String k) => d?[k] as int? ?? 0;
  final name = i.name ?? '';
  final songs = [if (i.total > 0) l.logChipSongs(i.total)];
  // A job with nothing special to say: its title and detail, or a plain failure.
  LogText plain(String title, String sub, [List<String> chips = const []]) =>
      e.failed
      ? LogText(l.logTaskFailed, title)
      : LogText(title, sub, chips: chips);
  return switch (i.kind) {
    ActivityKind.download => LogText(e.failed ? l.logDlFailed : l.logDlDone, name),
    ActivityKind.transfer =>
      e.failed
          ? LogText(l.logTransferFailed, name)
          : LogText(l.logTransferDone, name, chips: songs),
    ActivityKind.scan =>
      e.failed
          ? LogText(l.logScanFailed, l.logFailedSub)
          : e.stopped
          ? LogText(l.logScanStopped, l.logStoppedSub, chips: [l.logChipSongsOf(i.done, i.total)])
          : LogText(l.logScanDone, i.total > 0 ? l.logScanDoneSub : '', chips: songs),
    ActivityKind.enrich =>
      e.failed
          ? LogText(
              l.logEnrichInterrupted,
              l.logEnrichInterruptedSub,
              chips: [l.logChipUpdated(n('updated')), l.logChipNotFound(n('notFound'))],
            )
          : LogText(
              e.stopped ? l.logEnrichStopped : l.logEnrichDone,
              e.stopped ? l.logStoppedSub : '',
              chips: [if (i.done > 0) l.logChipSongs(i.done)],
            ),
    ActivityKind.enrichBackground =>
      e.noAnswer
          ? LogText(l.logBgStopped, l.logBgStoppedSub)
          : e.failed && i.done == 0 && i.total == 0
          ? LogText(l.logBgFailed, l.logBgFailedSub)
          : LogText(
              l.logBgDone,
              l.logBgDoneSub,
              chips: [
                if (i.done > 0) l.logChipSongs(i.done),
                if (i.total > 0) l.logChipNoResult(i.total), // total counts the songs asked in vain
              ],
            ),
    ActivityKind.secondOpinion =>
      e.failed
          ? LogText(l.logSecondOpinionFailed, l.logWhyRate)
          : LogText(l.logSecondOpinion, l.logSecondOpinionSub, chips: songs),
    ActivityKind.cleanup => plain(l.logCleanup, l.logCleanupSub, songs),
    ActivityKind.genreReread => e.stopped
        ? LogText(l.logGenres, l.logStoppedSub, chips: songs)
        : plain(l.logGenres, l.logGenresSub, songs),
    ActivityKind.releases => plain(l.logReleases, l.logReleasesSub),
    ActivityKind.podcastRefresh => plain(l.logPodcasts, ''),
    ActivityKind.radio => plain(l.logRadio, ''),
    ActivityKind.import =>
      e.failed
          ? LogText(l.logImportFailed, name)
          : LogText(l.logImportDone(name), '', chips: songs),
  };
}

LogText _importText(AppLocalizations l, LogEntry e) {
  final name = e.importName ?? '';
  final kind = e.event!;
  final resume = l.logHowResume(l.csvImportResume);
  // The update button exists on desktop only (Android updates yt-dlp by itself).
  final update = [
    if (isDesktop) ...[l.logHowSettings(l.navSettings, l.settingsPageOnline), l.logHowUpdate(l.ytDlpUpdate)],
  ];
  LogText fail(String title, String why, List<String> how) =>
      LogText(title, why, how: how, tech: importStopText(l, kind));
  return switch (kind) {
    ImportEventKind.completed => LogText(l.logImportDone(name), ''),
    ImportEventKind.planned => LogText(l.logImportReady(name), l.csvImportPlanned),
    ImportEventKind.rateLimited => fail(l.logImportRate, l.logWhyRate, [l.logHowWait, resume]),
    ImportEventKind.network => fail(l.logImportFailed, l.logWhyNetwork, [l.logHowOnline, resume]),
    ImportEventKind.toolMissing => fail(l.logImportFailed, l.logWhyToolMissing, [...update, resume]),
    ImportEventKind.toolOutdated => fail(l.logImportFailed, l.logWhyToolOld, [...update, resume]),
    ImportEventKind.failing => fail(l.logImportPaused, l.logWhyFailing, [l.logHowOnline, ...update, resume]),
  };
}

IconData logIcon(LogFilter category) => switch (category) {
  LogFilter.download => Icons.download_done_rounded,
  LogFilter.enrich => Icons.auto_fix_high_rounded,
  LogFilter.correction => Icons.edit_note_rounded,
  _ => Icons.library_music_outlined,
};

String logDayLabel(AppLocalizations l, String locale, DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) return l.logToday;
  if (day == DateTime(today.year, today.month, today.day - 1)) return l.logYesterday;
  return DateFormat.MMMEd(locale).format(day);
}

/// A small label: the number, the status.
class LogChip extends StatelessWidget {
  const LogChip(this.text, {super.key, this.icon, this.color});

  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final c = color ?? cc.textMuted;
    return DecoratedBox(
      decoration: BoxDecoration(color: cc.surface2, borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: c), const SizedBox(width: 4)],
            Flexible(
              child: Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c)),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Non riuscito» / «Fermato» (icon and text, not only colour), then the numbers.
class LogChips extends StatelessWidget {
  const LogChips(this.entry, this.text, {super.key});

  final LogEntry entry;
  final LogText text;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final chips = [
      if (entry.failed) LogChip(l.logFailedLabel, icon: Icons.error_outline_rounded, color: context.cc.error),
      if (entry.stopped && !entry.failed) LogChip(l.logStoppedLabel, icon: Icons.pause_rounded),
      for (final c in text.chips) LogChip(c),
    ];
    return chips.isEmpty ? const SizedBox.shrink() : Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}

/// The old identity struck through, the new one under an arrow.
class CorrectionLines extends StatelessWidget {
  const CorrectionLines(this.entry, {super.key});

  final LogEntry entry;

  static String ident(AppLocalizations l, ({String title, String? artist})? m) =>
      m == null ? '' : identLabel(l, m.title, m.artist);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ident(l, entry.oldIdent),
          style: theme.bodyMedium?.copyWith(
            color: context.cc.textMuted,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 6),
              child: Icon(Icons.arrow_forward_rounded, size: 16, color: context.cc.accentSoft),
            ),
            Expanded(
              child: Text(ident(l, entry.newIdent), style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }
}

/// «Ripristina» for a correction, with a 48 dp target.
class RevertButton extends ConsumerWidget {
  const RevertButton(this.entry, {super.key});

  final LogEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final from = CorrectionLines.ident(l, entry.oldIdent);
    return ActionButton(
      label: l.logRevert,
      semantics: '${l.logRevert}: $from',
      failed: l.logRevertFailed,
      action: () => ref.read(trackCorrectionsProvider).revert(entry.correction!),
      build: ({required onPressed, required child}) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        child: child,
      ),
    );
  }
}

/// One row of a day: icon of the category, title, a line of detail, the
/// numbers as chips and the time. The height follows the text.
class LogEntryCard extends StatelessWidget {
  const LogEntryCard({
    super.key,
    required this.row,
    required this.onTap,
    this.expanded = false,
    this.selected,
  });

  final LogRow row;
  final VoidCallback onTap;

  /// For a group of downloads: the song names are shown.
  final bool expanded;

  /// Null on a phone (no side panel); else whether the panel shows this line.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final e = row.entry;
    final grouped = row.group.isNotEmpty;
    final text = logText(l, e);
    final hasActions = grouped || e.revertible || text.how.isNotEmpty;
    final fmt = DateFormat.Hm(Localizations.localeOf(context).toLanguageTag());
    final title = grouped ? l.logDlGroup(row.group.length) : text.title;
    final label = [
      fmt.format(e.at),
      title,
      text.detail,
      if (e.revertible)
        l.logCorrectionSem(
          CorrectionLines.ident(l, e.oldIdent),
          CorrectionLines.ident(l, e.newIdent),
        ),
      if (e.failed) l.logFailedLabel else if (e.stopped) l.logStoppedLabel,
      ...text.chips,
    ].where((s) => s.isNotEmpty).join(', ');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected == true ? cc.surface2 : cc.surface1,
        borderRadius: BorderRadius.circular(CcDims.rCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CcTile(
            color: Colors.transparent,
            onTap: onTap,
            semanticsLabel: label,
            selected: selected,
            minHeight: hasActions ? 0 : 56,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, hasActions ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 2),
                    child: Icon(
                      logIcon(e.category),
                      color: e.failed ? cc.error : cc.accentSoft,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.titleSmall),
                        if (e.revertible)
                          Padding(padding: const EdgeInsets.only(top: 4), child: CorrectionLines(e))
                        else if (text.detail.isNotEmpty && !grouped)
                          Text(text.detail, style: theme.bodyMedium?.copyWith(color: cc.textMuted)),
                        if (e.failed || e.stopped || text.chips.isNotEmpty)
                          Padding(padding: const EdgeInsets.only(top: 6), child: LogChips(e, text)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text(fmt.format(e.at), style: theme.bodySmall?.copyWith(color: cc.textMuted)),
                  ),
                ],
              ),
            ),
          ),
          if (grouped && expanded)
            for (final g in row.group)
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 0, 12, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(g.item?.name ?? '', style: theme.bodyMedium)),
                    Text(fmt.format(g.at), style: theme.bodySmall?.copyWith(color: cc.textMuted)),
                  ],
                ),
              ),
          if (hasActions)
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 12, 4),
              child: Wrap(
                children: [
                  if (e.revertible) RevertButton(e),
                  if (grouped)
                    TextButton(
                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: onTap,
                      child: Text(expanded ? l.logDlGroupHide : l.logDlGroupShow),
                    ),
                  if (text.how.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: onTap,
                      icon: const Icon(Icons.info_outline_rounded),
                      label: Text(l.logHowTitle),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The whole line: in the side panel on desktop, in a sheet on a phone.
/// [onOpen] adds «Vedi i brani» (the second opinion and the completion).
class LogDetail extends StatelessWidget {
  const LogDetail(this.entry, {super.key, this.sources, this.onOpen, this.group = const []});

  final LogEntry entry;

  /// The finished downloads of a day shown as one row: all of them are listed.
  final List<LogEntry> group;
  final String? sources;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final text = logText(l, entry);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(CcDims.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group.isEmpty ? text.title : l.logDlGroup(group.length), style: theme.titleLarge),
          const SizedBox(height: 4),
          Text(
            DateFormat.yMMMEd(locale).add_Hm().format(entry.at),
            style: theme.bodySmall?.copyWith(color: cc.textMuted),
          ),
          if (group.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final g in group)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(g.item?.name ?? '', style: theme.bodyLarge)),
                    Text(DateFormat.Hm(locale).format(g.at), style: theme.bodySmall?.copyWith(color: cc.textMuted)),
                  ],
                ),
              ),
          ] else if (entry.revertible) ...[
            const SizedBox(height: 12),
            CorrectionLines(entry),
            RevertButton(entry),
          ] else if (text.detail.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(text.detail, style: theme.bodyLarge),
          ],
          if (entry.failed || entry.stopped || text.chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            LogChips(entry, text),
          ],
          if (sources != null) ...[
            const SizedBox(height: 12),
            Text(sources!, style: theme.bodyMedium),
          ],
          if (text.how.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(l.logHowTitle, style: theme.titleSmall),
            for (final (i, s) in text.how.indexed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${i + 1}. $s', style: theme.bodyMedium),
              ),
          ],
          if (text.tech != null) ...[
            const SizedBox(height: 20),
            Text(l.logTechTitle, style: theme.titleSmall),
            const SizedBox(height: 6),
            SelectableText(text.tech!, style: theme.bodyMedium?.copyWith(color: cc.textMuted)),
          ],
          if (onOpen != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onOpen, child: Text(l.logOpenSongs)),
          ],
        ],
      ),
    );
  }
}
