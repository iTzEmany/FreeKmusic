import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/nav_providers.dart';
import '../../providers/player_providers.dart';
import '../../services/audio/online_entries.dart' show isOnlineId;
import '../screens/lyrics/lyrics_screen.dart';
import '../screens/now_playing/now_playing_cards.dart';
import '../screens/now_playing/queue_sheet.dart';
import '../theme/tokens.dart';

/// 320 px column on the right: queue, lyrics or track info.
class SidePanelView extends ConsumerStatefulWidget {
  const SidePanelView({super.key, required this.panel});

  final SidePanel panel;

  @override
  ConsumerState<SidePanelView> createState() => _SidePanelViewState();
}

class _SidePanelViewState extends ConsumerState<SidePanelView> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final track =
        ref.watch(liveCurrentTrackProvider).value ??
        ref.watch(currentTrackProvider).value;
    // A streamed track shows the info of its shadow row (real id).
    final info = track != null && isOnlineId(track.id) ? ref.watch(currentShadowRowProvider) : track;
    final title = switch (widget.panel) {
      SidePanel.queue => l.queue,
      SidePanel.lyrics => l.lyrics,
      SidePanel.info => l.trackInfo,
      SidePanel.none => '',
    };
    final Widget body = switch (widget.panel) {
      SidePanel.queue => QueueSheet(
        scrollController: _scroll,
        showTitle: false,
      ),
      SidePanel.lyrics => const LyricsScreen(embedded: true),
      SidePanel.info =>
        info == null
            // A streamed track waits for its row (D-350); nothing for a radio or no track.
            ? track == null || ref.watch(onlineEntriesProvider)?.isRadioId(track.id) == true
                  ? const SizedBox.shrink()
                  : StreamCardsWait(key: ValueKey(track.id), infoOnly: true)
            : ListView(
                padding: const EdgeInsets.all(CcDims.gap12),
                children: [InfoCard(track: info)],
              ),
      SidePanel.none => const SizedBox.shrink(),
    };
    return SizedBox(
      width: MediaQuery.sizeOf(context).width >= CcDims.xlBreakpoint
          ? CcDims.sidePanelWidthXl
          : CcDims.sidePanelWidth,
      child: Material(
        color: cc.surface1,
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: l.close,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: ref.read(sidePanelProvider.notifier).close,
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
