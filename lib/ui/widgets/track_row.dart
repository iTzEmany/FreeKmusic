import 'dart:math' as math;

import '../../services/audio/online_entries.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/player_providers.dart';
import '../../core/platform.dart';
import '../../providers/selection_providers.dart';
import '../theme/app_theme.dart' show ccIconDensity;
import '../theme/tokens.dart';
import 'cover_image.dart';
import 'favorite_actions.dart';
import 'format_utils.dart';
import 'progress_frame.dart';
import 'ring_progress.dart' show NowPlayingDot;
import 'online_queue_row.dart';
import 'preview_cover.dart';
import 'track_actions.dart';
import 'track_drag.dart';
import 'track_row_selection.dart';
import 'motion.dart';
import 'show_msg.dart';

enum TrackRowVariant {
  /// Cover, title, «artist · album».
  standard,

  /// Track number instead of the cover; artist only when it differs.
  album,

  /// Drag handle on the right (needs [TrackRow.reorderIndex]).
  queue,

  /// Round ＋/✓ on the right (selection lists).
  pick,
}

/// The only track row of the app. Fixed height: pair it with `itemExtent`
/// from `trackRowExtentOf`.
class TrackRow extends StatefulWidget {
  const TrackRow({
    super.key,
    required this.track,
    required this.onTap,
    this.variant = TrackRowVariant.standard,
    this.isCurrent = false,
    this.isPlaying = false,
    this.compact = false,
    this.onMore,
    this.onFavorite,
    this.onLongPress,
    this.onSecondaryTap,
    this.index,
    this.albumArtist,
    this.picked = false,
    this.reorderIndex,
    this.selectionMode = false,
    this.selected = false,
    this.selectedPosition,
    this.subtitleSuffix,
    this.albumAsSubtitle = false,
    this.inLibrary = false,
  });

  final Track track;
  final VoidCallback onTap;
  final TrackRowVariant variant;
  final bool isCurrent, isPlaying, compact, picked;

  /// Queue variant: the song is in the library (check circle before the handle).
  final bool inLibrary;

  /// The list is in selection mode: a tick box replaces the cover or number,
  /// and a picked row ([selected]) is tinted. Same height either way.
  final bool selectionMode, selected;

  /// Place of a picked row in the order of the picks (1-based).
  final int? selectedPosition;

  /// Appended to the subtitle (the time of a listen in the history).
  final String? subtitleSuffix;

  /// The subtitle shows the album instead of the artist (artist page).
  final bool albumAsSubtitle;

  final VoidCallback? onMore, onFavorite, onLongPress;

  /// Right click on desktop; receives the global pointer position.
  final void Function(Offset position)? onSecondaryTap;

  /// 1-based position shown in the wide «#» column (track number if null).
  final int? index;

  /// Album variant: the artist is hidden when it equals this one.
  final String? albumArtist;

  /// Position inside a `ReorderableListView` for the drag handle.
  final int? reorderIndex;

  @override
  State<TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<TrackRow> {
  bool _hover = false;
  bool _focused = false;

  /// The wide row hides its ⋮ until the pointer is over it or focus is in it;
  /// a touch screen has no hover, so it always shows.
  bool _revealMore(BuildContext context) =>
      _hover ||
      _focused ||
      switch (Theme.of(context).platform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.fuchsia => true,
        _ => false,
      };

  String _subtitle(BuildContext context) {
    final t = widget.track;
    final parts = <String>[];
    switch (widget.variant) {
      case TrackRowVariant.album:
        final a = t.artist;
        if (a != null &&
            a.trim().toLowerCase() !=
                (widget.albumArtist ?? '').trim().toLowerCase()) {
          parts.add(a);
        }
      case _:
        final main = widget.albumAsSubtitle ? t.album : t.artist;
        if (main != null) parts.add(main);
    }
    final resume = t.resumePositionMs;
    if (resume != null) {
      parts.add(context.l10n.resumeFrom(formatDuration(resume)));
    }
    if (widget.subtitleSuffix != null) parts.add(widget.subtitleSuffix!);
    return parts.join(', ');
  }

  Widget _leading(BuildContext context, double cover, {bool dot = true}) {
    final t = widget.track;
    if (widget.selectionMode) {
      return SelectionBox(
        selected: widget.selected,
        position: widget.selectedPosition,
        size: widget.variant == TrackRowVariant.album ? 32 : cover,
      );
    }
    if (widget.variant == TrackRowVariant.album) {
      final n = t.trackNumber;
      return SizedBox(
        width: 32,
        child: Center(
          // 2 dp ring around the number of the playing track.
          child: DecoratedBox(
            decoration: widget.isCurrent
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: context.cc.accent, width: 2),
                  )
                : const BoxDecoration(),
            child: SizedBox.square(
              dimension: 28,
              child: Center(
                child: Text(
                  n == null ? '' : '$n',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ),
        ),
      );
    }
    final plain = CoverImage(coverKey: t.coverKey, size: cover);
    // Hold the cover for a 20 s preview (not in selection lists).
    final image = widget.variant == TrackRowVariant.pick
        ? plain
        : PreviewCover(track: t, size: cover, child: plain);
    if (!widget.isCurrent || !dot) return image;
    // Progress frame 4 dp off the cover (D-25).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        image,
        Positioned(
          left: -4,
          top: -4,
          right: -4,
          bottom: -4,
          child: Semantics(
            label: context.l10n.nowPlaying,
            child: const LiveProgressFrame(),
          ),
        ),
      ],
    );
  }

