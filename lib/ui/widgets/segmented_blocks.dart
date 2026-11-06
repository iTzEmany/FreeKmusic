import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'motion.dart';

class BlockItem<T> {
  const BlockItem({required this.value, this.icon, required this.label});
  final T value;
  final IconData? icon;
  final String label;
}

/// A row of blocks with icon and label; the selected one is filled with
/// [CcColors.text]. When the row does not fit (large text) it becomes 2x2.
class SegmentedBlocks<T> extends StatelessWidget {
  const SegmentedBlocks({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  final List<BlockItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Text-only chips painted [_compactHeight] tall inside a 48 dp tap area.
  final bool compact;

  static const _compactHeight = 36.0;
  static const _compactInset = (48 - _compactHeight) / 2;

  static const _gap = 8.0;
  static const _radius = BorderRadius.all(Radius.circular(CcDims.rSheet));

  Widget _block(BuildContext context, BlockItem<T> item, {required bool paint}) {
    final cc = context.cc;
    final on = item.value == selected;
    final fg = on ? cc.bg : cc.text;
    final block = Semantics(
      button: true,
      selected: on,
      label: item.label,
      excludeSemantics: true,
      onTap: () => onChanged(item.value),
      child: PressScale(
        child: Material(
          color: paint ? (on ? cc.text : cc.surface1) : Colors.transparent,
          borderRadius: _radius,
          child: InkWell(
            borderRadius: _radius,
            onTap: () => onChanged(item.value),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: compact ? _compactHeight : (item.icon == null ? 48 : 64)),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: CcDims.gap4,
                  vertical: compact ? 0 : CcDims.gap8,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.icon != null)
                      Icon(item.icon, size: 22, color: on ? cc.bg : cc.textMuted),
                    Text(
                      item.label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: fg),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!compact) return block;
    // The tap area is the full 48 dp; only the middle is painted.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(item.value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _compactInset),
        child: block,
      ),
    );
  }

  /// Width of the longest single word among the labels, as [Text] lays it out.
  double _widestWord(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    var widest = 0.0;
    for (final word in items.expand((e) => e.label.split(' '))) {
      final p = TextPainter(
        text: TextSpan(text: word, style: style),
        textScaler: scaler,
        textDirection: dir,
      )..layout();
      widest = widest > p.width ? widest : p.width;
      p.dispose();
    }
    return widest;
  }

  @override
  Widget build(BuildContext context) {
    final n = items.length;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(builder: (context, c) {
      // 8 = horizontal padding of [_block]; a word wider than that would break.
      if (n > 2 &&
          (c.maxWidth / n < 72 * scale ||
              _widestWord(context) > (c.maxWidth - _gap * (n - 1)) / n - 8)) {
        Widget line(Iterable<BlockItem<T>> its) => Row(children: [
          for (final (i, it) in its.indexed) ...[
            if (i > 0) const SizedBox(width: _gap),
            Expanded(child: _block(context, it, paint: true)),
          ],
        ]);
        final half = (n + 1) ~/ 2;
        return Column(children: [
          IntrinsicHeight(child: line(items.take(half))),
          const SizedBox(height: _gap),
          IntrinsicHeight(child: line(items.skip(half))),
        ]);
      }
      final cc = context.cc;
      final w = (c.maxWidth - _gap * (n - 1)) / n;
      final index = items.indexWhere((e) => e.value == selected);
      return Stack(children: [
        Positioned(
          left: 0,
          right: 0,
          top: compact ? _compactInset : 0,
          bottom: compact ? _compactInset : 0,
          child: Row(children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: cc.surface1, borderRadius: _radius),
                ),
              ),
            ],
          ]),
        ),
        if (index >= 0)
          Positioned(
            left: 0,
            top: compact ? _compactInset : 0,
            bottom: compact ? _compactInset : 0,
            width: w,
            child: AnimatedSlide(
              offset: Offset(index * (w + _gap) / w, 0),
              duration: ccDuration(context, CcMotion.enter),
              curve: CcMotion.curveIn,
              child: DecoratedBox(
                decoration: BoxDecoration(color: cc.text, borderRadius: _radius),
              ),
            ),
          ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < n; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                Expanded(child: _block(context, items[i], paint: false)),
              ],
            ],
          ),
        ),
      ]);
    });
  }
}
