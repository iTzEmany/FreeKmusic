import 'package:flutter/material.dart';

import '../../l10n/l10n_ext.dart';
import '../theme/tokens.dart';

/// What a dragged row carries: the ids are worked out when the drop happens
/// (the whole selection if the row was part of it, otherwise just that track).
class TrackDragData {
  const TrackDragData(this.resolve);

  final List<int> Function() resolve;
}

/// The small label that follows the pointer while tracks are dragged.
class DragPill extends StatelessWidget {
  const DragPill({super.key, required this.countOf});

  final int Function() countOf;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return Material(
      color: cc.accent,
      elevation: 6,
      borderRadius: BorderRadius.circular(CcDims.rCard),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: CcDims.gap8),
        child: Text(
          context.l10n.tracksCount(countOf()),
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: cc.onAccent),
        ),
      ),
    );
  }
}

/// A place where dragged tracks can be dropped (a playlist of the sidebar):
/// it lights up while a drag is over it.
class TrackDropTarget extends StatelessWidget {
  const TrackDropTarget({super.key, required this.onDrop, required this.child});

  final void Function(List<int> ids) onDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return DragTarget<TrackDragData>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => onDrop(d.data.resolve()),
      builder: (context, over, _) => DecoratedBox(
        key: over.isEmpty ? null : const ValueKey('drop-target-over'),
        decoration: BoxDecoration(
          color: over.isEmpty ? null : cc.accent.withValues(alpha: 0.2),
          border: over.isEmpty
              ? null
              : Border.all(color: cc.accent, width: 1.5),
          borderRadius: BorderRadius.circular(CcDims.rGrid),
        ),
        child: child,
      ),
    );
  }
}
