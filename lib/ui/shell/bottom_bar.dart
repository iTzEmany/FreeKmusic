import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../providers/nav_providers.dart';
import '../widgets/blurred_chrome.dart';
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

/// One block at the bottom: the mini-player (when something plays) and the
/// always-labelled tabs, with a dot on the active tab's icon. On Search the
/// dock steps aside while the keyboard is up.
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
    return _DockFrame(
      searching: selected == NavTab.search.index,
      layers: DockLayers(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The mini player stays with nothing playing (D-364): the dock does not jump.
            if (showPlayer) ...[
              const MiniPlayer(),
              // 1 dp rule between the two layers of the dock.
              Divider(
                height: 1,
                thickness: 1,
                indent: CcDims.gap8,
                endIndent: CcDims.gap8,
                color: cc.separator,
              ),
              const SizedBox(height: CcDims.gap4),
            ],
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

/// Marks the dock's layers (mini player and tabs): the box the player opens from.
class DockLayers extends StatelessWidget {
  const DockLayers({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// The only dock widget that follows the keyboard (it rebuilds on each frame
/// of its animation): on Search it hides the dock while the keyboard is up,
/// out of paint, taps, focus and semantics.
class _DockFrame extends StatelessWidget {
  const _DockFrame({required this.searching, required this.layers});

  final bool searching;
  final Widget layers;

  @override
  Widget build(BuildContext context) {
    const m = CcDims.dockMargin;
    final hide = searching && MediaQuery.viewInsetsOf(context).bottom > 0;
    // Offstage alone would leave the tabs focusable.
    return Offstage(
      offstage: hide,
      child: ExcludeFocus(
        excluding: hide,
        child: TickerMode(
          enabled: !hide,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              m,
              m,
              m,
              CcDims.dockBottom + MediaQuery.paddingOf(context).bottom,
            ),
            child: BlurredChrome(
              radius: CcDims.dockRadius,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CcDims.gap8,
                  CcDims.gap8,
                  CcDims.gap8,
                  6,
                ),
                child: layers,
              ),
            ),
          ),
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
                    // The label above already names it: the text would be read twice.
                    excludeSemantics: true,
                    onTap: () => onSelect(i),
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