  /// Wide rows end with [heart slot] [duration] [more slot]: fixed widths so
  /// the columns line up whether or not the actions are visible.
  Widget _wideTail(BuildContext context) {
    final cc = context.cc;
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final fav = widget.track.isFavorite;
    final showHeart = _hover || fav;
    if (widget.variant == TrackRowVariant.pick ||
        widget.variant == TrackRowVariant.queue) {
      return Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              formatDuration(widget.track.durationMs),
              textAlign: TextAlign.end,
              style: theme.labelSmall,
            ),
          ),
          _trailing(context, true),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 40,
          child: showHeart && widget.onFavorite != null
              ? IconButton(
                  tooltip: fav ? l.removeFromFavorites : l.favorite,
                  onPressed: widget.onFavorite,
                  visualDensity: ccIconDensity,
                  icon: HeartIcon(
                    favorite: fav,
                    size: 18,
                    color: fav ? cc.accent : cc.textMuted,
                  ),
                )
              : null,
        ),
        SizedBox(
          width: 56,
          child: Text(
            formatDuration(widget.track.durationMs),
            textAlign: TextAlign.center,
            style: theme.labelSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: widget.onMore == null
              ? null
              : _moreButton(context, visible: _revealMore(context)),
        ),
      ],
    );
  }

  /// The ⋮; hidden it is out of semantics and focus, and always >= 48 dp to hit.
  Widget _moreButton(BuildContext context, {required bool visible}) {
    if (!visible) return const SizedBox(width: 48, height: 48);
    return IconButton(
      tooltip: context.l10n.moreOptions,
      onPressed: widget.onMore,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(Icons.more_vert_rounded, color: context.cc.textMuted),
    );
  }

  Widget _trailing(BuildContext context, bool wide) {
    final cc = context.cc;
    final l = context.l10n;
    final fav = widget.track.isFavorite;
    switch (widget.variant) {
      case TrackRowVariant.pick:
        return Padding(
          padding: const EdgeInsets.only(left: CcDims.gap8),
          child: Icon(
            widget.picked
                ? Icons.check_circle_rounded
                : Icons.add_circle_outline_rounded,
            color: widget.picked ? cc.accent : cc.textMuted,
          ),
        );
      case TrackRowVariant.queue:
        final i = widget.reorderIndex;
        final handle = Icon(Icons.drag_handle_rounded, color: cc.textMuted);
        // Hidden from TalkBack: the list already offers move actions on the row.
        final grip = ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(left: CcDims.gap8),
            child: i == null
                ? handle
                : ReorderableDragStartListener(index: i, child: handle),
          ),
        );
        if (!widget.inLibrary) return grip;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: CcDims.gap8),
              child: Icon(
                Icons.check_circle_rounded,
                color: cc.accentSoft,
                semanticLabel: l.ytAlreadyInLibrary,
              ),
            ),
            grip,
          ],
        );
      case _:
    }
    final showActions = !wide || _revealMore(context) || fav;
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (wide && (_hover || fav) && widget.onFavorite != null)
          IconButton(
            tooltip: fav ? l.removeFromFavorites : l.favorite,
            onPressed: widget.onFavorite,
            visualDensity: ccIconDensity,
            icon: Icon(
              fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 18,
              color: fav ? cc.accent : cc.textMuted,
            ),
          )
        else if (fav)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CcDims.gap4),
            child: Icon(Icons.favorite_rounded, size: 16, color: cc.accent),
          ),
        if (widget.onMore != null) _moreButton(context, visible: showActions),
      ],
    );
    // Same width whether or not the actions show, so the columns line up.
    return wide
        ? SizedBox(
            width: 96,
            child: Align(alignment: Alignment.centerRight, child: actions),
          )
        : actions;
  }

  /// Columns (# · title · album · duration) only when the row itself is wide
  /// enough: the desktop side panel is 320 px inside a wide window.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => _row(
      context,
      MediaQuery.sizeOf(context).width >= CcDims.wideBreakpoint &&
          c.maxWidth >= 520,
    ),
  );

  Widget _row(BuildContext context, bool wide) {
    final cc = context.cc;
    final theme = Theme.of(context);
    final t = widget.track;
    final subtitle = _subtitle(context);
    final cover = widget.compact ? 40.0 : 48.0;
    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
      color: widget.isCurrent ? cc.accent : cc.text,
    );

    final titleBlock = ExcludeSemantics(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
        ],
      ),
    );

    final Widget row;
    if (wide && widget.variant != TrackRowVariant.pick) {
      final num = widget.variant == TrackRowVariant.album
          ? t.trackNumber
          : widget.index;
      row = Row(
        children: [
          SizedBox(
            width: 40,
            child: widget.selectionMode
                ? SelectionBox(
                    selected: widget.selected,
                    position: widget.selectedPosition,
                    size: 40,
                  )
                : widget.isCurrent
                ? Center(child: const NowPlayingDot())
                : Center(
                    child: Text(
                      num == null ? '' : '$num',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
          ),
          if (widget.variant != TrackRowVariant.album) ...[
            // The dot already sits in the number column.
            if (widget.selectionMode)
              CoverImage(coverKey: t.coverKey, size: cover)
            else
              _leading(context, cover, dot: false),
            const SizedBox(width: 12),
          ],
          Expanded(flex: 5, child: titleBlock),
          if (widget.variant != TrackRowVariant.album) ...[
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                t.album ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
          _wideTail(context),
        ],
      );
    } else {
      row = Row(
        children: [
          _leading(context, cover),
          const SizedBox(width: 12),
          Expanded(child: titleBlock),
          if (widget.variant == TrackRowVariant.album)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: CcDims.gap8),
              child: Text(
                formatDuration(t.durationMs),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          _trailing(context, false),
        ],
      );
    }

    final tint = widget.selected
        ? cc.accentSoft.withValues(alpha: 0.16)
        : _hover && wide
        ? cc.surface2.withValues(alpha: 0.5)
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) => setState(() => _focused = f),
        child: Semantics(
          // One node named by title and artist (no empty twin: the cover's long press used to split it).
          button: true,
          label: subtitle.isEmpty ? t.title : '${t.title}, $subtitle',
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          selected: widget.selectionMode ? widget.selected : null,
          value: widget.selected
              ? (widget.selectedPosition == null
                    ? context.l10n.selectedRow
                    : context.l10n.selectedRowAt(widget.selectedPosition!))
              : null,
          child: GestureDetector(
            // Right click only: its empty semantics tap would be TalkBack's.
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            onSecondaryTapDown: widget.onSecondaryTap == null
                ? null
                : (d) => widget.onSecondaryTap!(d.globalPosition),
            child: Material(
              color: tint,
              child: InkWell(
                excludeFromSemantics: true,
                onTap: widget.onTap,
                onLongPress: widget.onLongPress,
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    // «Quaderno» row: 1 dp hairline in surface2 from the text on.
                    Positioned(
                      left:
                          CcDims.margin +
                          (wide || widget.variant == TrackRowVariant.album
                              ? 0
                              : cover + 12),
                      right: CcDims.margin,
                      bottom: 0,
                      height: 1,
                      child: ColoredBox(color: cc.separator),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CcDims.margin,
                      ),
                      child: row,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rebuilds only when this row's «current / playing» state changes.
class LiveTrackRow extends ConsumerWidget {
  const LiveTrackRow({
    super.key,
    required this.track,
    required this.onTap,
    this.variant = TrackRowVariant.standard,
    this.compact = false,
    this.index,
    this.albumArtist,
    this.onMore,
    this.lead,
    this.reorderIndex,
    this.selection,
    this.subtitleSuffix,
    this.albumAsSubtitle = false,
    this.inLibrary = false,
    this.current,
  });

  /// Decides «is the playing one» when the list knows better than the id
  /// (a queue row is never the current entry); null: by id.
  final bool? current;

  final Track track;
  final VoidCallback onTap;
  final TrackRowVariant variant;
  final bool compact, inLibrary;
  final bool albumAsSubtitle;

  final int? index;
  final String? albumArtist;

  /// Makes the row pickable together with the others of its list (long press
  /// on a phone, Ctrl or Shift + click on a desktop).
  final RowSelection? selection;
  final String? subtitleSuffix;

  /// Replaces the default actions sheet.
  final VoidCallback? onMore;

  /// First entry of the track sheet (e.g. «Rimuovi dalla playlist»).
  final TrackAction? lead;
  final int? reorderIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isOnlineId(track.id)) {
      return OnlineQueueRow(
        track: track,
        onTap: onTap,
        reorderIndex: reorderIndex,
        current: current,
      );
    }
    final byId = ref.watch(
      currentTrackProvider.select((t) => t.value?.id == track.id),
    );
    final isCurrent = current ?? byId;
    final playing = isCurrent && (ref.watch(isPlayingProvider).value ?? false);
    void actions() => showTrackActions(context, ref, track, lead: lead);
    final sel = selection;
    final (active, position) = sel == null
        ? (false, -1)
        : ref.watch(
            selectionProvider(sel.listKey)
                .select((s) => (s.active, s.positionOf(track.id))),
          );
    final picked = position >= 0;
    void tap() {
      if (sel == null) return onTap();
      final keys = HardwareKeyboard.instance;
      final shift = keys.isShiftPressed;
      if (!active && !shift && !keys.isControlPressed && !keys.isMetaPressed) {
        return onTap();
      }
      final notifier = ref.read(selectionProvider(sel.listKey).notifier);
      shift
          ? notifier.selectRange(sel.visibleIds, track.id)
          : notifier.toggle(track.id);
    }

    // A phone picks with a long press; a desktop keeps the menu there.
    final phone = switch (Theme.of(context).platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => true,
      _ => false,
    };
    void longPress() {
      if (sel == null || !phone) return actions();
      HapticFeedback.selectionClick();
      ref.read(selectionProvider(sel.listKey).notifier).toggle(track.id);
    }

    final row = TrackRow(
      track: track,
      variant: variant,
      isCurrent: isCurrent,
      isPlaying: playing,
      onTap: tap,
      onMore: onMore ?? actions,
      onLongPress: longPress,
      selectionMode: active,
      selected: picked,
      selectedPosition: picked ? position + 1 : null,
      subtitleSuffix: subtitleSuffix,
      albumAsSubtitle: albumAsSubtitle,
      inLibrary: inLibrary,
      onSecondaryTap: (_) => actions(),
      onFavorite: () => toggleFavorite(context, ref, track),
      compact: compact,
      index: index,
      albumArtist: albumArtist,
      reorderIndex: reorderIndex,
    );
    // On a desktop a row can be dragged onto a playlist of the sidebar: the
    // whole selection (in the order of the picks) when the row is part of it,
    // otherwise just this track.
    Widget draggable(Widget child) {
      if (sel == null || !isDesktop) return child;
      List<int> ids() {
        final s = ref.read(selectionProvider(sel.listKey));
        return s.active && s.contains(track.id) ? s.orderedIds : [track.id];
      }

      return Draggable<TrackDragData>(
        data: TrackDragData(ids),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: DragPill(countOf: () => ids().length),
        child: child,
      );
    }

    // Queue and pick rows have their own gestures.
    if (variant == TrackRowVariant.queue || variant == TrackRowVariant.pick) {
      return row;
    }
    if (active) return draggable(row);
    return SwipeToQueue(
      swipeKey: 'swipe-queue-${track.id}',
      onQueue: () async {
        final added = await ref
            .read(playerControllerProvider)
            .addToQueue(track.id);
        if (context.mounted) showQueued(context, added);
      },
      child: draggable(row),
    );
  }
}

/// A swipe to the right that asks to queue [child]'s song; the row always
/// comes back. One that starts at the left edge belongs to the system back
/// gesture and does nothing (D-59).
class SwipeToQueue extends StatelessWidget {
  const SwipeToQueue({
    super.key,
    required this.swipeKey,
    required this.onQueue,
    required this.child,
  });

  final String swipeKey;
  final VoidCallback onQueue;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final edge = math.max(48.0, media.systemGestureInsets.left + 24);
    return Listener(
      onPointerDown: (e) => _lastDownX = e.position.dx,
      child: Dismissible(
        key: ValueKey(swipeKey),
        direction: DismissDirection.startToEnd,
        dismissThresholds: const {DismissDirection.startToEnd: 0.3},
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: CcDims.gap24),
          color: context.cc.surface2,
          child: Icon(Icons.queue_rounded, color: context.cc.accentSoft),
        ),
        confirmDismiss: (_) async {
          if (_lastDownX >= edge) onQueue();
          return false;
        },
        child: child,
      ),
    );
  }
}

/// Global x of the latest pointer-down: the one that started the swipe.
// shortcut: one shared x for all rows, a second finger during a swipe overwrites it; per-pointer tracking if it ever matters.
double _lastDownX = double.infinity;
