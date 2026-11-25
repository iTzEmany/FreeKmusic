import '../../../providers/playlist_ops.dart';
import '../../../providers/track_ops.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../data/repositories/playlist_repository.dart';
import '../../../data/repositories/track_repository.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/player_providers.dart';
import '../../widgets/cc_sheet.dart';

/// At most this many big rows: favourites and the most recent playlists.
const kCarPlaylistRows = 6;

/// The playlists to offer, newest activity first (played, else created).
List<PlaylistSummary> recentPlaylists(
  List<PlaylistSummary> all, {
  int max = kCarPlaylistRows - 1,
}) {
  int stamp(PlaylistSummary p) => p.lastPlayedAt ?? p.playlist.createdAt;
  final sorted = [...all.where((p) => p.trackCount > 0)]
    ..sort((a, b) => stamp(b).compareTo(stamp(a)));
  return sorted.take(max).toList();
}

Future<void> showCarPlaylists(BuildContext context) => showCcSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => const _CarPlaylistsSheet(),
);

class _CarPlaylistsSheet extends ConsumerWidget {
  const _CarPlaylistsSheet();

  Future<void> _play(
    BuildContext context,
    WidgetRef ref,
    List<Track> tracks,
    PlayContext pc,
  ) async {
    if (tracks.isEmpty) return;
    Navigator.of(context).pop();
    await ref
        .read(playerControllerProvider)
        .playFromList(tracks, 0, context: pc);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final lists = recentPlaylists(
      ref.watch(playlistsProvider).value ?? const [],
    );
    Widget row(IconData icon, String title, Future<void> Function() onTap) =>
        SizedBox(
          height: 72,
          child: ListTile(
            leading: Icon(icon, size: 36),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            onTap: onTap,
          ),
        );
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row(Icons.favorite_rounded, l.navFavorites, () async {
              final tracks = await ref.read(trackOpsProvider).favorites(sort: SortOption.title);
              if (context.mounted) {
                await _play(
                  context,
                  ref,
                  tracks,
                  const PlayContext(PlayContextKind.favorites),
                );
              }
            }),
            for (final p in lists)
              row(Icons.queue_music_rounded, context.l10n.playlistLabel(p.playlist.name), () async {
                final tracks = await ref.read(playlistOpsProvider).tracksOf(p.playlist.id);
                if (context.mounted) {
                  await _play(
                    context,
                    ref,
                    tracks,
                    PlayContext(PlayContextKind.playlist, p.playlist.name),
                  );
                }
              }),
          ],
        ),
      ),
    );
  }
}
