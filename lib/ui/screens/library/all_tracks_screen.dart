import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
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
import '../../widgets/segmented_blocks.dart';
import '../../widgets/shuffle_button.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/selection_bar.dart';
import '../../widgets/track_row.dart';
import '../../widgets/track_row_selection.dart';
import 'album_detail_screen.dart' show durationWords;
import 'scan_status.dart';
import '../../widgets/motion.dart';
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
            IconButton(
              tooltip: l.play,
              onPressed: onPlay,
              icon: Icon(Icons.play_arrow_rounded, color: cc.accent),
            ),
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

/// Every track as a collection: header with Play and Shuffle, search, sort
/// chips (header and bar hide on scroll down, come back on scroll up).
class AllTracksScreen extends ConsumerStatefulWidget {
  const AllTracksScreen({super.key, this.initialSort});

  /// Sort applied on open (null: keep the current one).
  final SortOption? initialSort;

  @override
  ConsumerState<AllTracksScreen> createState() => _AllTracksScreenState();
}

class _AllTracksScreenState extends ConsumerState<AllTracksScreen>
    with SingleTickerProviderStateMixin {
  static final _selectionKey = SelectionKey.all.key;
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  late final TrackQueryNotifier _query;
  // 1 = header, search and chips shown, 0 = hidden (the animation's goal).
  double _barTarget = 1;
  late final AnimationController _bar = AnimationController(
    vsync: this,
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    // Captured now: `ref` must not be used from dispose().
    _query = ref.read(trackQueryProvider(false).notifier);
    // Starts with an empty text (and the requested sort).
    Future<void>.microtask(
      () => _query.update(
        (q) => q.copyWith(text: '', sort: widget.initialSort ?? q.sort),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _bar.dispose();
    _controller.dispose();
    _scroll.dispose();
    // Leaves the shared query clean; deferred, a provider cannot be written
    // while the tree is unmounting (and the scope may be gone already).
    final query = _query;
    Future<void>.microtask(() {
      try {
        query.update((q) => q.copyWith(text: ''));
      } on Exception catch (e, st) {
        AppLog.d('query not cleared (scope gone?)', e, st);
      }
    });
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      CcTiming.debounce,
      () => _query.update((q) => q.copyWith(text: text)),
    );
  }

  bool _onScroll(Notification n) {
    // Direction of the user's finger or wheel (jumpTo, e.g. the A-Z strip,
    // never emits it); a list that fits, or the top, always shows the bar.
    final bool? show = switch (n) {
      UserScrollNotification(depth: 0, :final direction)
          when direction != ScrollDirection.idle =>
        direction == ScrollDirection.forward,
      ScrollMetricsNotification(depth: 0, :final metrics)
          when metrics.extentBefore <= 0 || metrics.maxScrollExtent <= 0 =>
        true,
      _ => null,
    };
    final target = show == null ? null : (show ? 1.0 : 0.0);
    if (target != null && target != _barTarget) {
      _barTarget = target;
      _bar.animateTo(
        target,
        duration: ccDuration(context, CcMotion.enter),
        curve: Curves.easeOutCubic,
      );
    }
    return false;
  }

  Widget _list(
    List<Track> list,
    SortOption sort,
    bool compact,
    PlayerController ctrl,
    PlayContext ctx,
  ) {
    final selection = RowSelection(
      listKey: _selectionKey,
      visibleIds: [for (final t in list) t.id],
    );
    final extent = trackRowExtentOf(context, compact);
    final view = EntranceScope(
      child: ListView.builder(
        controller: _scroll,
        itemExtent: extent,
        itemCount: list.length,
        itemBuilder: (_, i) => EnterOnce(
          index: i,
          child: LiveTrackRow(
            track: list[i],
            compact: compact,
            selection: selection,
            onTap: () => ctrl.playFromList(list, i, context: ctx),
          ),
        ),
      ),
    );
    // The A–Z strip only makes sense when the order is alphabetical.
    final byTitle = sort == SortOption.title;
    final byArtist = sort == SortOption.artist;
    if (!byTitle && !byArtist) return view;
    return AlphaScroller(
      controller: _scroll,
      itemExtent: extent,
      letters: [
        for (final t in list) leadingLetter(byTitle ? t.title : t.artist),
      ],
      child: view,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tracks = ref.watch(tracksProvider(false));
    final query = ref.watch(trackQueryProvider(false));
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
            // Not a sliver: AlphaScroller offsets are index * itemExtent.
            SizeTransition(
              sizeFactor: _bar,
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  _AllTracksHeader(
                    loaded: tracks.hasValue,
                    shown: shown,
                    wide: wide,
                    onPlay: () => ctrl.playAll(shown, context: ctx),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      CcDims.margin,
                      CcDims.gap4,
                      CcDims.margin,
                      CcDims.gap8,
                    ),
                    child: CcSearchField(
                      controller: _controller,
                      onChanged: _onChanged,
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
                      onChanged: (o) =>
                          _query.update((q) => q.copyWith(sort: o)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: NotificationListener<Notification>(
                onNotification: _onScroll,
                child: AsyncBody(
                  value: tracks,
                  loading: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      maxHeight: double.infinity,
                      child: Skeleton.list(
                        rowHeight: trackRowExtentOf(context, compact),
                      ),
                    ),
                  ),
                  onRetry: () => ref.invalidate(tracksProvider(false)),
                  isEmpty: (list) => list.isEmpty,
                  empty: EmptyState(
                    icon: query.text.isEmpty
                        ? Icons.music_off
                        : Icons.search_off,
                    message: query.text.isEmpty ? l.noTracks : l.noResults,
                  ),
                  data: (list) => _list(list, query.sort, compact, ctrl, ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
