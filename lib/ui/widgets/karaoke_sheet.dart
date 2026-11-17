import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/karaoke_providers.dart';
import '../../providers/player_providers.dart';
import '../theme/tokens.dart';
import 'cc_sheet.dart';
import '../screens/lyrics/lyrics_screen.dart';

/// The microphone of «In riproduzione» (D-584): absent where the backend has no
/// voice filter (macOS, iOS, Windows); opens [showKaraokeSheet].
class KaraokeButton extends ConsumerWidget {
  const KaraokeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(voiceFilterProvider) == null) return const SizedBox.shrink();
    // Bypassed (episode, radio): the filter does nothing, so the mic looks off.
    final on = ref.watch(karaokeProvider.select((k) => k.on)) &&
        !ref.watch(karaokeBypassProvider);
    final cc = context.cc;
    // One node: the state is toggled, the name stays «Karaoke».
    return Semantics(
      button: true,
      excludeSemantics: true,
      toggled: on,
      label: context.l10n.karaoke,
      onTap: () => showKaraokeSheet(context),
      child: IconButton(
        tooltip: context.l10n.karaoke,
        onPressed: () => showKaraokeSheet(context),
        icon: Icon(
          on ? Icons.mic_rounded : Icons.mic_none_rounded,
          color: on ? cc.accent : cc.textMuted,
        ),
      ),
    );
  }
}

/// Switch and «Voce» slider. Turning karaoke on opens the lyrics page when the
/// track has synced lyrics, unless [openLyrics] is false (already there).
Future<void> showKaraokeSheet(BuildContext context, {bool openLyrics = true}) =>
    showCcSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CcDims.margin,
            0,
            CcDims.margin,
            CcDims.margin,
          ),
          child: _KaraokePanel(openLyrics: openLyrics),
        ),
      ),
    );

class _KaraokePanel extends ConsumerWidget {
  const _KaraokePanel({required this.openLyrics});

  final bool openLyrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final k = ref.watch(karaokeProvider);
    final percent = (k.level * 100).round();
    final bypass = ref.watch(karaokeBypassProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (bypass)
          Text(
            l.karaokeBypassed,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.cc.textMuted),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.karaoke),
          value: k.on,
          onChanged: (v) {
            setKaraokeOn(ref, v);
            final track = ref.read(currentShadowRowProvider) ??
                ref.read(liveCurrentTrackProvider).value;
            if (v && openLyrics && track?.lyricsSynced != null) {
              final nav = Navigator.of(context, rootNavigator: true);
              Navigator.of(context).pop();
              nav.push(MaterialPageRoute<void>(builder: (_) => const LyricsScreen()));
            }
          },
        ),
        Row(
          children: [
            ExcludeSemantics(child: Text(l.karaokeVoice)),
            Expanded(
              child: Semantics(
                label: l.karaokeVoice,
                child: Slider(
                  value: k.level,
                  divisions: 20,
                  semanticFormatterCallback: (v) => l.karaokePercent((v * 100).round()),
                  onChanged: (v) => setKaraokeLevel(ref, v),
                ),
              ),
            ),
            ExcludeSemantics(child: Text(l.karaokePercent(percent))),
          ],
        ),
      ],
    );
  }
}
