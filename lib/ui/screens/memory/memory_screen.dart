import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../data/repositories/memory_queries.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/duplicate_providers.dart';
import '../../../providers/files_providers.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/memory_providers.dart';
import '../../../providers/nav_providers.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/error_state.dart';
import '../../widgets/format_utils.dart';
import '../../widgets/playlist_cover.dart';
import '../../widgets/section_header.dart';
import '../../widgets/show_msg.dart';
import '../../widgets/segmented_blocks.dart';
import '../../widgets/track_actions.dart';
import '../cleanup/duplicates_screen.dart';
import '../library/album_detail_screen.dart';
import '../library/favorites_screen.dart';
import '../library/library_shortcuts.dart';
import '../playlists/playlist_detail_screen.dart';
import '../settings/missing_tracks_screen.dart';
import '../stats/stats_screen.dart' show formatListened;
import 'folder_labels.dart';
import 'memory_app_data.dart';
import 'memory_ring.dart';
import 'memory_widgets.dart';
import 'never_played_screen.dart';

/// Fourth tab: how much space the library takes, split by playlist, format,
/// folder and track, what was never played, and what the app itself keeps.
class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen> {
  /// Nothing is measured until the tab is first shown (the tabs share an
  /// `IndexedStack`, which builds them all at start-up).
  bool _opened = false;

  void _refresh() {
    ref
      ..invalidate(memoryBreakdownProvider)
      ..invalidate(appDataUsageProvider)
      ..invalidate(enrichmentBytesProvider)
      ..invalidate(musicDiskSpaceProvider);
  }

