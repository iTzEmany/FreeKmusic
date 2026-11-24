import '../../data/db/tables.dart' show TombstoneKind;
import '../backup/user_data.dart';
import 'collection_sync.dart';

/// A playlist as the other device describes it: portable track references and
/// the `updated_at` that decides who is newer.
class RemotePlaylist {
  const RemotePlaylist({
    required this.uuid,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  final String uuid, name;
  final int createdAt, updatedAt;
  final List<TrackRef> items;

  Map<String, Object?> toJson() => {
        'uuid': uuid,
        'name': name,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'items': [for (final i in items) i.toJson()],
      };

  /// Anything malformed is a [FormatException] (the sync fails, nothing is guessed or cut: a playlist with
  /// dropped tracks would replace a whole one here); a date from the future counts as the oldest, and
  /// at most [kMaxSyncItems] tracks are read.
  factory RemotePlaylist.fromJson(Map<String, dynamic> j) {
    final uuid = j['uuid'], name = j['name'], items = j['items'];
    if (uuid is! String ||
        !isUuid(uuid) ||
        name is! String ||
        name.length > kMaxKeyLength ||
        items is! List) {
      throw const FormatException('malformed playlist');
    }
    final created = _finite(j['createdAt']).toInt(),
        updated = _finite(j['updatedAt']);
    return RemotePlaylist(
      uuid: uuid,
      name: name,
      createdAt: created,
      updatedAt: sanePastDate(updated) ?? 0,
      items: [for (final i in items.take(kMaxSyncItems)) parseTrackRef(i)],
    );
  }

  static num _finite(Object? v) => v is num && v.isFinite
      ? v
      : throw const FormatException('not a finite number');

  static TrackRef parseTrackRef(Object? i) {
    if (i is! Map<String, dynamic>) {
      throw const FormatException('malformed track');
    }
    for (final k in const [
      'title',
      'artist',
      'folder',
      'relPath',
      'sha256',
      'streamKey',
    ]) {
      final v = i[k];
      if (v != null && (v is! String || v.length > kMaxKeyLength)) {
        throw FormatException('malformed track $k');
      }
    }
    if (i['durationMs'] != null) _finite(i['durationMs']);
    return TrackRef.fromJson(i);
  }
}

/// A playlist of this device; [trackIds] are local ids in playlist order.
class LocalPlaylist {
  const LocalPlaylist({
    required this.id,
    required this.uuid,
    required this.name,
    required this.updatedAt,
    this.trackIds = const [],
  });

  final int id;
  final String uuid, name;
  final int updatedAt;
  final List<int> trackIds;
}

enum SyncAction {
  /// Not on this device yet: it is created.
  add,

  /// The other device changed it more recently: it is replaced.
  replace,

  /// This device changed it more recently: left alone (the other one takes it).
  keep,

  /// Nothing to do.
  same,
}

class SyncEntry {
  const SyncEntry({
    required this.action,
    required this.remote,
    this.local,
    this.trackIds = const [],
    this.missing = const [],
    this.removed = 0,
    this.renamed = false,
    this.reordered = false,
  });

  final SyncAction action;
  final RemotePlaylist remote;
  final LocalPlaylist? local;

  /// Local ids the playlist ends up with, in order (for [SyncAction.add] and
  /// [SyncAction.replace]).
  final List<int> trackIds;

  /// References with no track on this device.
  final List<TrackRef> missing;

  /// Local tracks the replacement drops from an existing playlist.
  final int removed;

  /// [SyncAction.replace]: the name changes.
  final bool renamed;

  /// [SyncAction.replace]: the same tracks, in another order.
  final bool reordered;

  /// Entries that write something.
  bool get writes => action == SyncAction.add || action == SyncAction.replace;
}

class SyncPlan {
  const SyncPlan(this.entries, [this.collections = const CollectionPlan()]);

  final List<SyncEntry> entries;

  /// Favourites, saved and hearted streamed tracks, and the deletions (playlists too).
  final CollectionPlan collections;

  Iterable<SyncEntry> _of(SyncAction a) => entries.where((e) => e.action == a);

  List<SyncEntry> get toAdd => _of(SyncAction.add).toList();
  List<SyncEntry> get toReplace => _of(SyncAction.replace).toList();
  List<SyncEntry> get toWrite => entries.where((e) => e.writes).toList();
  int get keptCount => _of(SyncAction.keep).length;
  int get sameCount => _of(SyncAction.same).length;

  /// Tracks of the other device's playlists (the ones not kept) that this
  /// device does not have, each listed once.
  List<TrackRef> get missing {
    final seen = <String>{};
    return [
      for (final e in entries)
        if (e.action != SyncAction.keep)
          for (final t in e.missing)
            if (seen.add('${t.folder}|${t.relPath}|${t.title}|${t.artist}')) t,
    ];
  }

  bool get isEmpty => toWrite.isEmpty && collections.isEmpty;
}

/// Decides, playlist by playlist (matched by `uuid`), what a sync does. The
/// most recent change wins; nothing is ever deleted because the other device
/// does not have a playlist, only because it has a more recent tombstone, and
/// only when [mine] (an own device, D-668). A playlist covered by a newer tombstone
/// known here is not added back, whoever sends it (on a tie the playlist stays). [resolve] finds the local track of a
/// reference (the same matching as a backup restore) or null. [localSide] and [remoteSide]
/// carry the rest (favourites, streamed tracks, tombstones): see [planCollections].
SyncPlan planSync(
  List<LocalPlaylist> local,
  List<RemotePlaylist> remote,
  int? Function(TrackRef) resolve, {
  SyncSide localSide = const SyncSide(),
  SyncSide remoteSide = const SyncSide(),
  bool mine = false,
  bool Function(String key)? hasFile,
}) {
  final collections = planCollections(localSide, remoteSide,
      mine: mine, playlistDates: {for (final l in local) l.uuid: l.updatedAt}, hasFile: hasFile);
  final deleting = {for (final t in collections.deletes) if (t.kind == TombstoneKind.playlist) t.key};
  final block = blockingTombstones(localSide, remoteSide, mine: mine);
  final byUuid = {for (final l in local) l.uuid: l};
  final seen = <String>{};
  final entries = <SyncEntry>[];
  for (final r in remote) {
    if (r.uuid.isEmpty || !seen.add(r.uuid) || deleting.contains(r.uuid)) continue;
    final l = byUuid[r.uuid];
    final resolved = <int>[];
    final missing = <TrackRef>[];
    for (final ref in r.items) {
      final id = resolve(ref);
      if (id == null) {
        missing.add(ref);
      } else if (!resolved.contains(id)) {
        resolved.add(id);
      }
    }
    if (l == null) {
      if (r.updatedAt < (block[(TombstoneKind.playlist, r.uuid)] ?? -1)) {
        entries.add(
          SyncEntry(action: SyncAction.keep, remote: r),
        ); // deleted here, more recently
        continue;
      }
      entries.add(SyncEntry(
          action: SyncAction.add,
          remote: r,
          trackIds: resolved,
          missing: missing));
      continue;
    }
    if (r.updatedAt < l.updatedAt) {
      entries.add(SyncEntry(action: SyncAction.keep, remote: r, local: l));
      continue;
    }
    final renamed = r.name != l.name;
    final sameSet = _sameSet(resolved, l.trackIds);
    final reordered = sameSet && !_sameOrder(resolved, l.trackIds);
    final changes = renamed || !sameSet || reordered;
    // Equal stamps with different content cannot happen between two honest
    // devices, except for tracks that were missing at the last sync and have
    // arrived since: then the playlist only grows. Anything else is left alone.
    final arrived = r.updatedAt == l.updatedAt &&
        resolved.length > l.trackIds.length &&
        l.trackIds.every(resolved.contains);
    if ((r.updatedAt == l.updatedAt && !arrived) || !changes) {
      entries.add(SyncEntry(
          action: SyncAction.same, remote: r, local: l, missing: missing));
      continue;
    }
    final localSet = l.trackIds.toSet();
    entries.add(SyncEntry(
      action: SyncAction.replace,
      remote: r,
      local: l,
      trackIds: resolved,
      missing: missing,
      removed: localSet.difference(resolved.toSet()).length,
      renamed: renamed,
      reordered: reordered,
    ));
  }
  // A favourite playlist is planned only if its playlist is here after this plan (so a later plan has nothing to do).
  final present = {
    for (final u in byUuid.keys)
      if (!deleting.contains(u)) u,
    for (final e in entries)
      if (e.action == SyncAction.add) e.remote.uuid,
  };
  return SyncPlan(
    entries,
    CollectionPlan(
      favoriteAdds: [
        for (final f in collections.favoriteAdds)
          if (f.kind != 'playlist' || present.contains(f.key)) f,
      ],
      saves: collections.saves,
      hearts: collections.hearts,
      deletes: collections.deletes,
      learned: collections.learned,
      settings: collections.settings,
      tables: collections.tables,
    ),
  );
}

bool _sameSet(List<int> a, List<int> b) =>
    a.length == b.length && a.toSet().containsAll(b);

bool _sameOrder(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
