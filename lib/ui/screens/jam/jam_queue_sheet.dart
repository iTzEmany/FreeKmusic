import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/jam_providers.dart';
import '../../../providers/share_hub.dart';
import '../../../services/jam/jam_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/segmented_blocks.dart';
import 'jam_parts.dart';
import 'jam_track_info_screen.dart';

/// The shared queue as a draggable modal sheet, opened by the «Coda» button
/// (as the player's queue).
Future<void> showJamQueueSheet(BuildContext context) => showCcSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.7,
    maxChildSize: 0.95,
    builder: (_, sc) => JamQueueSheet(scrollController: sc),
  ),
);

/// The sheet: the queue in a scroll view of its own.
class JamQueueSheet extends StatelessWidget {
  const JamQueueSheet({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    controller: scrollController,
    slivers: const [JamQueueSliver()],
  );
}

/// Title and rows with ⋮ («Salta qui», «Rimuovi») and ≡ (drag to move): the
/// sheet's body, and the desktop's side panel.
class JamQueueSliver extends ConsumerStatefulWidget {
  const JamQueueSliver({super.key});

  @override
  ConsumerState<JamQueueSliver> createState() => _JamQueueSliverState();
}

class _JamQueueSliverState extends ConsumerState<JamQueueSliver> {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(jamProvider);
    final jam = s.jam;
    final ctrl = ref.read(jamProvider.notifier);
    final ownId = ref.read(shareHubProvider.notifier).deviceId ?? '';
    String owner(JamItem i) {
      if (i.ownerDeviceId == ownId) return l.jamYou;
      final n = jam?.nameOf(i.ownerDeviceId) ?? '';
      if (n.isNotEmpty) return n;
      return ctrl.seenName(i.ownerDeviceId) ?? (s.peerName.isEmpty ? l.jamGuest : s.peerName);
    }

    final together = jam?.mode == JamMode.together;
    final items = jam?.items ?? const <JamItem>[];
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CcDims.margin,
              CcDims.gap8,
              CcDims.margin,
              CcDims.gap4,
            ),
            child: Text(
              l.jamQueue,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CcDims.margin,
              CcDims.gap4,
              CcDims.margin,
              CcDims.gap8,
            ),
            child: _modeRow(l, s, ctrl),
          ),
        ),
        if (items.isEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 240,
              child: EmptyState(
                icon: Icons.queue_music_rounded,
                message: l.jamEmpty,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: CcDims.margin),
            sliver: SliverReorderableList(
              proxyDecorator: (child, _, anim) =>
                  ccDragProxy(context, child, anim),
              itemCount: items.length,
              onReorderItem: (from, to) => together
                  ? null
                  : ctrl.send(JamCommand.move(items[from].id, to)),
              itemBuilder: (_, i) {
                final it = items[i];
                final isCurrent = i == jam!.currentIndex;
                return JamQueueRow(
                  key: ValueKey(it.id),
                  item: it,
                  who: owner(it),
                  isCurrent: isCurrent,
                  index: i,
                  showHandle: !together,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => JamTrackInfoScreen(itemId: it.id),
                    ),
                  ),
                  onJump: () => ctrl.send(JamCommand.jump(it.id)),
                  // Host: any item; guest: only their own, not the playing one.
                  onRemove: s.isHost || (it.ownerDeviceId == ownId && !isCurrent)
                      ? () => ctrl.send(JamCommand.remove(it.id))
                      : null,
                );
              },
            ),
          ),
      ],
    );
  }

  /// Host: active choice; guest: read only, announced as such.
  Widget _modeRow(AppLocalizations l, JamUiState s, JamController ctrl) {
    final mode = s.jam?.mode ?? JamMode.host;
    final row = SegmentedBlocks<JamMode>(
      items: [
        BlockItem(value: JamMode.host, label: l.jamModeHost),
        BlockItem(value: JamMode.together, label: l.jamModeTogether),
      ],
      selected: mode,
      onChanged: (m) => ctrl.send(JamCommand.setMode(m)),
    );
    if (s.isHost) return row;
    final name = mode == JamMode.host ? l.jamModeHost : l.jamModeTogether;
    return Semantics(
      label: '$name. ${l.jamModeGuestHint}',
      excludeSemantics: true,
      child: IgnorePointer(child: Opacity(opacity: 0.6, child: row)),
    );
  }
}
