
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;


import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../data/repositories/library_entries.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/podcast_providers.dart';
import '../../../providers/ui_providers.dart'
    show librarySearchRequestProvider, searchPrefillProvider;
import '../../../providers/review_providers.dart';
import '../../../data/repositories/smart_search.dart' show SearchIndex;
import '../../../providers/selection_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/tag_providers.dart';
import '../../shell/shell_nav.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/artist_avatar.dart';
import '../../widgets/cc_search_field.dart';
import '../../widgets/cover_image.dart';
import 'library_results.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/playlist_cover.dart';
import '../../widgets/progress_frame.dart';
import '../../widgets/async_body.dart' show RowsLoading;
import '../../../providers/player_providers.dart' show currentTrackProvider;
import '../../widgets/smart_cover.dart';
import '../playlists/playlist_detail_screen.dart';
import '../podcast/podcasts_screen.dart';
import '../radio/radio_screen.dart';
import '../../../providers/radio_providers.dart' show savedRadiosProvider;
import 'album_detail_screen.dart';
import 'all_tracks_screen.dart';
import 'artist_screen.dart';
import 'favorites_screen.dart';
import '../history/history_screen.dart';
import '../smart/smart_playlist_screen.dart';
import '../stats/stats_screen.dart';
import '../tags/tags_screen.dart';
import '../../../providers/folder_actions.dart';
import '../../../core/constants.dart';
import '../../../providers/releases_providers.dart'
    show followedArtistsProvider, releaseOptionsProvider;
import '../releases/followed_artists_screen.dart';
import 'review_screen.dart';
import 'library_shortcuts.dart';
import 'library_island.dart';
import '../../widgets/alpha_scroller.dart';
import '../../widgets/motion.dart';

