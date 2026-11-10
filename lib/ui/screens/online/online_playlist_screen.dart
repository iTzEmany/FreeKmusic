import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/online_collection_providers.dart';
import '../../../services/online/external_collection.dart';
import '../../../services/online/youtube_service.dart' show YtResult;
import '../../theme/tokens.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/net_thumbnail.dart';
import '../../widgets/show_msg.dart';
import '../../widgets/shuffle_button.dart' show ShufflePill;
import '../youtube/playlist_source_sheet.dart';
import 'artist_page_sections.dart' show PageSkeleton, thumbAt;
import 'catalog_error_view.dart';
import 'online_list_play.dart';
import 'online_page_frame.dart';
import 'online_song_row.dart';

/// A playlist or channel read from a link: cover, songs streamed on tap, Play,
/// Shuffle and a ⋮ menu with «Scarica» and «Copia link».
class OnlinePlaylistScreen extends ConsumerWidget {
  const OnlinePlaylistScreen(this.source, {super.key});

  final OnlineCollectionRef source;

  Future<void> _openMenu(BuildContext context, ExternalCollection c) {
    final l = context.l10n;
    return showCcActionSheet<String>(
      context: context,
      title: c.title,
      groups: [
        [
          CcAction<String>(
            icon: Icons.download_rounded,
            label: l.ytDownload,
            value: 'playlist-menu-download',
            onTap: () => PlaylistSourceSheet.show(context, c.sourceUrl),
          ),
          CcAction<String>(
            icon: Icons.link_rounded,
            label: l.copyLink,
            value: 'playlist-menu-copy',
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: c.sourceUrl));
              if (context.mounted) showMsg(context, l.copied);
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(onlineCollectionProvider(source));
    final data = page.value;
    final c = data?.collection;
    final listKey = 'online-collection:${c?.sourceUrl ?? source.hashCode}';
    final songs = <YtResult>[
      for (final m in data?.matches ?? const <TrackMatch>[])
        if (m is TrackReady) m.result,
    ];
    return OnlinePageFrame(
      title: c?.title ?? '',
      selectionKey: listKey,
      pickable: songs,
      onRefresh: () async => retryOnlineCollection(ref, source),
      slivers: [
        if (c != null)
          SliverToBoxAdapter(
            child: _Header(
              collection: c,
              listKey: listKey,
              onPlay: songs.isEmpty
                  ? null
                  : () => playOrQueueOnline(context, ref, songs, listKey: listKey),
              onMore: () => _openMenu(context, c),
            ),
          ),
        if (data != null)
          SliverList.builder(
            itemCount: data.matches.length,
            itemBuilder: (_, i) => switch (data.matches[i]) {
              // shortcut: index = row, true while every row is ready; 114 maps rows to `songs`.
              TrackReady(:final result) =>
                OnlineSongTile(result: result, index: i, selectionKey: listKey),
              // Drawn by phase 114 (matching in progress / no match found).
              TrackPending() || TrackNotFound() => const SizedBox.shrink(),
            },
          )
        else if (page.hasError)
          SliverToBoxAdapter(
            child: CatalogErrorView(
              error: page.error!,
              onRetry: () => retryOnlineCollection(ref, source),
            ),
          )
        else
          const SliverToBoxAdapter(child: PageSkeleton(rows: 8)),
        if (c != null && c.truncated)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(CcDims.margin),
              child: Text(
                context.l10n.playlistSourceTruncated(c.tracks.length),
                key: const ValueKey('playlist-truncated'),
                style: TextStyle(color: context.cc.textMuted),
              ),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.collection,
    required this.listKey,
    required this.onPlay,
    required this.onMore,
  });

  final ExternalCollection collection;
  final Object listKey;
  final VoidCallback? onPlay;
  final VoidCallback onMore;

  static const _cover = 144.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final owner = collection.owner;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CcDims.margin, 0, CcDims.margin, CcDims.gap8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NetThumbnail(
                url: thumbAt(context, collection.coverUrl, _cover),
                width: _cover,
                height: _cover,
                radius: CcDims.rGrid,
                icon: Icons.queue_music_rounded,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(collection.title,
                          maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.titleLarge),
                    ),
                    if (owner != null && owner.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: CcDims.gap4),
                        child: Text(owner,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodyLarge),
                      ),
                    Text(l.tracksCount(collection.tracks.length),
                        style: theme.bodyMedium?.copyWith(color: cc.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('playlist-play'),
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l.play),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ShufflePill(
                key: const ValueKey('playlist-shuffle'),
                listKey: listKey,
                plus: false,
              ),
            ),
            IconButton(
              key: const ValueKey('playlist-more'),
              tooltip: l.ytmMore,
              onPressed: onMore,
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ]),
        ],
      ),
    );
  }
}
