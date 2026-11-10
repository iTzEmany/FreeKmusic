import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/import_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/youtube_providers.dart';
import '../../../providers/yt_dlp_update_providers.dart';
import '../../../services/online/youtube_service.dart' show DownloadFormat;
import '../../theme/tokens.dart';
import '../../widgets/segmented_blocks.dart';
import '../../widgets/yt_dlp_update_button.dart';
import 'stream_cache_tile.dart';
import '../../widgets/show_msg.dart';

String downloadFormatLabel(AppLocalizations l, DownloadFormat f) => switch (f) {
  DownloadFormat.original => l.downloadFormatOriginal,
  DownloadFormat.m4a => l.downloadFormatM4a,
  DownloadFormat.mp3High => l.downloadFormatMp3High,
  DownloadFormat.mp3Low => l.downloadFormatMp3Low,
};

String downloadFormatHint(AppLocalizations l, DownloadFormat f) => switch (f) {
  DownloadFormat.original => l.downloadFormatOriginalHint,
  DownloadFormat.m4a => l.downloadFormatM4aHint,
  DownloadFormat.mp3High => l.downloadFormatMp3HighHint,
  DownloadFormat.mp3Low => l.downloadFormatMp3LowHint,
};

const _formatIcons = {
  DownloadFormat.original: Icons.high_quality_outlined,
  DownloadFormat.m4a: Icons.audiotrack_outlined,
  DownloadFormat.mp3High: Icons.graphic_eq,
  DownloadFormat.mp3Low: Icons.data_saver_on_outlined,
};

/// The formats from best to lowest quality, each with what it is good for.
Future<void> _pickFormat(
  BuildContext context,
  WidgetRef ref,
  DownloadFormat current,
) async {
  final picked = await showDialog<DownloadFormat>(
    context: context,
    builder: (dialogContext) {
      final l = dialogContext.l10n;
      var sel = current;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l.downloadFormat),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedBlocks<DownloadFormat>(
                    items: [
                      for (final f in DownloadFormat.values)
                        BlockItem(
                          value: f,
                          icon: _formatIcons[f]!,
                          label: downloadFormatLabel(l, f),
                        ),
                    ],
                    selected: sel,
                    onChanged: (f) => setState(() => sel = f),
                  ),
                  const SizedBox(height: 12),
                  // Blocks may ellipsize the long labels: the full one is here.
                  Text(
                    downloadFormatLabel(l, sel),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    downloadFormatHint(l, sel),
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: context.cc.textMuted),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, sel),
              child: Text(l.apply),
            ),
          ],
        ),
      );
    },
  );
  if (picked == null || picked == current) return;
  ref
      .read(settingsProvider.notifier)
      .update((c) => c.copyWith(downloadFormat: picked));
}

/// Rows of the «Download» group in the settings.
class DownloadSettingsTiles extends ConsumerWidget {
  const DownloadSettingsTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final n = ref.watch(settingsProvider.select((s) => s.downloadParallel));
    final format = ref.watch(settingsProvider.select((s) => s.downloadFormat));
    final rate = ref.watch(
      settingsProvider.select((s) => s.downloadRateLimitKBps),
    );
    return Column(
      children: [
        const _YtDlpTile(),
        ListTile(
          leading: const Icon(Icons.stacked_line_chart),
          title: Text(l.downloadParallel),
          subtitle: Text(l.downloadParallelHint),
          trailing: DropdownButton<int>(
            value: n,
            underline: const SizedBox.shrink(),
            items: [
              for (final v in const [1, 2, 3])
                DropdownMenuItem(value: v, child: Text('$v')),
            ],
            onChanged: (v) => v == null
                ? null
                : ref
                      .read(settingsProvider.notifier)
                      .update((c) => c.copyWith(downloadParallel: v)),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.high_quality_outlined),
          title: Text(l.downloadFormat),
          subtitle: Text(downloadFormatLabel(l, format)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _pickFormat(context, ref, format),
        ),
        if (isAndroid)
          SwitchListTile(
            key: const ValueKey('shazam-auto-download'),
            title: Text(l.shazamAutoDownload),
            subtitle: Text(l.shazamAutoDownloadHint),
            value: ref.watch(shazamAutoDownloadProvider),
            onChanged: ref.read(shazamAutoDownloadProvider.notifier).set,
          ),
        const _SearchCacheTile(),
        const StreamCacheTile(),
        ListTile(
          leading: const Icon(Icons.speed),
          title: Text(l.downloadRateLimit),
          trailing: DropdownButton<int>(
            value: _rateChoices.contains(rate) ? rate : 0,
            underline: const SizedBox.shrink(),
            items: [
              for (final v in _rateChoices)
                DropdownMenuItem(value: v, child: Text(_rateLabel(l, v))),
            ],
            onChanged: (v) => v == null
                ? null
                : ref
                      .read(settingsProvider.notifier)
                      .update((c) => c.copyWith(downloadRateLimitKBps: v)),
          ),
        ),
      ],
    );
  }
}

const _rateChoices = [0, 500, 1000, 2000];

String _rateLabel(AppLocalizations l, int kb) => kb == 0
    ? l.downloadRateNone
    : kb >= 1000
    ? l.downloadRateMb(kb ~/ 1000)
    : l.downloadRateKb(kb);

class _SearchCacheTile extends ConsumerWidget {
  const _SearchCacheTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final n = ref.watch(searchCacheCountProvider).value ?? 0;
    return ListTile(
      leading: const Icon(Icons.manage_search),
      title: Text(l.searchCacheClear),
      subtitle: Text(l.searchCacheCount(n)),
      enabled: n > 0,
      onTap: () async {
        await ref.read(searchCacheProvider).clear();
        ref.invalidate(searchCacheCountProvider);
        if (!context.mounted) return;
        showMsg(context, l.searchCacheCleared);
      },
    );
  }
}

class _YtDlpTile extends ConsumerWidget {
  const _YtDlpTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final status = ref.watch(ytDlpStatusProvider);
    final update = ref.watch(ytDlpUpdateProvider);
    final version = status.value?.version;
    final message =
        ytDlpUpdateMessage(l, update) ??
        (status.value?.outdated ?? false ? l.ytDlpTooOld : null);
    return ListTile(
      leading: const Icon(Icons.download_for_offline_outlined),
      title: Text(
        status.isLoading
            ? 'yt-dlp …'
            : version == null
            ? l.ytDlpUnknownVersion
            : l.ytDlpVersion(version),
      ),
      subtitle: message == null ? null : Text(message),
      // Android updates the embedded yt-dlp by itself on first use.
      trailing: isDesktop ? const YtDlpUpdateButton() : null,
    );
  }
}
