import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/karaoke_providers.dart';
import '../../providers/player_providers.dart';
import '../../providers/settings_providers.dart';
import '../../services/karaoke/separation_service.dart';
import '../theme/tokens.dart';
import 'cc_sheet.dart';
import '../screens/lyrics/lyrics_screen.dart';

/// The microphone of «In riproduzione»: only on Android and outside a Jam (D-620, D-623);
/// opens [showKaraokeSheet].
class KaraokeButton extends ConsumerWidget {
  const KaraokeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(karaokeButtonVisibleProvider)) {
      return const SizedBox.shrink();
    }
    // Bypassed (episode, radio): there is no backing track, so the mic looks off.
    final on =
        ref.watch(karaokeProvider.select((k) => k.on)) &&
        !ref.watch(karaokeBypassProvider);
    final name = context.l10n.karaoke;
    final cc = context.cc;
    // One node: the state is toggled, the name stays «Karaoke».
    return Semantics(
      button: true,
      excludeSemantics: true,
      toggled: on,
      label: name,
      onTap: () => showKaraokeSheet(context),
      child: IconButton(
        visualDensity: VisualDensity.compact, // next to the sleep chip
        tooltip: name,
        onPressed: () => showKaraokeSheet(context),
        icon: Icon(
          on ? Icons.mic_rounded : Icons.mic_none_rounded,
          color: on ? cc.accent : cc.textMuted,
        ),
      ),
    );
  }
}

/// Switch and «Alta qualità» row. Turning karaoke on opens the lyrics page when the
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
  double? _drag; // the slider value while it is held

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final k = ref.watch(karaokeProvider);
    final bypass = ref.watch(karaokeBypassProvider);
    final on = k.on;
    // «Alta qualità» (D-622): Android only.
    final target = ref.watch(karaokeTargetProvider).value;
    final sep = ref.watch(separationStateProvider);
    final base = ref.watch(karaokeBaseProvider).value;
    final mixing = ref.watch(karaokeMixingProvider);
    final highQuality =
        ref.watch(separationServiceProvider) != null && on && target != null;
    final baseReady = highQuality && base?.path != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (bypass)
          Text(
            l.karaokeBypassed,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.cc.textMuted),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.karaoke),
          value: on,
          onChanged: (v) {
            setKaraokeOn(ref, v);
            final track =
                ref.read(currentShadowRowProvider) ??
                ref.read(liveCurrentTrackProvider).value;
            if (v && widget.openLyrics && track?.lyricsSynced != null) {
              final nav = Navigator.of(context, rootNavigator: true);
              Navigator.of(context).pop();
              nav.push(
                MaterialPageRoute<void>(builder: (_) => const LyricsScreen()),
              );
            }
          },
        ),
        if (highQuality) _HighQualityRow(base: base, target: target, sep: sep),
        if (baseReady)
          Row(
            children: [
              Text(l.karaokeVoice),
              Expanded(
                child: Slider(
                  value: _drag ?? k.level,
                  label: l.karaokePercent(((_drag ?? k.level) * 100).round()),
                  divisions: 20,
                  onChanged: (v) => setState(() => _drag = v),
                  onChangeEnd: (v) {
                    ref
                        .read(settingsProvider.notifier)
                        .update((s) => s.copyWith(karaokeLevel: v));
                    setState(() => _drag = null);
                    unawaited(ref.read(karaokeApplyProvider)());
                  },
                ),
              ),
              SizedBox(
                width: 44,
                child: mixing
                    ? const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Text(
                        l.karaokePercent(((_drag ?? k.level) * 100).round()),
                        textAlign: TextAlign.end,
                      ),
              ),
            ],
          ),
      ],
    );
  }
}

/// «Alta qualità»: starts the separation of the current track and shows its progress.
/// Nothing while the stems exist (the «Voce» slider takes over).
class _HighQualityRow extends ConsumerWidget {
  const _HighQualityRow({
    required this.base,
    required this.target,
    required this.sep,
  });

  final KaraokeBase? base;
  final KaraokeTarget? target;
  final SeparationState sep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = this.target;
    if (target == null || base?.path != null) return const SizedBox.shrink();
    final l = context.l10n;
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: context.cc.textMuted);
    final running =
        sep.phase == SeparationPhase.model ||
        sep.phase == SeparationPhase.separating;
    if (running) {
      final model = sep.phase == SeparationPhase.model;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(l.karaokeHighQuality)),
                Text(
                  '${model ? l.karaokeHighQualityModel : l.karaokeHighQualitySeparating} '
                  '${l.karaokePercent((sep.fraction * 100).round())}',
                  style: muted,
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: sep.fraction > 0 ? sep.fraction : null,
            ),
            const SizedBox(height: 6),
            Text(l.karaokeHighQualityNote, style: muted),
          ],
        ),
      );
    }
    final input = target.input;
    final failed = sep.phase == SeparationPhase.failed;
    final cost = ref.watch(karaokeDataCostProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _startTile(context, ref, target, input, failed, cost?.track == true),
        if (cost != null && cost.model) Text(l.karaokeCostModel, style: muted),
      ],
    );
  }

  Widget _startTile(
    BuildContext context,
    WidgetRef ref,
    KaraokeTarget target,
    String? input,
    bool failed,
    bool trackCost,
  ) {
    final l = context.l10n;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l.karaokeHighQuality),
      subtitle: Text(
        input == null
            ? (trackCost ? l.karaokeCostTrack : l.karaokeHighQualityWaiting)
            : failed
            ? l.karaokeHighQualityFailed
            : l.karaokeHighQualityNote,
      ),
      enabled: input != null,
      onTap: input == null
          ? null
          : () => unawaited(
              ref.read(separationServiceProvider)!.request(target.key, input),
            ),
    );
  }
}
