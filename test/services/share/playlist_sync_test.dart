import 'package:codecore/services/backup/user_data.dart';
import 'package:codecore/services/share/collection_sync.dart';
import 'package:codecore/services/share/playlist_sync.dart';
import 'package:flutter_test/flutter_test.dart';

TrackRef _ref(String title) => TrackRef(title: title, relPath: '$title.mp3');

/// Tracks "a".."e" exist locally with ids 1..5; anything else is missing.
int? _resolve(TrackRef r) {
  const known = {'a': 1, 'b': 2, 'c': 3, 'd': 4, 'e': 5};
  return known[r.title];
}

LocalPlaylist _local(String uuid, String name, int at, List<int> ids) =>
    LocalPlaylist(id: 1, uuid: uuid, name: name, updatedAt: at, trackIds: ids);

RemotePlaylist _remote(String uuid, String name, int at, List<String> titles) =>
    RemotePlaylist(
        uuid: uuid,
        name: name,
        createdAt: 1,
        updatedAt: at,
        items: [for (final t in titles) _ref(t)]);

void main() {
  test('a playlist the device does not have is added, with its tracks resolved', () {
    final plan = planSync(
        [], [_remote('u1', 'Road', 10, ['a', 'c'])], _resolve);
    expect(plan.entries.single.action, SyncAction.add);
    expect(plan.entries.single.trackIds, [1, 3]);
    expect(plan.toAdd, hasLength(1));
    expect(plan.isEmpty, isFalse);
  });

  test('the other device is newer: the playlist is replaced and local-only tracks drop', () {
    final plan = planSync(
      [_local('u1', 'Road', 10, [1, 2, 3])],
      [_remote('u1', 'Road', 20, ['a', 'd'])],
      _resolve,
    );
    final e = plan.entries.single;
    expect(e.action, SyncAction.replace);
    expect(e.trackIds, [1, 4]);
    expect(e.removed, 2, reason: 'b and c are not in the newer version');
    expect(e.renamed, isFalse);
    expect(e.reordered, isFalse);
  });

  test('this device is newer: left alone, the other one will take it', () {
    final plan = planSync(
      [_local('u1', 'Road', 30, [1, 2])],
      [_remote('u1', 'Old name', 20, ['a'])],
      _resolve,
    );
    expect(plan.entries.single.action, SyncAction.keep);
    expect(plan.keptCount, 1);
    expect(plan.isEmpty, isTrue);
  });

  test('the same stamp is the same playlist, even if the lists differ', () {
    final plan = planSync(
      [_local('u1', 'Road', 20, [1, 2])],
      [_remote('u1', 'Road', 20, ['a', 'c'])],
      _resolve,
    );
    expect(plan.entries.single.action, SyncAction.same);
    expect(plan.sameCount, 1);
    expect(plan.isEmpty, isTrue);
  });

  test('tracks that were missing and have arrived are added at the same stamp', () {
    final plan = planSync(
      [_local('u1', 'Road', 20, [1])],
      [_remote('u1', 'Road', 20, ['a', 'b', 'c'])],
      _resolve,
    );
    expect(plan.entries.single.action, SyncAction.replace);
    expect(plan.entries.single.trackIds, [1, 2, 3]);
    expect(plan.entries.single.removed, 0);
  });

  test('tracks this device lacks are listed as missing, once, and skipped', () {
    final plan = planSync(
      [_local('u1', 'Road', 10, [1])],
      [
        _remote('u1', 'Road', 20, ['a', 'x', 'y', 'd']),
        _remote('u2', 'Gym', 5, ['x', 'b']),
      ],
      _resolve,
    );
    expect(plan.entries[0].trackIds, [1, 4]);
    expect(plan.entries[1].trackIds, [2]);
    expect(plan.missing.map((t) => t.title), ['x', 'y']);
  });

  test('a newer version with another name is a rename', () {
    final plan = planSync(
      [_local('u1', 'Road', 10, [1, 2])],
      [_remote('u1', 'Road trip', 20, ['a', 'b'])],
      _resolve,
    );
    final e = plan.entries.single;
    expect(e.action, SyncAction.replace);
    expect(e.renamed, isTrue);
    expect(e.reordered, isFalse);
    expect(e.removed, 0);
  });

  test('the same tracks in another order is a reorder', () {
    final plan = planSync(
      [_local('u1', 'Road', 10, [1, 2, 3])],
      [_remote('u1', 'Road', 20, ['c', 'a', 'b'])],
      _resolve,
    );
    final e = plan.entries.single;
    expect(e.action, SyncAction.replace);
    expect(e.reordered, isTrue);
    expect(e.renamed, isFalse);
    expect(e.trackIds, [3, 1, 2]);
  });

  test('a newer stamp that changes nothing here is "same", not a change, but still lists the missing tracks', () {
    final plan = planSync(
      [_local('u1', 'Road', 10, [1, 2])],
      [_remote('u1', 'Road', 20, ['a', 'x', 'b'])],
      _resolve,
    );
    expect(plan.entries.single.action, SyncAction.same);
    expect(plan.isEmpty, isTrue);
    expect(plan.missing.map((t) => t.title), ['x']);
  });

  test('both sides changed different playlists: each side wins its own', () {
    final plan = planSync(
      [_local('u1', 'One', 50, [1]), _local('u2', 'Two', 10, [2])],
      [_remote('u1', 'One', 20, ['a', 'b']), _remote('u2', 'Two', 40, ['b', 'c'])],
      _resolve,
    );
    expect(plan.entries[0].action, SyncAction.keep);
    expect(plan.entries[1].action, SyncAction.replace);
    expect(plan.entries[1].trackIds, [2, 3]);
    expect(plan.toWrite, hasLength(1));
  });

  test('a repeated or empty uuid is ignored; a track listed twice counts once', () {
    final plan = planSync(
      [],
      [
        _remote('u1', 'Road', 10, ['a', 'a', 'b']),
        _remote('u1', 'Copy', 99, ['c']),
        _remote('', 'No id', 10, ['a']),
      ],
      _resolve,
    );
    expect(plan.entries, hasLength(1));
    expect(plan.entries.single.remote.name, 'Road');
    expect(plan.entries.single.trackIds, [1, 2]);
  });

  test('a playlist only this device has is never dropped: it is not in the plan at all', () {
    // characterization: the sync has no delete, so one removed on the other side comes back from here.
    final plan = planSync([_local('u1', 'Road', 10, [1])], [], _resolve);
    expect(plan.entries, isEmpty);
    expect(plan.isEmpty, isTrue);
  });

  group('tombstones and collections', () {
    const u1 = '00000000-0000-4000-8000-000000000001';
    const vid = 'youtube:dQw4w9WgXcQ';
    TombstoneData tomb(String kind, String key, int at) => TombstoneData(kind: kind, key: key, deletedAt: at);
    SyncSide side({
      List<FavoriteCollectionData> favorites = const [],
      List<StreamEntry> streams = const [],
      List<TombstoneData> tombstones = const [],
    }) =>
        SyncSide(favorites: favorites, streams: streams, tombstones: tombstones);

    SyncPlan plan(List<LocalPlaylist> local, List<RemotePlaylist> remote,
            {SyncSide? here, SyncSide? there, bool mine = false, bool Function(String)? hasFile}) =>
        planSync(local, remote, _resolve,
            localSide: here ?? side(), remoteSide: there ?? side(), mine: mine, hasFile: hasFile);

    test('a newer tombstone of an own device deletes the playlist; an older or equal one is discarded', () {
      final local = [_local(u1, 'Road', 100, [1])];
      final newer = plan(local, [], there: side(tombstones: [tomb('playlist', u1, 101)]), mine: true);
      expect(newer.collections.deletes.single.key, u1);
      expect(newer.isEmpty, isFalse);
      for (final at in [100, 99]) {
        final p = plan(local, [], there: side(tombstones: [tomb('playlist', u1, at)]), mine: true);
        expect(p.collections.deletes, isEmpty, reason: 'deleted at $at, changed at 100');
        expect(p.collections.learned, isEmpty);
      }
    });

    test('a device that is not «mine» deletes nothing: its tombstones are ignored', () {
      final p = plan([_local(u1, 'Road', 100, [1])], [],
          there: side(tombstones: [tomb('playlist', u1, 500), tomb('favoriteAlbum', 'a|b', 500)]));
      expect(p.collections.deletes, isEmpty);
      expect(p.collections.learned, isEmpty);
      expect(p.isEmpty, isTrue);
    });

    test('a playlist deleted here is not added back by any device unless it changed after the deletion', () {
      final here = side(tombstones: [tomb('playlist', u1, 100)]);
      for (final mine in [false, true]) {
        final old = plan([], [_remote(u1, 'Road', 100, ['a'])], here: here, mine: mine);
        expect(old.entries.single.action, SyncAction.keep, reason: 'mine=$mine');
        expect(old.toAdd, isEmpty);
        expect(old.missing, isEmpty, reason: 'no tracks are asked for a playlist that is not added');
        final fresh = plan([], [_remote(u1, 'Road', 101, ['a'])], here: here, mine: mine);
        expect(fresh.toAdd, hasLength(1));
      }
    });

    test('a playlist deleted there is not added from there either (an own device), and the tombstone is learned', () {
      final p = plan([], [_remote(u1, 'Road', 50, ['a'])], there: side(tombstones: [tomb('playlist', u1, 60)]), mine: true);
      expect(p.toAdd, isEmpty);
      expect(p.collections.learned.single.key, u1);
    });

    test('a tombstone for something not here is learned once: a second plan has nothing to do', () {
      final t = tomb('favoriteAlbum', 'a|b', 80);
      expect(plan([], [], there: side(tombstones: [t]), mine: true).collections.learned, [t]);
      expect(plan([], [], here: side(tombstones: [t]), there: side(tombstones: [t]), mine: true).isEmpty, isTrue);
      expect(plan([], [], here: side(tombstones: [tomb('favoriteAlbum', 'a|b', 90)]), there: side(tombstones: [t]), mine: true).isEmpty, isTrue,
          reason: 'a more recent deletion is already known here');
    });

    test('favourites: added when missing, when newer than the deletion; deleted only by a newer tombstone', () {
      const album = FavoriteCollectionData(kind: 'album', key: 'a|b', addedAt: 100);
      expect(plan([], [], there: side(favorites: [album])).collections.favoriteAdds, [album]);
      expect(plan([], [], here: side(favorites: [album]), there: side(favorites: [album])).isEmpty, isTrue);
      final gone = side(tombstones: [tomb('favoriteAlbum', 'a|b', 100)]);
      expect(plan([], [], here: gone, there: side(favorites: [album])).collections.favoriteAdds, isEmpty, reason: 'tie: the deletion stays');
      const newer = FavoriteCollectionData(kind: 'album', key: 'a|b', addedAt: 101);
      expect(plan([], [], here: gone, there: side(favorites: [newer])).collections.favoriteAdds, [newer]);
      const undated = FavoriteCollectionData(kind: 'album', key: 'a|b');
      expect(plan([], [], here: gone, there: side(favorites: [undated])).collections.favoriteAdds, isEmpty, reason: 'no date = older than all');
      expect(plan([], [], there: side(favorites: [undated])).collections.favoriteAdds, [undated]);

      final del = plan([], [], here: side(favorites: [album]), there: side(tombstones: [tomb('favoriteAlbum', 'a|b', 101)]), mine: true);
      expect(del.collections.deletes.single.key, 'a|b');
      expect(plan([], [], here: side(favorites: [album]), there: side(tombstones: [tomb('favoriteAlbum', 'a|b', 100)]), mine: true).isEmpty, isTrue);
    });

    test('an album that travels is never a local folder path (unknown|…)', () {
      const local = FavoriteCollectionData(kind: 'album', key: 'unknown|/home/me/Music', addedAt: 5);
      expect(plan([], [], there: side(favorites: [local])).collections.favoriteAdds, isEmpty);
      final p = plan([], [],
          here: side(favorites: [local]),
          there: side(tombstones: [tomb('favoriteAlbum', 'unknown|/home/me/Music', 50)]),
          mine: true);
      expect(p.collections.deletes, isEmpty, reason: 'a favourite that never travels is not deleted by a tombstone either');
    });

    test('streamed tracks: saved and heart are two facets, each with its own date and tombstone', () {
      const entry = StreamEntry(key: vid, title: 'T', saved: true, addedAt: 100, favorite: true, favoritedAt: 200);
      final fresh = plan([], [], there: side(streams: [entry]));
      expect(fresh.collections.saves, [entry]);
      expect(fresh.collections.hearts, [entry]);
      final here = side(tombstones: [tomb('savedStream', vid, 150)]);
      final p = plan([], [], here: here, there: side(streams: [entry]));
      expect(p.collections.saves, isEmpty, reason: 'unsaved here after it was saved there');
      expect(p.collections.hearts, [entry], reason: 'the heart is newer than that deletion and independent');
      final onlySaved = plan([], [], here: side(streams: [const StreamEntry(key: vid, title: 'T', saved: true, addedAt: 1)]), there: side(streams: [entry]));
      expect(onlySaved.collections.saves, isEmpty);
      expect(onlySaved.collections.hearts, [entry]);
    });

    test('a streamed track that is already a file here is not added', () {
      const entry = StreamEntry(key: vid, title: 'T', saved: true, addedAt: 100, favorite: true);
      expect(plan([], [], there: side(streams: [entry]), hasFile: (k) => k == vid).isEmpty, isTrue);
    });

    test('tombstones delete the heart or the saved flag only when newer than their own date', () {
      const entry = StreamEntry(key: vid, title: 'T', saved: true, addedAt: 100, favorite: true, favoritedAt: 300);
      final there = side(tombstones: [tomb('savedStream', vid, 200), tomb('favoriteStream', vid, 200)]);
      final p = plan([], [], here: side(streams: [entry]), there: there, mine: true);
      expect(p.collections.deletes.map((t) => t.kind), ['savedStream'], reason: 'the heart is newer than the deletion');
    });

    test('a date from the future in a playlist cannot win: it counts as the oldest', () {
      final r = RemotePlaylist.fromJson({'uuid': u1, 'name': 'x', 'createdAt': 1, 'updatedAt': 9999999999999999, 'items': []});
      expect(r.updatedAt, 0);
    });
  });
}
