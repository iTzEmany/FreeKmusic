import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/youtube_providers.dart';
import '../theme/tokens.dart';
import '../../providers/yt_dlp_update_providers.dart';
import 'yt_dlp_update_button.dart';

/// «yt-dlp è troppo vecchio»: shown on desktop when `yt-dlp --version` is
/// older than the minimum the downloads need. Nothing otherwise.
class YtDlpOutdatedBanner extends ConsumerWidget {
  const YtDlpOutdatedBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isDesktop) return const SizedBox.shrink();
    final status = ref.watch(ytDlpStatusProvider).value;
    final update = ref.watch(ytDlpUpdateProvider);
    // A failed automatic download stays visible with «Riprova».
    if (status == null ||
        !(status.outdated || update.phase == YtDlpUpdatePhase.failed)) {
      return const SizedBox.shrink();
    }
    final cc = context.cc;
    final message = ytDlpUpdateMessage(context.l10n, update);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          CcDims.margin, CcDims.gap4, CcDims.margin, CcDims.gap8),
      child: Container(
        padding: const EdgeInsets.all(CcDims.gap12),
        decoration: BoxDecoration(
          color: cc.surface1,
          borderRadius: BorderRadius.circular(CcDims.rCard),
          border: Border.all(color: cc.error),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: cc.error),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.version == null
                        ? context.l10n.ytDlpMissingBanner
                        : context.l10n.ytDlpOutdatedBanner(status.version!),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (message != null)
                    Text(message,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cc.textMuted)),
                ],
              ),
            ),
            const YtDlpUpdateButton(),
          ],
        ),
      ),
    );
  }
}
