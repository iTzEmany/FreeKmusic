import '../../../core/app_log.dart';
import '../../widgets/cc_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../data/repositories/library_queries.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/selection_providers.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/online_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../shell/shell_nav.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/collection_header.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/cover_picker_sheet.dart';
import '../../../providers/cover_ops.dart';
import '../../widgets/async_body.dart';
import '../../widgets/selection_bar.dart';
import '../../widgets/track_row.dart';
import '../../widgets/track_row_selection.dart';
import '../devices/devices_sheet.dart';
import '../cleanup/album_merge_dialog.dart';
import '../playlists/playlist_dialogs.dart';
import 'artist_screen.dart';
import '../../widgets/motion.dart';
import '../../widgets/show_msg.dart';
import '../../../providers/shuffle_plus_providers.dart' show listKeyOf;

/// «1 ora e 52 minuti»; never «0 minuti» (under a minute rounds up).
String durationWords(AppLocalizations l, int ms) {
  final minutes = ms > 0 ? (ms / 60000).ceil() : 0;
  if (minutes < 60) return l.minutesWords(minutes);
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0
      ? l.hoursWords(h)
      : l.hoursAndMinutes(l.hoursWords(h), l.minutesWords(m));
}

/// «2004, 12 brani, 48 minuti».
String collectionMeta(
  AppLocalizations l, {
  int? year,
  required int tracks,
  required int durationMs,
  int? albums,
}) => tracks == 0
    ? l.collectionNoTracks
    : [
        if (albums != null) l.albumsCount(albums),
        if (year != null) '$year',
        l.tracksCount(tracks),
        durationWords(l, durationMs),
      ].join(', ');

class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({super.key, required this.album});

  final AlbumSummary album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tracks = ref.watch(albumTracksProvider(album.albumKey));
    final compact = ref.watch(settingsProvider).compactMode;
    final name = album.title ?? l.unknownAlbum;
    final playCtx = PlayContext(PlayContextKind.album, name);
    final list = tracks.value ?? const <Track>[];
    // The summary is a snapshot: a new cover key shows up through the live list.
    final coverKey = ref.watch(albumsProvider.select(
          (a) => a.value?.where((x) => x.albumKey == album.albumKey).firstOrNull?.coverKey,
        )) ??
        album.coverKey;
    final ctrl = ref.read(playerControllerProvider);

    // Follow the rows once loaded: the summary is a snapshot (a track moved
    // away or edited changes the album under this page).
    final meta = collectionMeta(
      l,
      year: album.year,
      tracks: tracks.hasValue ? list.length : album.trackCount,
      durationMs: tracks.hasValue
          ? list.fold<int>(0, (sum, t) => sum + t.durationMs)
          : album.durationMs,
    );

    final discs = {for (final t in list) t.discNumber ?? 1};
    final multiDisc = discs.length > 1;
    // Flat list of rows and disc headers, in disc order.
    final items = <Object>[];
    int? lastDisc;
    for (final t in list) {
      final d = t.discNumber ?? 1;
      if (multiDisc && d != lastDisc) items.add(d);
      lastDisc = d;
      items.add(t);
    }
    final position = {for (var i = 0; i < list.length; i++) list[i].id: i};
    final extent = trackRowExtentOf(context, compact);
    final key = SelectionKey.albumOf(album.albumKey);
    final selection = RowSelection(
      listKey: key,
      visibleIds: [for (final t in list) t.id],
    );

    final rows =
EntranceScope(
              child: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final it = items[i];
                if (it is int) return DiscHeader(it);
                final t = it as Track;
                final at = position[t.id] ?? 0;
                return SizedBox(
                  height: extent,
                  child: EnterOnce(
                    index: i,
                    child: LiveTrackRow(
                      track: t,
                      compact: compact,
                      variant: TrackRowVariant.album,
                      albumArtist: album.artist,
                      index: at + 1,
                      selection: selection,
                      onTap: () => ctrl.playFromList(list, at, context: playCtx),
                    ),
                  ),
                );
              },
            ),
            );

    // One key for the pill and Play: they must be the same list (D-534).

    final shuffleKey = listKeyOf([for (final t in list) t.id]);

    return SelectionScope(
      listKey: key,
      visibleIds: selection.visibleIds,
      child: CollectionScaffold(
        selectionBar: SelectionBarSlot(listKey: key, tracks: list),
        title: name,
        name: name,
        coverKey: coverKey,
        cover: (s) =>
            CoverImage(coverKey: coverKey, size: s, radius: CcDims.rGrid),
        subtitle: _AlbumSubtitle(album: album),
        meta: meta,
        onPlay: list.isEmpty
            ? null
            : () => ctrl.playAll(
                list,
                context: playCtx,
                listKey: shuffleKey,
              ),
        shuffleIds: list.isEmpty ? null : [for (final t in list) t.id],
        shuffleKey: shuffleKey,
        menu: _AlbumMenu(album: album, tracks: list),
        slivers: [
          SliverAsyncBody(
            value: tracks,
            onRetry: () => ref.invalidate(albumTracksProvider(album.albumKey)),
            loading: rows,
            data: (_) => rows,
          ),
        ],
      ),
    );
  }
}

