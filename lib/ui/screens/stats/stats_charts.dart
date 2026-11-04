import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../theme/tokens.dart';

/// Bars of the time played in each day or month, drawn by hand: no package.
/// [labelOf] gives the text under some of the bars (null = none).
/// [valueOf] gives the text of a bar when touched and for TalkBack; null means
/// the bar cannot be selected (a day in the future).
/// Touch or drag picks the bar by horizontal position; the choice stays on
/// release and goes away with the widget (give it a new key per period).
class StatsBars extends StatefulWidget {
  const StatsBars({
    super.key,
    required this.values,
    required this.labelOf,
    required this.valueOf,
    this.semanticsLabel,
  });

  final List<int> values;
  final String? Function(int index) labelOf;
  final String? Function(int index) valueOf;
  final String? semanticsLabel;

  @override
  State<StatsBars> createState() => _StatsBarsState();
}

class _StatsBarsState extends State<StatsBars> {
  int? _selected;

  void _pick(double dx, double width) {
    final n = widget.values.length;
    final i = (dx / width * n).floor().clamp(0, n - 1);
    if (widget.valueOf(i) != null && i != _selected) {
      setState(() => _selected = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final scaler = MediaQuery.textScalerOf(context);
    final style = Theme.of(context).textTheme.labelSmall!
        .copyWith(color: cc.textMuted);
    final n = widget.values.length;
    final band = scaler.scale(18);
    return Semantics(
      label: widget.semanticsLabel,
      container: true,
      image: true,
      child: SizedBox(
        height: 114 + 2 * band,
        child: LayoutBuilder(
          builder: (context, box) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _pick(d.localPosition.dx, box.maxWidth),
            onHorizontalDragStart: (d) => _pick(d.localPosition.dx, box.maxWidth),
            onHorizontalDragUpdate: (d) => _pick(d.localPosition.dx, box.maxWidth),
            child: CustomPaint(
              size: Size.infinite,
              painter: _BarsPainter(
                values: widget.values,
                color: cc.accent,
                emptyColor: cc.surface3,
                labels: [for (var i = 0; i < n; i++) widget.labelOf(i)],
                valueLabels: [for (var i = 0; i < n; i++) widget.valueOf(i)],
                selected: _selected,
                labelStyle: style,
                pickedStyle: style.copyWith(color: cc.text),
                textDirection: Directionality.of(context),
                textScaler: scaler,
                band: band,
              ),
            ),
          ),
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
    required this.labels,
    required this.valueLabels,
    required this.selected,
    required this.labelStyle,
    required this.pickedStyle,
    required this.textDirection,
    required this.textScaler,
    required this.band,
  });

  final List<int> values;
  final Color color, emptyColor;
  final List<String?> labels, valueLabels;
  final int? selected;
  final TextStyle labelStyle, pickedStyle;
  final TextDirection textDirection;
  final TextScaler textScaler;

  /// Height of the text rows above (the picked bar's label) and below (axis).
  final double band;

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
      final h = _height(i, peak, plotH);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, band + plotH - h, barW, h),
        const Radius.circular(2),
      );
      final base = values[i] == 0 ? emptyColor : color;
      canvas.drawRRect(
        rect,
        Paint()..color = selected == null || selected == i ? base : base.withValues(alpha: 0.35),
      );
      final text = labels[i];
      if (text != null) {
        final tp = _text(text, labelStyle);
        tp.paint(canvas, Offset(slot * i + (slot - tp.width) / 2, band + plotH + 4));
      }
    }
    final s = selected;
    final picked = s == null ? null : valueLabels[s];
    if (s != null && picked != null) {
      final tp = _text(picked, pickedStyle);
      final cx = slot * s + slot / 2;
      final left = (cx - tp.width / 2).clamp(0.0, (size.width - tp.width).clamp(0.0, size.width));
      tp.paint(canvas, Offset(left, band + plotH - _height(s, peak, plotH) - tp.height - 2));
    }
  }

  double _height(int i, int peak, double plotH) => peak == 0 || values[i] == 0
      ? 3.0
      : (values[i] / peak * (plotH - 4)).clamp(3.0, plotH);

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
      old.selected != selected || old.valueLabels.join('|') != valueLabels.join('|');

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.values != values ||
      old.color != color ||
      old.emptyColor != emptyColor ||
      old.selected != selected ||
      old.textScaler != textScaler ||
      old.labels != labels;
}
