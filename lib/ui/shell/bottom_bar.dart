import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/jam_providers.dart';
import '../../providers/nav_providers.dart';
import '../../providers/player_providers.dart';
import '../../providers/ui_providers.dart';
import '../widgets/cc_search_field.dart';
import '../theme/tokens.dart';
import '../widgets/mini_player.dart';

class BottomBarItem {
  const BottomBarItem(this.icon, this.selectedIcon, this.label);

  final IconData icon, selectedIcon;
  final String label;
}

const _iconSize = 24.0;
const _tabTop = 8.0; // the icon sits at a fixed height, whatever the text scale
const _dotSize = 6.0;
// Small enough that the apex stays inside the dock's clip when the tabs are
// its top edge (no track playing).
const _dotLift = 4.0;

/// One block at the bottom: on Search the field, then the mini-player (when
/// something plays) and the always-labelled tabs, with a dot on the active
/// tab's icon. While the keyboard is up only the field shows.
class ShellDock extends ConsumerWidget {
  const ShellDock({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
    this.showPlayer = true,
    this.showSearch = kEnableYoutube,
  });

  final List<BottomBarItem> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool showPlayer;

  /// Search is online only: without YouTube there is no such tab (D-358).
  final bool showSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = context.cc;
    final track =
        ref.watch(liveCurrentTrackProvider).value ??
        ref.watch(currentTrackProvider).value;
    final hasPlayer =
        showPlayer &&
        (track != null || ref.watch(jamProvider.select((j) => j.active)));
    final field =
        ref.watch(searchBarProvider) && selected == NavTab.search.index;
    // 1 dp rule between two layers of the dock.
    final rule = [
      Divider(
        height: 1,
        thickness: 1,
        indent: CcDims.gap8,
        endIndent: CcDims.gap8,
        color: cc.separator,
      ),
      const SizedBox(height: CcDims.gap4),
    ];
    return _DockFrame(
      searching: field,
      // Both children are built here, not in the frame: the keyboard moving
      // rebuilds the frame only.
      field: const _SearchField(),
      layers: DockLayers(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (field) ...rule,
            if (hasPlayer) ...[const MiniPlayer(), ...rule],
            _Tabs(
              items: items,
              tabs: [
                for (var i = 0; i < items.length; i++)
                  if (showSearch || i != NavTab.search.index) i,
              ],
              selected: selected,
              onSelect: onSelect,
            ),
          ],
        ),
      ),
    );
  }
}

/// Marks the dock's lower layers (mini player and tabs): the box the player
/// opens from, which leaves out the Search field above.
class DockLayers extends StatelessWidget {
  const DockLayers({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// The only dock widget that follows the keyboard (it rebuilds on each frame
/// of its animation): lifts the dock over it and hides the layers under the
/// field, out of paint, taps and semantics.
class _DockFrame extends StatelessWidget {
  const _DockFrame({
    required this.searching,
    required this.field,
    required this.layers,
  });

  final bool searching;
  final Widget field, layers;

  @override
  Widget build(BuildContext context) {
    const m = CcDims.dockMargin;
    // The Scaffold does not lift its bottom bar: the field clears the
    // keyboard by itself.
    final keyboard = searching ? MediaQuery.viewInsetsOf(context).bottom : 0.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        m,
        m,
        m,
        CcDims.dockBottom + MediaQuery.paddingOf(context).bottom + keyboard,
      ),
      // Material (not a coloured Container) so the ink of the taps shows.
      child: Material(
        color: context.cc.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CcDims.dockRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CcDims.gap8,
            CcDims.gap8,
            CcDims.gap8,
            6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (searching) field,
              // Offstage alone would leave the tabs focusable.
              ExcludeFocus(
                excluding: keyboard > 0,
                child: TickerMode(
                  enabled: keyboard == 0,
                  child: Offstage(offstage: keyboard > 0, child: layers),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dock's top layer on Search: the shared Search field and a ✕.
class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: CcDims.bottomBarHeight),
      // heightFactor: the bottom bar slot is as tall as the screen.
      child: Center(
        heightFactor: 1,
        child: CcSearchField(
          controller: ref.watch(searchControllerProvider),
          focusNode: ref.watch(searchFocusProvider),
          hint: l.ytHint,
          bare: true,
          onSubmitted: (_) => ref.read(searchSubmitProvider.notifier).submit(),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.items,
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  final List<BottomBarItem> items;

  /// The indexes of [items] shown, in order.
  final List<int> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          Row(
            children: [
              for (final i in tabs)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    label: items[i].label,
                    child: InkWell(
                      onTap: () => onSelect(i),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: CcDims.bottomBarHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: _tabTop,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                i == selected
                                    ? items[i].selectedIcon
                                    : items[i].icon,
                                size: _iconSize,
                                color: i == selected ? cc.text : cc.textMuted,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                items[i].label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: i == selected
                                          ? cc.text
                                          : cc.textMuted,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          _TabDot(
            index: tabs.indexOf(selected).clamp(0, tabs.length - 1),
            tabWidth: box.maxWidth / tabs.length,
            color: cc.accent,
          ),
        ],
      ),
    );
  }
}

/// The accent dot at the top right of the active icon. It hops to the new tab
/// along a small arc; with «Riduci animazioni» the duration is zero, so it
/// just jumps.
class _TabDot extends StatefulWidget {
  const _TabDot({
    required this.index,
    required this.tabWidth,
    required this.color,
  });

  final int index;
  final double tabWidth;
  final Color color;

  @override
  State<_TabDot> createState() => _TabDotState();
}

class _TabDotState extends State<_TabDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    value: 1,
  );
  late double _fromX = _x(widget.index);

  @override
  void didUpdateWidget(_TabDot old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    // Start from where the dot is now, so a quick second tap doesn't jump back.
    _fromX = _currentX(old.index, old.tabWidth);
    _c.duration = ccDuration(context, CcMotion.page);
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Centre of the icon's top-right corner in tab [i].
  double _x(int i, [double? tabWidth]) =>
      (i + 0.5) * (tabWidth ?? widget.tabWidth) + _iconSize / 2;

  // Where the dot is, heading for tab [to].
  double _currentX(int to, [double? tabWidth]) =>
      _fromX +
      (_x(to, tabWidth) - _fromX) * CcMotion.curveIn.transform(_c.value);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                final t = CcMotion.curveIn.transform(_c.value);
                final x = _currentX(widget.index);
                final y = _tabTop - math.sin(math.pi * t) * _dotLift;
                return Transform.translate(
                  offset: Offset(x - _dotSize / 2, y - _dotSize / 2),
                  child: child,
                );
              },
              child: Container(
                key: const ValueKey('tab-dot'),
                width: _dotSize,
                height: _dotSize,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
