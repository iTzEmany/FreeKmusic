import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/database_providers.dart';
import '../../widgets/alpha_scroller.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/cover_image.dart';
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
      body: AsyncBody(
        value: lists,
        onRetry: () => ref.invalidate(playlistsProvider),
        data: (items) => items.isEmpty
            ? EmptyState(icon: Icons.queue_music, message: l.noPlaylists)
            : PositionScroller(
                itemCount: items.length,
                builder: (controller) => ListView.builder(
                controller: controller,
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
                    subtitle: Text(l.playlistCountLabel(p.trackCount)),
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
      ),
    );
  }
}
