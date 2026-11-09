import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../data/db/app_database.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/romanization_ops.dart';
import '../../../providers/romanization_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/track_ops.dart';
import '../../../services/lyrics/romanization_resolver.dart'
    show RomanizationStatus;
import '../../../services/lyrics/script_detect.dart' show hasCjk;
import '../../../services/online/lrc_parser.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/show_msg.dart';
import 'lyrics_editor.dart';
import 'lyrics_romanization_editor.dart';
import '../../../services/lyrics/lyrics_shown.dart'
    show lyricsAsShown, lyricsPlainText;

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
    // The text as shown (sync switch applied) decides if it has CJK (D-459).
    final cjk = hasCjk(
      lyricsPlainText(
            lyricsAsShown(track, ref.watch(unsyncedLyricsProvider)),
          ) ??
          '',
    );
    final romOn = ref.watch(settingsProvider.select((s) => s.romanization));
    final romManual = ref.watch(
      manualRomanizationProvider.select((m) => m.containsKey(track.id)),
    );
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
          if (cjk)
            [
              CcAction(
                icon: Icons.abc_rounded,
                label: l.romanization,
                semanticsLabel:
                    '${l.romanization}, ${romOn ? l.lyricsSyncStateOn : l.lyricsSyncStateOff}',
                selected: romOn,
                onTap: () => ref
                    .read(settingsProvider.notifier)
                    .update((s) => s.copyWith(romanization: !romOn)),
              ),
              CcAction(
                icon: Icons.edit_note_rounded,
                label: l.romanizationEdit,
                onTap: () => _editRomanization(context, ref),
              ),
              if (romManual)
                CcAction(
                  icon: Icons.delete_outline_rounded,
                  label: l.romanizationDelete,
                  destructive: true,
                  onTap: () => _deleteRomanization(context, ref),
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

  /// The editor starts from the typed lines, else from what is shown now.
  void _editRomanization(BuildContext context, WidgetRef ref) {
    final typed = ref.read(manualRomanizationProvider)[track.id];
    final shown = ref.read(romanizationProvider(track.id)).value;
    final initial =
        typed ??
        (shown != null && shown.status == RomanizationStatus.ready
            ? shown.lines.map((e) => e ?? '').join('\n')
            : '');
    openRomanizationEditor(context, track.id, initial);
  }

  Future<void> _deleteRomanization(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final undo = await ref.read(romanizationOpsProvider).delete(track.id);
      if (undo == null) return;
      showMsgOn(
        messenger,
        l.romanizationDeleted,
        action: SnackBarAction(label: l.undo, onPressed: undo),
      );
    } on Object catch (e, st) {
      AppLog.e('delete romanization failed', e, st);
      showMsgOn(messenger, l.romanizationDeleteFailed);
    }
  }
}
