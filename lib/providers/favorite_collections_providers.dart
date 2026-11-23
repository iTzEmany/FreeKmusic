import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/favorite_collections_repository.dart';
import '../data/repositories/library_queries.dart';
import '../data/repositories/playlist_repository.dart';
import 'database_providers.dart';
import 'library_providers.dart';

const _stream = 'stream|';

/// Favourite albums, newest first. A canonical key `artist|album` finds the album stored as
/// `artist|album` or as `stream|artist|album` (the file one wins); a key with no album is skipped.
List<AlbumSummary> resolveFavoriteAlbums(List<String> keys, List<AlbumSummary> albums) {
  final byKey = {for (final a in albums) a.albumKey: a};
  return [
    for (final k in keys)
      ?(byKey[k] ?? byKey[k.startsWith(_stream) ? k.substring(_stream.length) : '$_stream$k']),
  ];
}

final favoriteAlbumsProvider = Provider<AsyncValue<List<AlbumSummary>>>((ref) {
  final keys = ref.watch(_keysProvider(FavoriteCollectionsRepository.album));
  final albums = ref.watch(albumsProvider);
  if (keys.hasError) return AsyncError(keys.error!, keys.stackTrace!);
  if (albums.hasError) return AsyncError(albums.error!, albums.stackTrace!);
  if (!keys.hasValue || !albums.hasValue) return const AsyncLoading();
  // Both spellings of one album: show it once.
  final seen = <String>{};
  return AsyncData([
    for (final a in resolveFavoriteAlbums(keys.value!, albums.value!))
      if (seen.add(a.albumKey.startsWith(_stream) ? a.albumKey.substring(_stream.length) : a.albumKey)) a,
  ]);
});

final favoritePlaylistsProvider = Provider<AsyncValue<List<PlaylistSummary>>>((ref) {
  final keys = ref.watch(_keysProvider(FavoriteCollectionsRepository.playlist));
  final lists = ref.watch(playlistsProvider);
  if (keys.hasError) return AsyncError(keys.error!, keys.stackTrace!);
  if (lists.hasError) return AsyncError(lists.error!, lists.stackTrace!);
  if (!keys.hasValue || !lists.hasValue) return const AsyncLoading();
  final byUuid = {for (final p in lists.value!) p.playlist.uuid: p};
  return AsyncData([for (final k in keys.value!) ?byUuid[k]]);
});

final _keysProvider = StreamProvider.family<List<String>, String>(
  (ref, kind) => ref.watch(favoriteCollectionsRepositoryProvider).watch(kind),
);

/// Is the album ([kind] 'album', key `albumKey`) or playlist (key uuid) a favourite.
final isFavoriteCollectionProvider = StreamProvider.family<bool, ({String kind, String key})>(
  (ref, a) => ref.watch(favoriteCollectionsRepositoryProvider).isFavorite(a.kind, a.key),
);

/// Toggles a favourite album or playlist.
final toggleFavoriteCollectionProvider = Provider<Future<void> Function(String kind, String key)>(
  (ref) => ref.read(favoriteCollectionsRepositoryProvider).toggle,
);
