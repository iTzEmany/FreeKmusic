import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Lets a list read the header's size and hide it before a programmatic jump.
class ShrinkingHeaderController {
  _RenderShrinkingHeader? _render;

  /// Full height of the header (0 before the first layout).
  double get extent => _render?.extent ?? 0;

  /// Height of the part currently on screen.
  double get visible => _render?.geometry?.paintExtent ?? 0;

  /// Moves the header out of view without animation. Call it right before a
  /// jump past its height, so a header that was partly shown cannot cover
  /// the row the jump lands on.
  void hide() => _render?.hide();
}

/// A header sliver that follows the scroll 1:1: it slides away as the list
/// goes down and comes back as soon as it goes up, wherever the list is.
/// Unlike [SliverFloatingHeader] it never snaps (no animation to turn off for
/// reduced motion). It is sized from its child on the first frame.
///
/// A part that must stay on screen goes outside the scroll view, above it.
/// One header per scroll view: each keeps its own state, so two would overlap.
class ShrinkingHeader extends SingleChildRenderObjectWidget {
  /// [color] makes the header opaque, so rows scrolled under it while it
  /// grows back do not show through.
  ShrinkingHeader({super.key, required Widget child, this.controller, Color? color})
    : super(child: color == null ? child : ColoredBox(color: color, child: child));

  final ShrinkingHeaderController? controller;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderShrinkingHeader()..bind(controller);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderShrinkingHeader).bind(controller);

  @override
  void didUnmountRenderObject(RenderObject renderObject) =>
      (renderObject as _RenderShrinkingHeader).bind(null);
}

// Like Flutter's floating headers, without the snap animation and without
// looking at the scroll direction (a mouse wheel leaves it idle): any move
// toward the start grows it. It overlays the rows while it grows.
class _RenderShrinkingHeader extends RenderSliverSingleBoxAdapter {
  ShrinkingHeaderController? _controller;
  double _effective = 0; // scroll offset as seen by the header: 0 = fully shown
  double? _last;
  double extent = 0;

  void bind(ShrinkingHeaderController? c) {
    if (_controller != c && _controller?._render == this) _controller!._render = null;
    _controller = c;
    c?._render = this;
  }

  void hide() {
    // No last offset: the next layout takes the offset as it is, so a jump
    // back does not count as the user scrolling up.
    _last = null;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    child!.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    extent = child!.size.height;
    final last = _last;
    if (last == null || (constraints.scrollOffset >= last && _effective >= extent)) {
      _effective = constraints.scrollOffset;
    } else {
      final delta = last - constraints.scrollOffset; // > 0 while it grows
      _effective = clampDouble(
        math.min(_effective, extent) - delta,
        0,
        constraints.scrollOffset,
      );
    }
    final paintExtent = extent - _effective;
    geometry = SliverGeometry(
      paintOrigin: math.min(constraints.overlap, 0),
      scrollExtent: extent,
      paintExtent: clampDouble(paintExtent, 0, constraints.remainingPaintExtent),
      layoutExtent: clampDouble(
        extent - constraints.scrollOffset,
        0,
        constraints.remainingPaintExtent,
      ),
      maxPaintExtent: extent,
      hasVisualOverflow: true,
    );
    (child!.parentData! as SliverPhysicalParentData).paintOffset = Offset(0, -_effective);
    _last = constraints.scrollOffset;
  }

  @override
  double childMainAxisPosition(RenderBox child) => -_effective;
}
