import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/favorite_collections_providers.dart';
import '../../../providers/pending_playlist_adds.dart' show addToPlaylistTag;
import '../../../providers/selection_providers.dart';
import '../../../providers/import_providers.dart';
import '../../../providers/library_overlap_providers.dart';
import '../../../providers/library_add_providers.dart';
import '../../../providers/track_state_providers.dart' show TrackState, trackStateProvider;
import '../../../providers/ytm_catalog_providers.dart';
import '../../../services/import/import_options.dart';
import '../../../services/import/playlist_import_service.dart' show ytmAlbumSourceKind;
import '../../../services/online/album_download_plan.dart';
import '../../../services/online/ytm_artist.dart';
import '../../../services/online/youtube_service.dart' show YtResult;
import '../../shell/shell_nav.dart';
import '../playlists/playlist_picker.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/collection_header.dart' show CollectionHeader, collectionActions;
import '../../widgets/confirm.dart';
import '../../widgets/format_utils.dart';
import '../../widgets/net_thumbnail.dart';
import '../import/import_detail_screen.dart';
import 'artist_page_screen.dart';
import 'artist_page_sections.dart';
import 'catalog_error_view.dart';
import 'online_list_play.dart';
import 'online_page_frame.dart';
import 'online_song_row.dart';
import '../../widgets/show_msg.dart';
import '../../widgets/action_catalog.dart';

/// An album, single or EP of YouTube Music: cover, numbered songs with
/// «Scarica», Play, Shuffle and a ⋮ menu (with «Scarica album»). [release] is what the page
/// was opened from (title and cover are shown while it loads).
class OnlineAlbumScreen extends ConsumerWidget {
  const OnlineAlbumScreen({super.key, required this.browseId, this.release});

  final String browseId;
  final YtmRelease? release;

  String get _listKey => SelectionKey.ytmAlbumOf(browseId);

  Future<void> _downloadAlbum(BuildContext context, WidgetRef ref, YtmAlbum album) async {
    final l = context.l10n;
    // What the import links instead of downloading: the songs it already has.
    final plan = albumDownloadPlan(
        album, (r) => ref.read(trackStateProvider(r.indexKey)) == TrackState.downloaded);
    if (plan.tracks.isEmpty) return;
    final body = [
      l.ytmAlbumConfirmBody(plan.tracks.length, l.durationMinutes(plan.duration.inMinutes),
          formatBytes(plan.estimatedBytes, Localizations.localeOf(context).toString())),
      if (plan.owned > 0) l.ytmAlbumConfirmOwned(plan.owned),
    ].join('\n');
    final ok = await showConfirm(
      context,
      title: l.ytmDownloadAlbumTitle(album.title),
      body: body,
      confirmLabel: l.ytDownload,
    );
    if (!ok || !context.mounted) return;
    final nav = Navigator.of(context);
    try {
      final id = await ref.read(playlistImportServiceProvider).startFromResults(
            plan.importName,
            plan.tracks,
            options: ImportOptions(folderPath: plan.folder, fetchCovers: true, downloadToo: true),
            sourceKind: ytmAlbumSourceKind,
          );
      if (!context.mounted) return;
      showMsg(
        context,
        l.ytmAlbumStarted(plan.importName),
        persist: true,
        action: SnackBarAction(
          label: l.ytmShowImport,
          onPressed: () => nav.push(MaterialPageRoute<void>(
              builder: (_) => ImportDetailScreen(importId: id))),
        ),
      );
    } on Object catch (e, st) {
      AppLog.e('album download: could not start the import', e, st);
      if (!context.mounted) return;
      showMsg(context, l.loadFailed);
    }
  }

  Future<void> _addToPlaylist(BuildContext context, WidgetRef ref, List<YtResult> songs) async {
    final picked = await pickPlaylist(context, ref);
    if (picked == null || !context.mounted) return;
    final adder = ref.read(libraryAdderProvider);
    final l = context.l10n;
    final done = [for (final r in songs) await adder.add(r, tag: addToPlaylistTag(picked.id))];
    if (!context.mounted) return;
    showMsg(
      context,
      done.contains(null)
          ? l.libraryAddFailed
          : done.contains(false)
          ? l.suggestionAddWhenDownloaded(picked.name)
          : l.addedToPlaylistMany(done.length, picked.name),
    );
  }

  /// The heart (D-724): off the library, a tap saves the album and favourites it; later taps only toggle the
  /// favourite, the saved album stays.
  Future<void> _toggleFavorite(WidgetRef ref, List<YtResult> songs) async {
    var key = await ref.read(savedOnlineAlbumKeyProvider(songs.first.indexKey).future);
    key ??= await saveOnlineAlbum(ref, songs);
    if (key == null) return;
    await ref.read(toggleFavoriteCollectionProvider)(favoriteAlbumKind, key);
  }

