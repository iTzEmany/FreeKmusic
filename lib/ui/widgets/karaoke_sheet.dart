import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/karaoke_providers.dart';
import '../../providers/player_providers.dart' show currentTrackProvider;
import '../../providers/settings_providers.dart';
import '../../services/karaoke/separation_service.dart';
import '../theme/tokens.dart';
import 'cc_sheet.dart';

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

/// Switch, separation progress and the «Voce» slider. Turning karaoke on keeps the sheet open.
Future<void> showKaraokeSheet(BuildContext context) => showCcSheet<void>(
  context: context,
  builder: (sheet) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        CcDims.margin,
        0,
        CcDims.margin,
        CcDims.margin,
      ),
      child: const _KaraokePanel(),
    ),
  ),
);

class _KaraokePanel extends ConsumerStatefulWidget {
  const _KaraokePanel();

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
    // The separation exists on Android only.
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
          onChanged: (v) => setKaraokeOn(ref, v),
        ),
        if (ref.watch(currentTrackProvider).value case final t?
            when ref.watch(instrumentalProvider(t)).value == true)
          Text(
            l.instrumentalTrack,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.cc.textMuted),
          ),
        if (highQuality) _SeparationRow(base: base, target: target, sep: sep),
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

/// The separation of the current track (it starts by itself, D-629): progress, the cost to confirm
/// on a metered network, or the failure with its retry. Nothing while the stems exist (the «Voce»
/// slider takes over).
class _SeparationRow extends ConsumerWidget {
  const _SeparationRow({
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
            Text(
              '${model ? l.karaokeHighQualityModel : l.karaokeHighQualitySeparating} '
              '${l.karaokePercent((sep.fraction * 100).round())}',
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
    final service = ref.read(separationServiceProvider)!;
    Widget action(String label, VoidCallback onTap) => Align(
      alignment: AlignmentDirectional.centerEnd,
      child: TextButton(onPressed: onTap, child: Text(label)),
    );
    if (sep.phase == SeparationPhase.failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.karaokeHighQualityFailed, style: muted),
          if (input != null)
            action(
              l.karaokeRetry,
              () => unawaited(service.request(target.key, input)),
            ),
        ],
      );
    }
    final cost = ref.watch(karaokeDataCostProvider).value;
    final confirmed = ref.watch(
      karaokeConfirmedProvider.select((c) => c.contains(target.key)),
    );
    if (cost != null && !confirmed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cost.model) Text(l.karaokeCostModel(kKaraokeModelMegabytes), style: muted),
          if (cost.track) Text(l.karaokeCostTrack, style: muted),
          // A stream not in the cache yet has nothing to confirm: it starts once the file lands.
          if (input == null)
            Text(l.karaokeHighQualityWaiting, style: muted)
          else
            action(
              l.karaokeStart,
              () => ref.read(karaokeConfirmedProvider.notifier).add(target.key),
            ),
        ],
      );
    }
    // It starts by itself; a streamed track first has to land in the cache.
    return input == null
        ? Text(l.karaokeHighQualityWaiting, style: muted)
        : const SizedBox.shrink();
  }
}
