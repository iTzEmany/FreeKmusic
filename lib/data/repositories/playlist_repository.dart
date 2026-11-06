import 'package:drift/drift.dart';

import '../../core/app_log.dart';
import '../../core/clock.dart';
import '../../core/playlist_order.dart';
import '../db/app_database.dart';
import 'hidden_playlists.dart';
import 'light_tracks.dart';
import 'track_kinds.dart';

class PlaylistSummary {
  const PlaylistSummary(this.playlist, this.trackCount,
      [this.autoCoverKey,
      this.lastPlayedAt,
      this.addedAt = 0,
      this.playCount = 0,
      this.durationMs = 0]);

  final Playlist playlist;
  final int trackCount;
  final String? autoCoverKey;

  /// Latest play of any of its tracks; null if none was ever played.
  final int? lastPlayedAt;

  /// When the latest track was added to the library (0 when empty).
  final int addedAt;

  /// Sum of the plays and of the durations of its tracks.
  final int playCount, durationMs;

  /// Custom cover if set, otherwise the first track that has one.
  String? get coverKey => playlist.coverKey ?? autoCoverKey;
}

class PlaylistRepository {
  PlaylistRepository(this._db);

  final AppDatabase _db;

  /// Every new playlist gets its own `uuid` and `updatedAt` (column defaults).
  Future<int> create(String name) => _db.into(_db.playlists).insert(
      PlaylistsCompanion.insert(
          name: name.trim(), createdAt: nowMs()));

  /// Every change below also stamps `updated_at`: it is what «last change
  /// wins» compares when playlists are synced between devices.
  Future<void> rename(int id, String name) =>
      (_db.update(_db.playlists)..where((p) => p.id.equals(id))).write(
          PlaylistsCompanion(name: Value(name.trim()), updatedAt: Value(nowMs())));

  Future<void> setCover(int id, String? coverKey) =>
      (_db.update(_db.playlists)..where((p) => p.id.equals(id))).write(
          PlaylistsCompanion(coverKey: Value(coverKey), updatedAt: Value(nowMs())));

  Future<void> _touch(int playlistId) =>
      (_db.update(_db.playlists)..where((p) => p.id.equals(playlistId)))
          .write(PlaylistsCompanion(updatedAt: Value(nowMs())));

  Future<void> delete(int id) =>
      (_db.delete(_db.playlists)..where((p) => p.id.equals(id))).go();

  /// Ids of the playlists that already hold every one of [trackIds].
  Future<Set<int>> containing(List<int> trackIds) async {
    if (trackIds.isEmpty) return {};
    final marks = List.filled(trackIds.length, '?').join(',');
    final rows = await _db.customSelect(
      'SELECT playlist_id FROM playlist_tracks WHERE track_id IN ($marks) '
      'GROUP BY playlist_id HAVING COUNT(DISTINCT track_id) = ?',
      variables: [
        for (final id in trackIds) Variable<int>(id),
        Variable<int>(trackIds.toSet().length),
      ],
      readsFrom: {_db.playlistTracks},
    ).get();
    return {for (final r in rows) r.read<int>('playlist_id')};
  }

