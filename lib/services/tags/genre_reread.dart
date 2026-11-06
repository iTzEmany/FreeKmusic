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
/// `track_genres` with every genre. `tracks.genre` is only brought back to the first genre on rows not edited by hand.
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

  /// Completes when the user leaves the app alone; asked before each file.
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
      // One file at a time, so a user who comes back is waited for before the next read.
      final files = <List<String>>[];
      for (final r in rows) {
        await waitIdle();
        if (cancelled()) break;
        files.add(await _fromFile(r));
      }
      if (files.length < rows.length) break;
      // The user may have edited a genre while the files were read: decide with the state of now.
      final now = await genres.editState([for (final r in rows) r.id]);
      for (var i = 0; i < rows.length; i++) {
        final cur = now[rows[i].id];
        if (cur == null) continue;
        final fromFile = files[i];
        // A file that gives nothing: the row's own genre, split on «;» only (a web genre may hold a «/»).
        if (fromFile.isEmpty) {
          if (await genres.replace(rows[i].id, splitGenres([cur.genre], slash: false))) changed++;
          continue;
        }
        final own = splitGenres([cur.genre]);
        // A hand edit keeps its genre; the file's list is used only when it starts with that same genre.
        final useFile = (!cur.userEdited || (own.isNotEmpty && own.first.toLowerCase() == fromFile.first.toLowerCase()));
        final list = useFile ? fromFile : own;
        if (await genres.replace(rows[i].id, list)) changed++;
        if (!cur.userEdited && list.isNotEmpty) await genres.setFirstGenre(rows[i].id, list.first);
      }
      read += rows.length;
      after = rows.last.id;
      saveAfter(after);
    }
    return GenreRereadReport(read: read, changed: changed);
  }

  /// The genres of the file; empty when it gives nothing or cannot be read.
  Future<List<String>> _fromFile(GenreRereadRow r) async {
    try {
      return (await reader.read(r.path, withCover: false)).genres;
    } on Object catch (e, st) {
      AppLog.w('genre re-read: ${r.path}', e, st);
      return const [];
    }
  }
}
