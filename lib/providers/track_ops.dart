import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/import_row.dart' show LibraryEntryLite;
import '../data/db/app_database.dart';
import '../data/repositories/track_repository.dart';
import '../core/app_log.dart';
import 'database_providers.dart';
import 'player_providers.dart';

/// What the UI does to library tracks: writes that used to be spread over
/// widgets via the repositories. Streams stay in their own providers.
class TrackOps {
  TrackOps(this._ref);

  final Ref _ref;

  TrackRepository get _repo => _ref.read(trackRepositoryProvider);

  /// Favourite for all [tracks] (or off, when they all are already). Touches
  /// only the ones that change; [undo] puts those back.
  Future<({int count, bool added, Future<void> Function() undo})> toggleFavorites(
    List<Track> tracks,
  ) async {
    final added = tracks.isEmpty || !tracks.every((t) => t.isFavorite);
    final changed = [
      for (final t in tracks)
        if (t.isFavorite != added) t.id,
    ];
    await _repo.setFavoriteMany(changed, added);
    return (count: changed.length, added: added, undo: () => _repo.setFavoriteMany(changed, !added));
  }

  /// Flips one track from its stored state; null when the row is gone.
  Future<({bool added, Future<void> Function() undo})?> toggleFavorite(int id) async {
    final fresh = await _repo.getById(id);
    if (fresh == null) return null;
    final previous = fresh.isFavorite;
    await _repo.setFavorite(id, !previous);
    return (added: !previous, undo: () => _repo.setFavorite(id, previous));
  }

  /// Favourites for the ids that are not yet; returns how many changed.
  Future<int> addFavorites(List<int> ids) async {
    final changed = [
      for (final t in await _repo.getByIds(ids))
        if (!t.isFavorite) t.id,
    ];
    await _repo.setFavoriteMany(changed, true);
    return changed.length;
  }

  Future<void> setLyrics(int id, {String? plain, String? synced, bool byUser = false}) =>
      _repo.setLyrics(id, plain: plain, synced: synced, byUser: byUser);

  Future<void> setIgnored(Set<int> ids, bool value) => _repo.setIgnored(ids, value);

  Future<void> deleteTrack(int id) => _repo.deleteTrack(id);

  /// Drops library rows whose file is gone; returns how many went.
  Future<int> deleteMissing(List<int> ids) => _repo.deleteMissingTracks(ids);

  Future<void> resetCovers() => _repo.resetCovers();

  Future<void> setResumePosition(int id, int? ms) => _repo.setResumePosition(id, ms);

  /// «Cronologia» wiped; returns how many plays went.
  Future<int> clearHistory() => _ref.read(playHistoryRepositoryProvider).clear();

  // One-shot reads the screens used to do through the repository.
  Future<List<Track>> byIds(List<int> ids) => _repo.getByIds(ids);
  Future<List<Track>> all() => _repo.watchTracks().first;
  /// Ids of the whole library (what «Riproduci tutta la libreria» plays), D-137.
  Future<List<int>> libraryIds() async => [for (final t in await all()) t.id];

  /// Plays the whole library, not what a search shows; errors are logged.
  Future<void> playLibrary() async {
    try {
      final tracks = await all();
      if (tracks.isEmpty) return;
      await _ref
          .read(playerControllerProvider)
          .playAll(tracks, context: const PlayContext(PlayContextKind.library));
    } on Object catch (e, st) {
      AppLog.e('play everything failed', e, st);
    }
  }

  Future<List<Track>> favorites({SortOption sort = SortOption.title}) => _repo.watchTracks(favoritesOnly: true, sort: sort).first;
  Future<List<Track>> ofAlbums(Iterable<String> keys) => _repo.tracksOfAlbums(keys);
  Future<Track?> byPath(String path) => _repo.byPath(path);
  Future<List<LibraryEntryLite>> liteEntries() => _repo.liteEntries();
}

final trackOpsProvider = Provider<TrackOps>(TrackOps.new);

/// Library tracks matching a search text (all of them for ''), live.
final trackSearchProvider = StreamProvider.autoDispose.family<List<Track>, String>(
  (ref, query) => ref.watch(trackRepositoryProvider).watchTracks(query: query),
);
