import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/track_ops.dart';
import '../../../services/online/lrc_parser.dart';
import '../../../providers/translation_providers.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/cover_backdrop.dart';
import '../../widgets/cover_image.dart';
import 'lyrics_editor.dart';
import 'lyrics_translate_flow.dart';
import 'lyrics_view.dart';
import '../../widgets/show_msg.dart';
import '../../widgets/cc_app_bar.dart';

/// Lyrics page: tinted backdrop, cover + title in the header, copy action.
/// [embedded] (desktop side panel) drops the app bar and the backdrop.
class LyricsScreen extends ConsumerWidget {
  const LyricsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    // A streamed track reads and saves on its shadow row (real id).
    final track = ref.watch(currentShadowRowProvider) ?? ref.watch(liveCurrentTrackProvider).value;
    if (track == null) {
      return Scaffold(
        backgroundColor: embedded ? Colors.transparent : context.cc.bg,
        appBar: embedded ? null : CcAppBar(title: l.lyrics),
        body: Center(child: Text(l.nothingPlaying)),
      );
    }
    if (embedded) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: LyricsView(track: track),
      );
    }
    final plain = lyricsPlainText(track);
    final theme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: context.cc.bg,
      appBar: CcAppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        titleWidget: Row(
          children: [
            CoverImage(coverKey: track.coverKey, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodyLarge,
                  ),
                  Text(
                    track.artist ?? l.unknownArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (plain != null && ref.watch(lyricsTranslatorProvider) != null)
            _TranslateButton(track: track),
          if (plain != null)
            IconButton(
              tooltip: l.copy,
              icon: const Icon(Icons.copy_rounded),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: plain));
                if (context.mounted) showMsg(context, l.copied);
              },
            ),
          _LyricsMenu(track: track, hasLyrics: plain != null),
        ],
      ),
      extendBodyBehindAppBar: false,
      body: CoverBackdrop(
        coverKey: track.coverKey,
        child: LyricsView(track: track),
      ),
    );
  }
}

/// «Traduci» (Android only): opens the flow, or removes an active translation.
class _TranslateButton extends ConsumerWidget {
  const _TranslateButton({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final active = ref.watch(
      lyricsTranslationProvider.select((t) => t?.trackId == track.id),
    );
    return IconButton(
      tooltip: active ? l.translateRemove : l.translateLyrics,
      icon: Icon(
        active ? Icons.translate_rounded : Icons.g_translate_rounded,
        color: active ? context.cc.accent : null,
      ),
      onPressed: () => active
          ? ref.read(lyricsTranslationProvider.notifier).clear()
          : runTranslateFlow(context, ref, track),
    );
  }
}

/// Menu of the lyrics page: write or edit, the per-track sync switch (only with
/// a synced text, D-472) and delete (D-471).
class _LyricsMenu extends ConsumerWidget {
  const _LyricsMenu({required this.track, required this.hasLyrics});

  final Track track;
  final bool hasLyrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final hasSynced = track.lyricsSynced != null && parseLrc(track.lyricsSynced!).isNotEmpty;
    final syncOn = !ref.watch(unsyncedLyricsProvider).contains(track.id);
    final unsynced = ref.read(unsyncedLyricsProvider.notifier);
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
                selected: syncOn,
                onTap: () => unsynced.setSynced(track.id, !syncOn),
              ),
            if (hasLyrics)
              CcAction(
                icon: Icons.delete_outline_rounded,
                label: l.lyricsDelete,
                destructive: true,
                onTap: () async {
                  await ref.read(trackOpsProvider).clearLyrics(track.id);
                  await unsynced.setSynced(track.id, true);
                  if (context.mounted) showMsg(context, l.lyricsDeleted);
                },
              ),
          ],
        ],
      ),
    );
  }
}
