import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/settings/settings_store.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/equalizer_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../services/audio/equalizer.dart';
import '../../theme/tokens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/segmented_blocks.dart';
import '../../widgets/cc_app_bar.dart';

/// Equalizer: on/off, a preset or the user's own bands, for the speaker and
/// for headphones separately. Only reachable where the player has one.
class EqualizerScreen extends ConsumerStatefulWidget {
  const EqualizerScreen({super.key});

  @override
  ConsumerState<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends ConsumerState<EqualizerScreen> {
  /// The output being edited; starts on the one in use.
  late OutputRoute _editing = ref.read(outputRouteProvider);

  String _presetName(AppLocalizations l, EqPreset p) => switch (p) {
        EqPreset.flat => l.eqPresetFlat,
        EqPreset.bass => l.eqPresetBass,
        EqPreset.voice => l.eqPresetVoice,
        EqPreset.treble => l.eqPresetTreble,
        EqPreset.custom => l.eqPresetCustom,
      };

  void _save(EqProfile p) => ref.read(settingsProvider.notifier).update((s) =>
      _editing == OutputRoute.headphones
          ? s.copyWith(eqHeadphones: p)
          : s.copyWith(eqSpeaker: p));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final eq = ref.watch(equalizerProvider);
    final s = ref.watch(settingsProvider);
    final bands = ref.watch(equalizerBandsProvider);
    final profile = eqProfileFor(s, _editing);

    Widget body;
    if (eq == null) {
      body = EmptyState(icon: Icons.equalizer, message: l.eqUnavailable);
    } else {
      body = ListView(
        padding: const EdgeInsets.symmetric(vertical: CcDims.gap8).withDock(context),
        children: [
          SwitchListTile(
            title: Text(l.equalizer),
            value: s.eqEnabled,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).update((c) => c.copyWith(eqEnabled: v)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap4, CcDims.margin, 0),
            child: SegmentedBlocks<OutputRoute>(
              items: [
                BlockItem(
                    value: OutputRoute.speaker,
                    icon: Icons.speaker_outlined,
                    label: l.eqOutputSpeaker),
                BlockItem(
                    value: OutputRoute.headphones,
                    icon: Icons.headphones_outlined,
                    label: l.eqOutputHeadphones),
              ],
              selected: _editing,
              onChanged: (v) => setState(() => _editing = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(CcDims.margin, 6, CcDims.margin, 6),
            child: Text(l.eqHint,
                style: theme.bodySmall?.copyWith(color: cc.textMuted)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in EqPreset.values)
                  ChoiceChip(
                    label: Text(_presetName(l, p)),
                    selected: profile.preset == p,
                    onSelected: (_) => bands.whenData((b) {
                      if (b == null) return;
                      // «Custom» starts from what the ears just heard.
                      _save(p == EqPreset.custom
                          ? EqProfile(
                              preset: p,
                              custom: profile.custom.isEmpty
                                  ? gainsFor(profile, b)
                                  : profile.custom)
                          : profile.copyWith(preset: p));
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          bands.when(
            loading: () => Padding(
              padding: const EdgeInsets.all(CcDims.margin),
              child: Text(l.eqWaiting,
                  style: theme.bodyMedium?.copyWith(color: cc.textMuted)),
            ),
            error: (_, _) => EmptyState(icon: Icons.equalizer, message: l.eqUnavailable),
            data: (b) => b == null
                ? EmptyState(icon: Icons.equalizer, message: l.eqUnavailable)
                : _Bands(
                    bands: b,
                    gains: gainsFor(profile, b),
                    onChanged: (i, v) {
                      final g = List.of(gainsFor(profile, b))..[i] = v;
                      _save(EqProfile(preset: EqPreset.custom, custom: g));
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap8, CcDims.margin, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.restart_alt),
                label: Text(l.eqReset),
                onPressed: () => _save(const EqProfile()),
              ),
            ),
          ),
        ],
      );
    }
    return Scaffold(appBar: CcAppBar(title: l.equalizer), body: body);
  }
}

/// One vertical slider per band, with its gain above and frequency below.
class _Bands extends StatelessWidget {
  const _Bands({required this.bands, required this.gains, required this.onChanged});

  final EqBands bands;
  final List<double> gains;
  final void Function(int band, double db) onChanged;

  String _hz(BuildContext context, double hz) {
    final f = NumberFormat('0.#', Localizations.localeOf(context).toString());
    return hz >= 1000 ? '${f.format(hz / 1000)} kHz' : '${hz.round()} Hz';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final muted = theme.labelSmall?.copyWith(color: context.cc.textMuted);
    return Row(
      children: [
        for (var i = 0; i < bands.count; i++)
          Expanded(
            child: Column(
              children: [
                Text('${gains[i].round()} dB', style: muted),
                SizedBox(
                  height: 190,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Slider(
                      value: gains[i].clamp(bands.minDb, bands.maxDb).toDouble(),
                      min: bands.minDb,
                      max: bands.maxDb,
                      onChanged: (v) => onChanged(i, v),
                    ),
                  ),
                ),
                Text(_hz(context, bands.centerHz[i]), style: muted),
              ],
            ),
          ),
      ],
    );
  }
}