/// Playlists, albums and artists in one place, with Favourites and
/// «Tutti i brani» pinned on top.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibraryKind? _kind;
  bool _searching = false;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  // How far the island has retracted, 1:1 with the scroll (D-407). Only the
  // island listens, so a scroll frame does not rebuild the list.
  final _shrink = ValueNotifier<double>(0);
  double _tabsHeight = libraryIslandTabsHeight; // tabs + scan status, reported by the island

  @override
  void dispose() {
    _shrink.dispose();
    _warm?.close();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _text = '';
  ProviderSubscription<AsyncValue<SearchIndex>>? _warm;

  void _setSearching(bool v) {
    _text = '';
    if (!v) _searchController.clear();
    // Index built on opening, before the first key (as Cerca does).
    _warm?.close();
    if (!v) _searchFocus.unfocus(); // the keyboard goes down at once
    _warm = v ? ref.listenManual(searchIndexProvider, (_, _) {}) : null;
    if (v) _shrink.value = 0; // the field lives in the title row
    setState(() => _searching = v);
  }

  /// Back and Esc first leave a selection made in the results.
  void _back() {
    if (ref.read(selectionProvider(SelectionKey.search.key)).active) {
      ref.read(selectionProvider(SelectionKey.search.key).notifier).clear();
    } else {
      _setSearching(false);
    }
  }

  void _setSettings({LibrarySort? sort, bool? grid}) {
    ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(librarySort: sort?.name, libraryGrid: grid));
  }

  bool _onScroll(ScrollNotification n, double max) {
    // A fling still running must not retract the row that holds the field.
    if (_searching || n.depth != 0 || n.metrics.axis != Axis.vertical) {
      return false;
    }
    final delta = n is ScrollUpdateNotification ? n.scrollDelta ?? 0 : 0;
    // Never more than the list has scrolled: at the top the island is whole.
    _shrink.value = clampDouble(
      _shrink.value + delta,
      0,
      math.min(max, math.max(0, n.metrics.pixels)),
    );
    return false;
  }

  void _open(LibraryEntry e) {
    final Widget page = switch (e.kind) {
      LibraryKind.playlist when e.smart != null => SmartPlaylistScreen(
        id: e.smart!.id,
      ),
      LibraryKind.playlist => PlaylistDetailScreen(
        playlist: e.playlist!.playlist,
      ),
      LibraryKind.album => AlbumDetailScreen(album: e.album!),
      LibraryKind.artist => ArtistDetailScreen(artist: e.artistSummary!),
    };
    ShellNav.open<void>(context, page);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final sort = LibrarySort.values.firstWhere(
      (s) => s.name == settings.librarySort,
      orElse: () => LibrarySort.recent,
    );
    final playlists = ref.watch(playlistsProvider);
    final albums = ref.watch(albumsProvider);
    final artists = ref.watch(artistsProvider);
    final built = ref.watch(libraryEntriesProvider((_kind, sort)));
    final folders = ref.watch(foldersProvider).value;
    final trackCount = ref.watch(trackCountProvider).value ?? 0;
    final denied = ref.watch(permissionDeniedProvider);

    // The list starts under the island, which floats above it.
    final rows = LibraryIslandRows.of(context);
    final inset =
        CcDims.gap12 + rows.fullHeight(_tabsHeight) + CcDims.gap8;
    Widget body;
    var isList = false;
    var count = l.libraryItemsCount(0);
    final error = playlists.error ?? albums.error ?? artists.error;
    if (denied) {
      body = EmptyState(
        icon: Icons.lock,
        message: l.permissionExplain,
        actionLabel: l.openSettings,
        onAction: openAppSettings,
      );
    } else if (error != null) {
      body = LoadError(
        error,
        playlists.stackTrace ??
            albums.stackTrace ??
            artists.stackTrace ??
            StackTrace.current,
        onRetry: () {
          ref.invalidate(playlistsProvider);
          ref.invalidate(albumsProvider);
          ref.invalidate(artistsProvider);
        },
      );
    } else if (!playlists.hasValue || !albums.hasValue || !artists.hasValue) {
      // Fixed rows may not fit a short pane: clipped instead of overflowing.
      body = const RowsLoading();
    } else if (trackCount == 0 && folders != null && folders.isEmpty) {
      body = EmptyState(
        icon: Icons.library_music,
        message: l.addMusicFolder,
        actionLabel: l.addFolder,
        onAction: () => addFolderAndScan(ref),
        secondaryLabel: l.useDefaultFolder,
        onSecondary: () => addDefaultFolderAndScan(ref),
      );
    } else {
      final entries = built.value!;
      count = switch (_kind) {
        null => l.libraryItemsCount(entries.length),
        LibraryKind.playlist => l.playlistsCount(entries.length),
        LibraryKind.album => l.albumsCount(entries.length),
        LibraryKind.artist => l.artistsCount(entries.length),
      };
      final shortcuts = _kind != null ? null : const _LibraryShortcuts();
      isList = true;
      body = settings.libraryGrid
          ? _LibraryGrid(
              key: PageStorageKey<LibraryKind?>(_kind),
              header: shortcuts,
              topInset: inset,
              entries: entries,
              onOpen: _open,
            )
          : _LibraryList(
              key: PageStorageKey<LibraryKind?>(_kind),
              header: shortcuts,
              topInset: inset,
              entries: entries,
              onOpen: _open,
              showLetters: sort == LibrarySort.alpha,
            );
    }

    if (!isList) body = Padding(padding: EdgeInsets.only(top: inset), child: body);

    ref.listen(librarySearchRequestProvider, (_, _) {
      if (!_searching) _setSearching(true);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _searchFocus.requestFocus(),
      );
    });
    final text = _text;
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: CallbackShortcuts(
        bindings: {
          if (_searching)
            const SingleActivator(LogicalKeyboardKey.escape): _back,
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Kept mounted so the scroll position survives the search.
              Positioned.fill(
                child: ExcludeFocus(
                  excluding: _searching,
                  child: Offstage(
                    offstage: _searching,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (n) => _onScroll(n, rows.shrinkMax),
                      child: body,
                    ),
                  ),
                ),
              ),
              if (_searching)
                Positioned.fill(
                  key: const ValueKey('library-results'),
                  // Starts under the sort row and follows it as it closes.
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: ccDuration(context, CcMotion.sheet),
                    curve: CcMotion.curveIn,
                    builder: (_, t, child) => Padding(
                      padding: EdgeInsets.only(top: inset - rows.toolbar * t),
                      child: child,
                    ),
                    child: text.isEmpty
                        ? const SizedBox.shrink()
                        : LibraryResults(
                            text: text,
                            kind: _kind,
                            onOnline: () {
                              ref
                                  .read(searchPrefillProvider.notifier)
                                  .set(text);
                              _setSearching(false);
                              ShellNav.showSearch(context, ref);
                            },
                          ),
                  ),
                ),
              Positioned(
                top: CcDims.gap12,
                left: CcDims.gap8,
                right: CcDims.gap8,
                child: LibraryIsland(
                  shrink: _shrink,
                  searching: _searching,
                  onSearch: () => _setSearching(true),
                  field: CcSearchField(
                    key: const ValueKey('library-search-bar'),
                    controller: _searchController,
                    focusNode: _searchFocus,
                    hint: l.librarySearchHint,
                    autofocus: true,
                    onQuery: (v) {
                      if (_searching) setState(() => _text = v);
                    },
                    onCloseEmpty: () => _setSearching(false),
                  ),
                  kind: _kind,
                  onKind: (k) {
                    ref
                        .read(selectionProvider(SelectionKey.search.key).notifier)
                        .clear();
                    setState(() {
                      _kind = k;
                      _shrink.value = 0;
                    });
                  },
                  countLabel: count,
                  sort: sort,
                  grid: settings.libraryGrid,
                  onSort: (s) => _setSettings(sort: s),
                  onToggleGrid: () => _setSettings(grid: !settings.libraryGrid),
                  onTabsHeight: (h) {
                    if ((h - _tabsHeight).abs() > 0.5) {
                      setState(() => _tabsHeight = h);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryShortcuts extends ConsumerWidget {
  const _LibraryShortcuts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final favCount = ref.watch(favoriteCountProvider).value ?? 0;
    final tagCount = ref.watch(
      tagsProvider.select((t) => t.value?.length ?? 0),
    );
    final podcastCount = ref.watch(
      podcastsProvider.select((p) => p.value?.length ?? 0),
    );
    final radioCount = ref.watch(
      savedRadiosProvider.select((r) => r.value?.length ?? 0),
    );
    final followedCount = ref.watch(
      followedArtistsProvider.select((v) => v.value?.length ?? 0),
    );
    final releaseTopArtists = ref.watch(
      releaseOptionsProvider.select((o) => o.topArtists),
    );
    final reviewCount = ref.watch(
      reviewCountProvider.select((c) => c.value ?? 0),
    );
    final trackCount = ref.watch(trackCountProvider).value ?? 0;
    void open(Widget w) => ShellNav.open<void>(context, w);
    return LibraryShortcuts(
      items: [
        LibraryShortcut(
          label: l.navFavorites,
          count: favCount,
          keepWhenZero: true,
          onTap: () => open(const FavoritesScreen()),
        ),
        LibraryShortcut(
          label: l.allTracks,
          count: trackCount,
          keepWhenZero: true,
          onTap: () => open(const AllTracksScreen()),
        ),
        LibraryShortcut(
          label: l.historyTitle,
          onTap: () => open(const HistoryScreen()),
        ),
        LibraryShortcut(
          label: l.podcastsTitle,
          count: podcastCount,
          keepWhenZero: true,
          onTap: () => open(const PodcastsScreen()),
        ),
        LibraryShortcut(
          label: l.radioTitle,
          count: radioCount,
          keepWhenZero: true,
          onTap: () => open(const RadioScreen()),
        ),
        if (kEnableYoutube && (followedCount > 0 || releaseTopArtists))
          LibraryShortcut(
            label: l.releasesFollowedLibrary,
            count: followedCount,
            keepWhenZero: true,
            onTap: () => open(const FollowedArtistsScreen()),
          ),
        LibraryShortcut(
          label: l.tagsTitle,
          count: tagCount,
          keepWhenZero: true,
          onTap: () => open(const TagsScreen()),
        ),
        LibraryShortcut(
          label: l.statsTitle,
          onTap: () => open(const StatsScreen()),
        ),
        if (reviewCount > 0)
          LibraryShortcut(
            label: l.reviewTitle,
            count: reviewCount,
            onTap: () => open(const ReviewScreen()),
          ),
      ],
    );
  }
}

String _subtitle(BuildContext context, LibraryEntry e) {
  final l = context.l10n;
  return switch (e.kind) {
    LibraryKind.playlist when e.smart != null => l.smartPlaylistLabel,
    LibraryKind.playlist => l.playlistCountLabel(e.count),
    LibraryKind.album =>
      '${l.kindAlbum}, ${e.variousArtists ? l.variousArtists : (e.artist ?? l.unknownArtist)}',
    LibraryKind.artist => l.kindArtist,
  };
}

String _title(BuildContext context, LibraryEntry e) =>
    e.title ??
    (e.kind == LibraryKind.artist
        ? context.l10n.unknownArtist
        : context.l10n.unknownAlbum);

Widget _cover(LibraryEntry e, double size) => switch (e.kind) {
  LibraryKind.playlist when e.smart != null => SmartCover(size: size),
  LibraryKind.artist => ArtistAvatar(
    name: e.title,
    size: size,
    coverKey: e.coverKey,
  ),
  LibraryKind.playlist => PlaylistCover(
    size: size,
    coverKeys: playlistCoverKeys(null, [e.coverKey]),
  ),
  LibraryKind.album => CoverImage(
    coverKey: e.coverKey,
    size: size,
    radius: CcDims.rList,
  ),
};

/// Row cover; the playing album gets the progress frame (playlists have no
/// cheap «is playing» signal, so they don't).
class _EntryCover extends ConsumerWidget {
  const _EntryCover(this.e);

  final LibraryEntry e;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        e.kind == LibraryKind.album &&
        ref.watch(
          currentTrackProvider.select((t) => t.value?.albumKey == e.id),
        );
    if (!current) return _cover(e, 48);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _cover(e, 48),
        const Positioned(
          left: -4,
          top: -4,
          right: -4,
          bottom: -4,
          child: LiveProgressFrame(),
        ),
      ],
    );
  }
}

