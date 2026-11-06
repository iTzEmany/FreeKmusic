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
import '../../widgets/play_buttons.dart';
import '../../widgets/segmented_blocks.dart';
import '../../widgets/shuffle_button.dart';
import '../../widgets/selection_bar.dart';
import '../../widgets/track_row.dart';
import '../../widgets/track_row_selection.dart';
import 'album_detail_screen.dart' show durationWords;
import 'scan_status.dart';
import '../../widgets/motion.dart';
import '../../widgets/shrinking_header.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/async_body.dart';
import '../../widgets/cc_search_field.dart';

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
    required this.wide,
    required this.onPlay,
  });

  final bool loaded;
  final List<Track> shown;
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
                  l.allTracks,
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
  const AllTracksScreen({super.key, this.initialSort});

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
    bool compact,
    PlayerController ctrl,
    PlayContext ctx,
  ) {
    final selection = RowSelection(
      listKey: _selectionKey,
      visibleIds: [for (final t in list) t.id],
    );
    final extent = trackRowExtentOf(context, compact);
    return EntranceScope(
      child: SliverFixedExtentList(
        itemExtent: extent,
        delegate: SliverChildBuilderDelegate(
          childCount: list.length,
          (_, i) => EnterOnce(
            index: i,
            child: LiveTrackRow(
              track: list[i],
              compact: compact,
              selection: selection,
              onTap: () => ctrl.playFromList(list, i, context: ctx),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(trackQueryProvider(false)).copyWith(text: _text);
    final fresh = ref.watch(tracksProvider(query));
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
              loaded: tracks.hasValue,
              shown: shown,
              wide: wide,
              onPlay: () => ctrl.playAll(shown, context: ctx),
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
    // The A–Z strip only makes sense when the order is alphabetical.
    final byTitle = query.sort == SortOption.title;
    final byArtist = query.sort == SortOption.artist;
    return AlphaScroller(
      controller: _scroll,
      itemExtent: rowHeight,
      topInset: () => _header.visible,
      start: () {
        _header.hide();
        return _header.extent;
      },
      letters: [
        if (byTitle || byArtist)
          for (final t in shown) leadingLetter(byTitle ? t.title : t.artist),
      ],
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          ShrinkingHeader(
            controller: _header,
            color: context.cc.bg,
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CcDims.margin,
                    0,
                    CcDims.margin,
                    CcDims.gap8,
                  ),
                  child: SegmentedBlocks<SortOption>(
                    items: [
                      for (final (o, icon) in const [
                        (
                          SortOption.defaultOrder,
                          Icons.format_list_numbered_rounded,
                        ),
                        (SortOption.title, Icons.sort_by_alpha_rounded),
                        (SortOption.artist, Icons.person_rounded),
                        (SortOption.addedAt, Icons.schedule_rounded),
                      ])
                        BlockItem(
                          value: o,
                          icon: icon,
                          label: _sortLabel(context, o),
                        ),
                    ],
                    selected: query.sort,
                    onChanged: (o) => _query.update((q) => q.copyWith(sort: o)),
                  ),
                ),
              ],
            ),
          ),
          SliverAsyncBody(
            value: tracks,
            loading: SliverToBoxAdapter(child: RowsLoading(rowHeight: rowHeight)),
            onRetry: () => ref.invalidate(tracksProvider(query)),
            data: (list) => list.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: query.text.isEmpty
                          ? Icons.music_off
                          : Icons.search_off,
                      message: query.text.isEmpty ? l.noTracks : l.noResults,
                    ),
                  )
                : _list(list, compact, ctrl, ctx),
          ),
          SliverToBoxAdapter(child: SizedBox(height: context.dockInset)),
        ],
      ),
    );
  }
}
