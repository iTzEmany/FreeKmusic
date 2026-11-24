import '../../data/db/tables.dart' show TombstoneKind;
import '../backup/user_data.dart';
import '../stream/stream_key.dart' show isStreamKey;

/// Most entries read from another device for one list; the rest is dropped.
const kMaxSyncItems = 20000;

/// A streamed track the user saved to the library and/or hearted, as a device describes it for the sync.
/// The dates decide who is newer: [addedAt] for the saved facet, [favoritedAt] for the heart (null = older than all).
class StreamEntry {
  const StreamEntry({
    required this.key,
    required this.title,
    this.artist,
    this.album,
    this.durationMs = 0,
    this.albumBrowseId,
    this.saved = false,
    this.addedAt,
    this.favorite = false,
    this.favoritedAt,
  });

  /// `<source>:<id>` (`TrackRef.streamKey`).
  final String key, title;
  final String? artist, album, albumBrowseId;
  final int durationMs;
  final bool saved, favorite;
  final int? addedAt, favoritedAt;

  Map<String, Object?> toJson() => {
        'key': key,
        'title': title,
        'artist': ?artist,
        'album': ?album,
        'durationMs': durationMs,
        'albumBrowseId': ?albumBrowseId,
        'saved': saved,
        'addedAt': ?addedAt,
        'favorite': favorite,
        'favoritedAt': ?favoritedAt,
      };

  /// Null for anything that is not a well-formed entry (bad key, over-long text, neither saved nor hearted):
  /// it comes from another device, so it is dropped, never trusted. Impossible dates become null.
  static StreamEntry? tryParse(Object? j) {
    if (j is! Map) return null;
    final key = j['key'], title = j['title'];
    if (key is! String || !isStreamKey(key) || key.length > kMaxKeyLength) return null;
    if (title is! String || title.length > kMaxKeyLength) return null;
    String? text(Object? v) => v is String && v.length <= kMaxKeyLength ? v : null;
    final saved = j['saved'] == true, favorite = j['favorite'] == true;
    if (!saved && !favorite) return null;
    final browse = j['albumBrowseId'];
    final duration = j['durationMs'];
    return StreamEntry(
      key: key,
      title: title,
      artist: text(j['artist']),
      album: text(j['album']),
      durationMs: duration is num && duration.isFinite && duration > 0 && duration < 86400000 ? duration.toInt() : 0,
      albumBrowseId: browse is String && isBrowseId(browse) ? browse : null,
      saved: saved,
      addedAt: sanePastDate(j['addedAt']),
      favorite: favorite,
      favoritedAt: sanePastDate(j['favoritedAt']),
    );
  }
}

/// One device's side of the sync besides the playlists.
class SyncSide {
  const SyncSide({this.favorites = const [], this.streams = const [], this.tombstones = const []});

  final List<FavoriteCollectionData> favorites;
  final List<StreamEntry> streams;
  final List<TombstoneData> tombstones;
}

/// What the sync does besides the playlists. Adds are never deletions; [deletes] and [learned] come from
/// the tombstones of an own device only.
class CollectionPlan {
  const CollectionPlan({
    this.favoriteAdds = const [],
    this.saves = const [],
    this.hearts = const [],
    this.deletes = const [],
    this.learned = const [],
  });

  final List<FavoriteCollectionData> favoriteAdds;

  /// Streamed tracks to save to the library here, and the ones to heart.
  final List<StreamEntry> saves, hearts;

  /// Deletions newer than what is here: the item goes (the row only, never a file) and the tombstone is kept.
  final List<TombstoneData> deletes;

  /// Deletions of things not here: only the tombstone is kept, so the item cannot come back from another device.
  final List<TombstoneData> learned;

  int get additions => favoriteAdds.length + saves.length + hearts.length;
  bool get isEmpty => additions == 0 && deletes.isEmpty && learned.isEmpty;
}

typedef TombstoneId = (String kind, String key);

Map<TombstoneId, int> _latest(Iterable<TombstoneData> all) {
  final out = <TombstoneId, int>{};
  for (final t in all) {
    final id = (t.kind, t.key);
    if (t.deletedAt > (out[id] ?? 0)) out[id] = t.deletedAt;
  }
  return out;
}

/// The latest deletion that keeps an item from coming back here: the ones recorded here, and the other
/// device's when it is [mine]. An item arrives only if it is more recent than this.
Map<TombstoneId, int> blockingTombstones(SyncSide local, SyncSide remote, {required bool mine}) =>
    _latest([...local.tombstones, if (mine) ...remote.tombstones]);

String? _favoriteTombstoneKind(FavoriteCollectionData f) => f.kind == 'playlist'
    ? TombstoneKind.favoritePlaylist
    : f.key.startsWith('unknown|') // a local folder path: it does not travel
        ? null
        : TombstoneKind.favoriteAlbum;

/// Pure: the favourites, saved and hearted streamed tracks and deletions of a sync. For each item the most
/// recent of the item and the deletion wins (null date = older than all, ties keep the item). Deletions
/// apply only when [mine] (the other device is one of the user's own): otherwise they are ignored, and
/// only additions remain; an addition covered by a newer deletion known here is never made, for any device.
/// [playlistDates] are `uuid -> updatedAt` of the visible playlists here; [hasFile] says a streamed track
/// is already a file here (then it is not added as a row).
CollectionPlan planCollections(
  SyncSide local,
  SyncSide remote, {
  required bool mine,
  Map<String, int> playlistDates = const {},
  bool Function(String key)? hasFile,
}) {
  final block = blockingTombstones(local, remote, mine: mine);
  final have = <TombstoneId, int>{
    for (final e in playlistDates.entries) (TombstoneKind.playlist, e.key): e.value,
  };
  for (final f in local.favorites) {
    final k = _favoriteTombstoneKind(f);
    if (k != null) have[(k, f.key)] = f.addedAt ?? 0;
  }
  for (final s in local.streams) {
    if (s.saved) have[(TombstoneKind.savedStream, s.key)] = s.addedAt ?? 0;
    if (s.favorite) have[(TombstoneKind.favoriteStream, s.key)] = s.favoritedAt ?? 0;
  }
  bool arrives(String kind, String key, int? date) =>
      !have.containsKey((kind, key)) && (date ?? 0) > (block[(kind, key)] ?? -1);

  final deletes = <TombstoneData>[], learned = <TombstoneData>[];
  if (mine) {
    final here = _latest(local.tombstones);
    for (final t in remote.tombstones) {
      final item = have[(t.kind, t.key)];
      if (item != null) {
        if (t.deletedAt > item) deletes.add(t);
      } else if (t.deletedAt > (here[(t.kind, t.key)] ?? 0)) {
        learned.add(t);
      }
    }
  }
  return CollectionPlan(
    favoriteAdds: [
      for (final f in remote.favorites)
        if (_favoriteTombstoneKind(f) case final k? when arrives(k, f.key, f.addedAt)) f,
    ],
    saves: [
      for (final s in remote.streams)
        if (s.saved && arrives(TombstoneKind.savedStream, s.key, s.addedAt) && !(hasFile?.call(s.key) ?? false)) s,
    ],
    hearts: [
      for (final s in remote.streams)
        if (s.favorite && arrives(TombstoneKind.favoriteStream, s.key, s.favoritedAt) && !(hasFile?.call(s.key) ?? false)) s,
    ],
    deletes: deletes,
    learned: learned,
  );
}
