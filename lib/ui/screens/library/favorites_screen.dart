import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart' show Track;
import '../../../data/repositories/track_repository.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/selection_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/collection_header.dart';
import '../../shell/shell_nav.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/async_body.dart';
import '../../widgets/playlist_cover.dart';
import '../../widgets/selection_bar.dart';
import '../../widgets/track_row.dart';
import '../../widgets/track_row_selection.dart';
import 'album_detail_screen.dart' show collectionMeta;
import 'all_tracks_screen.dart';
import '../../widgets/motion.dart';

/// The favourites as a collection page (pinned in the Library).
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  // A new sort is a new provider: keep the old list until it loads.
  AsyncValue<List<Track>>? _prev;

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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final query = ref.watch(trackQueryProvider(true));
    final tracks = keepWhileLoading(ref.watch(tracksProvider(query)), _prev);
    _prev = tracks;
    final compact = ref.watch(settingsProvider).compactMode;
    final ctrl = ref.read(playerControllerProvider);
    final list = tracks.value ?? const [];
    const playCtx = PlayContext(PlayContextKind.favorites);
    final durationMs = list.fold<int>(0, (a, t) => a + t.durationMs);
    final extent = trackRowExtentOf(context, compact);
    final key = SelectionKey.favorites.key;
    final selection = RowSelection(
      listKey: key,
      visibleIds: [for (final t in list) t.id],
    );
    final rows =
EntranceScope(
              child: SliverList.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => SizedBox(
                  height: extent,
                  child: EnterOnce(
                    index: i,
                    child: LiveTrackRow(
                      track: list[i],
                      compact: compact,
                      selection: selection,
                      onTap: () => ctrl.playFromList(list, i, context: playCtx),
                    ),
                  ),
                ),
              ),
            );
    final emptyState =
SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.favorite_border_rounded,
                message: l.favoritesEmptyTitle,
                help: l.favoritesEmptyHelp,
                actionLabel: l.openAllTracks,
                onAction: () =>
                    ShellNav.open<void>(context, const AllTracksScreen()),
              ),
            );

    return SelectionScope(
      listKey: key,
      visibleIds: selection.visibleIds,
      child: CollectionScaffold(
        selectionBar: SelectionBarSlot(listKey: key, tracks: list),
        title: l.navFavorites,
        name: l.navFavorites,
        cover: (s) =>
            PlaylistCover(size: s, favorites: true, radius: CcDims.rGrid),
        meta: collectionMeta(l, tracks: list.length, durationMs: durationMs),
        onPlay: list.isEmpty
            ? null
            : () => ctrl.playAll(list, context: playCtx),
        shuffleIds: list.isEmpty ? null : [for (final t in list) t.id],
        menu: IconButton(
          tooltip: l.sortBy,
          icon: const Icon(Icons.sort_rounded),
          onPressed: () async {
            final s = await showCcActionSheet<SortOption>(
              context: context,
              title: l.sortBy,
              groups: [
                [
                  for (final o in SortOption.values)
                    CcAction(
                      icon: Icons.sort_rounded,
                      label: _sortLabel(context, o),
                      value: o,
                      selected: o == query.sort,
                    ),
                ],
              ],
            );
            if (s != null) {
              ref
                  .read(trackQueryProvider(true).notifier)
                  .update((q) => q.copyWith(sort: s));
            }
          },
        ),
        slivers: [
          SliverAsyncBody(
            value: tracks,
            onRetry: () => ref.invalidate(tracksProvider(query)),
            loading: rows,
            data: (_) => list.isEmpty ? emptyState : rows,
          ),
        ],
      ),
    );
  }
}
