import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings/settings_store.dart' show StorageMode;
import '../services/online/youtube_service.dart';
import 'database_providers.dart';
import 'pending_playlist_adds.dart';
import 'settings_providers.dart';
import 'youtube_providers.dart';

/// The one place that decides between «Aggiungi alla libreria» without a file (streaming mode)
/// and the download of today (device mode). «Scarica sul dispositivo» calls `downloadsProvider` itself.
class LibraryAdder {
  LibraryAdder(this._ref);
  final Ref _ref;

  /// Streaming mode and not downloaded yet: saves the shadow row and returns its id.
  /// Null means the caller must download (device mode, or not a savable row); an already
  /// downloaded song is also null, so no second row appears next to its file.
  Future<int?> saveNow(YtResult r) async {
    if (_ref.read(settingsProvider).storageMode != StorageMode.stream) return null;
    final idx = await _ref.read(downloadIndexProvider.future);
    if (idx.contains(r.id, source: r.source)) return null;
    return _ref.read(trackRepositoryProvider).saveStream(r);
  }

  /// True when the song joined the library at once (no download started), as `DownloadsNotifier.add`.
  /// An `addto:` [tag] puts the row in that playlist right away in streaming mode.
  Future<bool> add(YtResult r, {String? tag}) async {
    final id = await saveNow(r);
    if (id == null) return _ref.read(downloadsProvider.notifier).add(r, tag: tag);
    final playlist = parseAddToPlaylistTag(tag);
    if (playlist != null) await _ref.read(playlistRepositoryProvider).addStreamTracks(playlist, [id]);
    return true;
  }
}

final libraryAdderProvider = Provider<LibraryAdder>(LibraryAdder.new);
