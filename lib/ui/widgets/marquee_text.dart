import 'package:flutter/material.dart';

/// One-line text that scrolls slowly when it does not fit (D-486). Static with
/// «…» when it fits-or-not under reduced motion; never intercepts touches.
class MarqueeText extends StatelessWidget {
  const MarqueeText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  static const _pause = 2.0; // seconds, at the start and at the end
  static const _speed = 30.0; // dp/s
  static const _back = 1.0; // seconds to return to the start

  @override
  Widget build(BuildContext context) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    final plain = Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) {
            final painter = TextPainter(
              text: TextSpan(text: text, style: effective),
              textDirection: Directionality.of(context),
              textScaler: scaler,
              maxLines: 1,
            )..layout();
            final overflow = painter.width - box.maxWidth;
            final h = painter.height;
            painter.dispose();
            if (overflow <= 0 || MediaQuery.disableAnimationsOf(context)) return plain;
            return IgnorePointer(
              child: ClipRect(
                child: SizedBox(
                  height: h,
                  child: _Scroller(
                    key: ValueKey((text, overflow)),
                    distance: overflow,
                    child: Text(text, maxLines: 1, softWrap: false, overflow: TextOverflow.visible, style: style),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Scroller extends StatefulWidget {
  const _Scroller({super.key, required this.distance, required this.child});

  final double distance;
  final Widget child;

  @override
  State<_Scroller> createState() => _ScrollerState();
}

class _ScrollerState extends State<_Scroller> with SingleTickerProviderStateMixin {
  late final double _run = widget.distance / MarqueeText._speed;
  late final double _total = MarqueeText._pause * 2 + _run + MarqueeText._back;
  // The ticker is muted by TickerMode when the screen is covered.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_total * 1000).round()),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _offset(double t) {
    const p = MarqueeText._pause;
    if (t < p) return 0;
    if (t < p + _run) return (t - p) * MarqueeText._speed;
    if (t < 2 * p + _run) return widget.distance;
    return widget.distance * (1 - (t - 2 * p - _run) / MarqueeText._back);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: OverflowBox(
          maxWidth: double.infinity,
          alignment: AlignmentDirectional.centerStart,
          child: widget.child,
        ),
        builder: (_, child) => Transform.translate(
          offset: Offset(-_offset(_c.value * _total), 0),
          child: child,
        ),
      );
}
