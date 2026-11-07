import 'package:flutter/material.dart';

import '../../../data/repositories/library_entries.dart';
import '../../../l10n/l10n_ext.dart';
import '../../theme/tokens.dart';
import '../../widgets/sort_sheet.dart';

/// Under the blocks: the count on the left, the sort menu and the list/grid
/// toggle on the right.
class LibraryToolbar extends StatelessWidget {
  const LibraryToolbar({
    super.key,
    required this.countLabel,
    required this.sort,
    required this.ascending,
    this.kind,
    required this.grid,
    required this.onSort,
    required this.onToggleGrid,
  });

  final String countLabel;
  final LibrarySort sort;
  final bool ascending;

  /// The tab shown: «Numero di brani» is not offered for the artists.
  final LibraryKind? kind;
  final bool grid;
  final void Function(LibrarySort sort, bool ascending) onSort;
  final VoidCallback onToggleGrid;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    String name(LibrarySort s) => switch (s) {
      LibrarySort.recent => l.sortRecent,
      LibrarySort.added => l.sortAddedRecently,
      LibrarySort.alpha => l.sortTitleAToZ,
      LibrarySort.artist => l.sortArtist,
      LibrarySort.year => l.sortYear,
      LibrarySort.plays => l.sortMostPlayed,
      LibrarySort.duration => l.sortDuration,
      LibrarySort.trackCount => l.sortTrackCount,
    };
    // Short forms for the button, which shares its row with the count.
    String shortName(LibrarySort s) => switch (s) {
      LibrarySort.recent => l.sortRecentShort,
      LibrarySort.added => l.sortAddedShort,
      LibrarySort.alpha => l.sortTitle,
      LibrarySort.artist => l.sortArtist,
      LibrarySort.year => l.sortYear,
      LibrarySort.plays => l.sortMostPlayedShort,
      LibrarySort.duration => l.sortDuration,
      LibrarySort.trackCount => l.sortTrackCountShort,
    };
    void pickSort() => showSortSheet<LibrarySort>(
      context: context,
      choices: [
        for (final o in LibrarySort.forKind(kind))
          SortChoice(o, name(o), ascendingByDefault: o.defaultAscending),
      ],
      selected: sort,
      ascending: ascending,
      onChanged: onSort,
    );

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
          // Not flexible: the button takes what it needs, the count gives way.
          Semantics(
                button: true,
                label:
                    '${l.sortBy}: ${name(sort)}, ${ascending ? l.sortAscending : l.sortDescending}',
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
                            shortName(sort),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.labelLarge,
                          ),
                        ),
                        Icon(
                          ascending
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 16,
                          color: cc.textMuted,
                        ),
                        Icon(Icons.arrow_drop_down_rounded, color: cc.textMuted),
                      ],
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
