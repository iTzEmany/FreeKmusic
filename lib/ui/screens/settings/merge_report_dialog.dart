import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/backup_merge.dart';
import '../../../l10n/l10n_ext.dart';
import '../../shell/shazam_share.dart';
import '../../widgets/show_msg.dart';

Future<void> showMergeReport(BuildContext context, MergeReport r) =>
    showDialog<void>(context: context, builder: (ctx) => _MergeReportDialog(report: r, host: context));

class _MergeReportDialog extends ConsumerWidget {
  const _MergeReportDialog({required this.report, required this.host});

  final MergeReport report;
  /// The screen under the dialog: the search tab opens from it once the dialog is gone.
  final BuildContext host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final r = report;
    final theme = Theme.of(context);
    String label(MissingTrack t) =>
        t.artist == null || t.artist!.isEmpty ? t.title : '${t.title} - ${t.artist}';
    final all = r.notFound.map(label).join('\n');

    return AlertDialog(
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.restoreMergeDone(r.recognized, r.notFound.length, r.playlistsCreated, r.favoritesAdded)),
          for (final line in [
            if (r.backupDbUnreadable) l.restoreMergeDbUnreadable,
            if (r.tables.playsAdded > 0) l.restoreMergePlays(r.tables.playsAdded),
            if (r.tables.tagsAdded > 0) l.restoreMergeTags(r.tables.tagsAdded),
            if (r.tables.smartPlaylistsAdded > 0) l.restoreMergeSmart(r.tables.smartPlaylistsAdded),
            if (r.tables.podcastsAdded > 0) l.restoreMergePodcasts(r.tables.podcastsAdded),
            if (r.themesDropped > 0) l.restoreMergeThemesDropped(r.themesDropped),
            if (r.tables.playsUnlinked > 0) l.restoreMergeUnlinked(r.tables.playsUnlinked),
          ])
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(line)),
          if (r.notFound.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(l.restoreNotFound, style: theme.textTheme.titleSmall),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: r.notFound.length,
                itemBuilder: (_, i) {
                  final t = r.notFound[i];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: t.artist == null || t.artist!.isEmpty ? null : Text(t.artist!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Semantics(
                      label: '${l.restoreSearchOnline}: ${t.title}${t.artist == null || t.artist!.isEmpty ? '' : ', ${t.artist}'}',
                      button: true,
                      excludeSemantics: true,
                      child: TextButton(
                        onPressed: () async {
                          // The dialog closes: keep the whole list for later.
                          await Clipboard.setData(ClipboardData(text: all));
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          if (!host.mounted) return;
                          showMsg(host, l.restoreListCopied);
                          openSearchWith(host, ref, '${t.artist ?? ''} ${t.title}'.trim());
                        },
                        child: Text(l.restoreSearchOnline),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ])),
      ),
      actions: [
        if (r.notFound.isNotEmpty)
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: all)),
            child: Text(l.restoreCopyList),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.close)),
      ],
    );
  }
}
