import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../data/settings/settings_store.dart' show StorageMode;
import '../data/db/app_database.dart' show Track;
import '../services/online/youtube_service.dart';
import '../services/stream/stream_key.dart' show streamPathOf;
import 'database_providers.dart';
import 'pending_playlist_adds.dart';
import 'settings_providers.dart';
import 'youtube_providers.dart';

/// Cache keys (`<source>:<id>`) of the streamed tracks saved to the library.
final savedStreamKeysProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(trackRepositoryProvider).watchSavedStreamKeys(),
);

/// «Already in the library» of an online song: a downloaded file or a saved stream.
final inLibraryOfProvider = Provider<bool Function(String id, MediaSource source)>((ref) {
  final index = ref.watch(downloadIndexProvider).value;
  final saved = ref.watch(savedStreamKeysProvider).value ?? const <String>{};
  return (id, source) => (index?.contains(id, source: source) ?? false) || saved.contains(downloadIndexKey(source, id));
});

/// The one place that decides between «Aggiungi alla libreria» without a file (streaming mode)
/// and the download of today (device mode). «Scarica sul dispositivo» calls `downloadsProvider` itself.
class LibraryAdder {
  LibraryAdder(this._ref);
  final Ref _ref;

  bool get streaming => _ref.read(settingsProvider).storageMode == StorageMode.stream;

  /// What «Aggiungi»/«Scarica» of [id] must not repeat: in streaming a downloaded file or a saved stream, in
  /// device mode only a downloaded file (a saved stream still has to be downloaded, D-695).
  bool alreadyThere(String id, MediaSource source) {
    if (streaming) return _ref.read(inLibraryOfProvider)(id, source);
    return _ref.read(downloadIndexProvider).value?.contains(id, source: source) ?? false;
  }

  /// Streaming mode and not downloaded yet: saves the shadow row and returns its id.
  /// Null means the caller must download (device mode, or an already downloaded song, so no
  /// second row appears next to its file) or, in streaming mode, that saving failed (logged).
  Future<int?> saveNow(YtResult r) async {
    return streaming ? saveStreamNow(r) : null;
  }

  /// Saves the shadow row whatever the storage mode (an import always saves, D-665). Null when a file is
  /// already there or saving failed (logged).
  Future<int?> saveStreamNow(YtResult r) async {
    final idx = await _ref.read(downloadIndexProvider.future);
    return await idx.containsOnDisk(r.id, source: r.source) ? null : _save(r);
  }

  Future<int?> _save(YtResult r) async {
    try {
      return await _ref.read(trackRepositoryProvider).saveStream(r);
    } on Object catch (e, st) {
      AppLog.w('library add: could not save ${r.indexKey}', e, st);
      return null;
    }
  }

  /// «Scarica»: downloading is saving (D-695), so the row is saved first, in either mode; a failed save is
  /// logged and the download goes on. Same result as `DownloadsNotifier.add`.
  Future<bool?> download(YtResult r, {String? tag}) async {
    final idx = await _ref.read(downloadIndexProvider.future);
    if (!await idx.containsOnDisk(r.id, source: r.source)) await _save(r);
    return _ref.read(downloadsProvider.notifier).add(r, tag: tag);
  }

  /// True when the song joined the library at once, false when a download started (as
  /// `DownloadsNotifier.add`), null when it could not be added. An `addto:` [tag] puts the
  /// row in that playlist right away in streaming mode.
  Future<bool?> add(YtResult r, {String? tag}) async {
    if (!streaming) return download(r, tag: tag); // device mode: save, then download (D-695), keeping the tag
    final idx = await _ref.read(downloadIndexProvider.future);
    // A file is already there: the download path joins the playlist without a second copy.
    if (await idx.containsOnDisk(r.id, source: r.source)) return _ref.read(downloadsProvider.notifier).add(r, tag: tag);
    final playlists = parseAddToPlaylistTag(tag);
    final saved = _ref.read(savedStreamKeysProvider).value;
    if (playlists.isEmpty && (saved?.contains(r.indexKey) ?? false)) return true;
    final id = await saveNow(r);
    if (id == null) return null;
    for (final playlist in playlists) {
      try {
        await _ref.read(playlistRepositoryProvider).addStreamTracks(playlist, [id]);
      } on Object catch (e, st) {
        AppLog.w('library add: could not put $id in playlist $playlist', e, st);
        return null;
      }
    }
    return true;
  }
}

final libraryAdderProvider = Provider<LibraryAdder>(LibraryAdder.new);

/// The current library row of the song behind a `trackStateKey` [key] (the row of [track] for a `#<id>` key, else the
/// row at the download's path or the shadow row), or null: what the open track menu is rebuilt from.
final trackRowLookupProvider = Provider<Future<Track?> Function(Track track, String key)>((ref) {
  return (track, key) async {
    final repo = ref.read(trackRepositoryProvider);
    if (key.startsWith('#')) return repo.getById(track.id);
    final path = (await ref.read(downloadIndexProvider.future)).pathForKey(key);
    return repo.byPath(path ?? streamPathOf(key));
  };
});
