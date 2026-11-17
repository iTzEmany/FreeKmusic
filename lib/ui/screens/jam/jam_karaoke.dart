import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/jam_providers.dart';
import '../../../providers/karaoke_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../services/jam/jam_models.dart';
import '../../theme/tokens.dart';

/// Host only, in the outputs sheet: whether guests command the karaoke (off by
/// default), and in a Jam without remote guests why the level is for every output (D-587).
class JamKaraokeHostTile extends ConsumerWidget {
  const JamKaraokeHostTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jam = ref.watch(jamKaraokeProvider);
    if (jam == null || !jam.isHost) return const SizedBox.shrink();
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.karaokeGuestsAllowed),
          value: jam.guestsAllowed,
          onChanged: (v) => ref.read(jamProvider.notifier).send(JamCommand.karaokeGuests(v)),
        ),
        if (!jam.remote)
          Text(
            l.karaokeJamLocalNote,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.cc.textMuted),
          ),
      ],
    );
  }
}

/// A guest of a remote Jam: who turned the karaoke on, and, if this device plays,
/// «Ignora per me» (it plays without the filter; the Jam is unchanged).
class JamKaraokeBox extends ConsumerWidget {
  const JamKaraokeBox({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jam = ref.watch(jamKaraokeProvider);
    final level = jam?.level;
    if (jam == null || level == null || jam.isHost || !jam.remote) return const SizedBox.shrink();
    final l = context.l10n;
    final cc = context.cc;
    final name = jam.hostName.isEmpty ? l.jamHostTag : jam.hostName;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: CcDims.margin),
      padding: const EdgeInsets.symmetric(horizontal: CcDims.gap12),
      decoration: BoxDecoration(
        border: Border.all(color: cc.separator),
        borderRadius: BorderRadius.circular(CcDims.gap12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: CcDims.gap8),
          Semantics(
            container: true,
            child: Text(l.karaokeJamBox(name, (level * 100).round())),
          ),
          if (jam.canIgnore)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l.karaokeJamIgnore),
              value: ref.watch(settingsProvider.select((s) => s.karaokeJamIgnore)),
              onChanged: (v) =>
                  ref.read(settingsProvider.notifier).update((s) => s.copyWith(karaokeJamIgnore: v)),
            ),
          if (!jam.canIgnore) const SizedBox(height: CcDims.gap8),
        ],
      ),
    );
  }
}
