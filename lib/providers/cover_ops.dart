import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/app_log.dart';
import '../data/db/app_database.dart';
import '../data/repositories/track_repository.dart';
import '../services/covers/cover_store.dart';
import '../services/scanner/library_scanner.dart';
import '../data/repositories/artist_info_repository.dart';
import 'database_providers.dart';
import 'library_providers.dart';
import 'playlist_ops.dart';

/// Library artist key -> cover key of the image picked by hand (D-566).
final artistImagesProvider = StreamProvider<Map<String, String>>(
  (ref) => ref.watch(artistInfoRepositoryProvider).watchImages(),
);

final coverOpsProvider = Provider<CoverOps>((ref) => CoverOps(ref));

/// Hand-picked covers: save a new one (the previous hand-picked file goes, the
/// original `sha1(albumKey)` never) and go back to the original.
class CoverOps {
  CoverOps(this._ref);

  final Ref _ref;

  TrackRepository get _tracks => _ref.read(trackRepositoryProvider);
  CoverStore get _store => _ref.read(coverStoreProvider);
  LibraryScanner get _scanner => _ref.read(libraryScannerProvider);

  Future<List<Playlist>> _playlists() => _ref.read(databaseProvider).select(_ref.read(databaseProvider).playlists).get();

  /// A new key per pick, so the image cache never shows the old picture.
  Future<String?> _save(String kind, Object id, List<int> bytes, String? mime) =>
      _store.saveFromBytes('manual:$kind:$id:${DateTime.now().microsecondsSinceEpoch}', bytes, mime);

  /// Deletes hand-picked files and their thumbnails once no row uses them; never the
  /// original of one of [albumKeys].
  Future<void> _drop(Iterable<String?> keys, Iterable<String> albumKeys) async {
    final originals = albumKeys.map(CoverStore.coverKeyFor).toSet();
    for (final key in keys.whereType<String>().toSet()) {
      if (originals.contains(key) || await _tracks.countWithCoverKey(key) > 0) continue;
      try {
        await _store.fileFor(key)?.delete();
        final thumb = File(p.join(_store.dir.path, CoverStore.thumbName(key)));
        if (await thumb.exists()) await thumb.delete();
      } on Object catch (e, st) {
        AppLog.w('old cover not deleted: $key', e, st);
      }
    }
  }

  /// Returns false when nothing was saved (empty or too large).
  Future<bool> setTrackCover(int trackId, List<int> bytes, String? mime) async {
    final before = await _tracks.getById(trackId);
    if (before == null) return false;
    final key = await _save('track', trackId, bytes, mime);
    if (key == null) return false;
    final old = before.coverSource > 0 ? before.coverKey : null;
    await _tracks.setManualCover(trackId, key);
    await _drop([old], [before.albumKey]);
    return true;
  }

  Future<bool> setAlbumCover(String albumKey, List<int> bytes, String? mime) async {
    final key = await _save('album', albumKey, bytes, mime);
    if (key == null) return false;
    final old = await _tracks.albumManualKeys(albumKey);
    await _tracks.setManualAlbumCover(albumKey, key);
    await _drop(old, [albumKey]);
    return true;
  }

  Future<bool> setPlaylistCover(int playlistId, List<int> bytes, String? mime) async {
    final key = await _save('playlist', playlistId, bytes, mime);
    if (key == null) return false;
    final old = (await _playlists()).where((p) => p.id == playlistId).firstOrNull?.coverKey;
    await _ref.read(playlistOpsProvider).setCover(playlistId, key);
    // Playlist covers are never shared with tracks: delete the old file as before.
    if (old != null) await _store.fileFor(old)?.delete();
    return true;
  }

  ArtistInfoRepository get _artists => _ref.read(artistInfoRepositoryProvider);

  Future<bool> setArtistCover(String artistKey, List<int> bytes, String? mime) async {
    final key = await _save('artist', artistKey, bytes, mime);
    if (key == null) return false;
    final old = (await _artists.images())[artistKey];
    await _artists.setImage(artistKey, key);
    await _drop([old], const []);
    return true;
  }

  Future<void> restoreArtistCover(String artistKey) async {
    final old = (await _artists.images())[artistKey];
    await _artists.clearImage(artistKey);
    await _drop([old], const []);
  }

  Future<void> restoreTrackCover(int trackId) async {
    final t = await _tracks.getById(trackId);
    if (t == null || t.coverSource == 0) return;
    final key = await _scanner.originalCoverKey(t.albumKey, t.path);
    await _tracks.restoreCover(trackId: trackId, coverKey: key);
    await _drop([t.coverKey], [t.albumKey]);
  }

  Future<void> restoreAlbumCover(String albumKey) async {
    final row = await _tracks.albumManualRow(albumKey);
    if (row == null) return;
    final key = await _scanner.originalCoverKey(albumKey, row.path);
    final old = await _tracks.albumManualKeys(albumKey);
    await _tracks.restoreCover(albumKey: albumKey, coverKey: key);
    await _drop(old, [albumKey]);
  }

  /// «Svuota cache copertine»: deletes every cover file except the hand-picked ones
  /// (tracks, albums) and the custom ones of playlists, then lets the next scan redo
  /// the automatic ones.
  Future<void> clearCache() async {
    final keep = {
      ...await _tracks.handPickedCoverKeys(),
      ...(await _artists.images()).values,
      for (final p in await _playlists())
        if (p.coverKey != null) p.coverKey!,
    };
    if (await _store.dir.exists()) {
      await for (final e in _store.dir.list()) {
        if (e is! File) continue;
        final stem = p.basenameWithoutExtension(e.path);
        final key = stem.endsWith('_t') ? stem.substring(0, stem.length - 2) : stem;
        if (!keep.contains(key)) await e.delete();
      }
    }
    await _tracks.resetCovers();
  }
}
