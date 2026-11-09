import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/translation_providers.dart';
import '../../../services/lyrics/lyrics_shown.dart';
import '../../theme/tokens.dart';
import '../../widgets/cover_backdrop.dart';
import '../../widgets/cover_image.dart';
import 'lyrics_menu.dart';
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
    final track =
        ref.watch(currentShadowRowProvider) ??
        ref.watch(liveCurrentTrackProvider).value;
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
            _TranslateButton(
              track: lyricsAsShown(track, ref.watch(unsyncedLyricsProvider)),
            ),
          if (plain != null)
            IconButton(
              tooltip: l.copy,
              icon: const Icon(Icons.copy_rounded),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: plain));
                if (context.mounted) showMsg(context, l.copied);
              },
            ),
          LyricsMenuButton(track: track),
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
