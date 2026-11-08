import '../../widgets/cc_sheet.dart';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/player_providers.dart';
import '../../../services/audio/online_entries.dart' show isOnlineId;
import '../../../providers/shuffle_plus_providers.dart'
    show shufflePlusPendingProvider;
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/confirm.dart';
import '../../widgets/dismiss_background.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/track_row.dart';
import 'suggestions_screen.dart';

/// The queue as a draggable modal sheet (Now Playing, desktop bar).
Future<void> showQueueSheet(BuildContext context) => showCcSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.7,
    maxChildSize: 0.95,
    builder: (_, sc) => QueueSheet(scrollController: sc),
  ),
);

/// «Coda»: the playing track and what comes next (already played tracks are
/// hidden). Rows reorder with the handle and dismiss with a swipe + undo.
class QueueSheet extends ConsumerStatefulWidget {
  const QueueSheet({
    super.key,
    required this.scrollController,
    this.showTitle = true,
  });

  final ScrollController scrollController;

  /// The desktop side panel already has its own «Coda» title.
  final bool showTitle;

  @override
  ConsumerState<QueueSheet> createState() => _QueueSheetState();
}

/// The part of the queue a list shows: the entries after the current one and
/// a key per entry (the same track may sit twice, so id + occurrence).
class _Upcoming {
  _Upcoming(this.first, this.tracks, this.keys);

  factory _Upcoming.of(List<Track> queue, int at) {
    final first = at >= 0 && at < queue.length ? at + 1 : 0;
    final tracks = queue.sublist(first);
    final seen = <int, int>{};
    return _Upcoming(first, tracks, [
      for (final t in tracks)
        'q-${t.id}-${seen[t.id] = (seen[t.id] ?? -1) + 1}',
    ]);
  }

  final int first;
  final List<Track> tracks;
  final List<String> keys;
}

/// Where the entry [key] must go in [live] so that it sits where the user
/// dropped it in [dropped] (the order the drag showed), as `(from, to)` queue
/// indices for a move; null when the entry is gone or already there. Anchors
/// on the neighbours that still exist, so entries added or removed while the
/// drag lasted do not shift the drop.
({int from, int to})? mapDrop({
  required String key,
  required List<String> dropped,
  required List<String> live,
  required int first,
}) {
  final from = live.indexOf(key);
  if (from < 0) return null;
  final at = dropped.indexOf(key);
  final rest = [...live]..removeAt(from);
  var to = rest.length;
  final liveSet = rest.toSet();
  for (var i = at + 1; i < dropped.length; i++) {
    if (liveSet.contains(dropped[i])) {
      to = rest.indexOf(dropped[i]);
      break;
    }
  }
  if (to == rest.length) {
    // Nothing after it any more: sit right behind the nearest survivor.
    for (var i = at - 1; i >= 0; i--) {
      if (liveSet.contains(dropped[i])) {
        to = rest.indexOf(dropped[i]) + 1;
        break;
      }
    }
  }
  if (to == from) return null;
  return (from: first + from, to: first + to);
}

class _QueueSheetState extends ConsumerState<QueueSheet> {
  /// What the list showed when the drag started. While [_dragging] the list
  /// keeps showing it: the queue may change under the finger (an import, a
  /// suggestion) and the list must not be rebuilt with other items then.
  _Upcoming? _dragSnapshot;
  bool _dragging = false;
  List<Track> _lastQueue = const [];

