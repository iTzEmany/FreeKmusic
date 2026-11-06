import 'dart:async';

import '../../core/app_log.dart';
import '../../data/repositories/track_genre_repository.dart';
import 'tag_reader.dart';

/// Bump to read every file again (the way genres are split changed).
const kGenreRereadVersion = 1;

/// What one [GenreReread.run] did.
class GenreRereadReport {
  const GenreRereadReport({this.read = 0, this.changed = 0, this.finished = false});

  /// Tracks gone through, and those whose `track_genres` rows changed.
  final int read, changed;

  /// The whole library was gone through (the bookmark went back to the start).
  final bool finished;
}

/// One-off (D-390): reads the tags of the existing library again, in batches, to fill
/// `track_genres` with every genre. Only `track_genres` is written, never `tracks.genre`.
/// The bookmark is saved after each batch, so a stopped run carries on where it was.
class GenreReread {
  GenreReread({
    required this.genres,
    required this.reader,
    required this.waitIdle,
    required this.loadAfter,
    required this.saveAfter,
    required this.markDone,
    this.cancelled = _never,
    this.batch = 20,
  });

  final TrackGenreRepository genres;
  final TagReader reader;

  /// Completes when the user leaves the app alone; asked before each batch.
  final Future<void> Function() waitIdle;
  final int Function() loadAfter;
  final void Function(int id) saveAfter;
  final void Function() markDone;
  final bool Function() cancelled;
  final int batch;

  static bool _never() => false;

  Future<GenreRereadReport> run() async {
    var read = 0, changed = 0;
    var after = loadAfter();
    while (!cancelled()) {
      final rows = await genres.rereadBatch(after, batch);
      if (rows.isEmpty) {
        saveAfter(0);
        markDone();
        return GenreRereadReport(read: read, changed: changed, finished: true);
      }
      await waitIdle();
      if (cancelled()) break;
      // Each read runs in its own isolate (the reader); a hand-edited genre stays what the user wrote.
      final lists = await Future.wait([
        for (final r in rows)
          r.userEdited ? Future.value(splitGenres([r.genre])) : _fromFile(r),
      ]);
      for (var i = 0; i < rows.length; i++) {
        if (await genres.replace(rows[i].id, lists[i])) changed++;
      }
      read += rows.length;
      after = rows.last.id;
      saveAfter(after);
    }
    return GenreRereadReport(read: read, changed: changed);
  }

  /// A file that gives nothing (unreadable, no tag) keeps what the row says.
  Future<List<String>> _fromFile(GenreRereadRow r) async {
    try {
      final fromFile = (await reader.read(r.path, withCover: false)).genres;
      return fromFile.isNotEmpty ? fromFile : splitGenres([r.genre]);
    } on Object catch (e, st) {
      AppLog.w('genre re-read: ${r.path}', e, st);
      return splitGenres([r.genre]);
    }
  }
}
