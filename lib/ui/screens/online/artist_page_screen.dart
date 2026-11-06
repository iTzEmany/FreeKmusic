import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../core/constants.dart';
import '../../../data/db/app_database.dart' show Track;
import '../../../data/repositories/library_queries.dart' show ArtistSummary;
import '../../../l10n/l10n_ext.dart';
import '../../../providers/artist_merge_providers.dart';
import '../../../providers/selection_providers.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/ytm_catalog_providers.dart';
import '../../../services/online/library_overlap.dart';
import '../../../services/online/youtube_service.dart';
import '../../../services/online/ytm_artist.dart';
import '../../shell/shell_nav.dart';
import '../../widgets/section_header.dart';
import '../../widgets/track_row.dart';
import '../library/artist_screen.dart';
import '../releases/follow_button.dart';
import '../youtube/online_results.dart';
import 'artist_page_sections.dart';
import 'artist_picker_sheet.dart' show mergeArtistWith;
import 'artist_songs_screen.dart';
import 'catalog_error_view.dart';
import 'discography_screen.dart';
import 'online_album_screen.dart';
import 'online_page_frame.dart';
import 'online_song_row.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/show_msg.dart';

/// The page of an artist on YouTube Music: the songs of the library first,
/// then top songs, releases, similar artists and the biography. [artist] is
/// the reference the page was opened from (it has the square photo).
class ArtistPageScreen extends ConsumerWidget {
  const ArtistPageScreen({super.key, required this.artist});

  final YtmArtistRef artist;

  /// Reads again every profile of the group.
  Future<void> _refresh(WidgetRef ref, List<String> ids) async {
    for (final id in ids) {
      try {
        await ref.read(ytmCatalogProvider).artist(id, ref.read(ytmLanguageProvider), refresh: true);
      } on Object catch (e) {
        AppLog.w('artist page: refresh failed ($e)');
      }
      ref.invalidate(artistPageProvider(id));
    }
  }

  /// Runs a change of the groups; a failure is logged and told, never left unhandled.
  Future<void> _guard(BuildContext context, Future<void> Function() change, String done) async {
    try {
      await change();
      if (context.mounted) showMsg(context, done);
    } on Object catch (e, st) {
      AppLog.w('artist merge change failed', e, st);
      if (context.mounted) showMsg(context, context.l10n.loadFailed);
    }
  }

  /// «Separa profili»: the whole group of [head] breaks apart, and the pairs are
  /// marked «diversi» so the detector does not offer the merge again.
  Future<void> _split(BuildContext context, WidgetRef ref, String id) => _guard(context, () async {
        await ref.read(artistAliasRepositoryProvider).dissolve(id);
        ref.read(artistMergeEpochProvider.notifier).bump();
      }, context.l10n.artistSplitDone);

  Future<void> _decide(BuildContext context, WidgetRef ref, YtmArtistRef head, YtmArtistRef other, {required bool merge}) {
    final l = context.l10n;
    return _guard(context, () async {
      final repo = ref.read(artistAliasRepositoryProvider);
      if (merge) {
        await repo.merge(head.id, other.id);
      } else {
        await repo.markNotSame(head.id, other.id);
      }
      ref.read(artistMergeEpochProvider.notifier).bump();
    }, merge ? l.artistMerged : l.artistNotSameDone);
  }

