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
import 'now_playing_controls.dart' show npEdge;
import '../../widgets/show_msg.dart';

/// «Suggerito · simile a «…»» with download, add to a playlist and «Non mi piace».
class SuggestedInfo extends ConsumerWidget {
  const SuggestedInfo({super.key, required this.track, this.onDislike});

  final Track track;

  /// Opens the «Non mi piace» choice (wired by the caller); null disables the tile.
  final VoidCallback? onDislike;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final entry = ref.watch(onlineEntriesProvider)?[track.id];
    final seed = entry?.seedTitle;
    final actions = ref.read(suggestionActionsProvider);
    ref.watch(downloadIndexProvider); // a promotion refreshes it
    if (entryInLibrary(ref, track.id)) return const SizedBox.shrink();
    final suggested = entry?.suggested ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: npEdge),
      child: Column(
        children: [
          if (suggested)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_outlined, size: 16, color: cc.accent),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      seed == null
                          ? l.suggestedBadge
                          : l.suggestedSimilarTo(seed),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: cc.accent),
                    ),
                  ),
                ],
              ),
            ),
          // Equal tiles filling the title's width: one axis for header and actions.
          Row(
            children: [
              _Tile(
                icon: Icons.download_rounded,
                label: l.ytDownload,
                onPressed: () async {
                  final now = await actions.downloadEntry(track.id);
                  if (now != null && context.mounted) {
                    showMsg(
                      context,
                      now ? l.addedToLibrary : l.suggestionDownloadStarted,
                    );
                  }
                },
              ),
              _Tile(
                icon: Icons.playlist_add_rounded,
                label: l.addToPlaylist,
                onPressed: () async {
                  final picked = await pickPlaylist(context, ref);
                  if (picked == null || !context.mounted) return;
                  final now = await actions.addToPlaylist(track.id, picked.id);
                  if (now != null && context.mounted) {
                    showMsg(
                      context,
                      now
                          ? l.addedToPlaylist(picked.name)
                          : l.suggestionAddWhenDownloaded(picked.name),
                    );
                  }
                },
              ),
              if (suggested)
                _Tile(
                  icon: Icons.thumb_down_outlined,
                  label: l.suggestionDislike,
                  semanticLabel: l.dislikePlayerLabel,
                  onPressed: onDislike,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final String? semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Expanded(
    // 8 px between the blocks, as the mockup's `.tiles`.
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: CcDims.gap4),
      child: Semantics(
        label: semanticLabel,
        excludeSemantics: semanticLabel != null,
        button: semanticLabel != null,
        enabled: onPressed != null,
        onTap: semanticLabel != null ? onPressed : null,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: context.cc.surface2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CcDims.rCard),
            ),
            minimumSize: const Size(0, 64),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
