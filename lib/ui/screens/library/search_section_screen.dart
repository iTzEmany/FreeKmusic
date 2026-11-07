import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../data/db/app_database.dart';
import '../../../data/repositories/library_search.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/library_providers.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/artist_avatar.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/playlist_cover.dart';
import 'album_detail_screen.dart';
import 'artist_screen.dart';
import '../online/artist_picker_sheet.dart';
import '../playlists/playlist_detail_screen.dart';
import '../../widgets/cc_app_bar.dart';

enum SearchSectionKind { artists, albums, playlists }

String searchSectionTitle(BuildContext context, SearchSectionKind kind) {
  final l = context.l10n;
  return switch (kind) {
    SearchSectionKind.artists => l.artists,
    SearchSectionKind.albums => l.albums,
    SearchSectionKind.playlists => l.navPlaylists,
  };
}

/// What [searchLibrary] found of one kind, and how many matched in all.
(int shown, int total) searchSectionCount(
  SearchSectionKind kind,
  LibrarySearchResults res,
) => switch (kind) {
  SearchSectionKind.artists => (res.artists.length, res.artistTotal),
  SearchSectionKind.albums => (res.albums.length, res.albumTotal),
  SearchSectionKind.playlists => (res.playlists.length, res.playlistTotal),
};

/// One result row: 40 leading, a line of title and one of subtitle.
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final Widget leading;
  final String title, subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: CcDims.margin),
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodyLarge,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodyMedium,
                  ),
                ],
              ),
            ),
            ?trailing,
            SizedBox(width: trailing == null ? CcDims.margin : 4),
          ],
        ),
      ),
    );
  }
}

/// The rows of [kind] in [res] (the preview and the full list share them).
List<Widget> searchSectionRows(
  BuildContext context,
  SearchSectionKind kind,
  LibrarySearchResults res,
) {
  final l = context.l10n;
  switch (kind) {
    case SearchSectionKind.artists:
      return [
        for (final a in res.artists)
          SearchResultRow(
            key: ValueKey('artist-${a.key}'),
            leading: ArtistAvatar(name: a.name, size: 40, coverKey: a.coverKey),
            title: a.name ?? l.unknownArtist,
            subtitle: [
              l.albumsCount(a.albumCount),
              l.tracksCount(a.trackCount),
            ].join(', '),
            onTap: () =>
                ShellNav.open<void>(context, ArtistDetailScreen(artist: a)),
            trailing: kEnableYoutube && a.name != null
                ? _YtmArtistButton(name: a.name!, id: a.key)
                : null,
          ),
      ];
    case SearchSectionKind.albums:
      return [
        for (final a in res.albums)
          SearchResultRow(
            key: ValueKey('album-${a.albumKey}'),
            leading: CoverImage(
              coverKey: a.coverKey,
              size: 40,
              radius: CcDims.rList,
            ),
            title: a.title ?? l.unknownAlbum,
            subtitle: a.artist ?? l.unknownArtist,
            onTap: () =>
                ShellNav.open<void>(context, AlbumDetailScreen(album: a)),
          ),
      ];
    case SearchSectionKind.playlists:
      return [
        for (final p in res.playlists)
          SearchResultRow(
            key: ValueKey('playlist-${p.playlist.id}'),
            leading: PlaylistCover(
              size: 40,
              coverKeys: playlistCoverKeys(p.playlist.coverKey, [
                p.autoCoverKey,
              ]),
            ),
            title: p.playlist.name,
            subtitle: l.playlistCountLabel(p.trackCount),
            onTap: () => ShellNav.open<void>(
              context,
              PlaylistDetailScreen(playlist: p.playlist),
            ),
          ),
      ];
  }
}

/// «Su YouTube Music» for a library artist.
class _YtmArtistButton extends ConsumerWidget {
  const _YtmArtistButton({required this.name, required this.id});

  final String name, id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    key: ValueKey('ytm-$id'),
    tooltip: context.l10n.ytmOnYoutubeMusic,
    icon: Icon(Icons.smart_display_rounded, color: context.cc.accentSoft),
    onPressed: () => openYtmArtist(
      context,
      ref,
      name,
      open: (page) => ShellNav.open<void>(context, page),
    ),
  );
}

/// «Tutti» of artists, albums or playlists: the whole list of one kind for
/// the same text as the preview.
class SearchSectionScreen extends ConsumerWidget {
  const SearchSectionScreen({
    super.key,
    required this.text,
    required this.kind,
  });

  final String text;
  final SearchSectionKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final res = searchLibrary(
      text: text,
      tracks: ref.watch(searchTracksProvider(text)).value ?? const <Track>[],
      artists: ref.watch(artistsProvider).value ?? const [],
      albums: ref.watch(albumsProvider).value ?? const [],
      playlists: ref.watch(playlistsProvider).value ?? const [],
      sectionLimit: 1 << 30,
    );
    final rows = searchSectionRows(context, kind, res);
    return Scaffold(
      appBar: CcAppBar(title: searchSectionTitle(context, kind)),
      body: rows.isEmpty
          ? EmptyState(
              icon: Icons.search_off_rounded,
              message: context.l10n.noResults,
            )
          : ListView.builder(
              itemCount: rows.length + 1,
              itemBuilder: (_, i) =>
                  i < rows.length ? rows[i] : SizedBox(height: 24 + context.dockInset),
            ),
    );
  }
}
