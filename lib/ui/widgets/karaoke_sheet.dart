import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_log.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/karaoke_providers.dart';
import '../../providers/player_providers.dart';
import '../../services/karaoke/karaoke_send_throttle.dart';
import '../theme/tokens.dart';
import 'cc_sheet.dart';
import '../screens/lyrics/lyrics_screen.dart';

/// The microphone of «In riproduzione» (D-584): absent where the backend has no
/// voice filter (macOS, iOS, Windows); opens [showKaraokeSheet].
class KaraokeButton extends ConsumerWidget {
  const KaraokeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(karaokeButtonVisibleProvider)) return const SizedBox.shrink();
    final jam = ref.watch(jamKaraokeProvider);
    // Bypassed (episode, radio): the filter does nothing, so the mic looks off.
    final on = jam != null
        ? jam.on
        : ref.watch(karaokeProvider.select((k) => k.on)) && !ref.watch(karaokeBypassProvider);
    // A guest without the host's permission: off, and the reason is the tooltip.
    final enabled = jam?.canCommand ?? true;
    final name = enabled ? context.l10n.karaoke : context.l10n.karaokeJamHostOnly;
    final cc = context.cc;
    // One node: the state is toggled, the name stays «Karaoke».
    return Semantics(
      button: true,
      excludeSemantics: true,
      enabled: enabled,
      toggled: on,
      label: name,
      onTap: enabled ? () => showKaraokeSheet(context) : null,
      child: IconButton(
        tooltip: name,
        onPressed: enabled ? () => showKaraokeSheet(context) : null,
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

class _KaraokePanel extends ConsumerStatefulWidget {
  const _KaraokePanel({required this.openLyrics});

  final bool openLyrics;

  @override
  ConsumerState<_KaraokePanel> createState() => _KaraokePanelState();
}

class _KaraokePanelState extends ConsumerState<_KaraokePanel> {
  // In a Jam the level comes back from the host with a delay: the thumb stays on the finger.
  double? _drag;
  late final _send = KaraokeSendThrottle(_sendJam);

  void _sendJam(double? level) {
    sendJamKaraoke(ref, level).then((e) {
      if (e != null) AppLog.d('karaoke: the Jam refused the level ($e)');
    });
  }

  @override
  void dispose() {
    _send.flush();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = ref.watch(karaokeProvider);
    final jam = ref.watch(jamKaraokeProvider);
    final bypass = jam == null && ref.watch(karaokeBypassProvider);
    final on = jam != null ? jam.on : k.on;
    final enabled = jam?.canCommand ?? true;
    // Off in a Jam: the slider shows (and keeps) this device's own level.
    final level = _drag ?? (jam?.level ?? k.level);
    final percent = (level * 100).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (bypass)
          Text(
            l.karaokeBypassed,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.cc.textMuted),
          ),
        if (!enabled)
          Text(
            l.karaokeJamHostOnly,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.cc.textMuted),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.karaoke),
          value: on,
          onChanged: !enabled
              ? null
              : (v) {
                  if (jam != null) {
                    _sendJam(v ? level : null);
                    return;
                  }
                  setKaraokeOn(ref, v);
                  final track = ref.read(currentShadowRowProvider) ??
                      ref.read(liveCurrentTrackProvider).value;
                  if (v && widget.openLyrics && track?.lyricsSynced != null) {
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
                  value: level,
                  divisions: 20,
                  semanticFormatterCallback: (v) => l.karaokePercent((v * 100).round()),
                  onChanged: !enabled
                      ? null
                      : (v) {
                          if (jam == null) return setKaraokeLevel(ref, v);
                          setState(() => _drag = v);
                          if (jam.on) {
                            _send.add(v);
                          } else {
                            setKaraokeLevel(ref, v);
                          }
                        },
                  onChangeEnd: (_) {
                    _send.flush();
                    setState(() => _drag = null);
                  },
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
