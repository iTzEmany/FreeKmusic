import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/repositories/hidden_playlists.dart';
import '../data/repositories/playlist_repository.dart';
import '../data/repositories/smart_playlist_repository.dart' show SmartSort;
import 'database_providers.dart';

/// Playlist actions (plain and smart) and the import history of a playlist.
class PlaylistOps {
  PlaylistOps(this._ref);

  final Ref _ref;

  PlaylistRepository get _repo => _ref.read(playlistRepositoryProvider);

  Future<int> create(String name) => _repo.create(name);

  /// A new playlist holding [trackIds] (a smart playlist turned into a normal one).
  Future<int> createWith(String name, List<int> trackIds) async {
    final id = await _repo.create(name);
    await _repo.addTracks(id, trackIds);
    return id;
  }

  /// Returns how many were really added (the ones already there are skipped).
  Future<int> addTracks(int playlistId, List<int> trackIds) => _repo.addTracks(playlistId, trackIds);

  /// Sets the cover and refreshes the list.
  Future<void> setCover(int id, String? key) async {
    await _repo.setCover(id, key);
    _ref.invalidate(playlistsProvider);
  }

  /// Takes the tracks out; [undo] puts them back where they were.
  Future<Future<void> Function()> removeTracks(int playlistId, List<int> trackIds) async {
    final before = await _repo.removeTracks(playlistId, trackIds);
    return () => _repo.restoreTracks(playlistId, before, trackIds);
  }

  /// Takes one track out of the row at [index] of [length]; [undo] re-adds it there.
  Future<Future<void> Function()> removeTrack(int playlistId, int trackId, {required int index, required int length}) async {
    await _repo.removeTrack(playlistId, trackId);
    return () async {
      // addStreamTracks: the row may be a shadow row (addTracks refuses kind 2).
      if (await _repo.addStreamTracks(playlistId, [trackId]) == 1) await _repo.reorder(playlistId, length - 1, index);
    };
  }

  Future<void> reorder(int playlistId, int oldIndex, int newIndex) => _repo.reorder(playlistId, oldIndex, newIndex);
  Future<void> rename(int id, String name) => _repo.rename(id, name);
  Future<void> delete(int id) => _repo.delete(id);

  /// The playlists the user sees (hidden system ones left out).
  Future<List<Playlist>> visible() => _ref.read(databaseProvider).visiblePlaylists();

  Future<List<Track>> tracksOf(int playlistId) => _repo.watchTracks(playlistId).first;

  /// Creates a smart playlist, or edits [existingId]. A null [limit] clears it.
  Future<void> saveSmart({
    int? existingId,
    required String name,
    required String rules,
    required SmartSort sort,
    int? limit,
  }) async {
    final repo = _ref.read(smartPlaylistRepositoryProvider);
    if (existingId == null) {
      await repo.create(name: name, rules: rules, sort: sort, limit: limit);
    } else {
      await repo.update(existingId, name: name, rules: rules, sort: sort, limit: limit, clearLimit: limit == null);
    }
  }

  Future<void> deleteSmart(int id) => _ref.read(smartPlaylistRepositoryProvider).delete(id);

  // Import history, as the export and the Exportify sync read it.
  Future<Map<int, String>> isrcByTrack(int playlistId) => _ref.read(importRepositoryProvider).isrcByTrack(playlistId);
  Future<List<PlaylistImport>> importsOf(int playlistId) => _ref.read(importRepositoryProvider).forPlaylist(playlistId);
  Future<List<PlaylistImportItem>> importItems(int importId) => _ref.read(importRepositoryProvider).items(importId);
}

final playlistOpsProvider = Provider<PlaylistOps>(PlaylistOps.new);

/// Ids of the playlists that already hold every track of the key (ids joined by «,»).
final playlistsContainingProvider = FutureProvider.autoDispose.family<Set<int>, String>(
  (ref, ids) => ref.watch(playlistRepositoryProvider).containing([
    for (final s in ids.split(',')) int.parse(s),
  ]),
);