  /// The normal search for the artist's name, when the page cannot be read.
  void _searchSongs(BuildContext context, YtmArtistRef artist) => ShellNav.open<void>(
        context,
        Scaffold(
          appBar: CcAppBar(title: artist.name),
          body: OnlineResults(query: artist.name, submitted: 1),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    // An alias opens the page of its main profile; the group is read first.
    final groupAsync = ref.watch(artistGroupProvider(artist.id));
    final ids = groupAsync.hasError ? [artist.id] : groupAsync.value;
    if (ids == null) {
      return OnlinePageFrame(
        title: artist.name,
        slivers: [
          SliverToBoxAdapter(child: ArtistHeader(artist: artist)),
          const SliverToBoxAdapter(child: PageSkeleton()),
        ],
      );
    }
    final page = ref.watch(artistPageProvider(ids.first));
    final shelves = ref.watch(groupShelvesProvider(ids.join('|')));
    final main = page.value;
    final head = ids.first == artist.id
        ? artist
        : YtmArtistRef(
            id: ids.first,
            name: main?.value.ref.name ?? artist.name,
            thumbnailUrl: artist.thumbnailUrl,
          );
    final suggestion = ref.watch(artistMergeSuggestionProvider((id: head.id, name: head.name))).value;
    final local = localArtistFor(head.name, ref.watch(artistsProvider).value ?? const []);
    final localTracks = local == null
        ? const <Track>[]
        : ref.watch(artistTracksProvider(local.key)).value ?? const <Track>[];
    final data = main;
    final songs = <YtResult>[];
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: ArtistHeader(
          artist: head,
          audience: data?.value.ref.audience,
          // The follow row is the main profile's: not the photo of the alias the page was opened from.
          action: kEnableYoutube
              ? FollowButton(artist: head.id == artist.id ? head : YtmArtistRef(id: head.id, name: head.name))
              : null,
        ),
      ),
      if (ids.length > 1) SliverToBoxAdapter(child: MergedProfilesNote(count: ids.length)),
      if (suggestion != null)
        SliverToBoxAdapter(
          child: MergeWarning(
            other: suggestion.audience == null ? suggestion.name : '${suggestion.name}, ${suggestion.audience}',
            onMerge: () => _decide(context, ref, head, suggestion, merge: true),
            onDifferent: () => _decide(context, ref, head, suggestion, merge: false),
          ),
        ),
    ];
    if (data != null) {
      if (data.stale) {
        slivers.add(SliverToBoxAdapter(child: OfflineNotice(fetchedAt: data.fetchedAt)));
      }
      if (local != null && localTracks.isNotEmpty) {
        slivers.addAll(_library(context, ref, local, localTracks));
      }
      final overlap = LibraryOverlap(localTracks);
      for (final shelf in shelves ?? data.value.shelves) {
        switch (shelf) {
          case YtmSongShelf():
            if (shelf.songs.isEmpty) break;
            final start = songs.length;
            songs.addAll(shelf.songs);
            slivers.addAll(_songs(context, head, shelf, start, overlap));
          case YtmReleaseShelf():
            if (shelf.releases.isEmpty) break;
            slivers.add(SliverToBoxAdapter(child: _releases(context, head, shelf)));
          case YtmArtistShelf():
            if (shelf.artists.isEmpty) break;
            slivers.add(SliverToBoxAdapter(
              child: ArtistList(
                shelf: shelf,
                onOpen: (a) =>
                    ShellNav.open<void>(context, ArtistPageScreen(artist: a)),
              ),
            ));
        }
      }
      final about = data.value.description?.trim() ?? '';
      if (about.isNotEmpty) slivers.add(SliverToBoxAdapter(child: AboutSection(text: about)));
    } else if (page.hasError) {
      slivers.add(SliverToBoxAdapter(
        child: CatalogErrorView(
          error: page.error!,
          onRetry: () => ref.invalidate(artistPageProvider(head.id)),
          notFoundText: l.ytmArtistNotFound,
          unreadableText: l.ytmArtistUnreadable,
          onSearch: () => _searchSongs(context, head),
          searchLabel: l.ytmSearchSongsOf(head.name),
        ),
      ));
    } else {
      slivers.add(const SliverToBoxAdapter(child: PageSkeleton()));
    }
    return OnlinePageFrame(
      title: head.name,
      selectionKey: SelectionKey.ytmArtistOf(head.id),
      pickable: songs,
      onRefresh: () => _refresh(ref, ids),
      actions: [
        PopupMenuButton<bool>(
          key: const ValueKey('artist-menu'),
          tooltip: l.moreActions,
          onSelected: (split) => split ? _split(context, ref, head.id) : mergeArtistWith(context, ref, head, ids),
          itemBuilder: (_) => [
            PopupMenuItem(value: false, height: 48, child: Text(l.artistMergeWith)),
            if (ids.length > 1) PopupMenuItem(value: true, height: 48, child: Text(l.artistSplit)),
          ],
        ),
      ],
      slivers: slivers,
    );
  }

  /// «Nella tua libreria»: up to five of the artist's songs you already have.
  List<Widget> _library(
      BuildContext context, WidgetRef ref, ArtistSummary local, List<Track> tracks) {
    final l = context.l10n;
    final shown = tracks.take(5).toList();
    final ctrl = ref.read(playerControllerProvider);
    final ctx = PlayContext(PlayContextKind.artist, local.name);
    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          l.ytmInYourLibrary,
          actionLabel: l.showAll,
          onAction: () => ShellNav.open<void>(context, ArtistDetailScreen(artist: local)),
        ),
      ),
      SliverList.builder(
        itemCount: shown.length,
        itemBuilder: (_, i) => SizedBox(
          height: 64,
          child: LiveTrackRow(
            track: shown[i],
            onTap: () => ctrl.playFromList(tracks, i, context: ctx),
          ),
        ),
      ),
    ];
  }

  List<Widget> _songs(
      BuildContext context, YtmArtistRef artist, YtmSongShelf shelf, int start, LibraryOverlap overlap) {
    final l = context.l10n;
    final link = shelf.allSongs;
    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          shelf.title,
          actionLabel: link == null ? null : l.showAll,
          onAction: link == null
              ? null
              : () => ShellNav.open<void>(
                  context, ArtistSongsScreen(artist: artist, title: shelf.title, link: link)),
        ),
      ),
      SliverList.builder(
        itemCount: shelf.songs.length,
        itemBuilder: (_, i) => OnlineSongTile(
          result: shelf.songs[i],
          index: start + i,
          selectionKey: SelectionKey.ytmArtistOf(artist.id),
          ownedLocally: overlap.owns(shelf.songs[i]),
        ),
      ),
    ];
  }

  Widget _releases(BuildContext context, YtmArtistRef artist, YtmReleaseShelf shelf) {
    final more = shelf.more;
    return ReleaseList(
      shelf: shelf,
      onOpen: (r) => ShellNav.open<void>(
          context, OnlineAlbumScreen(browseId: r.browseId, release: r)),
      onMore: more == null
          ? null
          : () => ShellNav.open<void>(
              context, DiscographyScreen(artist: artist, title: shelf.title, link: more)),
    );
  }
}
