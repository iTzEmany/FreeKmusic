import 'package:codecore/services/backup/user_data.dart';
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
}
