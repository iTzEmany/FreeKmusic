import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/radio_providers.dart';
import '../../../services/radio/radio_station.dart';
import '../../theme/tokens.dart';
import '../../widgets/radio_art.dart';
import 'radio_actions.dart';
import 'radio_labels.dart';

const kRadioRowHeight = 64.0;

/// The row grows with the text scale so two lines of text never overflow it.
double radioRowHeight(BuildContext context) =>
    kRadioRowHeight * (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0);

/// One station: favicon, name, «region · codec bitrate», the star. Tap plays,
/// long press (or the menu) opens the details.
class RadioStationRow extends ConsumerWidget {
  const RadioStationRow({
    super.key,
    required this.station,
    required this.onTap,
    required this.onMore,
    this.unreachable = false,
    this.dragHandle,
  });

  final RadioStation station;
  final VoidCallback onTap, onMore;

  /// Saved but Radio Browser says it no longer answers.
  final bool unreachable;

  /// «Le mie radio»: the grip to reorder.
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final saved = ref.watch(savedRadioIdsProvider.select((s) => s.contains(station.id)));
    final line = [
      if (station.state.isNotEmpty) station.state,
      radioQualityLine(station),
    ].where((e) => e.isNotEmpty).join(', ');
    return SizedBox(
      height: radioRowHeight(context),
      child: InkWell(
        onTap: onTap,
        onLongPress: onMore,
        onSecondaryTap: onMore,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
          child: Row(
            children: [
              RadioArt(station: station, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(station.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodyLarge),
                    if (line.isNotEmpty || unreachable)
                      Text(
                        [if (unreachable) l.radioNotResponding, line].where((e) => e.isNotEmpty).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodySmall?.copyWith(color: unreachable ? cc.error : cc.textMuted),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: saved ? l.radioUnsave : l.radioSave,
                onPressed: () => toggleSavedRadio(context, ref, station),
                icon: Icon(
                  saved ? Icons.star_rounded : Icons.star_border_rounded,
                  color: saved ? cc.accent : cc.textMuted,
                ),
              ),
              ?dragHandle,
            ],
          ),
        ),
      ),
    );
  }
}
