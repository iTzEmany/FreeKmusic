import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../data/db/app_database.dart' show Folder, Track;
import '../../data/repositories/track_repository.dart';
import '../covers/cover_store.dart';
import '../online/download_index.dart';
import '../online/youtube_service.dart';
import 'stream_cache.dart';

/// The cached file could not be moved; it is still in the cache.
class StreamPromoteException implements Exception {
  const StreamPromoteException(this.message, {this.noSpace = false});
  final String message;
  final bool noSpace;
  @override
  String toString() => message;
}

/// «Scarica» on a track whose file is in the stream cache: moves the file to
/// the download folder instead of downloading it again (R-10).
class StreamPromoter {
  StreamPromoter({
    required this.cache,
    required this.tracks,
    required this.covers,
    required this.downloadFolder,
    required this.index,
    required this.scan,
    required this.tag,
    this.onShadowMerged,
    this.publish,
    this.workDir,
    Future<void> Function(File, String)? rename,
    Future<void> Function(File, String)? copy,
  })  : _rename = rename ?? ((f, to) => f.rename(to)),
        _copy = copy ?? ((f, to) => f.copy(to));

  final StreamCache cache;
  final TrackRepository tracks;
  final CoverStore covers;
  final Future<(Directory, Folder)?> Function() downloadFolder;
  final Future<DownloadIndex> Function() index;
  final Future<void> Function(Folder folder, String path) scan;
  final Future<void> Function(int trackId) tag;
  /// The shadow row [shadowId] merged into the library row [keepId]: queues must follow.
  final void Function(int shadowId, int keepId)? onShadowMerged;
  /// Android: the file is moved to [workDir] first, then published; its final path is the row's path.
  final Future<String> Function(String path)? publish;
  final Future<Directory> Function()? workDir;
  final Future<void> Function(File, String) _rename; // seams for the cross-volume path
  final Future<void> Function(File, String) _copy;

  /// True when [r] was promoted from the cache; false = nothing to promote, download as usual.
  /// Throws [StreamPromoteException] when the move fails (the cache file stays).
  Future<bool> promote(YtResult r) async {
    final key = r.indexKey;
    final file = await cache.fileFor(key);
    if (file == null || await tracks.streamRow(key) == null) return false;
    final target = await downloadFolder();
    if (target == null) return false;
    final (dir, folder) = target;
    final ext = p.extension(file.path).replaceFirst('.', '');
    final pub = publish;
    final staging = pub == null ? dir.path : (await workDir!()).path;
    var dest = await _freePath(staging, downloadBaseName(r), ext);
    await _move(file, dest);
    if (pub != null) {
      try {
        dest = await pub(dest);
      } on Object catch (e, st) {
        AppLog.w('promote: publish failed for $key', e, st);
        try {
          await _move(File(dest), file.path); // the cache entry stays valid
        } on Object catch (e2, st2) {
          AppLog.w('promote: cached file not restored for $key', e2, st2);
        }
        throw StreamPromoteException('Impossibile pubblicare il brano: $e');
      }
    }
    cache.forget(key);
    // The file is in the downloads now: from here on nothing may lead to a second download.
    // Each step is logged on its own so one failure never skips the others.
    Track? row;
    String? oldCover;
    var handPicked = false;
    await _step(key, 'row', () async {
      final shadow = await tracks.streamRow(key);
      oldCover = shadow?.coverKey;
      handPicked = (shadow?.coverSource ?? 0) > 0;
      final existing = await tracks.byPath(dest);
      if (existing != null) {
        // A library row (e.g. missing) already owns this path: the shadow row merges into it.
        final gone = await tracks.mergeStreamRow(key, existing.id);
        if (gone != null) onShadowMerged?.call(gone, existing.id);
        row = existing;
      } else {
        row = await tracks.promoteStreamRow(key, dest, folder.id, File(dest));
        final r0 = row;
        // A hand-picked cover stays on its row (R-66).
        if (r0 != null && !handPicked) await _moveCover(oldCover, r0.albumKey);
      }
    });
    await _step(key, 'index', () async => (await index()).add(r.id, dest, source: r.source));
    await _step(key, 'scan', () => scan(folder, dest));
    final id = row?.id;
    if (id != null) await _step(key, 'tag', () => tag(id));
    return true;
  }

  Future<void> _step(String key, String name, Future<void> Function() body) async {
    try {
      await body();
    } on Object catch (e, st) {
      AppLog.w('promote: $name step failed for $key', e, st);
    }
  }

  Future<String> _freePath(String dir, String base, String ext) async {
    var candidate = p.join(dir, '$base.$ext');
    for (var n = 2; await File(candidate).exists(); n++) {
      candidate = p.join(dir, '$base ($n).$ext');
    }
    return candidate;
  }

  /// Gives the cover the shadow row had to its new album (what a scan would do).
  Future<void> _moveCover(String? oldKey, String albumKey) async {
    final f = oldKey == null ? null : covers.fileFor(oldKey);
    if (f == null) return;
    final png = f.path.toLowerCase().endsWith('.png');
    final key = await covers.saveFromBytes(albumKey, await f.readAsBytes(), png ? 'image/png' : 'image/jpeg');
    if (key != null) await tracks.setCoverForAlbum(albumKey, true, key);
  }

  /// `rename`, else (other volume, K-05) copy + size check + delete.
  Future<void> _move(File from, String to) async {
    try {
      await _rename(from, to);
      return;
    } on FileSystemException catch (e) {
      AppLog.i('promote: rename failed, copying (${e.osError?.errorCode})');
    }
    final dest = File(to);
    try {
      await _copy(from, to);
      if (await dest.length() != await from.length()) {
        throw const StreamPromoteException('Copia incompleta del file');
      }
    } on Object catch (e, st) {
      AppLog.w('promote: copy failed', e, st);
      try {
        if (await dest.exists()) await dest.delete();
      } on FileSystemException catch (err, st2) {
        AppLog.w('promote: partial copy not removed', err, st2);
      }
      if (e is StreamPromoteException) rethrow;
      final code = e is FileSystemException ? e.osError?.errorCode : null;
      final full = code == 28 || code == 112 || '$e'.contains('No space left');
      throw StreamPromoteException(
          full ? 'Spazio insufficiente per scaricare il brano' : 'Impossibile spostare il brano: $e',
          noSpace: full);
    }
    try {
      await from.delete();
    } on FileSystemException catch (e, st) {
      AppLog.w('promote: cache file not removed after the copy', e, st); // evicted later
    }
  }
}
