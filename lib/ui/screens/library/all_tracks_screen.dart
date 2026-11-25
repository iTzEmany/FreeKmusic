import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/track_repository.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/selection_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../../data/db/app_database.dart';
import '../../widgets/alpha_scroller.dart';
import '../../widgets/empty_state.dart';
import '../../../data/repositories/track_kinds.dart' show LibraryFilter;
import '../../widgets/library_filter_bar.dart';
import '../../widgets/play_buttons.dart';
import '../../widgets/segmented_blocks.dart';
import '../../widgets/shuffle_button.dart';
import '../../widgets/selection_bar.dart';
import '../../widgets/track_row.dart' show trackRowWide;
import '../../widgets/track_table.dart';
import '../../widgets/track_row_selection.dart';
import 'album_detail_screen.dart' show durationWords;
import 'scan_status.dart';
import '../../widgets/shrinking_header.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/async_body.dart';
import '../../widgets/cc_search_field.dart';
import '../../../providers/shuffle_plus_providers.dart' show listKeyOf;

String _sortLabel(BuildContext context, SortOption o) {
  final l = context.l10n;
  return switch (o) {
    SortOption.defaultOrder => l.sortDefault,
    SortOption.title => l.sortTitle,
    SortOption.artist => l.sortArtist,
    SortOption.album => l.sortAlbum,
    SortOption.year => l.sortYear,
    SortOption.addedAt => l.sortAdded,
    SortOption.duration => l.sortDuration,
  };
}

class _AllTracksHeader extends StatelessWidget {
  const _AllTracksHeader({
    required this.loaded,
    required this.shown,
    required this.shuffleKey,
    required this.wide,
    required this.onPlay,
    required this.title,
  });

  final String title;
  final bool loaded;
  final List<Track> shown;
  final Object shuffleKey;
  final bool wide;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final cc = context.cc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CcDims.margin,
        CcDims.gap8,
        CcDims.margin,
        CcDims.gap12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: wide ? theme.displaySmall : theme.headlineSmall,
                ),
                // No «0 brani» while loading or on error.
                if (loaded) ...[
                  const SizedBox(height: 4),
                  Text(
                    l.tracksAndDuration(
                      l.tracksCount(shown.length),
                      durationWords(
                        l,
                        shown.fold<int>(0, (sum, t) => sum + t.durationMs),
                      ),
                    ),
                    style: theme.bodyMedium?.copyWith(color: cc.textMuted),
                  ),
                ],
              ],
            ),
          ),
          if (shown.isNotEmpty) ...[
            PlayCircleButton(size: 48, onPressed: onPlay),
            ShuffleModeButton(
              size: 24,
              dot: false,
              listIds: () async => [for (final t in shown) t.id],
              listKey: shuffleKey,
            ),
          ],
        ],
      ),
    );
  }
}

/// Every track as a collection: a fixed row with count, Play and Shuffle; search
/// and sort chips follow the scroll (gone going down, back going up).
class AllTracksScreen extends ConsumerStatefulWidget {
  const AllTracksScreen({super.key, this.initialSort, this.downloadedNoPlaylist = false});

  /// Only the downloaded tracks that are in no playlist (D-485).
  final bool downloadedNoPlaylist;

  /// Sort applied on open (null: keep the current one).
  final SortOption? initialSort;

  @override
  ConsumerState<AllTracksScreen> createState() => _AllTracksScreenState();
}

class _AllTracksScreenState extends ConsumerState<AllTracksScreen> {
  static final _selectionKey = SelectionKey.all.key;
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  // Read at use time: the shell resets this provider when Library is left.
  TrackQueryNotifier get _query => ref.read(trackQueryProvider(false).notifier);
  // Local: another AllTracksScreen open at the same time keeps its own text.
  String _text = '';
  // A new query is a new provider: keep the old list on screen until it loads.
  AsyncValue<List<Track>>? _prev;
  final _header = ShrinkingHeaderController();

