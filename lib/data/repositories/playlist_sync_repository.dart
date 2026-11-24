import 'package:drift/drift.dart';

import '../../core/app_log.dart';
import '../../core/import_row.dart';
import '../../services/backup/track_resolver.dart';
import '../../services/backup/user_data.dart';
import '../../services/share/collection_sync.dart';
import '../../services/share/playlist_sync.dart';
import '../../services/online/youtube_service.dart' show YtResult;
import '../../services/stream/stream_key.dart';
import '../db/app_database.dart';
import '../db/tables.dart' show TombstoneKind, kTombstoneKinds;
import 'backup_queries.dart' show trackRefFor;
import 'favorite_collections_repository.dart';
import 'hidden_playlists.dart';
import 'sync_tombstone_repository.dart';
import 'track_kinds.dart';
import 'track_repository.dart';

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

  /// What `GET /sync/favorites` sends: favourite albums and playlists (an `unknown|` album key is a local folder path: no).
  Future<List<FavoriteCollectionData>> favorites() async => [
        for (final f in await _db.select(_db.favoriteCollections).get())
          if (!(f.kind == FavoriteCollectionsRepository.album && f.key.startsWith('unknown|')))
            FavoriteCollectionData(kind: f.kind, key: f.key, addedAt: f.addedAt),
      ];

  /// What `GET /sync/streams` sends: the streamed rows (kind 2) that are saved or hearted.
  Future<List<StreamEntry>> streams() async {
    final rows = await (_db.select(_db.tracks)
          ..where((t) => t.kind.equals(kStreamKind) & (t.saved.equals(true) | t.isFavorite.equals(true))))
        .get();
    return [
      for (final t in rows)
        if (keyOfStreamPath(t.path) case final key? when isStreamKey(key))
          StreamEntry(
            key: key,
            title: t.title,
            artist: t.artist,
            album: t.album,
            durationMs: t.durationMs,
            albumBrowseId: t.albumBrowseId,
            saved: t.saved,
            addedAt: t.saved ? t.addedAt : null,
            favorite: t.isFavorite,
            favoritedAt: t.isFavorite ? t.favoritedAt : null,
          ),
    ];
  }

  /// What `POST /sync/tombstones` sends: the deletions after [since] (all when null).
  Future<List<TombstoneData>> tombstones({int? since}) async => [
        for (final t in await SyncTombstoneRepository(_db).all(since: since))
          if (kTombstoneKinds.contains(t.kind)) TombstoneData(kind: t.kind, key: t.key, deletedAt: t.deletedAt),
      ];

  /// This device's side of a sync besides the playlists, for [planSync].
  Future<SyncSide> side() async =>
      SyncSide(favorites: await favorites(), streams: await streams(), tombstones: await tombstones());

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
  ///
  /// The rest of the plan follows: deletions and tombstones, then favourites (after the playlists, so a favourite
  /// playlist finds its uuid) and streamed rows. Every write re-checks its date against what is here now, as the
  /// plan may be older than the confirmation: an item is deleted only if older than the deletion and a tombstone
  /// goes only if the arriving item is more recent. A deletion removes a row or a flag, never a file; [hasFile]
  /// says a streamed track is already a file here (no row is made for it).
  Future<void> apply(SyncPlan plan, {bool Function(String key)? hasFile}) {
    return _db.transaction(() async {
      final tomb = SyncTombstoneRepository(_db);
      for (final e in plan.toWrite) {
        final r = e.remote;
        final int playlistId;
        var kept = const <int>[];
        if (e.action == SyncAction.add) {
          final gone = await tomb.deletedAt(TombstoneKind.playlist, r.uuid);
          if (gone != null && r.updatedAt <= gone) continue;
          playlistId = await _db.into(_db.playlists).insert(
              PlaylistsCompanion.insert(
                name: r.name,
                createdAt: r.createdAt,
                uuid: Value(r.uuid),
                updatedAt: Value(r.updatedAt),
              ));
          await tomb.clear(TombstoneKind.playlist, r.uuid);
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
      await _applyCollections(plan.collections, tomb, hasFile);
      AppLog.i('sync: ${plan.toAdd.length} playlists added, ${plan.toReplace.length} replaced, '
          '${plan.collections.additions} favourites/streams added, ${plan.collections.deletes.length} deleted');
    });
  }

  Future<void> _applyCollections(CollectionPlan c, SyncTombstoneRepository tomb, bool Function(String key)? hasFile) async {
    for (final t in [...c.deletes, ...c.learned]) {
      await _drop(t);
      await tomb.record(t.kind, t.key, at: t.deletedAt);
    }
    final uuids = {for (final p in await _db.select(_db.playlists).get()) ?p.uuid};
    for (final f in c.favoriteAdds) {
      if (f.kind == FavoriteCollectionsRepository.playlist && !uuids.contains(f.key)) continue;
      final kind = f.kind == FavoriteCollectionsRepository.playlist ? TombstoneKind.favoritePlaylist : TombstoneKind.favoriteAlbum;
      final gone = await tomb.deletedAt(kind, f.key);
      if (gone != null && (f.addedAt ?? 0) <= gone) continue;
      await FavoriteCollectionsRepository(_db).add(f.kind, f.key, addedAt: f.addedAt);
    }
    final tracks = TrackRepository(_db);
    for (final s in c.saves) {
      await tracks.ingestStream(_resultOf(s), at: s.addedAt ?? 0, hasFile: hasFile);
    }
    for (final s in c.hearts) {
      final id = await tracks.ingestStream(_resultOf(s), at: s.favoritedAt ?? 0, save: false, hasFile: hasFile);
      if (id == null) continue;
      await (_db.update(_db.tracks)..where((t) => t.id.equals(id)))
          .write(TracksCompanion(isFavorite: const Value(true), favoritedAt: Value(s.favoritedAt)));
      await tomb.clear(TombstoneKind.favoriteStream, s.key);
    }
  }

  YtResult _resultOf(StreamEntry s) =>
      streamResultOf(s.key, title: s.title, artist: s.artist, album: s.album, durationMs: s.durationMs, albumId: s.albumBrowseId);

  /// Removes what [t] deletes, if it is older than the deletion. Rows and flags only: a playlist (not a hidden one),
  /// a favourite, the `saved` or heart flag of a streamed row (kind 2, never a library file). The row stays.
  Future<void> _drop(TombstoneData t) async {
    final at = t.deletedAt;
    switch (t.kind) {
      case TombstoneKind.playlist:
        final p = await (_db.select(_db.playlists)
              ..where((p) => p.uuid.equals(t.key) & p.updatedAt.isSmallerThanValue(at) & _db.isPlaylistVisible(p)))
            .getSingleOrNull();
        if (p == null) return;
        await (_db.delete(_db.favoriteCollections)
              ..where((f) => f.kind.equals(FavoriteCollectionsRepository.playlist) & f.key.equals(t.key)))
            .go();
        await (_db.delete(_db.playlists)..where((x) => x.id.equals(p.id))).go();
      case TombstoneKind.favoriteAlbum || TombstoneKind.favoritePlaylist:
        final kind = t.kind == TombstoneKind.favoritePlaylist
            ? FavoriteCollectionsRepository.playlist
            : FavoriteCollectionsRepository.album;
        await (_db.delete(_db.favoriteCollections)
              ..where((f) => f.kind.equals(kind) & f.key.equals(t.key) & f.addedAt.isSmallerThanValue(at)))
            .go();
      case TombstoneKind.savedStream:
        await (_db.update(_db.tracks)
              ..where((r) => r.path.equals(streamPathOf(t.key)) & r.kind.equals(kStreamKind) & r.addedAt.isSmallerThanValue(at)))
            .write(const TracksCompanion(saved: Value(false)));
      case TombstoneKind.favoriteStream:
        await (_db.update(_db.tracks)
              ..where((r) =>
                  r.path.equals(streamPathOf(t.key)) &
                  r.kind.equals(kStreamKind) &
                  (r.favoritedAt.isNull() | r.favoritedAt.isSmallerThanValue(at))))
            .write(const TracksCompanion(isFavorite: Value(false), favoritedAt: Value(null)));
    }
  }
}
