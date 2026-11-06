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

/// A draggable strip at the right edge of a fixed-extent list: dragging it
/// jumps to the item whose initial sits under the finger and shows the
/// letter in a bubble.
class AlphaScroller extends StatefulWidget {
  const AlphaScroller({
    super.key,
    required this.controller,
    required this.letters,
    required this.itemExtent,
    this.start,
    this.topInset,
    required this.child,
  });

  final ScrollController controller;

  /// One letter per list item, in list order.
  final List<String> letters;
  final double itemExtent;

  /// Called before each jump: returns the scroll offset of the first item
  /// (0 by default). A list under a collapsing header hides the header here
  /// and returns the header's height.
  final double Function()? start;

  /// Height at the top that the strip leaves free (the visible part of a
  /// header), read again on every scroll.
  final double Function()? topInset;
  final Widget child;

  @override
  State<AlphaScroller> createState() => _AlphaScrollerState();
}

class _AlphaScrollerState extends State<AlphaScroller> {
  String? _bubble;
  double _inset = 0;

  void _jump(double dy, double height) {
    final n = widget.letters.length;
    if (n == 0 || height <= 0) return;
    final f = (dy / height).clamp(0.0, 1.0);
    final index = (f * (n - 1)).round();
    final c = widget.controller;
    if (c.hasClients) {
      c.jumpTo(
        ((widget.start?.call() ?? 0) + index * widget.itemExtent).clamp(0.0, c.position.maxScrollExtent),
      );
    }
    setState(() => _bubble = widget.letters[index]);
  }

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return Stack(
      children: [
        widget.child,
        // Empty letters (not alphabetical, loading): no strip, so touches
        // on the right edge scroll the list.
        if (widget.letters.isNotEmpty)
        ListenableBuilder(
          listenable: widget.controller,
          builder: (_, _) {
            // Frozen while dragging: the jump hides the header and the strip
            // must not move under the finger.
            if (_bubble == null) _inset = widget.topInset?.call() ?? 0;
            // Build runs before layout: catch up with the header's new size.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final now = widget.topInset?.call() ?? 0;
              if (mounted && _bubble == null && now != _inset) setState(() {});
            });
            return Positioned(
          top: _inset,
          bottom: 0,
          right: 0,
          width: isDesktop ? 28 : 48,
          child: LayoutBuilder(
            builder: (_, c) => GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragStart: (d) =>
                  _jump(d.localPosition.dy, c.maxHeight),
              onVerticalDragUpdate: (d) =>
                  _jump(d.localPosition.dy, c.maxHeight),
              onVerticalDragEnd: (_) => setState(() => _bubble = null),
              onVerticalDragCancel: () => setState(() => _bubble = null),
              child: const SizedBox.expand(),
            ),
          ),
        );
          },
        ),
        if (_bubble != null)
          Positioned(
            right: 40,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cc.accent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _bubble!,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: cc.onAccent),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
