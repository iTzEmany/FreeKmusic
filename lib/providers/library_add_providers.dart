import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../data/settings/settings_store.dart' show StorageMode;
import '../services/online/youtube_service.dart';
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

  bool get _streaming => _ref.read(settingsProvider).storageMode == StorageMode.stream;

  /// Streaming mode and not downloaded yet: saves the shadow row and returns its id.
  /// Null means the caller must download (device mode, or an already downloaded song, so no
  /// second row appears next to its file) or, in streaming mode, that saving failed (logged).
  Future<int?> saveNow(YtResult r) async {
    if (!_streaming) return null;
    final idx = await _ref.read(downloadIndexProvider.future);
    if (idx.contains(r.id, source: r.source)) return null;
    try {
      return await _ref.read(trackRepositoryProvider).saveStream(r);
    } on Object catch (e, st) {
      AppLog.w('library add: could not save ${r.indexKey}', e, st);
      return null;
    }
  }

  /// True when the song joined the library at once, false when a download started (as
  /// `DownloadsNotifier.add`), null when it could not be added. An `addto:` [tag] puts the
  /// row in that playlist right away in streaming mode.
  Future<bool?> add(YtResult r, {String? tag}) async {
    if (!_streaming) return _ref.read(downloadsProvider.notifier).add(r, tag: tag);
    final idx = await _ref.read(downloadIndexProvider.future);
    // A file is already there: the download path joins the playlist without a second copy.
    if (idx.contains(r.id, source: r.source)) return _ref.read(downloadsProvider.notifier).add(r, tag: tag);
    final playlist = parseAddToPlaylistTag(tag);
    final saved = _ref.read(savedStreamKeysProvider).value;
    if (playlist == null && (saved?.contains(r.indexKey) ?? false)) return true;
    final id = await saveNow(r);
    if (id == null) return null;
    if (playlist != null) {
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
