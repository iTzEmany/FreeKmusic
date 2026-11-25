import '../../../providers/track_ops.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/release_repository.dart' show RecentRelease;
import '../../../data/repositories/track_repository.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/memory_providers.dart';
import '../../../providers/radio_providers.dart';
import '../../../providers/releases_providers.dart';
import '../../../core/constants.dart';
import '../releases/new_releases_screen.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/net_thumbnail.dart';
import '../online/artist_page_sections.dart' show thumbAt;
import '../../widgets/cover_image.dart';
import '../../widgets/focus_ring_button.dart';
import '../../widgets/play_buttons.dart';
import '../../widgets/shelf_scroller.dart';
import '../../widgets/section_header.dart';
import '../../widgets/shuffle_button.dart';
import '../../../data/repositories/library_queries.dart' show AlbumSummary;
import '../library/album_detail_screen.dart';
import '../library/all_tracks_screen.dart';
import '../library/favorites_screen.dart';
import '../library/library_shortcuts.dart';
import '../playlists/playlists_screen.dart';
import '../radio/radio_screen.dart';
import 'cover_fan.dart';
import 'home_row.dart';
import '../../widgets/cc_app_bar.dart';
import '../../../providers/shuffle_plus_providers.dart' show libraryListKey;

/// «Casuale su tutto»: Play for the whole library (random start if shuffle is
/// on) next to the three-state shuffle button, which only changes the mode.
class ShuffleHero extends ConsumerWidget {
  const ShuffleHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final totals = ref.watch(memoryTotalsProvider).value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CcDims.margin,
        CcDims.gap8,
        CcDims.margin,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wraps on two lines at most inside the box width.
          Text(
            l.homeShuffleAll,
            style: theme.displaySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  totals == null
                      ? ''
                      : l.homeShuffleAllSub(
                          l.tracksCount(totals.trackCount),
                          l.hoursCount(totals.durationMs ~/ 3600000),
                        ),
                  style: theme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: CcDims.gap16),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: CcDims.gap4),
                child: PlayCircleButton(
                  size: 48,
                  onPressed: ref.read(trackOpsProvider).playLibrary,
                ),
              ),
              ShuffleModeButton(
                // What Play plays: the whole library, not the queue of before (D-137).
                listIds: ref.read(trackOpsProvider).libraryIds,
                listKey: libraryListKey,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Favourites, Playlist and Radio: the same tiles as the Library shortcuts
/// ([LibraryShortcuts]), with the count and its unit in the subtitle.
class ShortcutsRow extends ConsumerWidget {
  const ShortcutsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    int count<T>(AsyncValue<List<T>> v) => v.value?.length ?? 0;
    void open(Widget page) => ShellNav.open<void>(context, page);
    final radios = count(ref.watch(savedRadiosProvider));
    return LibraryShortcuts(
      items: [
        LibraryShortcut(
          label: l.navFavorites,
          meta: l.tracksCount(ref.watch(favoriteCountProvider).value ?? 0),
          onTap: () => open(const FavoritesScreen()),
        ),
        LibraryShortcut(
          label: l.navPlaylists,
          meta: l.playlistsCount(count(ref.watch(playlistsProvider))),
          onTap: () => open(
            Scaffold(
              appBar: CcAppBar(title: l.navPlaylists),
              body: const PlaylistsScreen(),
            ),
          ),
        ),
        LibraryShortcut(
          label: l.radioTitle,
          meta: radios == 0 ? l.homeRadioLive : l.radioLibrarySubtitle(radios),
          onTap: () => open(const RadioScreen()),
        ),
      ],
    );
  }
}

/// «Aggiunti da poco»: the fan (20 albums once open), and «Mostra tutti» for the full list by date.
class AddedLately extends ConsumerWidget {
  const AddedLately({super.key, this.wide = false});

  /// Desktop: a shelf of covers for the mouse instead of the fan.
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final albums = ref.watch(recentlyAddedAlbumsProvider);
    if (albums.isEmpty) return const SizedBox.shrink();
    return HomeBlock(
      header: SectionHeader(
        l.homeAddedLately,
        actionLabel: l.showAll,
        onAction: () {
          ShellNav.open<void>(
            context,
            const AllTracksScreen(initialSort: SortOption.addedAt),
          );
        },
      ),
      children: [if (wide) _AlbumShelf(albums) else CoverFan(albums: albums)],
    );
  }
}

