import 'package:codecore/core/clock.dart';
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
            {SyncSide? here, SyncSide? there, bool mine = true, bool Function(String)? hasFile}) =>
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
          there: side(tombstones: [tomb('playlist', u1, 500), tomb('favoriteAlbum', 'a|b', 500)]), mine: false);
      expect(p.collections.deletes, isEmpty);
      expect(p.collections.learned, isEmpty);
      expect(p.isEmpty, isTrue);
    });

    test('a playlist deleted here is not added back by any device unless it changed after the deletion', () {
      final here = side(tombstones: [tomb('playlist', u1, 100)]);
      for (final mine in [false, true]) {
        final old = plan(
          [],
          [
            _remote(u1, 'Road', 99, ['a']),
          ],
          here: here,
          mine: mine,
        );
        expect(
          old.entries.single.action,
          SyncAction.keep,
          reason: 'mine=$mine',
        );
        expect(old.toAdd, isEmpty);
        expect(
          old.missing,
          isEmpty,
          reason: 'no tracks are asked for a playlist that is not added',
        );
        for (final at in [100, 101]) {
          final fresh = plan(
            [],
            [
              _remote(u1, 'Road', at, ['a']),
            ],
            here: here,
            mine: mine,
          );
          expect(
            fresh.toAdd,
            hasLength(1),
            reason: 'mine=$mine at=$at: on a tie the item stays',
          );
        }
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
      expect(
        plan(
          [],
          [],
          here: gone,
          there: side(favorites: [album]),
        ).collections.favoriteAdds,
        [album],
        reason: 'tie: the item stays',
      );
      const older = FavoriteCollectionData(
        kind: 'album',
        key: 'a|b',
        addedAt: 99,
      );
      expect(
        plan(
          [],
          [],
          here: gone,
          there: side(favorites: [older]),
        ).collections.favoriteAdds,
        isEmpty,
      );
      const newer = FavoriteCollectionData(
        kind: 'album',
        key: 'a|b',
        addedAt: 101,
      );
      expect(
        plan(
          [],
          [],
          here: gone,
          there: side(favorites: [newer]),
        ).collections.favoriteAdds,
        [newer],
      );
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

    test('a tie keeps the item in every kind: it arrives over an equal tombstone and an equal tombstone deletes nothing', () {
      final here = side(
        tombstones: [
          tomb('favoriteAlbum', 'a|b', 100),
          tomb('savedStream', vid, 100),
          tomb('favoriteStream', vid, 100),
        ],
      );
      const entry = StreamEntry(
        key: vid,
        title: 'T',
        saved: true,
        addedAt: 100,
        favorite: true,
        favoritedAt: 100,
      );
      final p = plan(
        [],
        [],
        here: here,
        there: side(
          streams: [entry],
          favorites: [
            const FavoriteCollectionData(
              kind: 'album',
              key: 'a|b',
              addedAt: 100,
            ),
          ],
        ),
      );
      expect(
        (
          p.collections.saves.length,
          p.collections.hearts.length,
          p.collections.favoriteAdds.length,
        ),
        (1, 1, 1),
      );
      final mineSide = side(
        tombstones: [
          tomb('favoriteAlbum', 'a|b', 100),
          tomb('savedStream', vid, 100),
          tomb('favoriteStream', vid, 100),
        ],
      );
      final q = plan(
        [],
        [],
        here: side(
          streams: [entry],
          favorites: [
            const FavoriteCollectionData(
              kind: 'album',
              key: 'a|b',
              addedAt: 100,
            ),
          ],
        ),
        there: mineSide,
        mine: true,
      );
      expect(q.collections.deletes, isEmpty);
      expect(q.isEmpty, isTrue);
    });

    test('a favourite of a playlist that will not be here is not planned (a later plan is empty); one that will be is', () {
      const fav = FavoriteCollectionData(
        kind: 'playlist',
        key: u1,
        addedAt: 100,
      );
      expect(
        plan([], [], there: side(favorites: [fav])).collections.favoriteAdds,
        isEmpty,
        reason: 'no such playlist here or coming',
      );
      expect(plan([], [], there: side(favorites: [fav])).isEmpty, isTrue);
      expect(
        plan([], [
          _remote(u1, 'Road', 10, ['a']),
        ], there: side(favorites: [fav])).collections.favoriteAdds,
        [fav],
        reason: 'it arrives in this sync',
      );
      expect(
        plan(
          [
            _local(u1, 'Road', 10, [1]),
          ],
          [],
          there: side(favorites: [fav]),
        ).collections.favoriteAdds,
        [fav],
      );
      final deletedHere = side(tombstones: [tomb('playlist', u1, 200)]);
      expect(
        plan(
          [],
          [
            _remote(u1, 'Road', 10, ['a']),
          ],
          here: deletedHere,
          there: side(favorites: [fav]),
        ).collections.favoriteAdds,
        isEmpty,
        reason: 'the playlist is deleted here more recently: it does not come',
      );
      final goes = plan(
        [
          _local(u1, 'Road', 10, [1]),
        ],
        [],
        there: side(favorites: [fav], tombstones: [tomb('playlist', u1, 200)]),
        mine: true,
      );
      expect(goes.collections.deletes.single.key, u1);
      expect(
        goes.collections.favoriteAdds,
        isEmpty,
        reason: 'the playlist is deleted in this very plan',
      );
    });

    test('a playlist deleted by a tombstone is not written nor asked for, even when the other device still has it', () {
      final p = plan(
        [
          _local(u1, 'Road', 100, [1]),
        ],
        [
          _remote(u1, 'Road', 100, ['a', 'x']),
        ],
        there: side(tombstones: [tomb('playlist', u1, 150)]),
        mine: true,
      );
      expect(p.collections.deletes.single.key, u1);
      expect(p.entries, isEmpty);
      expect(p.toWrite, isEmpty);
      expect(p.missing, isEmpty);
    });

    test('a device that is not «mine» is neither obeyed nor believed: its tombstones neither block nor delete', () {
      final tombs = side(
        tombstones: [
          tomb('playlist', u1, 60),
          tomb('favoriteAlbum', 'a|b', 60),
          tomb('savedStream', vid, 60),
        ],
      );
      final p = plan(
        [],
        [
          _remote(u1, 'Road', 50, ['a']),
        ],
        there: SyncSide(
          favorites: const [
            FavoriteCollectionData(kind: 'album', key: 'a|b', addedAt: 50),
          ],
          streams: const [
            StreamEntry(key: vid, title: 'T', saved: true, addedAt: 50),
          ],
          tombstones: tombs.tombstones,
        ),
        mine: false,
      );
      expect(
        p.toAdd,
        hasLength(1),
        reason: 'the tombstone of a stranger does not block the playlist',
      );
      expect(p.collections.favoriteAdds, isEmpty, reason: 'favourites and saved tracks are for «mine» devices only (D-709)');
      expect(p.collections.saves, isEmpty);
      expect(p.collections.learned, isEmpty);
    });

    test('a tombstone between the dates of the saved facet and the heart touches only the older one', () {
      const entry = StreamEntry(
        key: vid,
        title: 'T',
        saved: true,
        addedAt: 300,
        favorite: true,
        favoritedAt: 100,
      );
      final p = plan(
        [],
        [],
        here: side(streams: [entry]),
        there: side(
          tombstones: [
            tomb('savedStream', vid, 200),
            tomb('favoriteStream', vid, 200),
          ],
        ),
        mine: true,
      );
      expect(p.collections.deletes.map((t) => t.kind), [
        'favoriteStream',
      ], reason: 'the saved date 300 is newer than the deletion');
    });

    test('a streamed entry only saved gives no heart; the heart is judged by its own date, not by the saved one', () {
      const onlySaved = StreamEntry(
        key: vid,
        title: 'T',
        saved: true,
        addedAt: 100,
      );
      expect(
        plan([], [], there: side(streams: [onlySaved])).collections.hearts,
        isEmpty,
      );
      const entry = StreamEntry(
        key: vid,
        title: 'T',
        saved: true,
        addedAt: 500,
        favorite: true,
        favoritedAt: 50,
      );
      final p = plan(
        [],
        [],
        here: side(tombstones: [tomb('favoriteStream', vid, 60)]),
        there: side(streams: [entry]),
      );
      expect(
        p.collections.hearts,
        isEmpty,
        reason: 'the heart (50) is older than its deletion (60), whatever the saved date',
      );
      expect(p.collections.saves, [entry]);
    });

    test('of a repeated tombstone the latest date is kept', () {
      final t = latestTombstones([
        {'kind': 'playlist', 'key': u1, 'deletedAt': 10},
        {'kind': 'playlist', 'key': u1, 'deletedAt': 30},
        {'kind': 'playlist', 'key': u1, 'deletedAt': 20},
      ]);
      expect(t.single.deletedAt, 30);
    });
  });

  group('what comes from another device is parsed strictly', () {
    const u1 = '00000000-0000-4000-8000-000000000001';
    const vid = 'youtube:dQw4w9WgXcQ';
    Map<String, Object?> entry([Map<String, Object?> over = const {}]) => {
      'key': vid,
      'title': 'T',
      'saved': true,
      ...over,
    };

    test('StreamEntry: saved or hearted alone are fine, texts and durations have limits, the album page id is validated', () {
      expect(
        StreamEntry.tryParse(entry({'saved': false, 'favorite': true}))!
            .favorite,
        isTrue,
      );
      expect(StreamEntry.tryParse(entry({'saved': true}))!.saved, isTrue);
      expect(StreamEntry.tryParse(entry({'title': 'x' * 512})), isNotNull);
      expect(StreamEntry.tryParse(entry({'title': 'x' * 513})), isNull);
      expect(
        StreamEntry.tryParse(entry({'artist': 'x' * 512, 'album': 'y' * 512}))!
            .artist,
        hasLength(512),
      );
      final long = StreamEntry.tryParse(
        entry({'artist': 'x' * 513, 'album': 'y' * 513}),
      )!;
      expect((long.artist, long.album), (null, null));
      expect(
        StreamEntry.tryParse(entry({'durationMs': 86399999}))!.durationMs,
        86399999,
      );
      for (final bad in [86400000, -1, 0, double.infinity, 'x']) {
        expect(
          StreamEntry.tryParse(entry({'durationMs': bad}))!.durationMs,
          0,
          reason: '$bad',
        );
      }
      expect(
        StreamEntry.tryParse(entry({'albumBrowseId': 'MPREb_abc-1'}))!
            .albumBrowseId,
        'MPREb_abc-1',
      );
      expect(
        StreamEntry.tryParse(entry({'albumBrowseId': 'a b/../x'}))!
            .albumBrowseId,
        isNull,
      );
      final future = nowMs() + const Duration(hours: 1).inMilliseconds;
      final e = StreamEntry.tryParse(
        entry({'favorite': true, 'addedAt': future, 'favoritedAt': future}),
      )!;
      expect(
        (e.addedAt, e.favoritedAt),
        (null, null),
        reason: 'a date more than 10 minutes ahead is not trusted',
      );
      expect(
        StreamEntry.tryParse(entry({'addedAt': nowMs() + 5 * 60000}))!.addedAt,
        isNotNull,
        reason: 'a few minutes of drift are tolerated',
      );
      expect(StreamEntry.tryParse(entry({'key': 'soundcloud:../x'})), isNull);
    });

    test('TombstoneData: key limits, kinds and keys that fit them, dates, the highest of a repeated one', () {
      Map<String, Object?> t(String kind, Object? key, [Object? at = 5]) => {
        'kind': kind,
        'key': key,
        'deletedAt': at,
      };
      expect(TombstoneData.tryParse(t('favoriteAlbum', 'k' * 512)), isNotNull);
      expect(TombstoneData.tryParse(t('favoriteAlbum', 'k' * 513)), isNull);
      expect(TombstoneData.tryParse(t('favoriteAlbum', '')), isNull);
      expect(TombstoneData.tryParse(t('favoriteAlbum', 'unknown|/x')), isNull);
      expect(TombstoneData.tryParse(t('playlist', 'not-a-uuid')), isNull);
      expect(
        TombstoneData.tryParse(t('favoritePlaylist', 'not-a-uuid')),
        isNull,
      );
      expect(TombstoneData.tryParse(t('playlist', u1)), isNotNull);
      expect(TombstoneData.tryParse(t('savedStream', vid)), isNotNull);
      expect(
        TombstoneData.tryParse(t('playlist', u1, double.infinity)),
        isNull,
      );
      expect(
        TombstoneData.tryParse(
          t('playlist', u1, nowMs() + const Duration(hours: 1).inMilliseconds),
        ),
        isNull,
      );
      final future = nowMs() + const Duration(minutes: 11).inMilliseconds;
      expect(
        TombstoneData.tryParse(t('playlist', u1, future)),
        isNull,
        reason: 'the tolerance is 10 minutes',
      );
      expect(
        TombstoneData.tryParse(
          t(
            'playlist',
            u1,
            nowMs() + const Duration(minutes: 9).inMilliseconds,
          ),
        ),
        isNotNull,
      );
    });

    test('FavoriteCollectionData: kind is kept, the album key is the canonical one (no stream| prefix), empty after it is dropped', () {
      final a = FavoriteCollectionData.tryParse({
        'kind': 'album',
        'key': 'stream|art|alb',
        'addedAt': 5,
      })!;
      expect((a.kind, a.key), ('album', 'art|alb'));
      expect(
        FavoriteCollectionData.tryParse({'kind': 'album', 'key': 'stream|'}),
        isNull,
      );
      expect(
        FavoriteCollectionData.tryParse({
          'kind': 'playlist',
          'key': 'stream|x',
        })!.key,
        'stream|x',
        reason: 'a playlist key is a uuid: left as it is',
      );
      expect(
        FavoriteCollectionData.tryParse({'kind': 'playlist', 'key': u1})!.kind,
        'playlist',
      );
      expect(
        FavoriteCollectionData.tryParse({'kind': 'album', 'key': 'k' * 512}),
        isNotNull,
      );
      expect(
        FavoriteCollectionData.tryParse({'kind': 'album', 'key': ''}),
        isNull,
      );
      expect(
        FavoriteCollectionData.tryParse({'kind': 'nope', 'key': 'k'}),
        isNull,
      );
    });

    test('a canonical key arrives as a favourite or a tombstone only once: stream|x and x are the same', () {
      final t = TombstoneData.tryParse({
        'kind': 'favoriteAlbum',
        'key': 'stream|art|alb',
        'deletedAt': 5,
      })!;
      expect(t.key, 'art|alb');
      expect(
        TombstoneData.tryParse({
          'kind': 'favoriteAlbum',
          'key': 'stream|unknown|/x',
          'deletedAt': 5,
        }),
        isNull,
      );
    });

    Map<String, Object?> playlist([Map<String, Object?> over = const {}]) => {
      'uuid': u1,
      'name': 'Road',
      'createdAt': 1,
      'updatedAt': 5,
      'items': [],
      ...over,
    };

    test('RemotePlaylist.fromJson throws a FormatException for anything malformed, instead of cutting or guessing', () {
      expect(RemotePlaylist.fromJson(playlist()).uuid, u1);
      for (final bad in [
        {'uuid': 'nope'},
        {'uuid': 5},
        {'name': 'x' * 513},
        {'name': 5},
        {'createdAt': double.infinity},
        {'updatedAt': double.nan},
        {'items': 'x'},
        {
          'items': [5],
        },
        {
          'items': [
            {'title': 'x' * 4097},
          ],
        },
        {
          'items': [
            {'title': 'x', 'artist': 'x' * 513},
          ],
        },
        {
          'items': [
            {'title': 'x', 'durationMs': double.infinity},
          ],
        },
      ]) {
        expect(
          () => RemotePlaylist.fromJson(playlist(bad)),
          throwsFormatException,
          reason: '$bad',
        );
      }
      expect(
        RemotePlaylist.fromJson(playlist({'name': 'x' * 512})).name,
        hasLength(512),
      );
      expect(
        RemotePlaylist.fromJson(
          playlist({
            'items': [
              {'title': 'x' * 4096, 'folder': '/d' * 2048, 'relPath': 'r' * 4096, 'artist': 'a' * 512},
            ],
          }),
        ).items,
        hasLength(1),
      );
    });

    test('a playlist of more than kMaxSyncItems tracks is malformed, not cut', () {
      expect(
        () => RemotePlaylist.fromJson(
          playlist({
            'items': [for (var i = 0; i < kMaxSyncItems + 1; i++) {'title': 't'}],
          }),
        ),
        throwsFormatException,
      );
    });
  });
}