  Widget _queueItem(
    int i,
    List<Track> upcoming,
    List<String> keys,
    int first,
    int queueLength,
    Set<int> enriching,
  ) {
    final ctrl = ref.read(playerControllerProvider);
    final l = context.l10n;
    final cc = context.cc;
    final t = upcoming[i];
    return Dismissible(
      key: ValueKey(keys[i]),
      background: const DismissBackground(),
      secondaryBackground: const DismissBackground(alignEnd: true),
      onDismissed: (_) async {
        await ctrl.removeFromQueue(first + i);
        if (!mounted) return;
        showUndoSnack(context, l.removedFromQueue, () {
          ctrl.addToQueue(t.id);
          final n = ref.read(queueProvider).value?.length ?? queueLength;
          ctrl.reorderQueue(n - 1, first + i);
        });
      },
      child: Material(
        color: cc.surface1.withValues(alpha: 0),
        child: SizedBox(
          height: trackRowExtentOf(context, false),
          // A suggestion still being enriched: its title and cover may change.
          child: Opacity(
            opacity: enriching.contains(t.id) ? 0.6 : 1,
            child: LiveTrackRow(
              track: t,
              variant: TrackRowVariant.queue,
              reorderIndex: i,
              onTap: () => ctrl.jumpToQueueIndex(first + i),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final scrollController = widget.scrollController;
    final showTitle = widget.showTitle;
    final l = context.l10n;
    // Rebuild only when the list really changed, not on every queue event.
    final queue = ref.watch(
      queueProvider.select((q) {
        final next = q.value ?? const <Track>[];
        return listEquals(_lastQueue, next) ? _lastQueue : _lastQueue = next;
      }),
    );
    ref.watch(currentTrackProvider.select((t) => t.value?.id));
    final pending = ref.watch(shufflePlusPendingProvider);
    final similar = ref.watch(similarSeedProvider);
    final ctrl = ref.read(playerControllerProvider);
    if (queue.isEmpty) {
      return EmptyState(icon: Icons.queue_music_rounded, message: l.emptyQueue);
    }
    final at = ref.read(audioHandlerProvider).currentIndex;
    final current = at >= 0 && at < queue.length ? queue[at] : null;
    final liveUp = _Upcoming.of(queue, at);
    final shown = _dragging && _dragSnapshot != null ? _dragSnapshot! : liveUp;
    final first = shown.first;
    final upcoming = shown.tracks;
    final keys = shown.keys;

    // What follows is built again from the playlist (album, …) playing:
    // in order from here, or a new shuffle.
    void clearNext() {
      final rebuilt = ctrl.hasQueueSource;
      final before = ctrl.rebuildUpcoming();
      if (before == null) return;
      showUndoSnack(
        context,
        rebuilt ? l.queueRebuilt : l.queueCleared,
        () => ctrl.restoreQueue(before),
      );
    }

    return Column(
      children: [
        _QueueTitleRow(
          showTitle: showTitle,
          hasUpcoming: upcoming.isNotEmpty,
          onClear: clearNext,
        ),
        Expanded(
          child: ReorderableListView.builder(
            scrollController: scrollController,
            buildDefaultDragHandles: false,
            proxyDecorator: (child, _, anim) =>
                ccDragProxy(context, child, anim),
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (current != null) ...[
                  SectionHeader(l.queueNowPlaying),
                  SizedBox(
                    height: trackRowExtentOf(context, false),
                    child: LiveTrackRow(
                      track: current,
                      onTap: ctrl.togglePlayPause,
                    ),
                  ),
                ],
                if (similar != null)
                  _SimilarHeader(
                    title: similar.title,
                    loading: similar.loading,
                    total: upcoming.length,
                    owned: upcoming.where((t) => !isOnlineId(t.id)).length,
                  )
                else if (upcoming.isNotEmpty)
                  SectionHeader(l.queueNext),
              ],
            ),
            // Rows for the suggestions Shuffle+ is still choosing.
            footer: pending.incoming > 0
                ? Skeleton.list(
                    rows: pending.incoming,
                    rowHeight: trackRowExtentOf(context, false),
                    label: l.shufflePlusChoosing(pending.incoming),
                  )
                : similar?.loading ?? false
                ? Skeleton.list(
                    rows: 4,
                    rowHeight: trackRowExtentOf(context, false),
                    label: l.queueSimilarSearching,
                  )
                : null,
            itemCount: upcoming.length,
            onReorderStart: (_) => setState(() {
              _dragSnapshot = liveUp;
              _dragging = true;
            }),
            onReorderEnd: (_) {
              if (mounted) setState(() => _dragging = false);
            },
            onReorderItem: (from, to) {
              final snap = _dragSnapshot;
              if (snap == null || from < 0 || from >= snap.keys.length) return;
              final dropped = [...snap.keys];
              dropped.insert(
                to.clamp(0, dropped.length - 1),
                dropped.removeAt(from),
              );
              // Map by entry, against the queue as it is now.
              final liveNow = _Upcoming.of(
                ref.read(queueProvider).value ?? const <Track>[],
                ref.read(audioHandlerProvider).currentIndex,
              );
              final move = mapDrop(
                key: snap.keys[from],
                dropped: dropped,
                live: liveNow.keys,
                first: liveNow.first,
              );
              if (move != null) ctrl.reorderQueue(move.from, move.to);
            },
            itemBuilder: (_, i) => _queueItem(
              i,
              upcoming,
              keys,
              first,
              queue.length,
              pending.enriching,
            ),
          ),
        ),
      ],
    );
  }
}

/// «Simili a «brano»» with the radio tag, and under it the count, or
/// «Cerco i brani simili…» while the first block comes (mockup, D-453).
class _SimilarHeader extends StatelessWidget {
  const _SimilarHeader({
    required this.title,
    required this.loading,
    required this.total,
    required this.owned,
  });

  final String title;
  final bool loading;
  final int total, owned;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CcDims.margin,
        20,
        CcDims.margin,
        CcDims.gap8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.queueSimilarTo(title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleMedium,
                ),
              ),
              Text(l.queueSimilarTag, style: theme.labelSmall),
            ],
          ),
          Text(
            loading ? l.queueSimilarSearching : l.queueSimilarCount(total, owned),
            style: theme.bodySmall?.copyWith(color: cc.textMuted),
          ),
        ],
      ),
    );
  }
}

class _QueueTitleRow extends StatelessWidget {
  const _QueueTitleRow({
    required this.showTitle,
    required this.hasUpcoming,
    required this.onClear,
  });

  final bool showTitle;
  final bool hasUpcoming;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CcDims.margin,
        CcDims.gap4,
        CcDims.gap8,
        0,
      ),
      child: LayoutBuilder(
        builder: (context, box) => Row(
          children: [
            Expanded(
              child: showTitle
                  ? Text(
                      l.queue,
                      style: Theme.of(context).textTheme.titleMedium,
                    )
                  : const SizedBox.shrink(),
            ),
            if (hasUpcoming)
              TextButton(onPressed: onClear, child: Text(l.queueClear)),
            // Intrinsic width; the cap only guards against overflow.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * 0.5),
              child: TextButton(
                onPressed: () => openSuggestions(context),
                child: Text(
                  l.suggestionsRecentTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
