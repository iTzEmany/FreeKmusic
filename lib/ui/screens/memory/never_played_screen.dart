import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/memory_providers.dart';
import '../../../providers/selection_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/selection_bar.dart';
import '../../widgets/track_row.dart';
import '../../widgets/track_row_selection.dart';
import '../../widgets/async_body.dart';
import '../../widgets/cc_app_bar.dart';

/// Memoria → «Mai ascoltati»: music with no listen at all, the biggest first.
/// Picking tracks offers the usual bulk actions, «Elimina dal dispositivo»
/// included.
class NeverPlayedScreen extends ConsumerWidget {
  const NeverPlayedScreen({super.key});

  static final _key = SelectionKey.neverPlayed.key;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tracks = ref.watch(neverPlayedTracksProvider);
    final compact = ref.watch(settingsProvider).compactMode;
    final ctrl = ref.read(playerControllerProvider);
    final shown = tracks.value ?? const <Track>[];
    final selection = RowSelection(
      listKey: _key,
      visibleIds: [for (final t in shown) t.id],
    );
    final extent = trackRowExtentOf(context, compact);
    return SelectionScope(
      listKey: _key,
      visibleIds: selection.visibleIds,
      child: Scaffold(
        appBar: SelectableAppBar(
          listKey: _key,
          tracks: shown,
          normal: CcAppBar(title: l.memoryNeverPlayed),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: AsyncBody(
              value: tracks,
              onRetry: () => ref.invalidate(neverPlayedTracksProvider),
              data: (list) => list.isEmpty
                  ? EmptyState(
                      icon: Icons.headphones_rounded,
                      message: l.memoryNeverPlayedNone,
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(CcDims.margin),
                          child: Text(
                            l.memoryNeverPlayedHint,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: context.cc.textMuted),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.zero.withDock(context),
                            itemCount: list.length,
                            itemExtent: extent,
                            itemBuilder: (_, i) => LiveTrackRow(
                              track: list[i],
                              compact: compact,
                              selection: selection,
                              onTap: () => ctrl.playFromList(list, i),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
