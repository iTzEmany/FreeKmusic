import 'package:flutter/material.dart';

/// One-line text that scrolls slowly when it does not fit (D-486). Static with
/// «…» when it fits-or-not under reduced motion; never intercepts touches.
class MarqueeText extends StatelessWidget {
  const MarqueeText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  static const _pause = 2.0; // seconds, at the start and at the end
  static const _speed = 30.0; // dp/s
  static const _fade = 16.0; // dp, on the edge that hides text
  static const _back = 1.0; // seconds to return to the start

  @override
  Widget build(BuildContext context) {
    var effective = DefaultTextStyle.of(context).style.merge(style);
    // Text does the same, so the measure matches what is drawn.
    if (MediaQuery.boldTextOf(context)) effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
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
              child: RepaintBoundary(
                child: ClipRect(
                  child: SizedBox(
                    height: h,
                    child: _Scroller(
                      key: ValueKey((text, overflow)),
                      // The extra fade width lets the last letter clear the fade.
                      distance: overflow + MarqueeText._fade,
                      child: Text(text, maxLines: 1, softWrap: false, overflow: TextOverflow.visible, style: style),
                    ),
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
        builder: (context, child) {
          final o = _offset(_c.value * _total);
          final left = o.clamp(0.0, MarqueeText._fade);
          final right = (widget.distance - o).clamp(0.0, MarqueeText._fade);
          return ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) {
              // Only the alpha matters with dstIn.
              final on = Theme.of(context).colorScheme.surface.withAlpha(255), off = on.withAlpha(0);
              return LinearGradient(
                colors: [left > 0 ? off : on, on, on, right > 0 ? off : on],
                stops: [0, left / r.width, 1 - right / r.width, 1],
              ).createShader(r);
            },
            child: Transform.translate(offset: Offset(-o, 0), child: child),
          );
        },
      );
}