  Stream<List<PlaylistSummary>> watchAll() {
    return _db
        .customSelect(
          'SELECT p.id, p.name, p.created_at, p.uuid, p.updated_at, '
          'p.cover_key AS custom_cover, '
          '(SELECT t.cover_key FROM playlist_tracks x JOIN tracks t ON t.id = x.track_id '
          'WHERE x.playlist_id = p.id AND t.cover_key IS NOT NULL '
          'ORDER BY x.position LIMIT 1) AS auto_cover, '
          '(SELECT COUNT(*) FROM playlist_tracks x JOIN tracks t ON t.id = x.track_id '
          'WHERE x.playlist_id = p.id AND t.kind = 0) AS n, '
          '(SELECT MAX(t.last_played_at) FROM playlist_tracks x JOIN tracks t '
          'ON t.id = x.track_id WHERE x.playlist_id = p.id) AS last_played, '
          '(SELECT MAX(t.added_at) FROM playlist_tracks x JOIN tracks t '
          'ON t.id = x.track_id WHERE x.playlist_id = p.id) AS added, '
          '(SELECT COALESCE(SUM(t.play_count), 0) FROM playlist_tracks x JOIN tracks t '
          'ON t.id = x.track_id WHERE x.playlist_id = p.id AND t.kind = 0) AS plays, '
          '(SELECT COALESCE(SUM(t.duration_ms), 0) FROM playlist_tracks x JOIN tracks t '
          'ON t.id = x.track_id WHERE x.playlist_id = p.id AND t.kind = 0) AS duration '
          'FROM playlists p LEFT JOIN playlist_tracks pt ON pt.playlist_id = p.id '
          // The technical playlist of «Scarica album» (see ytmAlbumSourceKind).
          'WHERE ${visiblePlaylistSql('p')} '
          'GROUP BY p.id ORDER BY p.name COLLATE NOCASE',
          readsFrom: {_db.playlists, _db.playlistTracks, _db.tracks, _db.playlistImports},
        )
        .watch()
        .map((rows) => [
              for (final r in rows)
                PlaylistSummary(
                  Playlist(
                    id: r.read<int>('id'),
                    name: r.read<String>('name'),
                    createdAt: r.read<int>('created_at'),
                    uuid: r.read<String?>('uuid'),
                    updatedAt: r.read<int>('updated_at'),
                    coverKey: r.read<String?>('custom_cover'),
                  ),
                  r.read<int>('n'),
                  r.read<String?>('auto_cover'),
                  r.read<int?>('last_played'),
                  r.read<int?>('added') ?? 0,
                  r.read<int>('plays'),
                  r.read<int>('duration'),
                ),
            ]);
  }

  /// The playlist's tracks in order, as list rows (see [lightTrackColumns]).
  Stream<List<Track>> watchTracks(int playlistId) {
    final entries = _db.playlistTracks.actualTableName;
    return _db
        .customSelect(
          'SELECT ${lightTrackColumns(_db, alias: 't')} FROM $entries e '
          'JOIN tracks t ON t.id = e.track_id '
          'WHERE e.playlist_id = ? AND t.missing = 0 AND t.ignored = 0 AND t.kind = 0 '
          'ORDER BY e.position',
          variables: [Variable<int>(playlistId)],
          readsFrom: {_db.playlistTracks, _db.tracks},
        )
        .watch()
        .map((rows) => [for (final r in rows) _db.tracks.map(r.data)]);
  }

  /// Returns how many tracks were actually added (duplicates are ignored, and
  /// so is anything that is not music: episodes and shadow rows).
  Future<int> addTracks(int playlistId, List<int> trackIds) {
    return _db.transaction(() async {
      final notMusic = (await (_db.selectOnly(_db.tracks)
                ..addColumns([_db.tracks.id])
                ..where(_db.tracks.id.isIn(trackIds) & _db.tracks.kind.isNotValue(kMusicKind)))
              .map((r) => r.read(_db.tracks.id)!)
              .get())
          .toSet();
      if (notMusic.isNotEmpty) {
        AppLog.i('playlist: ${notMusic.length} non-music tracks not added');
      }
      final existing = await (_db.select(_db.playlistTracks)
            ..where((t) => t.playlistId.equals(playlistId)))
          .get();
      final have = existing.map((e) => e.trackId).toSet();
      var next = existing.isEmpty
          ? 0
          : existing.map((e) => e.position).reduce((a, b) => a > b ? a : b) + 1;
      var added = 0;
      for (final id in trackIds) {
        if (notMusic.contains(id) || !have.add(id)) continue;
        await _db.into(_db.playlistTracks).insert(PlaylistTracksCompanion.insert(
            playlistId: playlistId, trackId: id, position: next++));
        added++;
      }
      if (added > 0) await _touch(playlistId);
      return added;
    });
  }

