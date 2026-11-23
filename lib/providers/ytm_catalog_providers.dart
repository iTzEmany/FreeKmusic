import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/app_log.dart';
import '../core/artist_key.dart';
import '../core/paths.dart';
import '../services/import/track_matcher.dart' show libraryTitleKey;
import '../services/online/library_overlap.dart' show LibraryOverlap;
import '../services/online/artist_link_resolver.dart';
import '../services/online/catalog_cache.dart';
import '../services/online/youtube_service.dart';
import '../services/online/ytm_artist.dart';
import '../services/online/ytm_catalog.dart';
import 'library_providers.dart';
import 'database_providers.dart' show artistAliasRepositoryProvider;
import 'settings_providers.dart';
import 'youtube_providers.dart';

/// Disk cache of artist, album and list pages (`catalog_cache.json`).
final catalogCacheProvider = Provider<CatalogCache>((ref) {
  final cache = CatalogCache(
      file: () async => File(p.join(await appSupportDir(), 'catalog_cache.json')));
  ref.onDispose(() => unawaited(cache.flush()));
  return cache;
});

final ytmCatalogProvider = Provider<YtmCatalog>((ref) => YtmCatalog(
    ref.watch(innerTubeClientProvider),
    ref.watch(ytDlpServiceProvider),
    ref.watch(catalogCacheProvider)));

/// The `hl` YouTube Music is asked for: the app language when supported.
final ytmLanguageProvider =
    Provider<String>((ref) => ytmLanguage(ref.watch(settingsProvider).language));

/// Resolves a credited name to a library page, an online page or a choice.
final artistLinkResolverProvider = Provider<ArtistLinkResolver>((ref) =>
    ArtistLinkResolver(
      library: ref.read(libraryQueriesProvider).artistNamed,
      search: (name) => ref
          .read(ytmCatalogProvider)
          .searchArtists(name, ref.read(ytmLanguageProvider)),
      aliases: () => ref.read(artistAliasRepositoryProvider).allAliases(),
    ));

/// An artist page. A failure is shown with its own «Riprova»: no silent retries.
/// «Aggiorna» calls `YtmCatalog.artist(…, refresh: true)` and invalidates this.
final artistPageProvider = FutureProvider.autoDispose
    .family<CatalogResult<YtmArtistPage>, String>(
  (ref, id) => ref.read(ytmCatalogProvider).artist(id, ref.read(ytmLanguageProvider)),
  retry: (_, _) => null,
);

final onlineAlbumProvider = FutureProvider.autoDispose
    .family<CatalogResult<YtmAlbum>, String>(
  (ref, browseId) =>
      ref.read(ytmCatalogProvider).album(browseId, ref.read(ytmLanguageProvider)),
  retry: (_, _) => null,
);

/// The full song list behind a «show all» link: `(browseId, params)`.
final artistSongsProvider = FutureProvider.autoDispose
    .family<CatalogResult<List<YtResult>>, ({String browseId, String? params})>(
  (ref, link) => ref.read(ytmCatalogProvider).songs(
      YtmBrowseLink(link.browseId, link.params), ref.read(ytmLanguageProvider)),
  retry: (_, _) => null,
);

final discographyProvider = FutureProvider.autoDispose
    .family<CatalogResult<List<YtmRelease>>, ({String browseId, String? params})>(
  (ref, link) => ref.read(ytmCatalogProvider).discography(
      YtmBrowseLink(link.browseId, link.params), ref.read(ytmLanguageProvider)),
  retry: (_, _) => null,
);

/// The songs of the library album [albumKey] that are not in the library (F-22), with their place on the
/// record: taken from the online album (its `browseId` saved with a stream row, else the best album search
/// hit with the same title and artist). Empty when the album cannot be found or the catalog is unreachable.
/// Read once per opening: later writes to the library do not search again (the rows hide what is owned).
final albumMissingTracksProvider = FutureProvider.autoDispose.family<List<YtmAlbumTrack>, String>((ref, albumKey) async {
  final own = await ref.read(albumTracksOnceProvider)(albumKey);
  if (own.isEmpty) return const [];
  final catalog = ref.read(ytmCatalogProvider);
  final hl = ref.read(ytmLanguageProvider);
  try {
    var browseId = own.map((t) => t.albumBrowseId).nonNulls.firstOrNull;
    if (browseId == null) {
      final first = own.first;
      final title = first.album ?? '';
      final artist = (first.albumArtist ?? '').isNotEmpty ? first.albumArtist! : first.artist ?? '';
      // A wrong album would list foreign songs: without an artist on both sides nothing is taken.
      if (title.isEmpty || artist.isEmpty) return const [];
      final hits = await catalog.searchAlbums('$title $artist', hl);
      browseId = hits
          .where((h) =>
              libraryTitleKey(h.release.title) == libraryTitleKey(title) &&
              h.artist != null &&
              artistKey(h.artist!.name) == artistKey(artist))
          .firstOrNull
          ?.release
          .browseId;
    }
    if (browseId == null) return const [];
    final album = (await catalog.album(browseId, hl)).value;
    final owned = LibraryOverlap(own);
    // The same place on the record with about the same length is the song too (another title spelling).
    bool samePlace(YtmAlbumTrack t) =>
        t.number != null &&
        t.result.duration != null &&
        own.any((o) =>
            o.trackNumber == t.number &&
            o.durationMs > 0 &&
            (o.durationMs - t.result.duration!.inMilliseconds).abs() <= 3000);
    return [
      for (final t in album.tracks)
        if (!owned.owns(t.result) && !samePlace(t)) t,
    ];
  } on Object catch (e, st) {
    AppLog.w('album $albumKey: missing songs not available', e, st);
    return const [];
  }
}, retry: (_, _) => null);
