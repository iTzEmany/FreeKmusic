import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/online_collection_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/ui_providers.dart' show searchPrefillProvider;
import '../../../services/online/external_collection.dart';
import '../../../services/online/external_links.dart';
import '../../../services/online/youtube_service.dart' show YtResult;
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/track_row.dart' show TrackRow;
import '../../widgets/cc_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/net_thumbnail.dart';
import '../../widgets/show_msg.dart';
import '../../widgets/shuffle_button.dart' show ShufflePill;
import '../import/import_flow.dart' show startCsvImport;
import '../now_playing/now_playing_screen.dart' show playFromSearchNotice, playMixedAndOpen;
import '../youtube/playlist_source_sheet.dart';
import 'artist_page_sections.dart' show PageSkeleton, thumbAt;
import 'catalog_error_view.dart';
import 'online_list_play.dart';
import 'online_collection_rows.dart';
import 'online_page_frame.dart';
import 'online_song_row.dart';

/// A playlist, album or channel read from a link: cover, songs streamed on tap,
/// Play, Shuffle and a ⋮ menu with «Scarica» and «Copia link». A Deezer or
/// Spotify page opens at once with its rows pending; each turns playable (or
/// «non trovato») as it is matched (R-195, R-196).
class OnlinePlaylistScreen extends ConsumerStatefulWidget {
  const OnlinePlaylistScreen(this.source, {super.key});

  final OnlineCollectionRef source;

  @override
  ConsumerState<OnlinePlaylistScreen> createState() => _OnlinePlaylistScreenState();
}

class _OnlinePlaylistScreenState extends ConsumerState<OnlinePlaylistScreen> {
  /// Rows a Play of this page already sent to the queue; null until Play.
  Set<int>? _queued;

  bool get _external => widget.source is ExternalRef;

  PlayContext _contextOf(ExternalCollection c) => PlayContext(
      c.kind == CollectionKind.album ? PlayContextKind.album : PlayContextKind.playlist, c.title);

  MixItem _mix(TrackMatch m) => switch (m) {
        TrackReadyOnline(:final result) => (track: null, online: result, seedTitle: null),
        TrackReadyLibrary(:final track) => (track: track, online: null, seedTitle: null),
        _ => throw StateError('only ready rows are played'),
      };

  /// Play of an external page: the rows ready now; the others join the queue as they arrive.
  void _playExternal(CollectionPage page, List<YtResult> songs, String listKey) {
    final ready = [
      for (var i = 0; i < page.matches.length; i++)
        if (page.matches[i] is TrackReady) i,
    ];
    if (ready.isEmpty) return;
    if (ref.read(playerControllerProvider).inJam) {
      playOrQueueOnline(context, ref, songs, listKey: listKey);
      return;
    }
    _queued = ready.toSet();
    unawaited(playMixedAndOpen(context, ref, [for (final i in ready) _mix(page.matches[i])],
        playContext: _contextOf(page.collection), listKey: listKey));
  }

