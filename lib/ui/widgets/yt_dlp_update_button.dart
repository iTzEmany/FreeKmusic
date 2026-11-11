import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/yt_dlp_update_providers.dart';
import '../../services/online/yt_dlp_updater.dart';

/// One line about the update in progress or its outcome; null when idle.
String? ytDlpUpdateMessage(AppLocalizations l, YtDlpUpdateState st) =>
    switch (st.phase) {
      YtDlpUpdatePhase.idle => null,
      YtDlpUpdatePhase.working =>
        l.ytDlpUpdating((st.progress * 100).round()),
      YtDlpUpdatePhase.done => l.ytDlpUpdated(st.tag ?? ''),
      YtDlpUpdatePhase.failed => switch (st.error) {
          YtDlpUpdateError.network => l.ytDlpUpdateErrNetwork,
          YtDlpUpdateError.hashMismatch => l.ytDlpUpdateErrHash,
          _ => l.ytDlpUpdateErrOther,
        },
    };

/// «Aggiorna» for the yt-dlp binary; a spinner while it downloads.
class YtDlpUpdateButton extends ConsumerWidget {
  const YtDlpUpdateButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(ytDlpUpdateProvider);
    if (st.phase == YtDlpUpdatePhase.working) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
            strokeWidth: 2, value: st.progress > 0 ? st.progress : null),
      );
    }
    return TextButton(
      onPressed: () => ref.read(ytDlpUpdateProvider.notifier).run(),
      child: Text(st.phase == YtDlpUpdatePhase.failed
          ? context.l10n.retry
          : context.l10n.ytDlpUpdate),
    );
  }
}
