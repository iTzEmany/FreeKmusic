import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../data/db/app_database.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/track_ops.dart';
import '../../../services/online/lrc_parser.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/show_msg.dart';
import 'lyrics_editor.dart';
import 'lyrics_view.dart' show lyricsPlainText;

/// Menu of the lyrics (page and desktop side panel): write or edit, the
/// per-track sync switch (only with a synced text, D-472) and delete (D-471).
class LyricsMenuButton extends ConsumerWidget {
  const LyricsMenuButton({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final hasLyrics = lyricsPlainText(track) != null;
    final hasSynced =
        track.lyricsSynced != null && parseLrc(track.lyricsSynced!).isNotEmpty;
    final syncOn = !ref.watch(unsyncedLyricsProvider).contains(track.id);
    final ops = ref.read(trackOpsProvider);
    return IconButton(
      tooltip: l.moreActions,
      icon: const Icon(Icons.more_vert_rounded),
      onPressed: () => showCcActionSheet<void>(
        context: context,
        groups: [
          [
            CcAction(
              icon: Icons.edit_rounded,
              label: hasLyrics ? l.lyricsEdit : l.lyricsWrite,
              onTap: () => openLyricsEditor(context, track),
            ),
            if (hasSynced)
              CcAction(
                icon: Icons.timer_rounded,
                label: l.lyricsSyncSwitch,
                semanticsLabel:
                    '${l.lyricsSyncSwitch}, ${syncOn ? l.lyricsSyncStateOn : l.lyricsSyncStateOff}',
                selected: syncOn,
                onTap: () => ops.setLyricsSynced(track.id, !syncOn),
              ),
            if (hasLyrics)
              CcAction(
                icon: Icons.delete_outline_rounded,
                label: l.lyricsDelete,
                destructive: true,
                onTap: () => _delete(context, ops),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, TrackOps ops) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final undo = await ops.deleteLyrics(track.id);
      showMsgOn(
        messenger,
        l.lyricsDeleted,
        action: SnackBarAction(label: l.undo, onPressed: undo),
      );
    } on Object catch (e, st) {
      AppLog.e('delete lyrics failed', e, st);
      showMsgOn(messenger, l.lyricsDeleteFailed);
    }
  }
}
