import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/nav_providers.dart';
import '../../providers/selection_providers.dart';
import '../theme/tokens.dart';
import 'bulk_actions.dart';
import 'track_actions.dart';
import 'action_catalog.dart';

/// The bar that takes the place of a page's header while tracks are picked:
/// «N selezionati», select all, ✕, the quick actions and the full menu.
class SelectionBar extends ConsumerWidget implements PreferredSizeWidget {
  const SelectionBar({
    super.key,
    required this.listKey,
    required this.tracks,
    this.bulk = const BulkContext(),
    this.belowStatusBar = true,
  });

  final String listKey;

  /// Every track the list shows, in order.
  final List<Track> tracks;
  final BulkContext bulk;

  /// False when the bar is not at the very top of the screen.
  final bool belowStatusBar;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final selection = ref.watch(selectionProvider(listKey));
    final notifier = ref.read(selectionProvider(listKey).notifier);
    // In the order of the picks, not of the list; a pick the list no longer
    // shows (a filter) is left out.
    final byId = {for (final t in tracks) t.id: t};
    final picked = [
      for (final id in selection.orderedIds)
        if (byId[id] != null) byId[id]!,
    ];
    final groups = bulkActions(
      context,
      ref,
      picked,
      bulk,
      done: notifier.clear,
    );
    // The two most used actions stay in the bar, the rest are in the menu.
    final quick = [
      for (final g in groups)
        for (final a in g.actions)
          if (a.icon == Icons.playlist_add_rounded ||
              a.icon == Icons.favorite_rounded ||
              a.icon == Icons.favorite_border_rounded)
            a,
    ];
    return LayoutBuilder(
      builder: (context, c) {
        // With big text or a narrow bar the quick actions go into the menu, so
        // the count keeps room to be read.
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final roomy = c.maxWidth / scale >= 340;
        return SelectionBarFrame(
          count: selection.count,
          belowStatusBar: belowStatusBar,
          onClose: notifier.clear,
          onSelectAll: () => notifier.selectAll([for (final t in tracks) t.id]),
          actions: [
            if (roomy)
              for (final a in quick)
                IconButton(
                  tooltip: a.label,
                  icon: Icon(a.icon),
                  onPressed: picked.isEmpty ? null : a.run,
                ),
            IconButton(
              tooltip: l.bulkActions,
              icon: Icon(CatalogAction.more.icon),
              onPressed: picked.isEmpty
                  ? null
                  : () => showTrackActionGroups(
                      context,
                      groups,
                      title: l.selectedCount(selection.count),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// The bar itself: ✕, «N selezionati», select all, then [actions].
class SelectionBarFrame extends StatelessWidget {
  const SelectionBarFrame({
    super.key,
    required this.count,
    required this.onClose,
    required this.onSelectAll,
    required this.actions,
    this.belowStatusBar = true,
  });

  final int count;
  final VoidCallback onClose, onSelectAll;
  final List<Widget> actions;
  final bool belowStatusBar;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Material(
      color: context.cc.surface2,
      child: SafeArea(
        top: belowStatusBar,
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              IconButton(
                tooltip: l.exitSelection,
                icon: const Icon(Icons.close_rounded),
                onPressed: onClose,
              ),
              Expanded(
                child: Text(
                  l.selectedCount(count),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: l.selectAll,
                icon: const Icon(Icons.select_all_rounded),
                onPressed: onSelectAll,
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

/// The [SelectionBar] while something is picked, nothing otherwise: for pages
/// that lay the bar over their own header.
class SelectionBarSlot extends ConsumerWidget {
  const SelectionBarSlot({
    super.key,
    required this.listKey,
    required this.tracks,
    this.bulk = const BulkContext(),
    this.belowStatusBar = true,
  });

  final String listKey;
  final List<Track> tracks;
  final BulkContext bulk;
  final bool belowStatusBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      selectionProvider(listKey).select((s) => s.active),
    );
    return active
        ? SelectionBar(
            listKey: listKey,
            tracks: tracks,
            bulk: bulk,
            belowStatusBar: belowStatusBar,
          )
        : const SizedBox.shrink();
  }
}

/// An app bar that turns into the [SelectionBar] while tracks are picked.
class SelectableAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const SelectableAppBar({
    super.key,
    required this.listKey,
    required this.tracks,
    required this.normal,
    this.bulk = const BulkContext(),
  });

  final String listKey;
  final List<Track> tracks;
  final PreferredSizeWidget normal;
  final BulkContext bulk;

  @override
  Size get preferredSize => normal.preferredSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      selectionProvider(listKey).select((s) => s.active),
    );
    return active
        ? SelectionBar(listKey: listKey, tracks: tracks, bulk: bulk)
        : normal;
  }
}

/// Wraps a list page: Back (phone) and Esc (desktop) leave the selection,
/// Ctrl+A picks everything shown, a filter that hides rows drops them from the
/// selection, and so does changing tab.
class SelectionScope extends ConsumerStatefulWidget {
  const SelectionScope({
    super.key,
    required this.listKey,
    required this.visibleIds,
    required this.child,
  });

  final String listKey;

  /// The ids the list shows now, in order.
  final List<int> visibleIds;
  final Widget child;

  @override
  ConsumerState<SelectionScope> createState() => _SelectionScopeState();
}

class _SelectionScopeState extends ConsumerState<SelectionScope> {
  bool _listening = false;

  SelectionNotifier get _notifier =>
      ref.read(selectionProvider(widget.listKey).notifier);

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _notifier.clear();
      return true;
    }
    final ctrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyA) {
      _notifier.selectAll(widget.visibleIds);
      return true;
    }
    return false;
  }

  void _listen(bool on) {
    if (on == _listening) return;
    _listening = on;
    if (on) {
      HardwareKeyboard.instance.addHandler(_onKey);
    } else {
      HardwareKeyboard.instance.removeHandler(_onKey);
    }
  }

  @override
  void didUpdateWidget(SelectionScope old) {
    super.didUpdateWidget(old);
    if (old.visibleIds != widget.visibleIds &&
        ref.read(selectionProvider(widget.listKey)).active) {
      final visible = widget.visibleIds.toSet();
      // Not while building: the selection is watched by the rows.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifier.retainWhere(visible);
      });
    }
  }

  @override
  void dispose() {
    _listen(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(
      selectionProvider(widget.listKey).select((s) => s.active),
    );
    ref.listen(navIndexProvider, (_, _) => _notifier.clear());
    // The handler is only kept while something is selected.
    _listen(active);
    return PopScope(
      canPop: !active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _notifier.clear();
      },
      child: widget.child,
    );
  }
}
