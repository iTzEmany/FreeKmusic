import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/selection_providers.dart';
import '../../widgets/selection_bar.dart';

/// The one wiring of the online pages' picks: a [SelectionScope] over [ids]
/// (the places of the songs in the list) and, while something is picked, the
/// bar with ✕, count and select all, plus the [actions] it is given.
/// [overlay] puts the bar over the page's top (artist, album pages); otherwise
/// it sits above [child] and pushes it down (the search results).
class OnlineSelectionScope extends ConsumerWidget {
  const OnlineSelectionScope({
    super.key,
    required this.selectionKey,
    required this.ids,
    required this.actions,
    required this.child,
    this.overlay = false,
  });

  final String selectionKey;
  final List<int> ids;
  final List<Widget> Function(Selection picked) actions;
  final Widget child;
  final bool overlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picked = ref.watch(selectionProvider(selectionKey));
    final notifier = ref.read(selectionProvider(selectionKey).notifier);
    final bar = picked.active
        ? SelectionBarFrame(
            count: picked.count,
            belowStatusBar: overlay,
            onClose: notifier.clear,
            onSelectAll: () => notifier.selectAll(ids),
            actions: actions(picked),
          )
        : null;
    return SelectionScope(
      listKey: selectionKey,
      visibleIds: ids,
      child: overlay
          ? Stack(children: [
              Positioned.fill(child: child),
              if (bar != null) Positioned(top: 0, left: 0, right: 0, child: bar),
            ])
          : Column(children: [?bar, Expanded(child: child)]),
    );
  }
}

/// How one online song row reads the picks of list [selectionKey]: the song
/// is id [index] of it. With [play] (what a plain tap does) [onTap] is always
/// set and also takes Ctrl and Shift + click, as the local rows do.
({
  bool selecting,
  bool selected,
  int? position,
  VoidCallback? onTap,
  VoidCallback onLongPress,
}) watchOnlinePick(
  WidgetRef ref,
  String selectionKey,
  int index, {
  VoidCallback? play,
}) {
  final picked = ref.watch(selectionProvider(selectionKey));
  final notifier = ref.read(selectionProvider(selectionKey).notifier);
  void tap() {
    final keys = HardwareKeyboard.instance;
    final shift = keys.isShiftPressed;
    if (!picked.active && !shift && !keys.isControlPressed && !keys.isMetaPressed) {
      return play?.call();
    }
    // shortcut: the places of a list are 0..n-1, so a range is every place between the anchor and this one; upgrade if a list skips places.
    shift
        ? notifier.selectRange([
            for (var i = 0; i <= math.max(index, picked.anchor ?? index); i++) i,
          ], index)
        : notifier.toggle(index);
  }

  return (
    selecting: picked.active,
    selected: picked.contains(index),
    position: picked.contains(index) ? picked.positionOf(index) + 1 : null,
    onTap: picked.active || play != null ? tap : null,
    onLongPress: () => notifier.toggle(index),
  );
}
