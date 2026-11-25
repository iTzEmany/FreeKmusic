import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../core/app_log.dart';
import '../../../providers/favorite_collections_providers.dart';
import '../../../providers/settings_providers.dart' show settingsStoreProvider;
import '../../../providers/online_collection_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/ui_providers.dart' show searchPrefillProvider;
import '../../../services/online/external_collection.dart';
import '../../../services/online/external_links.dart';
import '../../../services/radio/country_names.dart' show countryNameIn;
import '../../../services/online/youtube_service.dart' show YtResult;
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../search/chart_genre_labels.dart';
import '../../widgets/track_row.dart' show TrackRow;
import '../../widgets/cc_sheet.dart';
import '../../widgets/collection_header.dart' show CollectionHeader, collectionActions;
import '../../widgets/empty_state.dart';
import '../../widgets/net_thumbnail.dart';
import '../../widgets/show_msg.dart';
import '../import/import_flow.dart' show startCsvImport;
import '../now_playing/now_playing_screen.dart' show playFromSearchNotice, playMixedAndOpen;
import '../youtube/playlist_source_sheet.dart';
import 'artist_page_sections.dart' show PageSkeleton, thumbAt;
import 'catalog_error_view.dart';
import 'online_list_play.dart';
import 'online_collection_rows.dart';
import 'online_page_frame.dart';
import 'online_song_row.dart';
import '../../widgets/action_catalog.dart';

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

  /// The uuid of the library playlist this page was saved as (D-524): remembered per page address, so a later
  /// visit finds it (the heart is full, no second copy). Read once the page is known, see [_loading].
  String? _savedUuid;
  Future<void>? _loading;

  Future<void> _loadSaved(String sourceUrl) async {
    final uuid = await savedPlaylistOfPage(ref, sourceUrl);
    if (mounted && uuid != null) setState(() => _savedUuid = uuid);
  }

  bool get _external => widget.source is! YoutubeListingRef;

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
    final c = ref.read(onlineCollectionProvider(widget.source)).value?.collection;
    final queued = _queued, ctrl = ref.read(playerControllerProvider);
    if (queued == null || matches == null || c == null) return;
    // A library playlist with the same name is another list: the keyed Play tells them apart.
    if (!ctrl.isPlayingList('online-collection:${c.sourceUrl}')) return;
    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      if (m is! TrackReady || !queued.add(i)) continue;
      unawaited(switch (m) {
        TrackReadyOnline(:final result) => ctrl.appendOnline(result),
        TrackReadyLibrary(:final track) => ctrl.appendTrack(track.id),
      });
    }
  }

  void _searchByHand(ExternalTrack t) {
    ref.read(searchPrefillProvider.notifier).set([t.title, ?t.artists.firstOrNull].join(' '));
    ShellNav.showSearch(context, ref);
  }

  /// «Salva in Libreria»: returns the playlist's uuid, or null when no row is ready (nothing is saved).
  Future<String?> _save(ExternalCollection c, List<TrackMatch> matches) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final remember = ref.read(settingsStoreProvider); // before any await
    try {
      final saved = await saveToLibrary(ref, c.title, matches, fallback: l.newPlaylist);
      showMsgOn(messenger, saved == null ? l.extSaveNothing : l.extSavedAs(saved.name));
      final uuid = saved?.uuid;
      if (uuid == null) return null;
      await remember.writeSavedOnlinePlaylist(c.sourceUrl, uuid);
      if (mounted) setState(() => _savedUuid = uuid);
      return uuid;
    } on Object catch (e, st) {
      AppLog.w('online page: playlist not saved', e, st);
      showMsgOn(messenger, l.loadFailed);
      return null;
    }
  }

  /// The heart (D-724): off the library, a tap saves the playlist and favourites it; later taps only toggle the
  /// favourite, the saved copy stays.
  /// True when the favourite changed.
  Future<bool> _toggleFavorite(ExternalCollection c, List<TrackMatch> matches) async {
    final toggle = ref.read(toggleFavoriteCollectionProvider); // before any await
    await _loading;
    final uuid = _savedUuid ?? await _save(c, matches);
    if (uuid == null) return false;
    await toggle(favoritePlaylistKind, uuid);
    return true;
  }

  Future<void> _copyLink(ExternalCollection c) async {
    await Clipboard.setData(ClipboardData(text: c.sourceUrl));
    if (mounted) showMsg(context, context.l10n.copied);
  }

  Future<void> _openMenu(ExternalCollection c, List<YtResult> songs, List<TrackMatch> matches) {
    final l = context.l10n;
    return showCcActionSheet<String>(
      context: context,
      title: c.title,
      groups: [
        [
          CcAction<String>(
            icon: CatalogAction.download.icon,
            label: _external ? l.extDownloadAll : l.ytDownload,
            value: 'playlist-menu-download',
            onTap: () => _external
                ? startOnlineDownloads(context, ref, songs)
                : PlaylistSourceSheet.show(context, c.sourceUrl),
          ),
          if (widget.source is! ChartRef)
            CcAction<String>(
              icon: Icons.link_rounded,
              label: l.copyLink,
              value: 'playlist-menu-copy',
              onTap: () => _copyLink(c),
            ),
          CcAction<String>(
            icon: CatalogAction.library.icon,
            label: CatalogAction.library.label(l),
            value: 'playlist-menu-save',
            onTap: () => _save(c, matches),
          ),
          if (_external)
            CcAction<String>(
              icon: Icons.refresh_rounded,
              label: l.extRefresh,
              value: 'playlist-menu-refresh',
              onTap: () async {
                final ok = await refreshOnlineCollection(ref, widget.source);
                if (!ok && mounted) showMsg(context, l.loadFailed);
              },
            ),
        ],
      ],
    );
  }

  Widget _header(ExternalCollection c, List<TrackMatch> matches, List<YtResult> songs, bool anyReady,
      String listKey, String? sourceLine, VoidCallback playExternal) {
    final l = context.l10n;
    final owner = c.owner;
    final fav = _savedUuid != null &&
        (ref.watch(isFavoriteCollectionProvider((kind: favoritePlaylistKind, key: _savedUuid!))).value ?? false);
    final canPlay = _external ? anyReady : songs.isNotEmpty;
    _loading ??= _loadSaved(c.sourceUrl);
    return CollectionHeader(
      cover: (s) => NetThumbnail(
        url: thumbAt(context, c.coverUrl, s),
        width: s,
        height: s,
        radius: CcDims.rGrid,
        icon: Icons.queue_music_rounded,
      ),
      name: c.title,
      subtitle: owner == null || owner.isEmpty ? null : Text(owner, maxLines: 1, overflow: TextOverflow.ellipsis),
      meta: [?sourceLine, l.tracksCount(c.tracks.length)].join('\n'),
      actions: collectionActions(
        context,
        ref,
        onPlay: !canPlay
            ? null
            : _external
                ? playExternal
                : () => playOrQueueOnline(context, ref, songs, listKey: listKey),
        shuffleIds: const [],
        shuffleKey: listKey,
        shufflePlus: false,
        favorite: fav,
        onFavorite: () => _toggleFavorite(c, matches),
        // Rows still being matched would be left out of the copy.
        favoriteEnabled: !matches.any((m) => m is TrackPending),
        // A chart has no link of its own to share.
        onShare: widget.source is ChartRef ? null : (_) => _copyLink(c),
        menu: IconButton(
          key: const ValueKey('playlist-more'),
          tooltip: CatalogAction.more.label(l),
          onPressed: () => _openMenu(c, songs, matches),
          icon: Icon(CatalogAction.more.icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    if (_external) ref.listen(onlineMatchesProvider(source), (_, next) => _extendQueue(next.value));
    final page = ref.watch(onlineCollectionProvider(source));
    final live = _external ? ref.watch(onlineMatchesProvider(source)).value : null;
    final first = page.value;
    final l = context.l10n;
    // A chart titles itself from the genre label; the line under it says where it comes from.
    final chartInfo = first?.chart;
    final collection = source is ChartRef
        ? first?.collection.withTitle(l.chartTitle(chartGenreLabel(l, source.genre.id)))
        : first?.collection;
    final data = collection == null
        ? null
        : CollectionPage(collection, live ?? first!.matches, chart: chartInfo);
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
    // In a Jam only online songs can be sent (playOrQueueOnline).
    final anyReady = _external && ref.read(playerControllerProvider).inJam
        ? songs.isNotEmpty
        : data?.matches.any((m) => m is TrackReady) ?? false;
    // Exportify only helps with Spotify; a short link's service is not known yet.
    final exportify = source is ExternalRef && source.link?.service == ExternalService.spotify;
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
            child: _header(c, data?.matches ?? const [], songs, anyReady, listKey,
                chartInfo == null ? null : _chartLine(context, chartInfo), () => _playExternal(data!, songs, listKey)),
          ),
        if (data != null && data.matches.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: CatalogAction.playlist.icon,
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
              onSearch: exportify ? () => unawaited(startCsvImport(context, ref)) : null,
              searchLabel: exportify ? l.extExportifyFull : null,
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

/// «Classifica Deezer · aggiornata …»; Apple's feed also names the country it was read for.
String _chartLine(BuildContext context, ChartInfo info) {
  final l = context.l10n;
  final m = MaterialLocalizations.of(context);
  final when = '${m.formatShortDate(info.updated)} ${m.formatTimeOfDay(TimeOfDay.fromDateTime(info.updated))}';
  return info.apple
      ? l.chartSourceApple(
          countryNameIn(info.country, Localizations.localeOf(context).languageCode, info.country), when)
      : l.chartSourceDeezer(when);
}
