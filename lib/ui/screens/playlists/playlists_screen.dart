import 'package:flutter/material.dart';
import '../../widgets/create_flows.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/database_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/cover_image.dart';
import '../import/import_flow.dart';
import 'playlist_detail_screen.dart';
import '../../widgets/async_body.dart';
import '../../theme/tokens.dart';

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final lists = ref.watch(playlistsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'csv-import',
            onPressed: () => startCsvImport(context, ref),
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(l.csvImportMenu),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'new-playlist',
            onPressed: () => createPlaylistFlow(context, ref),
            icon: const Icon(Icons.add),
            label: Text(l.newPlaylist),
          ),
        ],
      ),
      body: AsyncBody(
        value: lists,
        onRetry: () => ref.invalidate(playlistsProvider),
        data: (items) => items.isEmpty
            ? EmptyState(icon: Icons.queue_music, message: l.noPlaylists)
            : ListView.builder(
                padding: EdgeInsets.zero.withDock(context),
                itemExtent: 64,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final p = items[i];
                  return ListTile(
                    leading: CoverImage(coverKey: p.coverKey, size: 48),
                    title: Text(
                      p.playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(l.tracksCount(p.trackCount)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PlaylistDetailScreen(playlist: p.playlist),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