  Future<void> _pullToRefresh() async {
    _refresh();
    await ref.read(memoryBreakdownProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final selected = ref.watch(navIndexProvider) == NavTab.memory.index;
    ref.listen(navIndexProvider, (prev, next) {
      if (next == NavTab.memory.index && prev != next && _opened) _refresh();
    });
    if (selected) _opened = true;
    final header = Padding(
      // Same frame as the Library header (whose row is 48 high).
      padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap12, CcDims.gap4, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            l.navMemory,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          header,
          Expanded(
            child: _opened
                ? RefreshIndicator(
                    onRefresh: _pullToRefresh,
                    child: _MemoryList(onRetry: _refresh),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

enum _Group { playlists, formats, folders }

enum _Heavy { tracks, albums }

/// How many of the heaviest tracks/albums show before «Mostra tutti».
const _heavyShown = 5;

class _MemoryList extends ConsumerStatefulWidget {
  const _MemoryList({required this.onRetry});

  final VoidCallback onRetry;

  @override
  ConsumerState<_MemoryList> createState() => _MemoryListState();
}

class _MemoryListState extends ConsumerState<_MemoryList> {
  _Group _group = _Group.playlists;
  _Heavy _heavy = _Heavy.tracks;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final totals = ref.watch(memoryTotalsProvider);
    final breakdown = ref.watch(memoryBreakdownProvider);
    final error = totals.error ?? breakdown.error;
    if (error != null) {
      return LoadError(
        error,
        totals.stackTrace ?? breakdown.stackTrace ?? StackTrace.current,
        onRetry: widget.onRetry,
      );
    }
    final t = totals.value, b = breakdown.value;
    if (t == null || b == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final ring = Padding(
      padding: const EdgeInsets.symmetric(vertical: CcDims.gap8),
      child: MemoryRing(
        musicBytes: t.sizeBytes,
        disk: ref.watch(musicDiskSpaceProvider).value,
      ),
    );
    final never = _neverPlayed(context, b);
    final tools = _tools(context);
    final main = [
      ..._groups(context, b),
      ..._heaviest(context, b),
    ];
    final pad = EdgeInsets.only(bottom: CcDims.gap32 + context.dockInset);
    if (MediaQuery.sizeOf(context).width >= CcDims.wideBreakpoint) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 330,
            child: ListView(
              padding: pad,
              children: [ring, ...never, ...tools],
            ),
          ),
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: pad,
              children: [...main, const MemoryAppDataSection(), const _EnrichmentRow()],
            ),
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: pad,
      children: [
        ring,
        ...main,
        ...never,
        ...tools,
        const MemoryAppDataSection(),
        const _EnrichmentRow(),
      ],
    );
  }

  Widget _blocks<T>(
    List<BlockItem<T>> items,
    T selected,
    ValueChanged<T> onChanged,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap8, CcDims.margin, CcDims.gap8),
    child: SegmentedBlocks<T>(
      items: items,
      selected: selected,
      onChanged: onChanged,
    ),
  );

  Future<void> _openFolder(BuildContext context, String path) async {
    if (await ref.read(folderOpenerProvider).open(path)) return;
    await Clipboard.setData(ClipboardData(text: path));
    if (context.mounted) showMsg(context, context.l10n.memoryOpenFolderFailed);
  }

  List<Widget> _groups(BuildContext context, MemoryBreakdown b) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final groups = switch (_group) {
      _Group.playlists => b.playlists,
      _Group.formats => b.formats,
      _Group.folders => b.folders,
    };
    final max = groups.firstOrNull?.totals.sizeBytes ?? 0;
    return [
      _blocks<_Group>(
        [
          BlockItem(
            value: _Group.playlists,
            icon: Icons.queue_music_rounded,
            label: l.memoryPlaylists,
          ),
          BlockItem(
            value: _Group.formats,
            icon: Icons.audio_file_rounded,
            label: l.memoryByFormat,
          ),
          BlockItem(
            value: _Group.folders,
            icon: Icons.folder_rounded,
            label: l.memoryByFolder,
          ),
        ],
        _group,
        (g) => setState(() => _group = g),
      ),
      for (final g in groups)
        switch (_group) {
          _Group.playlists => WeightRow(
            leading: PlaylistCover(
              size: 44,
              favorites: g.isFavorites,
              coverKeys: playlistCoverKeys(g.playlist?.coverKey, [g.autoCoverKey]),
            ),
            title: g.isFavorites ? l.navFavorites : g.name,
            subtitle: _countAndTime(l, g.totals),
            bytes: g.totals.sizeBytes,
            fraction: shareOf(g.totals.sizeBytes, max),
            onTap: () => ShellNav.open<void>(
              context,
              g.playlist == null
                  ? const FavoritesScreen()
                  : PlaylistDetailScreen(playlist: g.playlist!),
            ),
          ),
          _Group.formats => WeightRow(
            leading: const IconBox(Icons.audio_file_rounded),
            title: g.name.toUpperCase(),
            subtitle: l.tracksCount(g.totals.trackCount),
            bytes: g.totals.sizeBytes,
            fraction: shareOf(g.totals.sizeBytes, max),
          ),
          _Group.folders => WeightRow(
            leading: const IconBox(Icons.folder_rounded),
            title: g.path == null
                ? l.memoryNoFolder
                : folderLabels(b.folders)[g.path] ?? g.name,
            subtitle: l.tracksCount(g.totals.trackCount),
            detail: g.path,
            bytes: g.totals.sizeBytes,
            fraction: shareOf(g.totals.sizeBytes, max),
            onTap: g.path == null ? null : () => _openFolder(context, g.path!),
            semanticLabel: g.path == null
                ? null
                : l.memoryOpenFolderLabel(folderLabels(b.folders)[g.path] ?? g.name, g.path!),
            trailing: g.path == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: CcDims.gap8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new_rounded, size: 18, color: context.cc.accent),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            l.memoryOpenFolder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.labelMedium?.copyWith(color: context.cc.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        },
      if (_group == _Group.playlists && groups.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CcDims.margin,
            CcDims.gap8,
            CcDims.margin,
            0,
          ),
          child: Text(
            l.memoryPlaylistsNote,
            style: theme.bodySmall?.copyWith(color: context.cc.textMuted),
          ),
        ),
    ];
  }

  List<Widget> _heaviest(BuildContext context, MemoryBreakdown b) {
    final l = context.l10n;
    if (b.heaviestTracks.isEmpty) return const [];
    final tracks = _heavy == _Heavy.tracks;
    final count = tracks ? b.heaviestTracks.length : b.heaviestAlbums.length;
    final limit = _expanded ? count : _heavyShown;
    return [
      SectionHeader(
        l.memoryHeaviest,
        actionLabel: count > limit ? l.memoryShowAll : null,
        onAction: () => setState(() => _expanded = true),
      ),
      _blocks<_Heavy>(
        [
          BlockItem(
            value: _Heavy.tracks,
            icon: Icons.music_note_rounded,
            label: l.memoryHeaviestTracks,
          ),
          if (b.heaviestAlbums.isNotEmpty)
            BlockItem(
              value: _Heavy.albums,
              icon: Icons.album_rounded,
              label: l.memoryHeaviestAlbums,
            ),
        ],
        _heavy,
        (h) => setState(() => _heavy = h),
      ),
      if (tracks)
        for (final t in b.heaviestTracks.take(limit))
          _TrackWeight(
            title: t.title,
            subtitle: t.artist,
            coverKey: t.coverKey,
            bytes: t.sizeBytes,
            fraction: shareOf(t.sizeBytes, b.heaviestTracks.first.sizeBytes),
            track: t,
          )
      else
        for (final a in b.heaviestAlbums.take(limit))
          WeightRow(
            leading: CoverImage(coverKey: a.album.coverKey, size: 44),
            title: a.album.title ?? l.unknownAlbum,
            subtitle: a.album.variousArtists
                ? l.variousArtists
                : a.album.artist,
            bytes: a.sizeBytes,
            fraction: shareOf(a.sizeBytes, b.heaviestAlbums.first.sizeBytes),
            onTap: () => ShellNav.open<void>(
              context,
              AlbumDetailScreen(album: a.album),
            ),
          ),
    ];
  }

  List<Widget> _neverPlayed(BuildContext context, MemoryBreakdown b) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final n = b.neverPlayed;
    if (n.trackCount == 0) return const [];
    final meta = l.tracksAndDuration(
      l.tracksCount(n.trackCount),
      formatBytes(n.sizeBytes, l.localeName),
    );
    const radius = BorderRadius.all(Radius.circular(CcDims.rSheet));
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap16, CcDims.margin, 0),
        child: Material(
          color: cc.surface1,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: () =>
                ShellNav.open<void>(context, const NeverPlayedScreen()),
            child: Padding(
              padding: const EdgeInsets.all(CcDims.gap12),
              child: Row(
                children: [
                  Icon(Icons.headphones_rounded, size: 22, color: cc.textMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.memoryNeverPlayed, style: theme.labelLarge),
                        Text(
                          meta,
                          style: theme.bodySmall?.copyWith(
                            color: cc.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: cc.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _tools(BuildContext context) {
    final l = context.l10n;
    final missing = ref.watch(
      missingTracksProvider.select((m) => m.value?.length),
    );
    // Only a search already done; opening Memoria never starts one.
    final dup = ref.watch(duplicateSearchProvider);
    return [
      SectionHeader(l.memoryTools),
      LibraryShortcuts(
        items: [
          LibraryShortcut(
            label: l.duplicatesTitle,
            icon: Icons.content_copy_rounded,
            meta: dup.phase == DuplicatePhase.done
                ? l.memoryDuplicateGroups(dup.groups.length)
                : null,
            keepWhenZero: true,
            onTap: () =>
                ShellNav.open<void>(context, const DuplicatesScreen()),
          ),
          LibraryShortcut(
            label: l.missingTracksTitle,
            icon: Icons.link_off_rounded,
            meta: missing == null ? null : l.tracksCount(missing),
            keepWhenZero: true,
            onTap: () =>
                ShellNav.open<void>(context, const MissingTracksScreen()),
          ),
        ],
      ),
    ];
  }
}

String _countAndTime(AppLocalizations l, SizeTotals t) => l.tracksAndDuration(
  l.tracksCount(t.trackCount),
  formatListened(l, t.durationMs),
);

class _TrackWeight extends ConsumerWidget {
  const _TrackWeight({
    required this.title,
    required this.subtitle,
    required this.coverKey,
    required this.bytes,
    required this.fraction,
    required this.track,
  });

  final String title;
  final String? subtitle, coverKey;
  final int bytes;
  final double fraction;
  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) => WeightRow(
    leading: CoverImage(coverKey: coverKey, size: 44),
    title: title,
    subtitle: subtitle,
    bytes: bytes,
    fraction: fraction,
    onTap: () => showTrackActions(context, ref, track),
  );
}

/// «Arricchimento»: what the lyrics, curiosities and credits take; no button
/// to clear it.
class _EnrichmentRow extends ConsumerWidget {
  const _EnrichmentRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(enrichmentBytesProvider).value;
    if (e == null || e.total == 0) return const SizedBox.shrink();
    final l = context.l10n;
    final locale = l.localeName;
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CcDims.margin,
        CcDims.gap16,
        CcDims.margin,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.memoryEnrichment(formatBytes(e.total, locale)),
            style: theme.titleSmall,
          ),
          Text(
            l.memoryEnrichmentDetail(
              formatBytes(e.lyrics, locale),
              formatBytes(e.curiosities, locale),
              formatBytes(e.credits, locale),
            ),
            style: theme.bodySmall?.copyWith(color: context.cc.textMuted),
          ),
        ],
      ),
    );
  }
}