class _LibraryList extends StatelessWidget {
  const _LibraryList({
    super.key,
    required this.header,
    required this.topInset,
    required this.entries,
    required this.onOpen,
    required this.showLetters,
  });

  final Widget? header;
  final double topInset;
  final List<LibraryEntry> entries;
  final void Function(LibraryEntry) onOpen;
  final bool showLetters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final cc = context.cc;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    // Entries, with a letter (String) before each change of initial in A-Z.
    final rows = <Object>[];
    String? last;
    for (final e in entries) {
      if (showLetters) {
        final letter = leadingLetter(e.title);
        if (letter != last) rows.add(letter);
        last = letter;
      }
      rows.add(e);
    }
    Widget entryRow(LibraryEntry e) => InkWell(
      onTap: () => onOpen(e),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // «Quaderno» hairline from the text on.
          Positioned(
            left: CcDims.margin + 48 + 12,
            right: CcDims.margin,
            bottom: 0,
            height: 1,
            child: ColoredBox(color: cc.separator),
          ),
          Row(
            children: [
              const SizedBox(width: CcDims.margin),
              _EntryCover(e),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(context, e),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyLarge,
                    ),
                    Text(
                      _subtitle(context, e),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CcDims.margin),
            ],
          ),
        ],
      ),
    );
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: topInset)),
        if (header != null) SliverToBoxAdapter(child: header),
        SliverVariedExtentList.builder(
          itemCount: rows.length,
          itemExtentBuilder: (i, _) => rows[i] is String
              ? 40 * textScale
              : trackRowExtentOf(context, false),
          itemBuilder: (_, i) {
            final r = rows[i];
            if (r is LibraryEntry) return entryRow(r);
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                CcDims.margin,
                CcDims.gap16,
                CcDims.margin,
                CcDims.gap4,
              ),
              child: Text(
                r as String,
                style: theme.titleSmall?.copyWith(color: cc.accentSoft),
              ),
            );
          },
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.dockInset)),
      ],
    );
  }
}

class _LibraryGrid extends StatelessWidget {
  const _LibraryGrid({
    super.key,
    required this.header,
    required this.topInset,
    required this.entries,
    required this.onOpen,
  });

  final Widget? header;
  final double topInset;
  final List<LibraryEntry> entries;
  final void Function(LibraryEntry) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    Widget tile(LibraryEntry e) {
      return PressScale(
        child: InkWell(
          onTap: () => onOpen(e),
          borderRadius: BorderRadius.circular(CcDims.rGrid),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, c) =>
                        Center(child: _cover(e, c.biggest.shortestSide)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _title(context, e),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyLarge,
                ),
                Text(
                  _subtitle(context, e),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: topInset)),
        if (header != null) SliverToBoxAdapter(child: header),
        SliverPadding(
          padding: const EdgeInsets.all(CcDims.margin - 6),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              childAspectRatio: 0.8,
            ),
            itemCount: entries.length,
            itemBuilder: (_, i) => tile(entries[i]),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.dockInset)),
      ],
    );
  }
}

