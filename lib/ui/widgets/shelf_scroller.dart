import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Wraps a horizontal list (a shelf) for the mouse: arrows at the edges that
/// hide at the ends, the wheel scrolling sideways over the shelf, and dragging
/// with the mouse. The list must use the [controller] it is given.
class ShelfScroller extends StatefulWidget {
  const ShelfScroller({super.key, required this.builder});

  final Widget Function(BuildContext context, ScrollController controller)
  builder;

  @override
  State<ShelfScroller> createState() => _ShelfScrollerState();
}

class _ShelfScrollerState extends State<ShelfScroller> {
  final _controller = ScrollController();
  bool _canBack = false, _canForward = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onMetrics(Notification n) {
    final m = n is ScrollNotification
        ? n.metrics
        : n is ScrollMetricsNotification
        ? n.metrics
        : null;
    if (m == null || m.axis != Axis.horizontal) return false;
    final back = m.pixels > m.minScrollExtent + 0.5;
    final forward = m.pixels < m.maxScrollExtent - 0.5;
    if (back != _canBack || forward != _canForward) {
      // Notifications can arrive while the tree is building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _canBack = back;
            _canForward = forward;
          });
        }
      });
    }
    return false;
  }

  void _step(int dir) {
    final p = _controller.position;
    _controller.animateTo(
      (p.pixels + dir * p.viewportDimension * 0.8).clamp(
        p.minScrollExtent,
        p.maxScrollExtent,
      ),
      duration: ccDuration(context, CcMotion.sheet),
      curve: Curves.easeOut,
    );
  }

  // A plain (vertical) wheel moves the shelf, but only while it can move that
  // way: at an end the page scrolls as usual. A sideways delta is the list's.
  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || e.scrollDelta.dx != 0) return;
    if (!_controller.hasClients) return;
    final p = _controller.position;
    final target = (p.pixels + e.scrollDelta.dy).clamp(
      p.minScrollExtent,
      p.maxScrollExtent,
    );
    if (target == p.pixels) return;
    GestureBinding.instance.pointerSignalResolver.register(
      e,
      (_) => _controller.jumpTo(target),
    );
  }

  Widget _arrow(BuildContext context, {required bool forward}) {
    final cc = context.cc;
    final loc = MaterialLocalizations.of(context);
    return Align(
      alignment: forward ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CcDims.gap8),
        child: IconButton.filled(
          tooltip: forward ? loc.nextPageTooltip : loc.previousPageTooltip,
          style: IconButton.styleFrom(
            minimumSize: const Size(36, 36),
            backgroundColor: cc.surface2,
            foregroundColor: cc.text,
          ),
          icon: Icon(
            forward ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
          ),
          onPressed: () => _step(forward ? 1 : -1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= CcDims.wideBreakpoint;
    return NotificationListener<Notification>(
      onNotification: _onMetrics,
      child: Listener(
        onPointerSignal: _onSignal,
        child: Stack(
          children: [
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                scrollbars: false,
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: widget.builder(context, _controller),
            ),
            if (wide && _canBack) Positioned.fill(child: _arrow(context, forward: false)),
            if (wide && _canForward) Positioned.fill(child: _arrow(context, forward: true)),
          ],
        ),
      ),
    );
  }
}
