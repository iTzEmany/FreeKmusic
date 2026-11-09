import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/daylist_providers.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/play_buttons.dart';
import '../../widgets/playlist_cover.dart';
import 'daylist_labels.dart';
import 'daylist_screen.dart';

/// The daylist card of Home, after «Riprendi» (D-444). Nothing while the slot
/// is off, the daylist is still loading or there are too few songs (D-473).
class DaylistCard extends ConsumerWidget {
  const DaylistCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(daylistVisibleProvider);
    if (d == null || d.result.tooFew) return const SizedBox.shrink();
    final l = context.l10n;
    final cc = context.cc;
    final text = Theme.of(context).textTheme;
    final name = daylistName(l, d.slotIndex, d.result.genres);
    final time = daylistHour(d.nextChange.hour);
    final count = d.result.items.length;
    final covers = playlistCoverKeys(null, [for (final i in d.result.items) i.track?.coverKey]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap16, CcDims.margin, 0),
      child: Material(
        color: cc.surface1,
        borderRadius: BorderRadius.circular(CcDims.rCard),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: l.daylistCardLabel(count, name, time),
                excludeSemantics: true,
                onTap: () => ShellNav.open<void>(context, const DaylistScreen()),
                child: InkWell(
                  key: const ValueKey('daylist-card'),
                  onTap: () => ShellNav.open<void>(context, const DaylistScreen()),
                  child: Padding(
                    padding: const EdgeInsets.all(CcDims.gap12),
                    child: Row(
                      children: [
                        PlaylistCover(size: 88, radius: CcDims.rList, coverKeys: covers),
                        const SizedBox(width: CcDims.gap12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.daylistNow, style: text.bodySmall?.copyWith(color: cc.accentSoft)),
                              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodyLarge),
                              Text(
                                l.daylistCardMeta(count, time),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall?.copyWith(color: cc.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: CcDims.gap12),
              child: PlayCircleButton(
                size: 48,
                tooltip: l.daylistPlay,
                onPressed: () => ref.read(daylistActionsProvider).play(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