class _AlbumSubtitle extends StatelessWidget {
  const _AlbumSubtitle({required this.album});

  final AlbumSummary album;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final artistName = album.variousArtists
        ? l.variousArtists
        : (album.artist ?? l.unknownArtist);
    return album.variousArtists || album.artist == null
            ? Text(artistName, style: Theme.of(context).textTheme.bodyLarge)
            : InkWell(
                onTap: () => ShellNav.open<void>(
                  context,
                  ArtistDetailScreen(
                    artist: ArtistSummary(
                      key: album.artist!.trim().toLowerCase(),
                      name: album.artist,
                      trackCount: 0,
                      albumCount: 0,
                    ),
                  ),
                ),
                child: Text(
                  artistName,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700, color: cc.text),
                ),
              );
  }
}

class _AlbumMenu extends ConsumerWidget {
  const _AlbumMenu({required this.album, required this.tracks});

  final AlbumSummary album;
  final List<Track> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final list = tracks;
    final ctrl = ref.read(playerControllerProvider);
    return IconButton(
      tooltip: l.moreActions,
      icon: const Icon(Icons.more_vert_rounded),
      onPressed: () async {
        final v = await showCcActionSheet<_AlbumAction>(
          context: context,
          title: album.title ?? l.unknownAlbum,
          groups: [
            [
              CcAction(icon: Icons.queue_music_rounded, label: l.addToQueue, value: _AlbumAction.queue),
              CcAction(icon: Icons.playlist_add_rounded, label: l.addToPlaylist, value: _AlbumAction.playlist),
              CcAction(icon: Icons.share_rounded, label: l.shareMenu, value: _AlbumAction.share),
              CcAction(icon: Icons.auto_fix_high_rounded, label: l.enrichAlbum, value: _AlbumAction.enrich),
              CcAction(icon: Icons.image_outlined, label: l.coverChange, value: _AlbumAction.cover),
              if (list.any((t) => t.coverSource == 1))
                CcAction(icon: Icons.restore_rounded, label: l.coverRestoreOriginal, value: _AlbumAction.restoreCover),
              CcAction(icon: Icons.merge_rounded, label: l.albumMergeWith, value: _AlbumAction.merge),
            ],
          ],
        );
        if (v == null || !context.mounted) return;
        switch (v) {
          case _AlbumAction.queue:
            var added = 0, full = false;
            for (final t in list) {
              final r = await ctrl.addToQueue(t.id);
              added += r?.added ?? 1;
              if (r != null && r.full) {
                full = true;
                break;
              }
            }
            if (context.mounted) showQueued(context, (added: added, full: full), wanted: list.length);
          case _AlbumAction.playlist:
            showAddToPlaylistSheet(context, ref, list);
          case _AlbumAction.share:
            DevicesSheet.show(context, trackIds: [for (final t in list) t.id]);
          case _AlbumAction.enrich:
            try {
              final r = await ref
                  .read(enrichJobProvider.notifier)
                  .startDue(among: [for (final t in list) t.id]);
              if (!context.mounted) return;
              if (r == EnrichStart.nothing) showMsg(context, l.enrichNothingToDo);
              if (r == EnrichStart.busy) showMsg(context, l.enrichBusy);
            } on Object catch (e, st) {
              if (e is Error) {
                AppLog.e('enrich album: not started', e, st);
              } else {
                AppLog.w('enrich album: not started', e, st);
              }
            }
          case _AlbumAction.cover:
            showCoverPicker(
              context,
              save: (ops, bytes, mime) => ops.setAlbumCover(album.albumKey, bytes, mime),
              online: album.title == null
                  ? null
                  : (album: album.title!, artist: album.variousArtists ? '' : album.artist ?? ''),
            );
          case _AlbumAction.restoreCover:
            ref.read(coverOpsProvider).restoreAlbumCover(album.albumKey);
          case _AlbumAction.merge:
            // The album this page shows is gone once merged: leave it.
            showAlbumMergeDialog(context, ref, album).then((merged) {
              if (merged && context.mounted) Navigator.of(context).maybePop();
            });
        }
      },
    );
  }
}

enum _AlbumAction { queue, playlist, share, enrich, cover, restoreCover, merge }
