import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../theme/tokens.dart';

/// Bars of the time played in each day or month, drawn by hand: no package.
/// [axisOf] is the text under each bar; only every N-th is drawn, N chosen from
/// [steps] (the first that fits the column width and text size), by
/// [showAxis]`(index, N)`. [valueOf] is the text of a bar when touched and for
/// TalkBack; null means the bar cannot be selected (a day in the future).
/// Touch or drag picks the bar by horizontal position; the choice stays on
/// release and goes away with the widget (give it a new key per period).
class StatsBars extends StatefulWidget {
  const StatsBars({
    super.key,
    required this.values,
    required this.axisOf,
    required this.steps,
    required this.showAxis,
    required this.valueOf,
    this.semanticsLabel,
  });

  final List<int> values;
  final List<String> axisOf;
  final List<int> steps;
  final bool Function(int index, int step) showAxis;
  final List<String?> valueOf;
  final String? semanticsLabel;

  @override
  State<StatsBars> createState() => _StatsBarsState();
}

class _StatsBarsState extends State<StatsBars> {
  int? _selected;

  void _pick(double dx, double width) {
    final n = widget.values.length;
    if (n == 0 || width <= 0) return;
    final i = (dx / width * n).floor().clamp(0, n - 1);
    if (widget.valueOf[i] != null && i != _selected) {
      setState(() => _selected = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final scaler = MediaQuery.textScalerOf(context);
    final style = Theme.of(context).textTheme.labelSmall!
        .copyWith(color: cc.textMuted);
    final dir = Directionality.of(context);
    final band = scaler.scale(22);
    // The widest axis text decides how many bars share one label.
    final widest = widget.axisOf.fold('', (a, b) => b.length > a.length ? b : a);
    final probe = TextPainter(
      text: TextSpan(text: widest, style: style),
      textDirection: dir,
      textScaler: scaler,
    )..layout();
    final labelW = probe.width + 6;
    probe.dispose();
    return Semantics(
      label: widget.semanticsLabel,
      container: true,
      image: true,
      child: SizedBox(
        height: 106 + 2 * band,
        child: LayoutBuilder(
          builder: (context, box) {
            final slot = box.maxWidth / widget.values.length;
            final step = widget.steps.firstWhere(
              (s) => s * slot >= labelW,
              orElse: () => widget.steps.last,
            );
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Tap on release, so a vertical scroll never selects a bar.
              onTapUp: (d) => _pick(d.localPosition.dx, box.maxWidth),
              onHorizontalDragStart: (d) => _pick(d.localPosition.dx, box.maxWidth),
              onHorizontalDragUpdate: (d) => _pick(d.localPosition.dx, box.maxWidth),
              child: CustomPaint(
                size: Size.infinite,
                painter: _BarsPainter(
                  values: widget.values,
                  color: cc.accent,
                  emptyColor: cc.surface3,
                  boxColor: cc.surface2,
                  axis: widget.axisOf,
                  axisShown: [
                    for (var i = 0; i < widget.values.length; i++) widget.showAxis(i, step),
                  ],
                  valueLabels: widget.valueOf,
                  selected: _selected,
                  labelStyle: style,
                  pickedStyle: style.copyWith(color: cc.text, fontWeight: FontWeight.w700),
                  textDirection: dir,
                  textScaler: scaler,
                  band: band,
                  labelW: labelW,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.values,
    required this.color,
    required this.emptyColor,
    required this.boxColor,
    required this.axis,
    required this.axisShown,
    required this.valueLabels,
    required this.selected,
    required this.labelStyle,
    required this.pickedStyle,
    required this.textDirection,
    required this.textScaler,
    required this.band,
    required this.labelW,
  });

  final List<int> values;
  final Color color, emptyColor, boxColor;
  final List<String> axis;
  final List<bool> axisShown;
  final List<String?> valueLabels;
  final int? selected;
  final TextStyle labelStyle, pickedStyle;
  final TextDirection textDirection;
  final TextScaler textScaler;

  /// Height of the text rows above (the picked bar's label) and below (axis).
  final double band;

  /// Width of the widest axis text: a neighbour closer than this to the
  /// picked bar's label is left out, so the two never overlap.
  final double labelW;

  TextPainter _text(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: textDirection,
    textScaler: textScaler,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final plotH = size.height - 2 * band;
    final peak = values.reduce((a, b) => a > b ? a : b);
    final slot = size.width / values.length;
    final barW = (slot * 0.62).clamp(2.0, 28.0);
    for (var i = 0; i < values.length; i++) {
      final x = slot * i + (slot - barW) / 2;
      // A day with nothing played still shows a stub, so the axis reads.
      final h = peak == 0 || values[i] == 0
          ? 3.0
          : (values[i] / peak * (plotH - 4)).clamp(3.0, plotH);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, band + plotH - h, barW, h),
        const Radius.circular(2),
      );
      // The picked bar is always accent, even at zero.
      final base = selected == i || values[i] > 0 ? color : emptyColor;
      canvas.drawRRect(
        rect,
        Paint()..color = selected == null || selected == i ? base : base.withValues(alpha: 0.35),
      );
      final s = selected;
      if (s == i || (axisShown[i] && (s == null || (i - s).abs() * slot >= labelW))) {
        final tp = _text(axis[i], selected == i ? pickedStyle : labelStyle);
        tp.paint(canvas, Offset(slot * i + (slot - tp.width) / 2, band + plotH + 4));
        tp.dispose();
      }
    }
    final s = selected;
    final picked = s == null ? null : valueLabels[s];
    if (s != null && picked != null) {
      // In the reserved top band, on a box, so tall bars never hide it.
      final tp = _text(picked, pickedStyle);
      final cx = slot * s + slot / 2;
      final boxW = tp.width + 12;
      final left = (cx - boxW / 2).clamp(0.0, (size.width - boxW).clamp(0.0, size.width));
      final boxH = tp.height + 4;
      final top = (band - boxH) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, top, boxW, boxH), const Radius.circular(6)),
        Paint()..color = boxColor,
      );
      tp.paint(canvas, Offset(left + 6, top + 2));
      tp.dispose();
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final slot = size.width / values.length;
    return [
      for (var i = 0; i < values.length; i++)
        if (valueLabels[i] != null)
          CustomPainterSemantics(
            rect: Rect.fromLTWH(slot * i, 0, slot, size.height),
            properties: SemanticsProperties(
              label: valueLabels[i],
              selected: selected == i,
              textDirection: textDirection,
            ),
          ),
    ];
  };

  @override
  bool shouldRebuildSemantics(_BarsPainter old) =>
      old.selected != selected || !listEquals(old.valueLabels, valueLabels);

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.values != values ||
      old.color != color ||
      old.emptyColor != emptyColor ||
      old.boxColor != boxColor ||
      old.selected != selected ||
      old.textScaler != textScaler ||
      !listEquals(old.axisShown, axisShown) ||
      old.axis != axis;
}
