import '../../widgets/cc_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;

import '../playlists/export_dialog.dart';

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
import '../../theme/tokens.dart';
import '../../widgets/activity_button.dart';
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
import '../devices/devices_sheet.dart';
import '../playlists/playlist_detail_screen.dart';
import '../podcast/podcasts_screen.dart';
import '../radio/radio_screen.dart';
import '../../../providers/radio_providers.dart' show savedRadiosProvider;
import 'album_detail_screen.dart';
import 'all_tracks_screen.dart';
import 'artist_screen.dart';
import 'favorites_screen.dart';
import '../history/history_screen.dart';
import '../smart/smart_playlist_editor.dart';
import '../smart/smart_playlist_screen.dart';
import '../stats/stats_screen.dart';
import '../tags/tags_screen.dart';
import '../../../providers/folder_actions.dart';
import 'folders_sheet.dart';
import '../../../core/constants.dart';
import '../../../providers/releases_providers.dart'
    show followedArtistsProvider, releaseOptionsProvider;
import '../releases/followed_artists_screen.dart';
import 'review_screen.dart';
import 'scan_status.dart';
import 'library_shortcuts.dart';
import 'library_toolbar.dart';
import '../../widgets/alpha_scroller.dart';
import '../../widgets/motion.dart';
import '../../widgets/new_playlist_menu.dart';
import '../../widgets/segmented_blocks.dart';

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

  @override
  void dispose() {
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
    _warm = v ? ref.listenManual(searchIndexProvider, (_, _) {}) : null;
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

  void _setSettings({LibrarySort? sort, bool? grid}) => ref
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(librarySort: sort?.name, libraryGrid: grid));

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

    Widget body;
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
      body = settings.libraryGrid
          ? _LibraryGrid(
              key: PageStorageKey<LibraryKind?>(_kind),
              header: shortcuts,
              entries: entries,
              onOpen: _open,
            )
          : _LibraryList(
              key: PageStorageKey<LibraryKind?>(_kind),
              header: shortcuts,
              entries: entries,
              onOpen: _open,
              showLetters: sort == LibrarySort.alpha,
            );
    }

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
          body: Column(
            children: [
              _LibraryHeader(
                open: _searching,
                onSearch: () => _setSearching(true),
                field: CcSearchField(
                  key: const ValueKey('library-search-bar'),
                  controller: _searchController,
                  focusNode: _searchFocus,
                  hint: l.librarySearchHint,
                  autofocus: true,
                  onQuery: (v) => setState(() => _text = v),
                  onCloseEmpty: () => _setSearching(false),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    // One layer that fades as a whole (D-382); kept mounted so
                    // the scroll position survives the search.
                    Positioned.fill(
                      child: _Veil(
                        hidden: _searching,
                        child: Column(
                          children: [
                            const ScanStatus(),
                            _KindTabs(
                              selected: _kind,
                              onChanged: (k) => setState(() => _kind = k),
                            ),
                            LibraryToolbar(
                              countLabel: count,
                              sort: sort,
                              grid: settings.libraryGrid,
                              onSort: (s) => _setSettings(sort: s),
                              onToggleGrid: () =>
                                  _setSettings(grid: !settings.libraryGrid),
                            ),
                            Expanded(child: body),
                          ],
                        ),
                      ),
                    ),
                    if (_searching)
                      Positioned.fill(
                        key: const ValueKey('library-results'),
                        child: text.isEmpty
                            ? const SizedBox.shrink()
                            : LibraryResults(
                                text: text,
                                onOnline: () {
                                  ref
                                      .read(searchPrefillProvider.notifier)
                                      .set(text);
                                  _setSearching(false);
                                  ShellNav.showSearch(context, ref);
                                },
                              ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades [child] out (shifted by [dx], [dy] of its own size) as one repainted layer; not tappable,
/// focusable or spoken while [hidden]. Transform and opacity only.
class _Veil extends StatelessWidget {
  const _Veil({
    required this.hidden,
    required this.child,
    this.dx = 0,
    this.dy = 0.02,
  });

  final bool hidden;
  final Widget child;
  final double dx, dy;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: hidden,
    child: ExcludeFocus(
      excluding: hidden,
      child: ExcludeSemantics(
        excluding: hidden,
        child: RepaintBoundary(
          child: AnimatedSlide(
            offset: hidden ? Offset(dx, dy) : Offset.zero,
            duration: ccDuration(context, CcMotion.enter),
            curve: CcMotion.curveIn,
            child: AnimatedOpacity(
              opacity: hidden ? 0 : 1,
              duration: ccDuration(context, CcMotion.enter),
              curve: CcMotion.curveIn,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

class _LibraryHeader extends ConsumerStatefulWidget {
  const _LibraryHeader({
    required this.open,
    required this.onSearch,
    required this.field,
  });

  final bool open;
  final VoidCallback onSearch;
  final Widget field;

  @override
  ConsumerState<_LibraryHeader> createState() => _LibraryHeaderState();
}

/// The lens becomes the search bar (D-382): title and icons leave with opacity
/// and a shift, the lens slides to the left edge and the field opens around it.
class _LibraryHeaderState extends ConsumerState<_LibraryHeader> {
  final _lens = GlobalKey();
  // Lens to the left edge, in lens widths; measured when the search opens.
  Offset _lensShift = Offset.zero;
  bool _fieldMounted = false;

  double _width = 0;

  // Lens shift to the left edge. Measured on opening and again when the width
  // changes with the search open (desktop resize); the lens' own shift is
  // taken out, so the natural position is what is measured.
  void _measure({required bool shifted}) {
    final box = _lens.currentContext?.findRenderObject() as RenderBox?;
    final me = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || me == null) return;
    final natural =
        box.localToGlobal(Offset.zero).dx -
        (shifted ? _lensShift.dx * box.size.width : 0);
    final dx =
        (me.localToGlobal(Offset.zero).dx + 4 - natural) / box.size.width;
    if (dx != _lensShift.dx) setState(() => _lensShift = Offset(dx, 0));
  }

  @override
  void didUpdateWidget(_LibraryHeader old) {
    super.didUpdateWidget(old);
    if (widget.open && !old.open) {
      final box = _lens.currentContext?.findRenderObject() as RenderBox?;
      final me = context.findRenderObject() as RenderBox?;
      if (box != null && me != null) {
        final dx =
            me.localToGlobal(Offset.zero).dx +
            4 -
            box.localToGlobal(Offset.zero).dx;
        _lensShift = Offset(dx / box.size.width, 0);
      }
      _fieldMounted = true; // even if the lens could not be measured
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final open = widget.open;
    Widget out(Widget c, double dx) =>
        _Veil(hidden: open, dx: dx, dy: 0, child: c);
    return LayoutBuilder(
      builder: (context, box) {
        if (open && box.maxWidth != _width && _width != 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && widget.open) _measure(shifted: true);
          });
        }
        _width = box.maxWidth;
        return _header(context, theme, open, out);
      },
    );
  }

  Widget _header(
    BuildContext context,
    TextTheme theme,
    bool open,
    Widget Function(Widget, double) out,
  ) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: CcDims.gap12),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (_fieldMounted)
            Positioned.fill(
              left: 4,
              right: CcDims.gap12,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: open ? 1 : 0),
                duration: ccDuration(context, CcMotion.sheet),
                curve: CcMotion.curveIn,
                onEnd: () {
                  if (!open) setState(() => _fieldMounted = false);
                },
                builder: (_, t, child) => ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.12 + 0.88 * t,
                    child: child,
                  ),
                ),
                child: IgnorePointer(
                  ignoring: !open,
                  child: ExcludeFocus(
                    excluding: !open,
                    child: ExcludeSemantics(
                      excluding: !open,
                      child: AnimatedOpacity(
                        opacity: open ? 1 : 0,
                        duration: ccDuration(context, CcMotion.enter),
                        child: widget.field,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(
              left: CcDims.margin,
              right: CcDims.gap4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: out(
                    Text(
                      l.navLibrary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.headlineSmall,
                    ),
                    -0.1,
                  ),
                ),
                out(const ActivityButton(), 0.3),
                AnimatedSlide(
                  key: _lens,
                  offset: open ? _lensShift : Offset.zero,
                  duration: ccDuration(context, CcMotion.sheet),
                  curve: CcMotion.curveIn,
                  child: ExcludeSemantics(
                    excluding: open,
                    child: IconButton(
                      tooltip: l.navSearch,
                      icon: const Icon(Icons.search_rounded),
                      onPressed: open ? null : widget.onSearch,
                    ),
                  ),
                ),
                out(
                  NewPlaylistMenu(
                    onSmart: () => ShellNav.open<bool>(
                      context,
                      const SmartPlaylistEditor(),
                    ),
                  ),
                  0.3,
                ),
                out(
                  IconButton(
                    tooltip: l.moreActions,
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () async {
                      final v = await showCcActionSheet<_LibraryMenuAction>(
                        context: context,
                        groups: [
                          [
                            CcAction(
                              icon: Icons.folder_open_rounded,
                              label: l.folders,
                              value: _LibraryMenuAction.folders,
                            ),
                            CcAction(
                              icon: Icons.refresh_rounded,
                              label: l.refreshLibrary,
                              value: _LibraryMenuAction.scan,
                            ),
                            CcAction(
                              icon: Icons.share_rounded,
                              label: l.shareTitle,
                              value: _LibraryMenuAction.share,
                            ),
                            CcAction(
                              icon: Icons.upload_file_rounded,
                              label: l.exportAllPlaylists,
                              value: _LibraryMenuAction.exportAll,
                            ),
                          ],
                        ],
                      );
                      if (v == null || !context.mounted) return;
                      switch (v) {
                        case _LibraryMenuAction.folders:
                          showCcSheet<void>(
                            context: context,
                            builder: (_) => const FoldersSheet(),
                          );
                        case _LibraryMenuAction.scan:
                          scanWithPermission(ref);
                        case _LibraryMenuAction.share:
                          DevicesSheet.show(context);
                        case _LibraryMenuAction.exportAll:
                          exportAllPlaylistsFlow(context, ref);
                      }
                    },
                  ),
                  0.3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KindTabs extends StatelessWidget {
  const _KindTabs({required this.selected, required this.onChanged});

  final LibraryKind? selected;
  final ValueChanged<LibraryKind?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CcDims.margin,
        CcDims.gap8,
        CcDims.margin,
        0,
      ),
      child: SegmentedBlocks<LibraryKind?>(
        items: [
          BlockItem(value: null, label: l.libraryAll),
          BlockItem(value: LibraryKind.playlist, label: l.navPlaylists),
          BlockItem(value: LibraryKind.album, label: l.albums),
          BlockItem(value: LibraryKind.artist, label: l.artists),
        ],
        selected: selected,
        onChanged: onChanged,
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
    required this.entries,
    required this.onOpen,
    required this.showLetters,
  });

  final Widget? header;
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
        if (header != null) SliverToBoxAdapter(child: header),
        SliverVariedExtentList.builder(
          itemCount: rows.length,
          itemExtentBuilder: (i, _) => rows[i] is String ? 40 * textScale : 64,
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
      ],
    );
  }
}

class _LibraryGrid extends StatelessWidget {
  const _LibraryGrid({
    super.key,
    required this.header,
    required this.entries,
    required this.onOpen,
  });

  final Widget? header;
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
      ],
    );
  }
}

enum _LibraryMenuAction { folders, scan, share, exportAll }
