import 'package:flutter/material.dart';

import '../../l10n/l10n_ext.dart';
import '../theme/tokens.dart';

/// Placeholder blocks with the shape of the real content, pulsing in opacity
/// (0.55 to 1 in 1.4 s; fixed at 0.8 with reduced motion). One controller per
/// skeleton, one node for TalkBack («Caricamento…» or [label]). No shimmer (D-367).
class Skeleton extends StatefulWidget {
  /// 64 dp rows (or [rowHeight]), cover 48.
  const Skeleton.list({
    super.key,
    int rows = 8,
    this.onCard = false,
    this.rowHeight,
    this.label,
  }) : _kind = _Kind.list,
       lineHeight = 22,
       roles = false,
       _n = rows;

  /// 72 dp rows (or [rowHeight]), cover 56.
  const Skeleton.bigRow({
    super.key,
    int rows = 5,
    this.onCard = false,
    this.rowHeight,
  }) : _kind = _Kind.bigRow,
       label = null,
       lineHeight = 22,
       roles = false,
       _n = rows;

  /// Square cells (radius 8) with title and artist below, two per row.
  const Skeleton.gridCell({
    super.key,
    int count = 6,
    this.onCard = false,
  }) : _kind = _Kind.grid,
      label = null,
      rowHeight = null,
      lineHeight = 22,
      roles = false,
      _n = count;

  /// Text lines ([lineHeight] pitch, 22 dp) for the body of a card; [roles]
  /// draws name-and-role rows (48 dp, no cover) like the Crediti ones.
  const Skeleton.card({
    super.key,
    int lines = 5,
    this.onCard = true,
    this.lineHeight = 22,
    this.roles = false,
  }) : _kind = _Kind.card,
       label = null,
       rowHeight = null,
       _n = lines;

  /// Chart bars; fills the height it is given.
  const Skeleton.bars({
    super.key,
    int count = 31,
    this.onCard = false,
  }) : _kind = _Kind.bars,
      label = null,
      rowHeight = null,
      lineHeight = 22,
      roles = false,
      _n = count;

  final _Kind _kind;
  final int _n;

  /// Row variants only: the height of the real rows (e.g. `trackRowExtentOf`).
  final double? rowHeight;

  /// Inside a card: blocks in surface3 (mockup), since surface2 would melt
  /// into the card's own surface1/surface2.
  final bool onCard;

  /// What TalkBack says; null = «Caricamento…».
  final String? label;

  /// Card variant: pitch of the text lines, name-and-role rows.
  final double lineHeight;
  final bool roles;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

enum _Kind { list, bigRow, grid, card, bars }

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _opacity = Tween(
    begin: 0.55,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.onCard ? context.cc.surface3 : context.cc.surface2;
    final body = ExcludeSemantics(child: _body(color));
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: widget.label ?? context.l10n.loadingContent,
      liveRegion: true,
      child: still
          ? Opacity(opacity: 0.8, child: body)
          : FadeTransition(opacity: _opacity, child: body),
    );
  }

  Widget _body(Color color) {
    final n = widget._n;
    switch (widget._kind) {
      case _Kind.list:
        return _rows(color, n, widget.rowHeight ?? 64, 48);
      case _Kind.bigRow:
        return _rows(color, n, widget.rowHeight ?? 72, 56);
      case _Kind.card:
        return Column(
          children: [
            for (var i = 0; i < n; i++)
              if (widget.roles)
                SizedBox(
                  height: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(
                        widthFactor: i.isEven ? 0.5 : 0.4,
                        child: _block(color, height: 14),
                      ),
                      const SizedBox(height: 4),
                      FractionallySizedBox(
                        widthFactor: 0.3,
                        child: _block(color, height: 12),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  height: widget.lineHeight,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: i == n - 1 ? 0.55 : (i.isEven ? 1 : 0.92),
                    child: _block(color, height: 14),
                  ),
                ),
          ],
        );
      case _Kind.bars:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < n; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: FractionallySizedBox(
                    heightFactor: 0.3 + 0.6 * ((i * 37) % 11) / 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      case _Kind.grid:
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: CcDims.margin),
          child: Wrap(
            runSpacing: CcDims.gap16,
            children: [
              for (var i = 0; i < n; i++)
                FractionallySizedBox(
                  widthFactor: 0.5,
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i.isEven ? CcDims.gap8 : 0,
                      left: i.isEven ? 0 : CcDims.gap8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: _block(color, radius: CcDims.rGrid),
                        ),
                        const SizedBox(height: CcDims.gap8),
                        FractionallySizedBox(
                          widthFactor: 0.8,
                          child: _block(color, height: 14),
                        ),
                        const SizedBox(height: CcDims.gap8),
                        FractionallySizedBox(
                          widthFactor: 0.5,
                          child: _block(color, height: 12),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
    }
  }

  Widget _rows(Color color, int n, double h, double cover) => Column(
    children: [
      for (var i = 0; i < n; i++)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: CcDims.margin),
          child: SizedBox(
            height: h,
            child: Row(
              children: [
                _block(color, width: cover, height: cover),
                const SizedBox(width: CcDims.gap12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FractionallySizedBox(
                        widthFactor: i.isEven ? 0.6 : 0.48,
                        child: _block(color, height: 14),
                      ),
                      const SizedBox(height: CcDims.gap8),
                      FractionallySizedBox(
                        widthFactor: i.isEven ? 0.35 : 0.3,
                        child: _block(color, height: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _block(
    Color color, {
    double? width,
    double? height,
    double radius = CcDims.rList,
  }) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