  /// Rows matched after Play go to the end of the queue while it still comes from this page (D-525).
  void _extendQueue(List<TrackMatch>? matches) {
    final queued = _queued, c = ref.read(onlineCollectionProvider(widget.source)).value?.collection;
    if (queued == null || matches == null || c == null) return;
    final now = ref.read(playContextProvider), mine = _contextOf(c);
    if (now?.kind != mine.kind || now?.name != mine.name) return;
    final ctrl = ref.read(playerControllerProvider);
    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      if (m is! TrackReady || !queued.add(i)) continue;
      unawaited(switch (m) {
        TrackReadyOnline(:final result) => ctrl.enqueueOnline(result),
        TrackReadyLibrary(:final track) => ctrl.addToQueue(track.id),
      });
    }
  }

  void _searchByHand(ExternalTrack t) {
    ref.read(searchPrefillProvider.notifier).set([t.title, ?t.artists.firstOrNull].join(' '));
    ShellNav.showSearch(context, ref);
  }

  Future<void> _openMenu(ExternalCollection c, List<YtResult> songs) {
    final l = context.l10n;
    return showCcActionSheet<String>(
      context: context,
      title: c.title,
      groups: [
        [
          CcAction<String>(
            icon: Icons.download_rounded,
            label: _external ? l.extDownloadAll : l.ytDownload,
            value: 'playlist-menu-download',
            onTap: () => _external
                ? startOnlineDownloads(context, ref, songs)
                : PlaylistSourceSheet.show(context, c.sourceUrl),
          ),
          CcAction<String>(
            icon: Icons.link_rounded,
            label: l.copyLink,
            value: 'playlist-menu-copy',
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: c.sourceUrl));
              if (mounted) showMsg(context, l.copied);
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    if (_external) ref.listen(onlineMatchesProvider(source), (_, next) => _extendQueue(next.value));
    final page = ref.watch(onlineCollectionProvider(source));
    final live = _external ? ref.watch(onlineMatchesProvider(source)).value : null;
    final first = page.value;
    final data = first == null || live == null ? first : CollectionPage(first.collection, live);
    final c = data?.collection;
    final listKey = 'online-collection:${c?.sourceUrl ?? source.hashCode}';
    // Selection ids are places in [songs]; rows still pending or unmatched have none.
    final songs = <YtResult>[];
    final slot = <int, int>{};
    for (final (i, m) in (data?.matches ?? const <TrackMatch>[]).indexed) {
      if (m is TrackReadyOnline) {
        slot[i] = songs.length;
        songs.add(m.result);
      }
    }
    final anyReady = data?.matches.any((m) => m is TrackReady) ?? false;
    final l = context.l10n;
    return OnlinePageFrame(
      title: c?.title ?? '',
      selectionKey: listKey,
      pickable: songs,
      onRefresh: () async {
        final ok = await refreshOnlineCollection(ref, source);
        if (!ok && context.mounted) showMsg(context, l.loadFailed);
      },
      slivers: [
        if (c != null)
          SliverToBoxAdapter(
            child: _Header(
              collection: c,
              listKey: listKey,
              onPlay: !(_external ? anyReady : songs.isNotEmpty)
                  ? null
                  : _external
                      ? () => _playExternal(data!, songs, listKey)
                      : () => playOrQueueOnline(context, ref, songs, listKey: listKey),
              onMore: () => _openMenu(c, songs),
            ),
          ),
        if (data != null && data.matches.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.queue_music_rounded,
              message: l.playlistSourceEmpty,
            ),
          )
        else if (data != null)
          SliverList.builder(
            itemCount: data.matches.length,
            itemBuilder: (_, i) => switch (data.matches[i]) {
              TrackReadyOnline(:final result) =>
                OnlineSongTile(result: result, index: slot[i]!, selectionKey: listKey),
              TrackReadyLibrary(:final track) => TrackRow(
                  track: track,
                  onTap: () => unawaited(playFromSearchNotice(context, ref, track: track)),
                ),
              TrackPending() => PendingRow(c!.tracks[i], i),
              TrackNotFound() => NotFoundRow(c!.tracks[i], i, onSearch: () => _searchByHand(c.tracks[i])),
            },
          )
        else if (page.hasError)
          SliverToBoxAdapter(
            child: CatalogErrorView(
              error: page.error!,
              onRetry: () => retryOnlineCollection(ref, source),
              onSearch: _external ? () => unawaited(startCsvImport(context, ref)) : null,
              searchLabel: _external ? l.extExportifyFull : null,
            ),
          )
        else
          const SliverToBoxAdapter(child: PageSkeleton(rows: 8)),
        if (c != null && c.truncated)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(CcDims.margin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _external
                        ? l.extTruncated(c.tracks.length)
                        : l.playlistSourceTruncated(c.tracks.length),
                    key: const ValueKey('playlist-truncated'),
                    style: TextStyle(color: context.cc.textMuted),
                  ),
                  // Spotify's public page stops at 100 songs: the full list comes from Exportify (R-208).
                  if (parseExternalLink(c.sourceUrl)?.service == ExternalService.spotify)
                    TextButton(
                      key: const ValueKey('playlist-exportify'),
                      onPressed: () => unawaited(startCsvImport(context, ref)),
                      child: Text(l.extExportifyFull),
                    ),
                ],
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
