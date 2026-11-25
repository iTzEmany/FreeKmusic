import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/library_queries.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/library_providers.dart';
import '../../providers/preview_providers.dart';
import '../../providers/player_providers.dart';
import '../../core/platform.dart' show isDesktop;
import '../../data/db/app_database.dart' show Track;
import '../screens/playlists/playlist_dialogs.dart' show showAddToPlaylistSheet;
import 'action_catalog.dart';
import 'album_grid.dart';
import 'context_menu.dart';
import 'show_msg.dart';
import 'cover_image.dart';
import 'motion.dart';
import 'progress_frame.dart';

/// Hold a cover: 20 s of the album's first track.
Future<void> _previewAlbum(WidgetRef ref, String albumKey) async {
  final tracks = await ref.read(albumTracksOnceProvider)(albumKey);
  if (tracks.isNotEmpty) {
    await ref.read(previewProvider.notifier).start(tracks.first);
  }
}

/// «Aggiungi alla coda» for several songs (as the ⋮ of an album page does).
Future<void> queueTracks(BuildContext context, WidgetRef ref, List<Track> tracks) async {
  final ctrl = ref.read(playerControllerProvider);
  var added = 0, full = false;
  for (final t in tracks) {
    final r = await ctrl.addToQueue(t.id);
    added += r?.added ?? 1;
    if (r != null && r.full) {
      full = true;
      break;
    }
  }
  if (context.mounted) showQueued(context, (added: added, full: full), wanted: tracks.length);
}

/// Right click on an album (desktop): queue and playlist, as in the ⋮ of its page.
void showAlbumMenu(BuildContext context, WidgetRef ref, AlbumSummary album, Offset at) {
  if (!isDesktop) return;
  final l = context.l10n;
  Future<List<Track>> tracks() => ref.read(albumTracksOnceProvider)(album.albumKey);
  showContextMenu(context, at, [
    [
      MenuAction(CatalogAction.queue.icon, l.addToQueue, () async {
        final list = await tracks();
        if (context.mounted) await queueTracks(context, ref, list);
      }),
      MenuAction(CatalogAction.playlist.icon, l.addToPlaylist, () async {
        final list = await tracks();
        if (context.mounted) await showAddToPlaylistSheet(context, ref, list);
      }),
    ],
  ]);
}

class AlbumCard extends ConsumerWidget {
  const AlbumCard({super.key, required this.album, required this.onTap});

  final AlbumSummary album;
  final VoidCallback onTap;

  Future<void> _preview(WidgetRef ref) => _previewAlbum(ref, album.albumKey);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artist = album.variousArtists
        ? context.l10n.variousArtists
        : (album.artist ?? context.l10n.unknownArtist);
    return PressScale(
      child: InkWell(
        onTap: onTap,
        onSecondaryTapDown: (d) => showAlbumMenu(context, ref, album, d.globalPosition),
        borderRadius: BorderRadius.circular(CcDims.rGrid),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => Semantics(
                    customSemanticsActions: {
                      CustomSemanticsAction(
                        label: context.l10n.previewTrack,
                      ): () =>
                          _preview(ref),
                    },
                    child: GestureDetector(
                      // Hold the cover: 20 s of the album's first track.
                      onLongPressStart: (_) => _preview(ref),
                      onLongPressEnd: (_) =>
                          ref.read(previewProvider.notifier).stop(),
                      onLongPressCancel: ref
                          .read(previewProvider.notifier)
                          .stop,
                      child: CoverImage(
                        coverKey: album.coverKey,
                        size: c.biggest.shortestSide,
                        radius: 8,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                album.title ?? context.l10n.unknownAlbum,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Up to this many albums are listed as rows; more become a grid (D-33).
const albumRowsMax = 4;

/// Few albums as rows, many as a grid.
class AlbumShelf extends StatelessWidget {
  const AlbumShelf({super.key, required this.albums, required this.onOpen});

  final List<AlbumSummary> albums;
  final void Function(AlbumSummary) onOpen;

  @override
  Widget build(BuildContext context) => albums.length <= albumRowsMax
      ? Column(
          children: [
            for (final a in albums) AlbumRow(album: a, onTap: () => onOpen(a)),
          ],
        )
      : Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CcDims.margin - CcDims.gap8,
          ),
          child: AlbumGrid(albums: albums, shrinkWrap: true, onOpen: onOpen),
        );
}

/// One album as a row: square cover (with the playback frame while one of its
/// tracks plays), title and «year, N tracks».
class AlbumRow extends ConsumerWidget {
  const AlbumRow({super.key, required this.album, required this.onTap});

  final AlbumSummary album;
  final VoidCallback onTap;

  static const _box = 60.0, _inset = 4.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final current = ref.watch(
      currentTrackProvider.select((t) => t.value?.albumKey == album.albumKey),
    );
    final cover = CoverImage(
      coverKey: album.coverKey,
      size: _box - 2 * _inset,
      radius: CcDims.rList,
    );
    final meta = [
      if (album.year != null) '${album.year}',
      l.tracksCount(album.trackCount),
    ].join(', ');
    return PressScale(
      child: InkWell(
        onTap: onTap,
        onSecondaryTapDown: (d) => showAlbumMenu(context, ref, album, d.globalPosition),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CcDims.margin,
              vertical: CcDims.gap8,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onLongPressStart: (_) => _previewAlbum(ref, album.albumKey),
                  onLongPressEnd: (_) =>
                      ref.read(previewProvider.notifier).stop(),
                  onLongPressCancel: ref.read(previewProvider.notifier).stop,
                  child: SizedBox.square(
                    dimension: _box,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (current) const Positioned.fill(child: LiveProgressFrame()),
                        cover,
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: CcDims.gap12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.title ?? l.unknownAlbum,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodyLarge?.copyWith(
                          color: current ? cc.accentSoft : cc.text,
                        ),
                      ),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodySmall?.copyWith(color: cc.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