/// «Nuove uscite»: its own block, only while there are new releases (D-671).
class NewReleasesBlock extends ConsumerWidget {
  const NewReleasesBlock({super.key, this.wide = false});

  /// Desktop: the shelf gets the mouse arrows and wheel ([ShelfScroller]).
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = kEnableYoutube
        ? (ref.watch(newReleasesCountProvider).value ?? 0)
        : 0;
    if (n <= 0) return const SizedBox.shrink();
    final l = context.l10n;
    final recent =
        ref.watch(recentReleasesProvider(30)).value ?? const <RecentRelease>[];
    // 30-day window or loading.
    if (recent.isEmpty) return const SizedBox.shrink();
    return HomeBlock(
      header: SectionHeader(
        l.newReleasesTitle,
        key: const ValueKey('resume-releases'),
        count: '$n',
        actionLabel: l.showAll,
        onAction: () => ShellNav.open<void>(context, const NewReleasesScreen()),
      ),
      children: [
        SizedBox(
          height: _shelfHeight,
          child: _scroller(
            (controller) => ListView.separated(
              controller: controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                CcDims.gap12,
                0,
                CcDims.gap12,
                CcDims.gap12,
              ),
              itemCount: recent.length.clamp(0, _shelfMax),
              separatorBuilder: (_, _) => const SizedBox(width: CcDims.gap12),
              itemBuilder: (_, i) => _ReleaseTile(recent[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scroller(Widget Function(ScrollController? c) list) =>
      wide ? ShelfScroller(builder: (_, c) => list(c)) : list(null);
}

const _shelfMax = 8;
const _shelfCover = 96.0;
const _shelfHeight = _shelfCover + 56;

class _ReleaseTile extends StatelessWidget {
  const _ReleaseTile(this.release);

  final RecentRelease release;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final r = release.release;
    return Semantics(
      button: true,
      label: '${r.title}, ${release.artistName}',
      excludeSemantics: true,
      onTap: () => ShellNav.open<void>(context, const NewReleasesScreen()),
      // A cover opens the full list, like «Tutti» (no page per release here).
      child: InkWell(
        key: ValueKey('shelf-release-${r.browseId}'),
        onTap: () => ShellNav.open<void>(context, const NewReleasesScreen()),
        child: SizedBox(
          width: _shelfCover,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(CcDims.rList),
                child: NetThumbnail(
                  url: thumbAt(context, r.thumbUrl, _shelfCover),
                  width: _shelfCover,
                  height: _shelfCover,
                  icon: Icons.album_rounded,
                ),
              ),
              const SizedBox(height: CcDims.gap4),
              Text(
                r.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodyMedium,
              ),
              Text(
                release.artistName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The recently added albums as covers on a [ShelfScroller] (desktop home).
class _AlbumShelf extends StatelessWidget {
  const _AlbumShelf(this.albums);

  final List<AlbumSummary> albums;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    return SizedBox(
      height: _shelfHeight + CcDims.gap16,
      child: ShelfScroller(
        builder: (_, controller) => ListView.separated(
          controller: controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(
            CcDims.gap12,
            0,
            CcDims.gap12,
            CcDims.gap12,
          ),
          itemCount: albums.length,
          separatorBuilder: (_, _) => const SizedBox(width: CcDims.gap12),
          itemBuilder: (_, i) {
            final a = albums[i];
            return Semantics(
              label:
                  '${a.title ?? l.unknownAlbum}, ${a.variousArtists ? l.variousArtists : (a.artist ?? l.unknownArtist)}',
              excludeSemantics: true,
              button: true,
              child: FocusRing(
                child: InkWell(
                  onTap: () =>
                      ShellNav.open<void>(context, AlbumDetailScreen(album: a)),
                  child: SizedBox(
                    width: _shelfCover,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CoverImage(
                          coverKey: a.coverKey,
                          size: _shelfCover,
                          radius: CcDims.rList,
                        ),
                        const SizedBox(height: CcDims.gap4),
                        Text(
                          a.title ?? l.unknownAlbum,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodyMedium,
                        ),
                        Text(
                          a.variousArtists
                              ? l.variousArtists
                              : (a.artist ?? l.unknownArtist),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
