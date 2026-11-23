import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/favorite_collections_repository.dart';
import '../data/repositories/library_queries.dart';
import '../data/repositories/playlist_repository.dart';
import 'database_providers.dart';
import 'library_providers.dart';

const _stream = 'stream|';

/// Kinds of favourite collection, for the UI (which does not import the repository).
const favoriteAlbumKind = FavoriteCollectionsRepository.album;
const favoritePlaylistKind = FavoriteCollectionsRepository.playlist;

/// Favourite albums, newest first. A key `artist|album` (with or without `stream|`) finds the album
/// stored as `artist|album` (the file one wins) or as `stream|artist|album`; a gone key is skipped.
/// Each album shows once.
List<AlbumSummary> resolveFavoriteAlbums(List<String> keys, List<AlbumSummary> albums) {
  final byKey = {for (final a in albums) a.albumKey: a};
  final seen = <String>{};
  return [
    for (final k in keys)
      if (k.startsWith(_stream) ? k.substring(_stream.length) : k case final canon)
        if (seen.add(canon))
          ?(byKey[canon] ?? byKey['$_stream$canon']),
  ];
}

final favoriteAlbumsProvider = Provider<AsyncValue<List<AlbumSummary>>>((ref) {
  final keys = ref.watch(_keysProvider(favoriteAlbumKind));
  if (keys.hasError) return AsyncError(keys.error!, keys.stackTrace!);
  if (keys.hasValue && keys.value!.isEmpty) return const AsyncData([]);
  final albums = ref.watch(albumsProvider);
  if (albums.hasError) return AsyncError(albums.error!, albums.stackTrace!);
  if (!keys.hasValue || !albums.hasValue) return const AsyncLoading();
  return AsyncData(resolveFavoriteAlbums(keys.value!, albums.value!));
});

final favoritePlaylistsProvider = Provider<AsyncValue<List<PlaylistSummary>>>((ref) {
  final keys = ref.watch(_keysProvider(favoritePlaylistKind));
  if (keys.hasError) return AsyncError(keys.error!, keys.stackTrace!);
  if (keys.hasValue && keys.value!.isEmpty) return const AsyncData([]);
  final lists = ref.watch(playlistsProvider);
  if (lists.hasError) return AsyncError(lists.error!, lists.stackTrace!);
  if (!keys.hasValue || !lists.hasValue) return const AsyncLoading();
  final byUuid = {for (final p in lists.value!) p.playlist.uuid: p};
  return AsyncData([for (final k in keys.value!) ?byUuid[k]]);
});

final _keysProvider = StreamProvider.autoDispose.family<List<String>, String>(
  (ref, kind) => ref.watch(favoriteCollectionsRepositoryProvider).watch(kind),
);

/// Is the album ([kind] 'album', key `albumKey`) or playlist (key uuid) a favourite.
final isFavoriteCollectionProvider = StreamProvider.autoDispose.family<bool, ({String kind, String key})>(
  (ref, a) => ref.watch(favoriteCollectionsRepositoryProvider).isFavorite(a.kind, a.key),
);

/// Toggles a favourite album or playlist.
final toggleFavoriteCollectionProvider = Provider<Future<void> Function(String kind, String key)>(
  (ref) => ref.read(favoriteCollectionsRepositoryProvider).toggle,
);