  /// Adds [trackId] of CSV row [rowIndex] of import [importId] right before the
  /// first track already in the playlist that came from a later row, else at
  /// the end. Manually added or reordered tracks keep their place. Returns
  /// false when the track was already in the playlist.
  Future<bool> placeImported(
      int playlistId, int importId, int rowIndex, int trackId) {
    return _db.transaction(() async {
      final rows = await (_db.select(_db.playlistTracks)
            ..where((t) => t.playlistId.equals(playlistId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();
      final ids = rows.map((r) => r.trackId).toList();
      if (ids.contains(trackId)) return false;
      final fromRow = {
        for (final i in await (_db.select(_db.playlistImportItems)
              ..where((i) =>
                  i.importId.equals(importId) & i.trackId.isNotNull()))
            .get())
          i.trackId!: i.rowIndex,
      };
      var at = ids.indexWhere((id) {
        final r = fromRow[id];
        return r != null && r > rowIndex;
      });
      if (at < 0) at = ids.length;
      await _db.into(_db.playlistTracks).insert(PlaylistTracksCompanion.insert(
          playlistId: playlistId, trackId: trackId, position: ids.length));
      ids.insert(at, trackId);
      await _writeOrder(playlistId, ids);
      return true;
    });
  }

  Future<void> removeTrack(int playlistId, int trackId) =>
      _db.transaction(() async {
        await (_db.delete(_db.playlistTracks)
              ..where((t) =>
                  t.playlistId.equals(playlistId) & t.trackId.equals(trackId)))
            .go();
        await _renumber(playlistId);
      });

  /// Takes [trackIds] out of a playlist (one transaction). Returns the order
  /// the playlist had, to give to [restoreTracks] for an undo.
  Future<List<int>> removeTracks(int playlistId, List<int> trackIds) =>
      _db.transaction(() async {
        final before = await (_db.select(_db.playlistTracks)
              ..where((t) => t.playlistId.equals(playlistId))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
        await (_db.delete(_db.playlistTracks)
              ..where((t) =>
                  t.playlistId.equals(playlistId) & t.trackId.isIn(trackIds)))
            .go();
        await _renumber(playlistId);
        return [for (final r in before) r.trackId];
      });

  /// Puts back [removed] where [orderBefore] (from [removeTracks]) had them;
  /// tracks added in the meantime stay, after the others.
  Future<void> restoreTracks(
      int playlistId, List<int> orderBefore, List<int> removed) {
    return _db.transaction(() async {
      final current = [
        for (final r in await (_db.select(_db.playlistTracks)
              ..where((t) => t.playlistId.equals(playlistId))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get())
          r.trackId,
      ];
      final have = current.toSet();
      var next = current.length;
      for (final id in removed) {
        if (have.add(id)) {
          await _db.into(_db.playlistTracks).insert(
              PlaylistTracksCompanion.insert(
                  playlistId: playlistId, trackId: id, position: next++));
        }
      }
      final known = orderBefore.toSet();
      await _writeOrder(playlistId, [
        for (final id in orderBefore)
          if (have.contains(id)) id,
        for (final id in current)
          if (!known.contains(id)) id,
      ]);
    });
  }

  /// Indices refer to the displayed order; `newIndex` is the final position.
  Future<void> reorder(int playlistId, int oldIndex, int newIndex) =>
      _db.transaction(() async {
        final rows = await (_db.select(_db.playlistTracks)
              ..where((t) => t.playlistId.equals(playlistId))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
        if (oldIndex < 0 || oldIndex >= rows.length) return;
        final ids = rows.map((r) => r.trackId).toList();
        final moved = ids.removeAt(oldIndex);
        ids.insert(newIndex.clamp(0, ids.length), moved);
        await _writeOrder(playlistId, ids);
      });

  /// Puts the tracks of [newIndexByTrack] in the order of their new index;
  /// the others keep their place next to the track before them
  /// (see `reorderForSync`).
  Future<void> reorderBy(int playlistId, Map<int, int> newIndexByTrack) =>
      _db.transaction(() async {
        final rows = await (_db.select(_db.playlistTracks)
              ..where((t) => t.playlistId.equals(playlistId))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
        final ids = rows.map((r) => r.trackId).toList();
        await _writeOrder(playlistId, reorderForSync(ids, newIndexByTrack));
      });

  Future<String?> nameOf(int playlistId) async => (await (_db.select(_db.playlists)
            ..where((p) => p.id.equals(playlistId)))
          .getSingleOrNull())
      ?.name;

  Future<void> _renumber(int playlistId) async {
    final rows = await (_db.select(_db.playlistTracks)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    await _writeOrder(playlistId, rows.map((r) => r.trackId).toList());
  }

  /// Every change of the tracks or their order ends here (or in [addTracks]).
  Future<void> _writeOrder(int playlistId, List<int> ids) async {
    for (var i = 0; i < ids.length; i++) {
      await (_db.update(_db.playlistTracks)
            ..where((t) =>
                t.playlistId.equals(playlistId) & t.trackId.equals(ids[i])))
          .write(PlaylistTracksCompanion(position: Value(i)));
    }
    await _touch(playlistId);
  }
}
