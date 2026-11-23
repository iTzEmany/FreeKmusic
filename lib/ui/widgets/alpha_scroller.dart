import 'package:flutter/material.dart';

import '../../core/platform.dart';
import '../../core/text_utils.dart';
import '../theme/tokens.dart';

/// «A»–«Z» for letters (accents folded), «#» for everything else.
String leadingLetter(String? text) {
  final t = (text ?? '').trim();
  if (t.isEmpty) return '#';
  final folded = normalize(t);
  if (folded.isEmpty) return '#';
  final c = String.fromCharCode(folded.runes.first).toUpperCase();
  return RegExp(r'^[A-Z]$').hasMatch(c) ? c : '#';
}

/// Below this many items the strip is not worth having (D-694).
const alphaScrollerMinItems = 100;

/// Owns the [ScrollController] of a list that has none of its own and puts
/// the by-position [AlphaScroller] on it.
class PositionScroller extends StatefulWidget {
  const PositionScroller({
    super.key,
    required this.itemCount,
    this.topInset,
    required this.builder,
  });

  final int itemCount;
  final double Function()? topInset;
  final Widget Function(ScrollController controller) builder;

  @override
  State<PositionScroller> createState() => _PositionScrollerState();
}

class _PositionScrollerState extends State<PositionScroller> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlphaScroller(
    controller: _controller,
    itemCount: widget.itemCount,
    topInset: widget.topInset,
    child: widget.builder(_controller),
  );
}

/// A draggable strip at the right edge of a list. With [letters] and
/// [itemExtent] (fixed-extent list) it jumps to the item whose initial sits
/// under the finger and shows the letter in a bubble; with only [itemCount]
/// the finger's fraction maps onto the scroll extent and the bubble reads
/// «120 / 850». Thin and almost invisible at rest, it shows while the list
/// scrolls and widens (≥ 48 dp handle) as long as it is touched (D-694).
class AlphaScroller extends StatefulWidget {
  const AlphaScroller({
    super.key,
    required this.controller,
    this.letters = const [],
    this.itemExtent,
    this.itemCount,
    this.start,
    this.topInset,
    this.bottomInset,
    required this.child,
  });

  final ScrollController controller;

  /// One letter per list item, in list order (alphabetical mode).
  final List<String> letters;
  final double? itemExtent;

  /// Number of items, for the by-position mode (no [letters]/[itemExtent]).
  final int? itemCount;

  /// Called before each jump: returns the scroll offset of the first item
  /// (0 by default). A list under a collapsing header hides the header here
  /// and returns the header's height.
  final double Function()? start;

  /// Height at the top that the strip leaves free (the visible part of a
  /// header), read again on every scroll.
  final double Function()? topInset;

  /// Height at the bottom left free for the dock / mini player; default: [CcContext.dockInset].
  final double? bottomInset;
  final Widget child;

  @override
  State<AlphaScroller> createState() => _AlphaScrollerState();
}

class _AlphaScrollerState extends State<AlphaScroller>
    with SingleTickerProviderStateMixin {
  static const _handle = 48.0;
  // Shown for the first 80 % of the run after a scroll, then fades out.
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
    value: 1,
  );
  String? _bubble;
  bool _touched = false;
  double _inset = 0;

  bool get _byLetters =>
      widget.letters.isNotEmpty && widget.itemExtent != null;
  int get _count => _byLetters ? widget.letters.length : widget.itemCount ?? 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(AlphaScroller old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
    // The strip vanished under the finger (list shrank): drop its state.
    if (_count < alphaScrollerMinItems && (_touched || _bubble != null)) {
      _touched = false;
      _bubble = null;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    _fade.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_count >= alphaScrollerMinItems) _fade.forward(from: 0);
  }

  void _jump(double dy, double height) {
    final n = _count;
    if (n == 0 || height <= 0) return;
    final f = (dy / height).clamp(0.0, 1.0);
    final index = (f * (n - 1)).round();
    final c = widget.controller;
    if (c.hasClients) {
      final max = c.position.maxScrollExtent;
      c.jumpTo(
        _byLetters
            ? ((widget.start?.call() ?? 0) + index * widget.itemExtent!).clamp(0.0, max)
            : f * max,
      );
    }
    // shortcut: the bubble's index is approximate by position and maxScrollExtent
    // may change while the finger rests (lazy lists); fine for a scrub aid.
    setState(() => _bubble = _byLetters ? widget.letters[index] : '${index + 1} / $n');
  }

  void _touch(bool on) {
    if (_touched != on) setState(() => _touched = on);
  }

  void _release() => setState(() {
    _bubble = null;
    _touched = false;
  });

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: [
        widget.child,
        // Few items, or empty letters (not alphabetical, loading): no strip, so
        // touches on the right edge scroll the list.
        if (_count >= alphaScrollerMinItems)
        ListenableBuilder(
          listenable: Listenable.merge([widget.controller, _fade]),
          builder: (_, _) {
            // Frozen while dragging: the jump hides the header and the strip
            // must not move under the finger.
            if (_bubble == null) _inset = widget.topInset?.call() ?? 0;
            // Build runs before layout: catch up with the header's new size.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final now = widget.topInset?.call() ?? 0;
              if (mounted && _bubble == null && now != _inset) setState(() {});
            });
            final v = _fade.value;
            final scrolling = v < 0.8 ? 1.0 : (reduced ? 0.0 : (1 - v) / 0.2);
            final opacity = _touched ? 1.0 : 0.12 + 0.6 * scrolling;
            return Positioned(
          top: _inset,
          bottom: widget.bottomInset ?? context.dockInset,
          right: 0,
          width: isDesktop ? 28 : 48,
          child: ExcludeSemantics(child: LayoutBuilder(
            builder: (_, c) {
              final cx = widget.controller;
              final max = cx.hasClients ? cx.position.maxScrollExtent : 0.0;
              final f = max > 0 ? (cx.position.pixels / max).clamp(0.0, 1.0) : 0.0;
              return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _touch(true),
              onPointerUp: (_) => _touch(false),
              onPointerCancel: (_) => _touch(false),
              child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragStart: (d) {
                _touch(true);
                _jump(d.localPosition.dy, c.maxHeight);
              },
              onVerticalDragUpdate: (d) =>
                  _jump(d.localPosition.dy, c.maxHeight),
              onVerticalDragEnd: (_) => _release(),
              onVerticalDragCancel: _release,
              child: Stack(
                children: [
                  Positioned(
                    key: const ValueKey('scroller-handle'),
                    top: f * (c.maxHeight - _handle).clamp(0.0, double.infinity),
                    right: 2,
                    height: _handle,
                    child: Opacity(
                      opacity: opacity,
                      child: AnimatedContainer(
                        duration: ccDuration(context, CcMotion.press),
                        width: _touched ? 12 : 3,
                        decoration: BoxDecoration(
                          color: _touched ? cc.accent : cc.textMuted,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            );
            },
          )),
        );
          },
        ),
        if (_bubble != null)
          Positioned(
            right: 40,
            top: 0,
            bottom: 0,
            child: ExcludeSemantics(child: Center(
              child: Container(
                constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: cc.accent,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  _bubble!,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: cc.onAccent),
                ),
              ),
            )),
          ),
      ],
    );
  }
}
