import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/suggestion_actions.dart';
import '../../../providers/youtube_providers.dart' show downloadIndexProvider;
import '../../widgets/track_actions.dart' show entryInLibrary;
import '../../theme/tokens.dart';
import '../playlists/playlist_picker.dart';
import '../../widgets/show_msg.dart';

/// «Suggerito · simile a «…»» with the two things worth doing with a streamed
/// song: download it, or download it into a playlist.
class SuggestedInfo extends ConsumerWidget {
  const SuggestedInfo({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final entry = ref.watch(onlineEntriesProvider)?[track.id];
    final seed = entry?.seedTitle;
    final actions = ref.read(suggestionActionsProvider);
    ref.watch(downloadIndexProvider); // a promotion refreshes it
    if (entryInLibrary(ref, track.id)) return const SizedBox.shrink();
    return Column(
      children: [
        if (entry?.suggested ?? false)
          Row(
            children: [
              Icon(Icons.cloud_outlined, size: 16, color: cc.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  seed == null ? l.suggestedBadge : l.suggestedSimilarTo(seed),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: cc.accent),
                ),
              ),
            ],
          ),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () async {
                final now = await actions.downloadEntry(track.id);
                if (now != null && context.mounted) {
                  showMsg(context, now ? l.addedToLibrary : l.suggestionDownloadStarted);
                }
              },
              icon: const Icon(Icons.download_rounded, size: 20),
              label: Text(l.ytDownload),
            ),
            TextButton.icon(
              onPressed: () async {
                final picked = await pickPlaylist(context, ref);
                if (picked == null || !context.mounted) return;
                final now = await actions.addToPlaylist(track.id, picked.id);
                if (now != null && context.mounted) {
                  showMsg(context, now ? l.addedToPlaylist(picked.name) : l.suggestionAddWhenDownloaded(picked.name));
                }
              },
              icon: const Icon(Icons.playlist_add_rounded, size: 20),
              label: Text(l.addToPlaylist),
            ),
          ],
        ),
      ],
    );
  }
}
