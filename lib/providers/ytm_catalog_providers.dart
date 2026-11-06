import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/paths.dart';
import '../services/online/artist_link_resolver.dart';
import '../services/online/catalog_cache.dart';
import '../services/online/youtube_service.dart';
import '../services/online/ytm_artist.dart';
import '../services/online/ytm_catalog.dart';
import 'library_providers.dart';
import 'artist_merge_providers.dart' show artistAliasRepositoryProvider;
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
