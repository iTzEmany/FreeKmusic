import 'package:flutter/material.dart';

import '../../../data/repositories/library_entries.dart';
import '../../../l10n/l10n_ext.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_sheet.dart';

/// Under the blocks: the count on the left, the sort menu and the list/grid
/// toggle on the right.
class LibraryToolbar extends StatelessWidget {
  const LibraryToolbar({
    super.key,
    required this.countLabel,
    required this.sort,
    required this.grid,
    required this.onSort,
    required this.onToggleGrid,
  });

  final String countLabel;
  final LibrarySort sort;
  final bool grid;
  final ValueChanged<LibrarySort> onSort;
  final VoidCallback onToggleGrid;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    String name(LibrarySort s) => switch (s) {
      LibrarySort.recent => l.sortRecent,
      LibrarySort.alpha => l.sortAToZ,
      LibrarySort.added => l.sortAddedRecently,
    };
    Future<void> pickSort() async {
      final s = await showCcActionSheet<LibrarySort>(
        context: context,
        title: l.sortBy,
        groups: [
          [
            for (final o in LibrarySort.values)
              CcAction(icon: Icons.sort_rounded, label: name(o), value: o, selected: o == sort),
          ],
        ],
      );
      if (s != null) onSort(s);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(CcDims.margin, 0, CcDims.gap4, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              countLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.bodyMedium,
            ),
          ),
          Flexible(
            // Right-aligned: the flexible slot is half the row, sort sits by the grid button.
            child: Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                button: true,
                label: '${l.sortBy}: ${name(sort)}',
                onTap: pickSort,
                excludeSemantics: true,
                child: InkWell(
                onTap: pickSort,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: CcDims.gap8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            name(sort),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.labelLarge,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down_rounded, color: cc.textMuted),
                      ],
                    ),
                  ),
                ),
              ),
              ),
            ),
          ),
          IconButton(
            tooltip: grid ? l.viewAsList : l.viewAsGrid,
            icon: Icon(
              grid ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
            onPressed: onToggleGrid,
          ),
        ],
      ),
    );
  }
}