  @override
  void initState() {
    super.initState();
    final sort = widget.initialSort;
    if (sort != null) {
      Future<void>.microtask(() {
        if (mounted) _query.update((q) => q.copyWith(sort: sort));
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Widget _list(
    List<Track> list,
    TrackQuery query,
    bool compact,
    PlayerController ctrl,
    PlayContext ctx,
  ) {
    final current = tableSortOf(query.sort, descending: query.descending);
    return TrackTable(
      tracks: list,
      compact: compact,
      selection: RowSelection(
        listKey: _selectionKey,
        visibleIds: [for (final t in list) t.id],
      ),
      sort: current,
      onSort: (c) {
        final next = current?.clicked(c) ?? TableSort(c);
        _query.update(
          (q) => q.copyWith(sort: c.sortOption, descending: !next.ascending),
        );
      },
      // The queue is the list as shown, in the order of the sorted column.
      onPlay: (_, i) => ctrl.playFromList(list, i, context: ctx),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(trackQueryProvider(false)).copyWith(text: _text, filter: ref.watch(libraryFilterProvider));
    final fresh = widget.downloadedNoPlaylist
        ? ref.watch(downloadedNoPlaylistProvider(query))
        : ref.watch(tracksProvider(query));
    final tracks = keepWhileLoading(fresh, _prev);
    _prev = tracks.hasError ? null : tracks;
    final compact = ref.watch(settingsProvider).compactMode;
    final ctrl = ref.read(playerControllerProvider);
    final ctx = PlayContext(
      query.text.trim().isEmpty
          ? PlayContextKind.library
          : PlayContextKind.search,
    );
    final shown = tracks.value ?? const <Track>[];
    // One key for the pill and Play: they must be the same list (D-534).
    final shuffleKey = listKeyOf([for (final t in shown) t.id]);
    final wide = MediaQuery.sizeOf(context).width >= CcDims.wideBreakpoint;
    return SelectionScope(
      listKey: _selectionKey,
      visibleIds: [for (final t in shown) t.id],
      child: Scaffold(
        appBar: SelectableAppBar(
          listKey: _selectionKey,
          tracks: shown,
          normal: const CcAppBar(),
        ),
        body: Column(
          children: [
            const ScanStatus(),
            _AllTracksHeader(
              title: widget.downloadedNoPlaylist
                  ? context.l10n.downloadedNoPlaylist
                  : context.l10n.allTracks,
              loaded: tracks.hasValue,
              shown: shown,
              shuffleKey: shuffleKey,
              wide: wide,
              onPlay: () => ctrl.playAll(
                shown,
                context: ctx,
                listKey: shuffleKey,
              ),
            ),
            Expanded(child: _scrollView(query, tracks, shown, compact, ctrl, ctx)),
          ],
        ),
      ),
    );
  }

  Widget _scrollView(
    TrackQuery query,
    AsyncValue<List<Track>> tracks,
    List<Track> shown,
    bool compact,
    PlayerController ctrl,
    PlayContext ctx,
  ) {
    final l = context.l10n;
    final rowHeight = trackRowExtentOf(context, compact);
    // The A–Z strip only makes sense when the order is alphabetical; otherwise by position.
    final byTitle = query.sort == SortOption.title;
    final byArtist = query.sort == SortOption.artist;
    // The table's headers sort and chips filter; the phone keeps its two bars.
    return LayoutBuilder(builder: (context, box) {
    final wide = trackRowWide(context, box.maxWidth);
    return AlphaScroller(
      controller: _scroll,
      itemExtent: rowHeight,
      itemCount: shown.length,
      topInset: () => _header.visible,
      start: () => _header.extent + (wide ? kTableHeaderHeight : 0),
      letters: [
        if (byTitle || byArtist)
          for (final t in shown) leadingLetter(byTitle ? t.title : t.artist),
      ],
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          ShrinkingHeader(
            controller: _header,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CcDims.margin,
                    CcDims.gap4,
                    CcDims.margin,
                    CcDims.gap8,
                  ),
                  child: CcSearchField(
                    controller: _controller,
                    onQuery: (v) => setState(() => _text = v),
                    hint: l.searchHint,
                  ),
                ),
                if (wide)
                  _WideChips(
                    query: query,
                    showFilter: !widget.downloadedNoPlaylist,
                    onAdded: (on) => _query.update(
                      (q) => q.copyWith(
                        sort: on ? SortOption.addedAt : SortOption.defaultOrder,
                        descending: false,
                      ),
                    ),
                  )
                else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CcDims.margin,
                    0,
                    CcDims.margin,
                    CcDims.gap8,
                  ),
                  child: SegmentedBlocks<SortOption>(
                    items: [
                      for (final o in const [
                        SortOption.defaultOrder,
                        SortOption.title,
                        SortOption.artist,
                        SortOption.addedAt,
                      ])
                        BlockItem(value: o, label: _sortLabel(context, o)),
                    ],
                    selected: query.sort,
                    onChanged: (o) => _query.update((q) => q.copyWith(sort: o, descending: false)),
                  ),
                ),
                  if (!widget.downloadedNoPlaylist) const LibraryFilterBar(),
                ],
              ],
            ),
          ),
          SliverAsyncBody(
            value: tracks,
            loading: SliverToBoxAdapter(child: RowsLoading(rowHeight: rowHeight)),
            onRetry: () => ref.invalidate(
              widget.downloadedNoPlaylist
                  ? downloadedNoPlaylistProvider(query)
                  : tracksProvider(query),
            ),
            data: (list) => list.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: query.text.isEmpty
                          ? Icons.music_off
                          : Icons.search_off,
                      message: query.text.isNotEmpty
                          ? l.noResults
                          : widget.downloadedNoPlaylist
                              ? l.downloadedNoPlaylistEmpty
                              : query.filter == LibraryFilter.stream
                                  ? l.noStreamedTracks
                                  : l.noTracks,
                    ),
                  )
                : _list(list, query, compact, ctrl, ctx),
          ),
          SliverToBoxAdapter(child: SizedBox(height: context.dockInset)),
        ],
      ),
    );
    });
  }
}

/// The wide window's filter: chips in one line (the sort is in the table's headers), plus «recently added», which has no column.
class _WideChips extends ConsumerWidget {
  const _WideChips({
    required this.query,
    required this.showFilter,
    required this.onAdded,
  });

  final TrackQuery query;
  final bool showFilter;
  final ValueChanged<bool> onAdded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final filter = ref.watch(libraryFilterProvider);
    final names = {
      LibraryFilter.all: l.showAll,
      LibraryFilter.device: l.storageModeDevice,
      LibraryFilter.stream: l.storageModeStream,
    };
    return Semantics(
      container: true,
      label: l.libraryFilterLabel,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CcDims.margin,
          0,
          CcDims.margin,
          CcDims.gap8,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: CcDims.gap8,
            runSpacing: CcDims.gap4,
            children: [
              if (showFilter)
                for (final f in LibraryFilter.values)
                  ChoiceChip(
                    label: Text(names[f]!),
                    selected: filter == f,
                    onSelected: (_) =>
                        ref.read(libraryFilterProvider.notifier).set(f),
                  ),
              FilterChip(
                label: Text(l.sortAdded),
                selected: query.sort == SortOption.addedAt,
                onSelected: onAdded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
