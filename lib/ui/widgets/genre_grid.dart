import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'cc_tile.dart';

/// A genre cell: [tag] is what [GenreGrid.onSelect] reports, [label] is shown
/// with an optional [subtitle] (e.g. the number of tracks) under it.
class GenreItem {
  const GenreItem(this.tag, this.label, {this.subtitle});

  final String tag, label;
  final String? subtitle;
}

/// Genres as a uniform sliver grid. [columns] (or [wideColumns] on a wide
/// screen) shrink by one at 130 % text and by two at 180 %, never under two;
/// cells hold two lines of text and are never under 56 dp. A sliver, so a long
/// list builds only the cells in view.
class GenreGrid extends StatelessWidget {
  const GenreGrid({
    super.key,
    required this.items,
    required this.onSelect,
    this.selected,
    this.columns = 4,
    int? wideColumns,
  }) : wideColumns = wideColumns ?? columns;

  final List<GenreItem> items;
  final String? selected;
  final ValueChanged<String> onSelect;
  final int columns, wideColumns;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final scaler = MediaQuery.textScalerOf(context);
    final scale = scaler.scale(12) / 12;
    final wide = MediaQuery.sizeOf(context).width >= CcDims.wideBreakpoint;
    final base = wide ? wideColumns : columns;
    final cols = (scale < 1.3 ? base : (scale < 1.8 ? base - 1 : base - 2))
        .clamp(2, base);
    // Two lines of 12 sp text (three with a subtitle) plus padding, never
    // under 56 dp.
    final lines = items.any((g) => g.subtitle != null) ? 3 : 2;
    final cell = (scaler.scale(12) * lines * 1.4 + 16).clamp(56.0, 200.0);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          mainAxisExtent: cell,
        ),
        delegate: SliverChildBuilderDelegate(childCount: items.length, (_, i) {
          final g = items[i];
          final on = g.tag == selected;
          return CcTile(
            key: ValueKey('genre-${g.tag}'),
            color: on ? cc.accent : null,
            selected: on,
            semanticsLabel: g.subtitle == null
                ? g.label
                : '${g.label}, ${g.subtitle}',
            onTap: () => onSelect(g.tag),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      g.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: on ? cc.onAccent : cc.text,
                      ),
                    ),
                    if (g.subtitle != null)
                      Text(
                        g.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: on ? cc.onAccent : cc.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
