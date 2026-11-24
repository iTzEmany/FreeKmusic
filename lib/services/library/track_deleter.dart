import 'dart:io';

import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/hidden_playlists.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../data/repositories/track_repository.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../import/import_options.dart' show forgetImportDownloadToo;
import 'duplicate_cleanup.dart';

/// Deletes files through the platform (Android's system dialog); returns the
/// paths that are gone. Null where the platform has no such thing.
typedef PlatformDeleter = Future<List<String>> Function(List<String> paths);

/// What a «delete from the device» pass did.
class TrackDeleteReport {
  const TrackDeleteReport({
    required this.deleted,
    required this.failed,
    this.refused = const {},
  });

  /// File gone (or already gone) and library row removed.
  final List<Track> deleted;

  /// File still there, row untouched, with the system's reason.
  final Map<Track, String> failed;

  /// The subset of [failed] that went through the platform deleter and is
  /// still on disk (dialog refused, or unknown to MediaStore): the OS reason
  /// would only mislead there.
  final Set<Track> refused;
}

Future<void> _deleteFile(String path) => File(path).delete();

String failureReason(Object e) =>
    e is FileSystemException ? (e.osError?.message ?? e.message) : '$e';

/// Really deletes songs: the audio file from the device and then the library
/// row (so playlists, favourites, history and tags go with it). A track whose
/// file cannot be deleted stays in the library untouched.
class TrackDeleter {
  TrackDeleter({
    required this.tracks,
    required this.removeFromQueue,
    FileDeleter? deleter,
    this.platform,
    this.db,
    this.onDeleted,
  }) : _deleter = deleter ?? _deleteFile;

  final TrackRepository tracks;

  /// Takes the tracks out of the queue and lets the player release them.
  final Future<void> Function(Set<int> ids) removeFromQueue;
  final FileDeleter _deleter;

  /// When given, the leftovers of deleted downloads are tidied: empty
  /// technical album playlists and empty folders inside the library roots.
  final AppDatabase? db;

  /// Only on Android: for the files plain deletion is not allowed to touch.
  final PlatformDeleter? platform;

  /// Called, and awaited, with the rows that were removed (the download state of those tracks changed).
  final Future<void> Function(List<Track> gone)? onDeleted;

  /// Podcast episodes (`kind != 0`) are skipped: they have their own cleanup.
  Future<TrackDeleteReport> deleteTracks(List<Track> input) async {
    final byId = {
      for (final t in input)
        if (t.kind == 0) t.id: t,
    };
    final list = byId.values.toList();
    if (list.isEmpty) return const TrackDeleteReport(deleted: [], failed: {});
    await removeFromQueue(byId.keys.toSet());

    final gone = <Track>[];
    final failed = <Track, String>{};
    final denied = <Track, String>{};
    final refused = <Track>{};
    for (final t in list) {
      if (!await File(t.path).exists()) {
        gone.add(t);
        continue;
      }
      try {
        await _deleter(t.path);
        gone.add(t);
      } on Object catch (e, st) {
        AppLog.w('delete track failed: ${t.path}', e, st);
        // Android's FUSE may answer ENOENT, EPERM or EACCES for a file it will
        // not let us delete: whatever the errno, a file still there is offered
        // to the platform.
        (platform != null && await File(t.path).exists() ? denied : failed)[t] =
            failureReason(e);
      }
    }
    if (denied.isNotEmpty) {
      try {
        await platform!([for (final t in denied.keys) t.path]);
      } on Object catch (e, st) {
        AppLog.w('platform delete failed', e, st);
      }
      for (final e in denied.entries) {
        if (await File(e.key.path).exists()) {
          failed[e.key] = e.value;
          refused.add(e.key);
        } else {
          gone.add(e.key);
        }
      }
    }
    await tracks.deleteTracks([for (final t in gone) t.id]);
    await _tidy(gone);
    if (gone.isNotEmpty) {
      try {
        await onDeleted?.call(gone);
      } on Object catch (e, st) {
        AppLog.w('onDeleted failed', e, st);
      }
    }
    return TrackDeleteReport(deleted: gone, failed: failed, refused: refused);
  }

  /// Best effort: a failure here never turns a successful delete into an error.
  Future<void> _tidy(List<Track> gone) async {
    final db = this.db;
    if (db == null || gone.isEmpty) return;
    try {
      await _dropEmptyAlbumPlaylists(db);
      final roots = [for (final f in await db.select(db.folders).get()) p.normalize(f.path)];
      await _removeEmptyDirs(gone, roots);
    } on Object catch (e, st) {
      AppLog.w('tidy after delete failed', e, st);
    }
  }

  /// «Scarica album» keeps a hidden playlist per album; with no track left it
  /// is only clutter (its import rows go with it).
  Future<void> _dropEmptyAlbumPlaylists(AppDatabase db) async {
    final ids = await db.customSelect(
      'SELECT i.playlist_id AS id FROM playlist_imports i '
      "WHERE i.source_kind = '$ytmAlbumSourceKind' AND NOT EXISTS "
      '(SELECT 1 FROM playlist_tracks t WHERE t.playlist_id = i.playlist_id)',
    ).get();
    for (final row in ids) {
      final id = row.read<int>('id');
      final imports = await (db.select(db.playlistImports)..where((i) => i.playlistId.equals(id))).get();
      await forgetImportDownloadToo(await SharedPreferences.getInstance(), [for (final i in imports) i.id]);
      await PlaylistRepository(db).delete(id); // its import rows go by cascade, after the delete has seen it is hidden
    }
  }

  /// Walks up from each deleted file's folder removing folders that are empty,
  /// strictly inside a library root (a root itself is never removed).
  Future<void> _removeEmptyDirs(List<Track> gone, List<String> roots) async {
    final dirs = {for (final t in gone) p.dirname(t.path)};
    for (var dir in dirs) {
      dir = p.normalize(dir);
      while (roots.any((r) => p.isWithin(r, dir))) {
        final d = Directory(dir);
        if (!await d.exists() || !(await d.list().isEmpty)) break;
        try {
          await d.delete();
        } on FileSystemException catch (e, st) {
          AppLog.w('empty folder not removed: $dir', e, st);
          break;
        }
        dir = p.dirname(dir);
      }
    }
  }
}
