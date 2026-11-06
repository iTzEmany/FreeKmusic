import '../../widgets/cc_sheet.dart';
import '../../widgets/cover_picker_sheet.dart';

import 'package:flutter/material.dart';

import '../../widgets/prompt_name.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/playlist_ops.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/selection_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/collection_header.dart';
import '../../shell/shell_nav.dart';
import '../../widgets/bulk_actions.dart';
import '../../widgets/confirm.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/playlist_cover.dart';
import '../../widgets/track_actions.dart';
import '../../widgets/selection_bar.dart';
import '../../widgets/track_row.dart';
import '../../widgets/track_row_selection.dart';
import '../import/import_banner.dart';
import '../library/album_detail_screen.dart' show collectionMeta;
import 'add_tracks_screen.dart';
import 'export_dialog.dart';
import 'playlist_order.dart';
import '../../widgets/sort_sheet.dart';
import '../../widgets/motion.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({super.key, required this.playlist});

  final Playlist playlist;

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  late String _name = widget.playlist.name;
  bool _editing = false;

  Future<void> _onAction(
    _PlaylistAction v,
    int id,
    String key,
    List<Track> tracks,
  ) async {
    final l = context.l10n;
    final ops = ref.read(playlistOpsProvider);
    switch (v) {
      case _PlaylistAction.sort:
        _pickSort(id);
      case _PlaylistAction.edit:
        // Reordering and picking do not mix.
        ref.read(selectionProvider(key).notifier).clear();
        setState(() => _editing = !_editing);
      case _PlaylistAction.add:
        ShellNav.open<void>(context, AddTracksScreen(playlistId: id));
      case _PlaylistAction.cover:
        await showCoverPicker(
          context,
          save: (ops, bytes, mime) => ops.setPlaylistCover(id, bytes, mime),
          libraryKeys: {for (final t in tracks) ?t.coverKey}.toList(),
        );
      case _PlaylistAction.clearCover:
        await ops.setCover(id, null);
      case _PlaylistAction.export:
        await exportPlaylistFlow(
          context,
          ref,
          playlist: widget.playlist,
          name: _name,
          tracks: tracks,
        );
      case _PlaylistAction.rename:
        final n = await promptName(
          context,
          initial: _name,
          confirmLabel: l.save,
          title: l.renamePlaylist,
          hint: l.playlistName,
        );
        if (n == null) return;
        await ops.rename(id, n);
        if (mounted) setState(() => _name = n);
      case _PlaylistAction.delete:
        final ok = await showConfirm(
          context,
          title: l.confirmDeletePlaylistTitle,
          body: l.confirmDeletePlaylistBody(_name),
          confirmLabel: l.delete,
          destructive: true,
        );
        if (!ok) return;
        await ops.delete(id);
        ref.read(settingsProvider.notifier).update(
          (s) => s.copyWith(playlistSorts: {...s.playlistSorts}..remove('$id')),
        );
        if (mounted) Navigator.of(context).pop();
    }
  }

  void _saveOrder(int id, PlaylistSort sort, bool ascending) {
    // Reordering only exists in the personal order.
    if (sort != PlaylistSort.personal) _editing = false;
    ref.read(settingsProvider.notifier).update((s) {
      final m = {...s.playlistSorts};
      if (sort == PlaylistSort.personal) {
        m.remove('$id');
      } else {
        m['$id'] = PlaylistOrder(sort, ascending).encode();
      }
      return s.copyWith(playlistSorts: m);
    });
  }

  void _pickSort(int id) {
    final l = context.l10n;
    final cur = PlaylistOrder.parse(
      ref.read(settingsProvider).playlistSorts['$id'],
    );
    String name(PlaylistSort s) => switch (s) {
      PlaylistSort.personal => l.sortPersonal,
      PlaylistSort.title => l.sortTitle,
      PlaylistSort.artist => l.sortArtist,
      PlaylistSort.album => l.sortAlbum,
      PlaylistSort.year => l.sortYear,
      PlaylistSort.added => l.sortAddedRecently,
      PlaylistSort.duration => l.sortDuration,
    };
    showSortSheet<PlaylistSort>(
      context: context,
      choices: [
        for (final o in PlaylistSort.values)
          SortChoice(
            o,
            name(o),
            hasDirection: o != PlaylistSort.personal,
            ascendingByDefault: o.ascendingByDefault,
          ),
      ],
      selected: cur.sort,
      ascending: cur.ascending,
      onChanged: (v, asc) => _saveOrder(id, v, asc),
    );
  }

  List<List<CcAction<_PlaylistAction>>> _menuGroups(bool hasCustomCover, bool personal) {
    final l = context.l10n;
    return [
      [
        CcAction(
          icon: Icons.sort_rounded,
          label: l.sortBy,
          value: _PlaylistAction.sort,
        ),
        if (personal)
          CcAction(
            icon: Icons.swap_vert_rounded,
            label: _editing ? l.finishEditing : l.editOrder,
            value: _PlaylistAction.edit,
          ),
        CcAction(
          icon: Icons.playlist_add_rounded,
          label: l.addSongs,
          value: _PlaylistAction.add,
        ),
        CcAction(
          icon: Icons.image_outlined,
          label: l.playlistChangeCover,
          value: _PlaylistAction.cover,
        ),
        if (hasCustomCover)
          CcAction(
            icon: Icons.hide_image_outlined,
            label: l.playlistRemoveCover,
            value: _PlaylistAction.clearCover,
          ),
        CcAction(
          icon: Icons.ios_share_rounded,
          label: l.exportPlaylist,
          value: _PlaylistAction.export,
        ),
        CcAction(
          icon: Icons.edit_outlined,
          label: l.rename,
          value: _PlaylistAction.rename,
        ),
      ],
      [
        CcAction(
          icon: Icons.delete_outline_rounded,
          label: l.delete,
          value: _PlaylistAction.delete,
          destructive: true,
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final id = widget.playlist.id;
    final stored =
        ref.watch(playlistTracksProvider(id)).value ?? const <Track>[];
    final order = PlaylistOrder.parse(
      ref.watch(settingsProvider.select((s) => s.playlistSorts))['$id'],
    );
    final personal = order.sort == PlaylistSort.personal;
    final tracks = order.apply(stored);
    final ops = ref.read(playlistOpsProvider);
    final summary = ref
        .watch(playlistsProvider)
        .value
        ?.where((p) => p.playlist.id == id)
        .firstOrNull;
    final custom = summary?.playlist.coverKey;
    final compact = ref.watch(settingsProvider).compactMode;
    final ctrl = ref.read(playerControllerProvider);
    final playCtx = PlayContext(PlayContextKind.playlist, _name);
    final coverKeys = playlistCoverKeys(custom, tracks.map((t) => t.coverKey));
    final durationMs = tracks.fold<int>(0, (a, t) => a + t.durationMs);
    final extent = trackRowExtentOf(context, compact);
    final key = SelectionKey.playlistOf(id);
    final selection = RowSelection(
      listKey: key,
      visibleIds: [for (final t in tracks) t.id],
    );

    Future<void> remove(Track t, int i) async {
      final undo = await ops.removeTrack(
        id,
        t.id,
        index: i,
        length: tracks.length,
      );
      if (!context.mounted) return;
      showUndoSnack(context, l.removedFromPlaylist, undo);
    }

    final Widget list;
    if (tracks.isEmpty) {
      list = SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.queue_music_rounded,
          message: l.noTracksInPlaylist,
          actionLabel: l.addSongs,
          onAction: () =>
              ShellNav.open<void>(context, AddTracksScreen(playlistId: id)),
        ),
      );
    } else if (_editing && personal) {
      list = SliverReorderableList(
        proxyDecorator: (child, _, anim) => ccDragProxy(context, child, anim),
        itemCount: tracks.length,
        onReorderItem: (from, to) => ops.reorder(id, from, to),
        itemBuilder: (_, i) {
          final t = tracks[i];
          return _EditRow(
            key: ValueKey('pl-edit-${t.id}'),
            track: t,
            index: i,
            onRemove: () => remove(t, i),
          );
        },
      );
    } else {
      list = EntranceScope(
        child: SliverList.builder(
          itemCount: tracks.length,
          itemBuilder: (_, i) {
            final t = tracks[i];
            return SizedBox(
              height: extent,
              child: EnterOnce(
                index: i,
                child: LiveTrackRow(
                  track: t,
                  compact: compact,
                  selection: selection,
                  lead: TrackAction(
                    Icons.playlist_remove_rounded,
                    l.removeFromPlaylistAction,
                    () => remove(t, i),
                  ),
                  onTap: () => ctrl.playFromList(tracks, i, context: playCtx),
                ),
              ),
            );
          },
        ),
      );
    }

    return SelectionScope(
      listKey: key,
      visibleIds: selection.visibleIds,
      child: CollectionScaffold(
        selectionBar: SelectionBarSlot(
          listKey: key,
          tracks: tracks,
          bulk: BulkContext(playlistId: id),
        ),
        title: _name,
        name: _name,
        coverKey: coverKeys.firstOrNull,
        cover: (s) =>
            PlaylistCover(size: s, coverKeys: coverKeys, radius: CcDims.rGrid),
        meta: collectionMeta(l, tracks: tracks.length, durationMs: durationMs),
        onPlay: tracks.isEmpty
            ? null
            : () => ctrl.playAll(tracks, context: playCtx),
        shuffleIds: tracks.isEmpty ? null : [for (final t in tracks) t.id],
        menu: IconButton(
          tooltip: l.moreActions,
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () async {
            final v = await showCcActionSheet<_PlaylistAction>(
              context: context,
              groups: _menuGroups(custom != null, personal),
            );
            if (v != null) _onAction(v, id, key, tracks);
          },
        ),
        slivers: [
          SliverToBoxAdapter(child: ImportBanner(playlistId: id)),
          list,
        ],
      ),
    );
  }
}

enum _PlaylistAction { sort, edit, add, cover, clearCover, export, rename, delete }

class _EditRow extends StatelessWidget {
  const _EditRow({
    super.key,
    required this.track,
    required this.index,
    required this.onRemove,
  });

  final Track track;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: CcDims.margin),
                child: Icon(Icons.drag_handle_rounded),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    track.artist ?? l.unknownArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l.removeFromPlaylistAction,
              icon: const Icon(Icons.close_rounded),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
