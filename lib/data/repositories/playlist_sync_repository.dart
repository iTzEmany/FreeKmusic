import 'package:drift/drift.dart';

import '../../core/app_log.dart';
import '../../core/import_row.dart';
import '../../services/backup/track_resolver.dart';
import '../../services/share/playlist_sync.dart';
import '../db/app_database.dart';
import 'backup_queries.dart' show trackRefFor;
import 'hidden_playlists.dart';
import 'track_kinds.dart';

/// Reads the playlists in the shapes [planSync] needs, and writes a plan.
class PlaylistSyncRepository {
  PlaylistSyncRepository(this._db);

  final AppDatabase _db;

  Future<Set<int>> _shadowIds() async => (await (_db.selectOnly(_db.tracks)
            ..addColumns([_db.tracks.id])
            ..where(_db.tracks.kind.equals(kStreamKind)))
          .map((r) => r.read(_db.tracks.id)!)
          .get())
      .toSet();

  /// Track ids in playlist order. Shadow rows (streamed tracks, D-524) are left out: they are
  /// not synced, so neither the plan nor the export sees them.
  Future<Map<int, List<int>>> _trackIdsByPlaylist() async {
    final links = await (_db.select(_db.playlistTracks)
          ..orderBy([(l) => OrderingTerm.asc(l.position)]))
        .get();
    final shadow = await _shadowIds();
    final byPlaylist = <int, List<int>>{};
    var skipped = 0;
    for (final l in links) {
      if (shadow.contains(l.trackId)) {
        skipped++;
        continue;
      }
      (byPlaylist[l.playlistId] ??= []).add(l.trackId);
    }
    if (skipped > 0) AppLog.i('sync: $skipped streamed tracks in playlists not synced');
    return byPlaylist;
  }

  Future<List<LocalPlaylist>> local() async {
    final ids = await _trackIdsByPlaylist();
    final rows = await _db.visiblePlaylists();
    return [
      for (final p in rows)
        if (p.uuid != null)
          LocalPlaylist(
            id: p.id,
            uuid: p.uuid!,
            name: p.name,
            updatedAt: p.updatedAt,
            trackIds: ids[p.id] ?? const [],
          ),
    ];
  }

  /// What `GET /sync/playlists` sends: every playlist with portable tracks.
  Future<List<RemotePlaylist>> export() {
    return _db.transaction(() async {
      final folders = {
        for (final f in await _db.select(_db.folders).get()) f.id: f.path,
      };
      final tracks = {
        for (final t in await _db.select(_db.tracks).get()) t.id: t,
      };
      final ids = await _trackIdsByPlaylist();
      return [
        for (final p in await _db.visiblePlaylists())
          if (p.uuid != null)
            RemotePlaylist(
              uuid: p.uuid!,
              name: p.name,
              createdAt: p.createdAt,
              updatedAt: p.updatedAt,
              items: [
                for (final id in ids[p.id] ?? const <int>[])
                  if (tracks[id] != null) trackRefFor(tracks[id]!, folders),
              ],
            ),
      ];
    });
  }

  /// A resolver over this device's library, the one a backup restore uses.
  Future<TrackResolver> resolver({bool caseInsensitive = false}) async {
    final folders = {
      for (final f in await _db.select(_db.folders).get()) f.id: f.path,
    };
    final entries = <LibraryEntryLite>[];
    final relPaths = <int, String>{};
    final hashes = <int, String>{};
    final music = _db.select(_db.tracks)..where((t) => t.kind.equals(0));
    for (final t in await music.get()) {
      entries.add(LibraryEntryLite(
          id: t.id,
          title: t.title,
          artist: t.artist,
          durationMs: t.durationMs,
          path: t.path));
      final ref = trackRefFor(t, folders);
      if (ref.relPath != null) relPaths[t.id] = ref.relPath!;
      if (t.sha256 != null) hashes[t.id] = t.sha256!;
    }
    return TrackResolver(entries, relPaths,
        sha256ById: hashes, caseInsensitive: caseInsensitive);
  }

  /// Writes the added and replaced playlists of [plan] in one transaction, so
  /// a failure leaves everything as it was. The playlist takes the other
  /// device's `updated_at`: both sides then compare equal until someone edits.
  Future<void> apply(SyncPlan plan) {
    return _db.transaction(() async {
      for (final e in plan.toWrite) {
        final r = e.remote;
        final int playlistId;
        var kept = const <int>[];
        if (e.action == SyncAction.add) {
          playlistId = await _db.into(_db.playlists).insert(
              PlaylistsCompanion.insert(
                name: r.name,
                createdAt: r.createdAt,
                uuid: Value(r.uuid),
                updatedAt: Value(r.updatedAt),
              ));
        } else {
          playlistId = e.local!.id;
          await (_db.update(_db.playlists)
                ..where((p) => p.id.equals(playlistId)))
              .write(PlaylistsCompanion(
                  name: Value(r.name), updatedAt: Value(r.updatedAt)));
          // The plan never saw the streamed tracks: they stay, after the synced ones.
          final shadow = await _shadowIds();
          kept = [
            for (final l in await (_db.select(_db.playlistTracks)
                  ..where((t) => t.playlistId.equals(playlistId))
                  ..orderBy([(t) => OrderingTerm.asc(t.position)]))
                .get())
              if (shadow.contains(l.trackId)) l.trackId,
          ];
          await (_db.delete(_db.playlistTracks)
                ..where((t) => t.playlistId.equals(playlistId)))
              .go();
        }
        final ids = [...e.trackIds, ...kept.where((id) => !e.trackIds.contains(id))];
        for (var i = 0; i < ids.length; i++) {
          await _db.into(_db.playlistTracks).insert(
              PlaylistTracksCompanion.insert(
                  playlistId: playlistId, trackId: ids[i], position: i));
        }
      }
      AppLog.i('sync: ${plan.toAdd.length} playlists added, '
          '${plan.toReplace.length} replaced');
    });
  }
}
