import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show OrdinalSortKey;

import '../../data/db/app_database.dart';
import '../../data/repositories/track_repository.dart' show SortOption;
import '../../l10n/l10n_ext.dart';
import '../theme/app_theme.dart' show trackRowExtentOf;
import '../theme/tokens.dart';
import 'motion.dart';
import 'track_actions.dart' show TrackAction;
import 'track_row.dart';
import 'track_row_selection.dart';

/// The columns of the table of tracks (wide window); [number] is the order the list has by itself.
enum TableColumn { number, title, artist, album, duration }

/// Which column orders the table and in which direction.
class TableSort {
  const TableSort(this.column, {this.ascending = true});

  final TableColumn column;
  final bool ascending;

  /// The sort after a click on [c]: another column starts ascending, the same one flips.
  TableSort clicked(TableColumn c) =>
      c == column ? TableSort(c, ascending: !ascending) : TableSort(c);
}

extension TableColumnSort on TableColumn {
  SortOption get sortOption => switch (this) {
    TableColumn.number => SortOption.defaultOrder,
    TableColumn.title => SortOption.title,
    TableColumn.artist => SortOption.artist,
    TableColumn.album => SortOption.album,
    TableColumn.duration => SortOption.duration,
  };
}

/// The header to show for a library query: null when it is a sort the columns do not have (or the plain default).
TableSort? tableSortOf(SortOption sort, {required bool descending}) {
  final c = TableColumn.values.where((c) => c.sortOption == sort).firstOrNull;
  if (c == null || (c == TableColumn.number && !descending)) return null;
  return TableSort(c, ascending: !descending);
}

const kTableHeaderHeight = 36.0;

/// The pinned header of a [TrackTable]. Same widths as the wide `TrackRow`,
/// so the titles sit over their columns; [onSort] null: plain labels.
class TrackTableHeader extends StatelessWidget {
  const TrackTableHeader({
    super.key,
    required this.compact,
    this.sort,
    this.onSort,
  });

  final bool compact;
  final TableSort? sort;
  final ValueChanged<TableColumn>? onSort;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    String name(TableColumn c) => switch (c) {
      TableColumn.number => '#',
      TableColumn.title => l.sortTitle,
      TableColumn.artist => l.sortArtist,
      TableColumn.album => l.sortAlbum,
      TableColumn.duration => l.sortDuration,
    };
    Widget cell(TableColumn c, {Alignment align = Alignment.centerLeft}) {
      final on = sort?.column == c;
      final label = c == TableColumn.number ? l.tableNumberColumn : name(c);
      final text = Text(
        name(c),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: on ? cc.text : cc.textMuted,
        ),
      );
      final content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: text),
          if (on)
            Icon(
              sort!.ascending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 14,
              color: cc.text,
            ),
        ],
      );
      return Semantics(
        button: onSort != null,
        sortKey: OrdinalSortKey(c.index.toDouble()),
        label: on
            ? (sort!.ascending
                  ? l.tableSortedAscending(label)
                  : l.tableSortedDescending(label))
            : onSort == null
            ? label
            : l.tableSortBy(label),
        excludeSemantics: true,
        onTap: onSort == null ? null : () => onSort!(c),
        child: InkWell(
          onTap: onSort == null ? null : () => onSort!(c),
          child: Align(alignment: align, child: content),
        ),
      );
    }

    return SizedBox(
      height: kTableHeaderHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cc.bg,
          border: Border(bottom: BorderSide(color: cc.separator)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
          child: Row(
            children: [
              SizedBox(width: 40, child: cell(TableColumn.number, align: Alignment.center)),
              SizedBox(width: (compact ? 40 : 48) + 12),
              Expanded(flex: 5, child: cell(TableColumn.title)),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: cell(TableColumn.artist)),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: cell(TableColumn.album)),
              const SizedBox(width: 40),
              SizedBox(width: 56, child: cell(TableColumn.duration, align: Alignment.center)),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one list of tracks for a wide window: a pinned header with sortable
/// columns over `LiveTrackRow`s with an artist column, locale or online alike.
/// Below the wide breakpoint (or in a narrow pane) it is the plain list of
/// rows of the phone. A sliver: put it in a `CustomScrollView`.
///
/// [tracks] are in the order shown: tapping a row calls [onPlay] with that
/// track and its place in them, and the queue has to be that list.
class TrackTable extends StatelessWidget {
  const TrackTable({
    super.key,
    required this.tracks,
    required this.compact,
    required this.onPlay,
    this.selection,
    this.sort,
    this.onSort,
    this.lead,
  });

  final List<Track> tracks;
  final bool compact;
  final void Function(Track track, int index) onPlay;

  /// Makes the rows pickable (Ctrl / Shift + click, long press on a phone).
  final RowSelection? selection;

  /// The sorted column and the click on a header ([onSort] null: not clickable).
  final TableSort? sort;
  final ValueChanged<TableColumn>? onSort;

  /// First entry of a row's menu.
  final TrackAction? Function(Track track)? lead;

  @override
  Widget build(BuildContext context) {
    final extent = trackRowExtentOf(context, compact);
    return SliverLayoutBuilder(
      builder: (context, c) {
        final wide = trackRowWide(context, c.crossAxisExtent);
        return SliverMainAxisGroup(
          slivers: [
            if (wide)
              SliverPersistentHeader(
                pinned: true,
                delegate: _HeaderDelegate(
                  TrackTableHeader(compact: compact, sort: sort, onSort: onSort),
                ),
              ),
            EntranceScope(
              child: SliverFixedExtentList(
                itemExtent: extent,
                delegate: SliverChildBuilderDelegate(
                  childCount: tracks.length,
                  (_, i) => EnterOnce(
                    index: i,
                    child: LiveTrackRow(
                      track: tracks[i],
                      compact: compact,
                      selection: selection,
                      index: i + 1,
                      artistColumn: true,
                      lead: lead?.call(tracks[i]),
                      onTap: () => onPlay(tracks[i], i),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  const _HeaderDelegate(this.header);

  final Widget header;

  @override
  double get minExtent => kTableHeaderHeight;
  @override
  double get maxExtent => kTableHeaderHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) => header;

  @override
  bool shouldRebuild(_HeaderDelegate old) => true;
}
