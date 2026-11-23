import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Lets a list read the header's size.
class ShrinkingHeaderController {
  _RenderShrinkingHeader? _render;

  /// Full height of the header (0 before the first layout).
  double get extent => _render?.extent ?? 0;

  /// Height of the part currently on screen.
  double get visible => _render?.geometry?.paintExtent ?? 0;
}

/// A header sliver that scrolls away with the list and comes back only when
/// the list is at the top, like a plain non-floating header. It never
/// overlays the rows, so with no background of its own (D-687) no row shows
/// under its text. It is sized from its child on the first frame.
///
/// A part that must stay on screen goes outside the scroll view, above it.
class ShrinkingHeader extends SingleChildRenderObjectWidget {
  /// No background of its own: the app background shows through.
  const ShrinkingHeader({super.key, required super.child, this.controller});

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

class _RenderShrinkingHeader extends RenderSliverSingleBoxAdapter {
  ShrinkingHeaderController? _controller;
  double extent = 0;

  void bind(ShrinkingHeaderController? c) {
    if (_controller != c && _controller?._render == this) _controller!._render = null;
    _controller = c;
    c?._render = this;
  }

  @override
  void performLayout() {
    child!.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    extent = child!.size.height;
    final offset = constraints.scrollOffset;
    final visible = clampDouble(extent - offset, 0, constraints.remainingPaintExtent);
    geometry = SliverGeometry(
      paintOrigin: math.min(constraints.overlap, 0),
      scrollExtent: extent,
      paintExtent: visible,
      layoutExtent: visible,
      maxPaintExtent: extent,
      hasVisualOverflow: true,
    );
    (child!.parentData! as SliverPhysicalParentData).paintOffset = Offset(0, -offset);
  }

  @override
  double childMainAxisPosition(RenderBox child) => -constraints.scrollOffset;
}
