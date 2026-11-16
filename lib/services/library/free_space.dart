import 'dart:io';

import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/track_kinds.dart' show kMusicKind;
import '../../data/repositories/track_repository.dart';
import '../online/download_index.dart';
import 'duplicate_cleanup.dart' show FileDeleter;

/// A file the app downloaded itself ([key] = `<source>:<id>` in the download index): the only kind
/// «Libera spazio» may offer (a file the app did not download is never touched).
class FreeSpaceCandidate {
  const FreeSpaceCandidate(this.track, this.key, this.stale);
  final Track track;
  final String key;

  /// Not played for 90 days (or never).
  final bool stale;
  int get sizeBytes => track.sizeBytes;
}

class FreeSpaceReport {
  const FreeSpaceReport({required this.freedIds, required this.failedIds, required this.freedBytes});
  final List<int> freedIds;

  /// File still on disk: the row was put back as it was.
  final List<int> failedIds;
  final int freedBytes;
}

/// «Libera spazio» (D-581): a downloaded track goes back to being a saved stream row (same id, so
/// playlists, plays, favourite and lyrics stay) and its file is deleted.
class FreeSpaceService {
  FreeSpaceService({
    required this.tracks,
    required this.index,
    FileDeleter? deleter,
    this.platform,
    int Function()? nowMs,
  }) : _deleter = deleter ?? _deleteFile,
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final TrackRepository tracks;
  final DownloadIndex index;
  final FileDeleter _deleter;

  /// Android: for files plain deletion is refused (returns the paths that are gone).
  final Future<List<String>> Function(List<String> paths)? platform;
  final int Function() _nowMs;

  static Future<void> _deleteFile(String path) => File(path).delete();
  static const _staleMs = 90 * 24 * 3600 * 1000;

  /// File rows downloaded by the app and still on disk: unplayed for 90 days first, then the biggest.
  Future<List<FreeSpaceCandidate>> freeSpaceCandidates() async {
    final limit = _nowMs() - _staleMs;
    final out = <FreeSpaceCandidate>[];
    for (final e in index.entries) {
      final t = await tracks.byPath(e.value);
      if (t == null || t.kind != kMusicKind || !await File(e.value).exists()) continue;
      out.add(FreeSpaceCandidate(t, e.key, (t.lastPlayedAt ?? 0) < limit));
    }
    out.sort((a, b) {
      if (a.stale != b.stale) return a.stale ? -1 : 1;
      return b.sizeBytes.compareTo(a.sizeBytes);
    });
    return out;
  }

  /// Order, per track: 1. the row is demoted, 2. the file is deleted, 3. the download index forgets it.
  /// So there is never a row pointing to a missing file, nor a deleted file whose row still says
  /// «file». When the delete fails (after the platform dialog, if any) the row is put back as it was:
  /// the file and its row stay consistent and the failure is logged. Ids that are not candidates are ignored.
  Future<FreeSpaceReport> freeSpace(Iterable<int> ids) async {
    final wanted = ids.toSet();
    final todo = [for (final c in await freeSpaceCandidates()) if (wanted.contains(c.track.id)) c];
    final demoted = <FreeSpaceCandidate>[];
    for (final c in todo) {
      try {
        if (await tracks.demoteToStream(c.track.id, c.key) == null) continue;
      } on Object catch (e, st) {
        AppLog.w('free space: row not demoted: ${c.track.path}', e, st);
        continue;
      }
      demoted.add(c);
      try {
        await _deleter(c.track.path);
      } on Object catch (e, st) {
        AppLog.w('free space: delete failed: ${c.track.path}', e, st);
      }
    }
    final retry = [for (final c in demoted) if (await File(c.track.path).exists()) c.track.path];
    if (platform != null && retry.isNotEmpty) {
      try {
        await platform!(retry);
      } on Object catch (e, st) {
        AppLog.w('free space: platform delete failed', e, st);
      }
    }
    final freed = <FreeSpaceCandidate>[];
    final back = <int>[];
    for (final c in demoted) {
      if (await File(c.track.path).exists()) {
        await tracks.restoreRow(c.track);
        back.add(c.track.id);
      } else {
        freed.add(c);
        await index.remove(c.key);
      }
    }
    return FreeSpaceReport(
      freedIds: [for (final c in freed) c.track.id],
      failedIds: back,
      freedBytes: freed.fold(0, (s, c) => s + c.sizeBytes),
    );
  }
}
