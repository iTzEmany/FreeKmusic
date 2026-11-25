import 'package:flutter/material.dart';
import '../../widgets/track_table.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../data/db/app_database.dart' show Track;
import '../../../data/repositories/library_queries.dart' show AlbumSummary;
import '../../../data/repositories/playlist_repository.dart' show PlaylistSummary;
import '../../../data/repositories/track_repository.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/favorite_collections_providers.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/selection_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/shuffle_plus_providers.dart' show listKeyOf;
import '../../../services/share/share_fragment.dart' show SharedKind;
import '../../shell/shell_nav.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/async_body.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/collection_header.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/motion.dart';
import '../../widgets/playlist_cover.dart';
import '../../widgets/section_header.dart';
import '../../widgets/selection_bar.dart';
import '../../widgets/share_collection.dart';
import '../../widgets/track_row.dart';
import '../../widgets/track_row_selection.dart';
import '../playlists/playlist_detail_screen.dart';
import 'album_detail_screen.dart' show AlbumDetailScreen, collectionMeta;
import 'all_tracks_screen.dart';

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
    _prev = tracks.hasError ? null : tracks;
    final compact = ref.watch(settingsProvider).compactMode;
    final ctrl = ref.read(playerControllerProvider);
    final list = tracks.value ?? const [];
    for (final p in [favoriteAlbumsProvider, favoritePlaylistsProvider]) {
      ref.listen(p, (_, n) {
        if (n.hasError) AppLog.w('favourite collections failed', n.error, n.stackTrace);
      });
    }
    final albums = ref.watch(favoriteAlbumsProvider).value ?? const <AlbumSummary>[];
    final playlists = ref.watch(favoritePlaylistsProvider).value ?? const <PlaylistSummary>[];
    const playCtx = PlayContext(PlayContextKind.favorites);
    final durationMs = list.fold<int>(0, (a, t) => a + t.durationMs);
    final extent = trackRowExtentOf(context, compact);
    final key = SelectionKey.favorites.key;
    final selection = RowSelection(
      listKey: key,
      visibleIds: [for (final t in list) t.id],
    );
    final rows = MediaQuery.sizeOf(context).width >= CcDims.wideBreakpoint
        ? TrackTable(
            tracks: list,
            compact: compact,
            selection: selection,
            onPlay: (_, i) => ctrl.playFromList(list, i, context: playCtx),
          )
        : EntranceScope(
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

    // One key for the pill and Play: they must be the same list (D-534).

    final shuffleKey = listKeyOf([for (final t in list) t.id]);

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
            : () => ctrl.playAll(
                list,
                context: playCtx,
                listKey: shuffleKey,
              ),
        downloadTracks: list,
        onShare: list.isEmpty
            ? null
            : (r) => shareTracks(context, ref, SharedKind.playlist, l.navFavorites, list, origin: r),
        scrollerCount: albums.length + playlists.length + list.length,
        shuffleIds: list.isEmpty ? null : [for (final t in list) t.id],
        shuffleKey: shuffleKey,
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
          if (albums.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(l.albums, count: '${albums.length}')),
            SliverList.builder(
              itemCount: albums.length,
              itemBuilder: (_, i) => ListTile(
                leading: CoverImage(coverKey: albums[i].coverKey, size: 48, radius: CcDims.rGrid),
                title: Text(albums[i].title ?? l.unknownAlbum, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(albums[i].variousArtists ? l.variousArtists : albums[i].artist ?? l.unknownArtist,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => ShellNav.open<void>(context, AlbumDetailScreen(album: albums[i])),
              ),
            ),
          ],
          if (playlists.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(l.navPlaylists, count: '${playlists.length}')),
            SliverList.builder(
              itemCount: playlists.length,
              itemBuilder: (_, i) => ListTile(
                leading: PlaylistCover(
                  size: 48,
                  coverKeys: playlistCoverKeys(playlists[i].playlist.coverKey, [playlists[i].autoCoverKey]),
                  radius: CcDims.rGrid,
                ),
                title: Text(playlists[i].playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(l.tracksCount(playlists[i].trackCount)),
                onTap: () => ShellNav.open<void>(context, PlaylistDetailScreen(playlist: playlists[i].playlist)),
              ),
            ),
          ],
          if (list.isNotEmpty && (albums.isNotEmpty || playlists.isNotEmpty))
            SliverToBoxAdapter(child: SectionHeader(l.tracks, count: '${list.length}')),
          SliverAsyncBody(
            value: tracks,
            onRetry: () => ref.invalidate(tracksProvider(query)),
            loading: rows,
            data: (_) => list.isEmpty && albums.isEmpty && playlists.isEmpty ? emptyState : rows,
          ),
        ],
      ),
    );
  }
}
