import 'cc_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/settings_providers.dart';
import '../theme/tokens.dart';

const playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

/// «1,5×»: the number in the user's language.
String formatSpeed(BuildContext context, double v) =>
    '${NumberFormat('0.##', Localizations.localeOf(context).toString()).format(v)}×';

/// Chip with the current speed (highlighted when not 1×); opens the choices.
class SpeedButton extends ConsumerWidget {
  const SpeedButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = context.cc;
    final speed = ref.watch(settingsProvider.select((s) => s.playbackSpeed));
    final changed = speed != 1.0;
    return Tooltip(
      message: context.l10n.playbackSpeed,
      child: InkWell(
        borderRadius: BorderRadius.circular(CcDims.rSheet),
        onTap: () => SpeedSheet.show(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: CcDims.gap4),
          decoration: BoxDecoration(
            color: changed ? cc.accent.withValues(alpha: 0.18) : cc.surface2,
            borderRadius: BorderRadius.circular(CcDims.rSheet),
          ),
          child: Text(
            formatSpeed(context, speed),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: changed ? cc.accent : cc.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ),
      ),
    );
  }
}

class SpeedSheet extends ConsumerWidget {
  const SpeedSheet({super.key});

  static Future<void> show(BuildContext context) => showCcSheet<void>(
        context: context,
        builder: (_) => const SpeedSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final current = ref.watch(settingsProvider.select((s) => s.playbackSpeed));
    void pick(double v) {
      ref
          .read(settingsProvider.notifier)
          .update((c) => c.copyWith(playbackSpeed: v));
      Navigator.of(context).pop();
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            CcDims.margin, 0, CcDims.margin, CcDims.margin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.playbackSpeed, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in playbackSpeeds)
                  ChoiceChip(
                    label: Text(formatSpeed(context, v)),
                    selected: v == current,
                    onSelected: (_) => pick(v),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l.playbackSpeedHint,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.cc.textMuted)),
          ],
        ),
      ),
    );
  }
}
