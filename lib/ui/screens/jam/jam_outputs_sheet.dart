import '../../widgets/cc_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/jam_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/share_hub.dart';
import '../../../services/jam/jam_models.dart';
import '../../theme/tokens.dart';

/// «Uscite e sincronia»: which devices play, the offset, the latency and the
/// shared volume.
class JamOutputsSheet extends ConsumerWidget {
  const JamOutputsSheet({super.key});

  static Future<void> show(BuildContext context) => showCcSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const JamOutputsSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final s = ref.watch(jamProvider);
    final jam = s.jam;
    if (jam == null) return const SizedBox.shrink();
    final ctrl = ref.read(jamProvider.notifier);
    final ownId = ref.read(shareHubProvider.notifier).deviceId ?? '';
    final others = [
      for (final p in jam.participants)
        if (p.id != ownId) p,
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          CcDims.margin,
          0,
          CcDims.margin,
          CcDims.margin,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.jamOutput, style: theme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: Text(l.jamOutputHere),
                  selected: jam.outputs.contains(ownId),
                  onSelected: (_) => ctrl.toggleOutput(ownId),
                ),
                for (final p in others)
                  ChoiceChip(
                    label: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    selected: jam.outputs.contains(p.id),
                    onSelected: (_) => ctrl.toggleOutput(p.id),
                  ),
              ],
            ),
            if (jam.synced) ...[
              const SizedBox(height: 12),
              Text(
                s.syncErrorMs == null
                    ? l.jamSyncing
                    : l.jamSynced(s.syncErrorMs!.abs()),
                style: theme.bodyMedium?.copyWith(color: cc.textMuted),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: '-50 ms',
                    icon: const Icon(Icons.remove),
                    onPressed: () => ctrl.setLatencyMs(
                      ref.read(settingsProvider).jamLatencyMs - 50,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      l.jamLatency(ref.watch(settingsProvider).jamLatencyMs),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    tooltip: '+50 ms',
                    icon: const Icon(Icons.add),
                    onPressed: () => ctrl.setLatencyMs(
                      ref.read(settingsProvider).jamLatencyMs + 50,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.volume_down_rounded),
                Expanded(
                  child: Slider(
                    value: jam.volume.clamp(0.0, 1.0),
                    onChanged: (v) => ctrl.send(JamCommand.volume(v)),
                  ),
                ),
                const Icon(Icons.volume_up_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
