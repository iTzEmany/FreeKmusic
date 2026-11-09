import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'track_kinds.dart';

/// A track the genre re-read goes through.
typedef GenreRereadRow = ({int id, String path, bool userEdited, String? genre});

/// `track_genres` (D-390): every genre of a track, in tag order. `tracks.genre`
/// stays the first one.
class TrackGenreRepository {
  TrackGenreRepository(this._db);

  final AppDatabase _db;

  /// The genres of [trackId], in order.
  Future<List<String>> of(int trackId) async {
    final rows = await (_db.select(_db.trackGenres)
          ..where((g) => g.trackId.equals(trackId))
          ..orderBy([(g) => OrderingTerm.asc(g.position)]))
        .get();
    return [for (final r in rows) r.genre];
  }

  /// The genres of every library music track that has rows (not missing, not
  /// hidden), in tag order: what the daylist ranks with.
  Future<Map<int, List<String>>> musicGenres() async {
    final q = _db.select(_db.trackGenres).join([
      innerJoin(_db.tracks, _db.tracks.id.equalsExp(_db.trackGenres.trackId)),
    ])
      ..where(_db.tracks.kind.equals(kMusicKind) & _db.tracks.missing.equals(false) & _db.tracks.ignored.equals(false))
      ..orderBy([OrderingTerm.asc(_db.trackGenres.position)]);
    final out = <int, List<String>>{};
    for (final row in await q.get()) {
      final g = row.readTable(_db.trackGenres);
      (out[g.trackId] ??= []).add(g.genre);
    }
    return out;
  }

  /// Writes [genres] as the genres of [trackId]; nothing is touched when they are
  /// already there. True when the rows changed.
  Future<bool> replace(int trackId, List<String> genres) => _db.transaction(() async {
        if (_same(await of(trackId), genres)) return false;
        await write(trackId, genres);
        return true;
      });

  /// [replace] for many tracks at once (the scan): one read, one delete, one insert,
  /// instead of three statements per track.
  Future<void> replaceMany(Map<int, List<String>> byTrack) async {
    if (byTrack.isEmpty) return;
    await _db.transaction(() async {
      final old = <int, List<String>>{};
      final ids = byTrack.keys.toList();
      for (var i = 0; i < ids.length; i += 500) {
        final rows = await (_db.select(_db.trackGenres)
              ..where((g) => g.trackId.isIn(ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500)))
              ..orderBy([(g) => OrderingTerm.asc(g.position)]))
            .get();
        for (final r in rows) {
          (old[r.trackId] ??= []).add(r.genre);
        }
      }
      final changed = [
        for (final e in byTrack.entries)
          if (!_same(old[e.key] ?? const [], e.value)) e.key,
      ];
      for (var i = 0; i < changed.length; i += 500) {
        final chunk = changed.sublist(i, i + 500 > changed.length ? changed.length : i + 500);
        await (_db.delete(_db.trackGenres)..where((g) => g.trackId.isIn(chunk))).go();
      }
      await _db.batch((b) => b.insertAll(_db.trackGenres, [
            for (final id in changed)
              for (var i = 0; i < byTrack[id]!.length; i++)
                TrackGenresCompanion.insert(trackId: id, genre: byTrack[id]![i], position: i),
          ]));
    });
  }

  /// Like [replace] without reading first: for a caller that knows the genre changed
  /// and is under a read budget (the enrichment commit).
  Future<void> write(int trackId, List<String> genres) => _db.transaction(() async {
        await (_db.delete(_db.trackGenres)..where((g) => g.trackId.equals(trackId))).go();
        await _db.batch((b) => b.insertAll(_db.trackGenres, [
              for (var i = 0; i < genres.length; i++)
                TrackGenresCompanion.insert(trackId: trackId, genre: genres[i], position: i),
            ]));
      });

  static bool _same(List<String> a, List<String> b) =>
      a.length == b.length && [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

  /// The current `user_edited` and `genre` of [ids], by id (a deleted track is absent).
  Future<Map<int, ({bool userEdited, String? genre})>> editState(List<int> ids) async {
    final rows = await (_db.selectOnly(_db.tracks)
          ..addColumns([_db.tracks.id, _db.tracks.userEdited, _db.tracks.genre])
          ..where(_db.tracks.id.isIn(ids)))
        .get();
    return {
      for (final r in rows)
        r.read(_db.tracks.id)!: (userEdited: r.read(_db.tracks.userEdited)!, genre: r.read(_db.tracks.genre)),
    };
  }

  /// Sets `tracks.genre` of [trackId] to [genre] when it differs (no read first).
  Future<void> setFirstGenre(int trackId, String genre) => _db.customUpdate(
        'UPDATE tracks SET genre = ?1 WHERE id = ?2 AND genre IS NOT ?1',
        variables: [Variable<String>(genre), Variable<int>(trackId)],
        updates: {_db.tracks},
      );

  /// Music tracks with a file, by id above [after], for the re-read.
  Future<List<GenreRereadRow>> rereadBatch(int after, int limit) async {
    final rows = await _db
        .customSelect(
          'SELECT id, path, user_edited, genre FROM tracks WHERE id > ?1 AND kind = $kMusicKind AND missing = 0 '
          'ORDER BY id LIMIT ?2',
          variables: [Variable<int>(after), Variable<int>(limit)],
          readsFrom: {_db.tracks},
        )
        .get();
    return [
      for (final r in rows)
        (id: r.read<int>('id'), path: r.read<String>('path'), userEdited: r.read<bool>('user_edited'), genre: r.read<String?>('genre')),
    ];
  }
}