  Future<void> _share(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: 'https://music.youtube.com/browse/$browseId'));
    if (context.mounted) showMsg(context, context.l10n.copied);
  }

  Future<void> _openMenu(BuildContext context, WidgetRef ref, YtmAlbum album, List<YtResult> songs) {
    final l = context.l10n;
    final items = <(String, IconData, String, VoidCallback)>[
      ('album-menu-download', CatalogAction.download.icon, l.ytmDownloadAlbum,
          () => _downloadAlbum(context, ref, album)),
      ('album-menu-queue', CatalogAction.queue.icon, CatalogAction.queue.label(l), () => queueOnlineList(context, ref, songs)),
      ('album-menu-playlist', CatalogAction.playlist.icon, CatalogAction.playlist.label(l),
          () => _addToPlaylist(context, ref, songs)),
      ('album-menu-save', CatalogAction.library.icon, CatalogAction.library.label(l), () async {
        final key = await saveOnlineAlbum(ref, songs);
        if (context.mounted) showMsg(context, key == null ? l.extSaveNothing : l.extSavedAs(album.title));
      }),
    ];
    return showCcActionSheet<String>(
      context: context,
      title: album.title,
      groups: [
        [
          for (final (key, icon, label, run) in items)
            CcAction<String>(icon: icon, label: label, value: key, onTap: run),
        ],
      ],
    );
  }

  Widget _header(BuildContext context, WidgetRef ref, YtmAlbum? a, List<YtResult> songs) {
    final l = context.l10n;
    final cc = context.cc;
    final title = a?.title ?? release?.title ?? '';
    final kind = a == null
        ? release?.subtitle ?? ''
        : [a.kindLabel, a.year].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    var total = Duration.zero;
    for (final t in a?.tracks ?? const <YtmAlbumTrack>[]) {
      total += t.result.duration ?? Duration.zero;
    }
    final stats = a == null || a.tracks.isEmpty
        ? ''
        : [
            l.tracksCount(a.tracks.length),
            if (total > Duration.zero) l.durationMinutes(total.inMinutes),
          ].join(', ');
    final artist = a?.artist;
    final savedKey = songs.isEmpty ? null : ref.watch(savedOnlineAlbumKeyProvider(songs.first.indexKey)).value;
    final fav = savedKey != null &&
        (ref.watch(isFavoriteCollectionProvider((kind: favoriteAlbumKind, key: savedKey))).value ?? false);
    return CollectionHeader(
      cover: (s) => NetThumbnail(
        url: thumbAt(context, a?.coverUrl ?? release?.thumbnailUrl, s),
        width: s,
        height: s,
        radius: CcDims.rGrid,
        icon: Icons.album_rounded,
      ),
      name: title,
      subtitle: artist == null || artist.name.isEmpty
          ? null
          : InkWell(
              key: const ValueKey('album-artist'),
              onTap: artist.id.isEmpty ? null : () => ShellNav.open<void>(context, ArtistPageScreen(artist: artist)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: CcDims.gap4),
                child: Text(artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: artist.id.isEmpty ? null : cc.accentSoft)),
              ),
            ),
      meta: [kind, stats].where((s) => s.isNotEmpty).join('\n'),
      actions: collectionActions(
        context,
        ref,
        onPlay: songs.isEmpty ? null : () => playOrQueueOnline(context, ref, songs, listKey: _listKey),
        shuffleIds: const [],
        shuffleKey: _listKey,
        shufflePlus: false,
        favorite: fav,
        onFavorite: songs.isEmpty ? null : () => _toggleFavorite(ref, songs),
        onShare: a == null ? null : (_) => _share(context),
        menu: a == null
            ? null
            : IconButton(
                key: const ValueKey('album-more'),
                tooltip: CatalogAction.more.label(l),
                onPressed: () => _openMenu(context, ref, a, songs),
                icon: Icon(CatalogAction.more.icon),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(onlineAlbumProvider(browseId));
    final data = page.value;
    final album = data?.value;
    final overlap = ref.watch(localOverlapProvider(album?.artist?.name ?? ''));
    final songs = [for (final t in album?.tracks ?? const <YtmAlbumTrack>[]) t.result];
    return OnlinePageFrame(
      title: album?.title ?? release?.title ?? '',
      selectionKey: _listKey,
      pickable: songs,
      onRefresh: () async {
        try {
          await ref
              .read(ytmCatalogProvider)
              .album(browseId, ref.read(ytmLanguageProvider), refresh: true);
        } on Object catch (e) {
          AppLog.w('album page: refresh failed ($e)');
        }
        ref.invalidate(onlineAlbumProvider(browseId));
      },
      slivers: [
        SliverToBoxAdapter(child: _header(context, ref, album, songs)),
        if (data != null && data.stale)
          SliverToBoxAdapter(child: OfflineNotice(fetchedAt: data.fetchedAt)),
        if (album != null)
          SliverList.builder(
            itemCount: album.tracks.length,
            itemBuilder: (_, i) => OnlineSongTile(
              result: album.tracks[i].result,
              index: i,
              number: album.tracks[i].number ?? i + 1,
              selectionKey: _listKey,
              ownedLocally: album.artist != null && overlap.owns(album.tracks[i].result),
            ),
          )
        else if (page.hasError)
          SliverToBoxAdapter(
            child: CatalogErrorView(
              error: page.error!,
              onRetry: () => ref.invalidate(onlineAlbumProvider(browseId)),
            ),
          )
        else
          const SliverToBoxAdapter(child: PageSkeleton(rows: 8)),
      ],
    );
  }
}
