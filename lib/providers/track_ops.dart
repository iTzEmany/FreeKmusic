import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/import_row.dart' show LibraryEntryLite;
import '../data/db/app_database.dart';
import '../data/repositories/track_repository.dart';
import '../core/app_log.dart';
import '../services/online/lrc_parser.dart' show lyricsFromText;
import 'database_providers.dart';
import 'enrich_completer_providers.dart';
import 'online_providers.dart' show autoParts;
import 'player_providers.dart';
import 'settings_providers.dart';
import 'translation_providers.dart';

/// What the UI does to library tracks: writes that used to be spread over
/// widgets via the repositories. Streams stay in their own providers.
class TrackOps {
  TrackOps(this._ref);

  final Ref _ref;

  TrackRepository get _repo => _ref.read(trackRepositoryProvider);

  /// Favourite for all [tracks] (or off, when they all are already). Touches
  /// only the ones that change; [undo] puts those back.
  Future<({int count, bool added, Future<void> Function() undo})>
  toggleFavorites(List<Track> tracks) async {
    final added = tracks.isEmpty || !tracks.every((t) => t.isFavorite);
    final changed = [
      for (final t in tracks)
        if (t.isFavorite != added) t.id,
    ];
    await _repo.setFavoriteMany(changed, added);
    return (
      count: changed.length,
      added: added,
      undo: () => _repo.setFavoriteMany(changed, !added),
    );
  }

  /// Flips one track from its stored state; null when the row is gone.
  Future<({bool added, Future<void> Function() undo})?> toggleFavorite(
    int id,
  ) async {
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

  Future<void> setLyrics(
    int id, {
    String? plain,
    String? synced,
    bool byUser = false,
  }) => _repo.setLyrics(id, plain: plain, synced: synced, byUser: byUser);

  /// Saves lyrics typed or pasted by the user (F-110): timed lines make them
  /// synced. Returns null when there is nothing to save, else whether they are synced.
  Future<bool?> saveLyricsText(int id, String raw) async {
    final parsed = lyricsFromText(raw);
    if (parsed.plain == null && parsed.synced == null) return null;
    await _repo.setLyrics(
      id,
      plain: parsed.plain,
      synced: parsed.synced,
      byUser: true,
    );
    // A new text starts with the sync on, and an old translation no longer fits.
    await _ref.read(unsyncedLyricsProvider.notifier).setSynced(id, true);
    _ref.read(lyricsTranslationProvider.notifier).clearFor(id);
    return parsed.synced != null;
  }

  /// Turns the synced version of one track on or off (D-472); its translation no longer fits.
  Future<void> setLyricsSynced(int id, bool synced) async {
    _ref.read(lyricsTranslationProvider.notifier).clearFor(id);
    await _ref.read(unsyncedLyricsProvider.notifier).setSynced(id, synced);
  }

  /// Deletes the lyrics of one track (D-471) and, when the enrichment is on,
  /// lets it look for them again. [undo] puts everything back.
  Future<Future<void> Function()> deleteLyrics(int id) async {
    final unsynced = _ref.read(unsyncedLyricsProvider.notifier);
    final wasUnsynced = _ref.read(unsyncedLyricsProvider).contains(id);
    final snapshot = await _repo.clearLyrics(id);
    await unsynced.setSynced(id, true);
    _ref.read(lyricsTranslationProvider.notifier).clearFor(id);
    if (autoParts(_ref.read(settingsProvider)).isNotEmpty) {
      unawaited(_ref.read(enrichCompleterProvider.notifier).start());
    }
    return () async {
      try {
        await _repo.restoreLyrics(id, snapshot);
        if (wasUnsynced) await unsynced.setSynced(id, false);
      } on Object catch (e, st) {
        AppLog.e('undo delete lyrics failed', e, st);
      }
    };
  }

  Future<void> setIgnored(Set<int> ids, bool value) =>
      _repo.setIgnored(ids, value);

  Future<void> deleteTrack(int id) => _repo.deleteTrack(id);

  /// Drops library rows whose file is gone; returns how many went.
  Future<int> deleteMissing(List<int> ids) => _repo.deleteMissingTracks(ids);

  Future<void> resetCovers() => _repo.resetCovers();

  Future<void> setResumePosition(int id, int? ms) =>
      _repo.setResumePosition(id, ms);

  /// «Cronologia» wiped; returns how many plays went.
  Future<int> clearHistory() =>
      _ref.read(playHistoryRepositoryProvider).clear();

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

  /// «Shuffle+ della libreria» of the empty player: the whole library from a
  /// random song, with Shuffle+ where it is allowed; errors are logged.
  Future<void> playLibraryPlus() async {
    try {
      await _ref
          .read(playerControllerProvider)
          .playShufflePlus(
            await libraryIds(),
            context: const PlayContext(PlayContextKind.library),
          );
    } on Object catch (e, st) {
      AppLog.e('shuffle+ of the library failed', e, st);
    }
  }

  /// What ▶ does when nothing plays (D-364): the last queue again, else Shuffle+ of the library.
  Future<void> playWhenEmpty() async {
    try {
      // Decided on what the label says (lastQueueProvider), not on the raw queue.
      final last = await _ref.read(lastQueueProvider.future);
      if (last == null ||
          !await _ref.read(playerControllerProvider).resumeLastQueue()) {
        await playLibraryPlus();
      }
    } on Object catch (e, st) {
      AppLog.w('play when empty failed', e, st);
    }
  }

  Future<List<Track>> favorites({SortOption sort = SortOption.title}) =>
      _repo.watchTracks(favoritesOnly: true, sort: sort).first;
  Future<List<Track>> ofAlbums(Iterable<String> keys) =>
      _repo.tracksOfAlbums(keys);
  Future<Track?> byPath(String path) => _repo.byPath(path);
  Future<List<LibraryEntryLite>> liteEntries() => _repo.liteEntries();
}

final trackOpsProvider = Provider<TrackOps>(TrackOps.new);

/// Library tracks matching a search text (all of them for ''), live.
final trackSearchProvider = StreamProvider.autoDispose
    .family<List<Track>, String>(
      (ref, query) =>
          ref.watch(trackRepositoryProvider).watchTracks(query: query),
    );
