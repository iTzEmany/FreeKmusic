import 'package:codecore/core/clock.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/favorite_collections_repository.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/playlist_sync_repository.dart';
import 'package:codecore/data/repositories/sync_tombstone_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/backup/user_data.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/share/collection_sync.dart';
import 'package:codecore/services/stream/stream_key.dart';
import 'package:codecore/services/share/playlist_sync.dart';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' show Value, Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A device: its own DB, its music folder at [root] and the files in [names].
class _Device {
  _Device(this.root, List<String> names) : db = AppDatabase(NativeDatabase.memory()) {
    playlists = PlaylistRepository(db);
    sync = PlaylistSyncRepository(db);
    seed = () async {
      final folder = await db.into(db.folders).insert(FoldersCompanion.insert(path: root, addedAt: 1));
      await TrackRepository(db).upsertBatch([
        for (final n in names)
          TracksCompanion.insert(
              path: '$root/$n.mp3', title: n, albumKey: 'k', format: 'mp3',
              sizeBytes: 1, mtimeMs: 1, addedAt: 1,
              artist: const Value('Art'), durationMs: const Value(180000), folderId: Value(folder)),
      ]);
    };
  }

  final String root;
  final AppDatabase db;
  late final PlaylistRepository playlists;
  late final PlaylistSyncRepository sync;
  late final Future<void> Function() seed;

  Future<int> id(String name) async => (await TrackRepository(db).idForPath('$root/$name.mp3'))!;

  Future<List<String>> titlesOf(String playlistName) async {
    final rows = await db.customSelect(
        'SELECT t.title FROM playlists p JOIN playlist_tracks x ON x.playlist_id = p.id '
        'JOIN tracks t ON t.id = x.track_id WHERE p.name = ? ORDER BY x.position',
        variables: [Variable.withString(playlistName)]).get();
    return [for (final r in rows) r.read<String>('title')];
  }

  Future<void> setStamp(String name, int at) => db.customUpdate(
      'UPDATE playlists SET updated_at = ? WHERE name = ?',
      variables: [Variable.withInt(at), Variable.withString(name)], updates: {db.playlists});

  /// Applies [plan] with its collections, as the confirmation of the whole sync does.
  Future<void> applyAll(SyncPlan plan, {bool Function(String)? hasFile}) =>
      sync.apply(plan, applyCollections: true, hasFile: hasFile);

  /// What a sync from [other] does to this device. Favourites and saved tracks travel between «mine» devices only
  /// (D-709), so the plan is for one; [mine] true also brings its deletions (a device that is not «mine» is served
  /// no tombstones), null (the default) is a «mine» device that has deleted nothing yet, false is one that is not.
  Future<SyncPlan> planFrom(_Device other, {bool? mine, bool Function(String)? hasFile}) async {
    final resolver = await sync.resolver();
    final there = SyncSide(
        favorites: await other.sync.favorites(),
        streams: await other.sync.streams(),
        tombstones: mine == true ? await other.sync.tombstones() : const []);
    return planSync(await sync.local(), await other.sync.export(), resolver.resolve,
        localSide: await sync.side(), remoteSide: there, mine: mine ?? true, hasFile: hasFile);
  }
}

void main() {
  // Two devices = two databases, each with its own executor.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late _Device phone, pc;

  setUp(() async {
    phone = _Device('/storage/music', ['a', 'b', 'c']);
    pc = _Device(r'/home/me/Music', ['a', 'b']); // the PC has no «c» and another root
    await phone.seed();
    await pc.seed();
    final list = await phone.playlists.create('Road');
    await phone.playlists.addTracks(list, [await phone.id('a'), await phone.id('b'), await phone.id('c')]);
    await phone.setStamp('Road', 1000);
  });
  tearDown(() async {
    await phone.db.close();
    await pc.db.close();
  });

  test('export carries uuid, stamp and portable tracks in playlist order', () async {
    final out = await phone.sync.export();
    expect(out, hasLength(1));
    expect(out.single.name, 'Road');
    expect(out.single.updatedAt, 1000);
    expect(out.single.items.map((t) => t.title), ['a', 'b', 'c']);
    expect(out.single.items.map((t) => t.relPath), ['a.mp3', 'b.mp3', 'c.mp3']);
  });

  test('a new playlist arrives with the tracks the PC has; the rest is missing', () async {
    final plan = await pc.planFrom(phone);
    expect(plan.toAdd, hasLength(1));
    expect(plan.missing.map((t) => t.title), ['c']);

    await SyncTombstoneRepository(pc.db).record('playlist', plan.toAdd.single.remote.uuid, at: 500);
    await pc.sync.apply(plan);
    expect(await SyncTombstoneRepository(pc.db).all(), isEmpty, reason: 'an added playlist is back: its tombstone goes');
    expect(await pc.titlesOf('Road'), ['a', 'b']);
    final mine = (await pc.sync.local()).single;
    final theirs = (await phone.sync.local()).single;
    expect(mine.uuid, theirs.uuid, reason: 'the same playlist on both sides');
    expect(mine.updatedAt, 1000, reason: 'the stamp of the other device');

    // Syncing again has nothing to write, and still knows what is missing.
    final again = await pc.planFrom(phone);
    expect(again.isEmpty, isTrue);
    expect(again.sameCount, 1);
    expect(again.missing.map((t) => t.title), ['c']);
  });

  test('renamed and reordered on the phone: the PC takes it, then both are equal', () async {
    await pc.sync.apply(await pc.planFrom(phone));
    final list = (await phone.sync.local()).single.id;
    await phone.playlists.rename(list, 'Road trip');
    await phone.playlists.reorder(list, 2, 0); // c, a, b
    await phone.setStamp('Road trip', 2000);

    final plan = await pc.planFrom(phone);
    final e = plan.toReplace.single;
    expect(e.renamed, isTrue);
    expect(e.missing.map((t) => t.title), ['c']);

    await pc.sync.apply(plan);
    expect(await pc.titlesOf('Road trip'), ['a', 'b']);
    expect((await pc.sync.local()).single.updatedAt, 2000);
    expect((await pc.planFrom(phone)).isEmpty, isTrue);
    expect(await pc.db.select(pc.db.playlists).get(), hasLength(1), reason: 'replaced, not duplicated');
  });

  test('changed more recently on the PC: the phone keeps its own and the PC is untouched', () async {
    await pc.sync.apply(await pc.planFrom(phone));
    final list = (await pc.sync.local()).single.id;
    await pc.playlists.removeTrack(list, await pc.id('a'));
    await pc.setStamp('Road', 5000);

    final plan = await pc.planFrom(phone);
    expect(plan.keptCount, 1);
    await pc.sync.apply(plan);
    expect(await pc.titlesOf('Road'), ['b']);

    // From the phone's side the PC's version is the newer one.
    final back = await phone.planFrom(pc);
    expect(back.toReplace, hasLength(1));
  });

  test('a failing write rolls the whole sync back', () async {
    final good = RemotePlaylist(uuid: 'u-good', name: 'Good', createdAt: 1, updatedAt: 1);
    final bad = RemotePlaylist(uuid: 'u-bad', name: 'Bad', createdAt: 1, updatedAt: 1);
    final a = await pc.id('a');
    final plan = SyncPlan([
      SyncEntry(action: SyncAction.add, remote: good, trackIds: [a]),
      SyncEntry(action: SyncAction.add, remote: bad, trackIds: [a, a]), // same track twice
    ]);
    await expectLater(pc.sync.apply(plan), throwsA(anything));
    expect(await pc.db.select(pc.db.playlists).get(), isEmpty, reason: 'not even the first one stays');
  });

  test('deleted here and still there: it stays deleted until the other side changes it again', () async {
    await pc.sync.apply(await pc.planFrom(phone));
    await pc.playlists.delete((await pc.sync.local()).single.id);
    expect(await pc.sync.local(), isEmpty);

    for (final mine in [false, true]) {
      final plan = await pc.planFrom(phone, mine: mine);
      expect(plan.toAdd, isEmpty, reason: 'the stamp of the phone (1000) is older than the deletion, mine=$mine');
      await pc.sync.apply(plan);
      expect(await pc.sync.local(), isEmpty);
    }
    await phone.setStamp('Road', nowMs() + 60000); // edited there after the deletion
    final back = await pc.planFrom(phone);
    expect(back.toAdd, hasLength(1));
    await pc.sync.apply(back);
    expect(await pc.titlesOf('Road'), ['a', 'b']);
    expect(await SyncTombstoneRepository(pc.db).all(), isEmpty, reason: 'back: the tombstone goes');
  });

  test('a playlist only the PC has stays after syncing from the phone', () async {
    await pc.playlists.create('Only PC');
    await pc.sync.apply(await pc.planFrom(phone));
    expect((await pc.sync.local()).map((p) => p.name), unorderedEquals(['Road', 'Only PC']));
  });

  test('the same stamp with another order here: nothing is written on either side', () async {
    await pc.sync.apply(await pc.planFrom(phone));
    final list = (await pc.sync.local()).single.id;
    await pc.playlists.reorder(list, 1, 0); // b, a
    await pc.setStamp('Road', 1000);

    final plan = await pc.planFrom(phone);
    expect(plan.sameCount, 1);
    expect(plan.isEmpty, isTrue);
    await pc.sync.apply(plan);
    expect(await pc.titlesOf('Road'), ['b', 'a']);
    expect((await phone.planFrom(pc)).isEmpty, isTrue);
  });

  test('applying a sync never changes the library tracks (kind 0): same rows, same favourites', () async {
    final before = await pc.db.select(pc.db.tracks).get();
    final a = before.firstWhere((t) => t.title == 'a');
    await pc.db.customUpdate('UPDATE tracks SET is_favorite = 1 WHERE id = ?',
        variables: [Variable.withInt(a.id)], updates: {pc.db.tracks});
    await pc.sync.apply(await pc.planFrom(phone));
    final after = await pc.db.select(pc.db.tracks).get();
    expect(after.map((t) => (t.id, t.path, t.kind, t.isFavorite)),
        before.map((t) => (t.id, t.path, t.kind, t.title == 'a')));
  });

  group('streamed tracks in a playlist (D-524)', () {
    late int shadow;
    late List<String> log;
    late DebugPrintCallback oldPrint;

    setUp(() async {
      log = [];
      oldPrint = debugPrint;
      debugPrint = (m, {wrapWidth}) => log.add(m ?? '');
      shadow = await TrackRepository(phone.db).ensureStreamRow(const YtResult(id: 'v1', title: 'Streamed', channel: 'Ch', duration: null));
      await phone.playlists.addStreamTracks((await phone.sync.local()).single.id, [shadow]);
      await phone.setStamp('Road', 1000);
    });
    tearDown(() => debugPrint = oldPrint);

    test('export and local view skip them, with a log', () async {
      expect((await phone.sync.export()).single.items.map((t) => t.title), ['a', 'b', 'c']);
      expect((await phone.sync.local()).single.trackIds, isNot(contains(shadow)));
      expect(log.where((l) => l.contains('streamed tracks in playlists not synced')), isNotEmpty);
    });

    test('a replacement from the other device keeps them, after the synced tracks', () async {
      await pc.sync.apply(await pc.planFrom(phone));
      final list = (await pc.sync.local()).single.id;
      final pcShadow = await TrackRepository(pc.db).ensureStreamRow(const YtResult(id: 'v9', title: 'PC stream', channel: 'Ch', duration: null));
      await pc.playlists.addStreamTracks(list, [pcShadow]);
      await pc.playlists.reorder(list, 1, 0); // b, a, shadow
      await pc.setStamp('Road', 1000);
      await phone.setStamp('Road', 2000); // the phone's a, b, c is now the newer one

      final plan = await pc.planFrom(phone);
      expect(plan.toReplace, hasLength(1));
      await pc.sync.apply(plan);
      expect(await pc.titlesOf('Road'), ['a', 'b', 'PC stream']);
    });
  });

  group('deletions, favourites and streamed tracks between two devices (D-668)', () {
    const keyA = 'youtube:aaaaaaaaaaa', keyB = 'youtube:bbbbbbbbbbb';
    var clock = 0;
    int tick() => clock += 100;
    YtResult yt(String id, String title) => YtResult(id: id, title: title, channel: 'Ch', duration: null);

    setUp(() {
      clock = 5000000;
      nowMsOverride = () => clock;
    });
    tearDown(() => nowMsOverride = null);

    /// Every library row (kind 0), as a sync must leave it.
    Future<List<String>> libraryRows(_Device d) async => [
          for (final r in await d.db.customSelect('SELECT id, path, is_favorite FROM tracks WHERE kind = 0 ORDER BY id').get())
            '${r.read<int>('id')}|${r.read<String>('path')}|${r.read<int>('is_favorite')}',
        ];
    Future<int?> deletedAt(_Device d, String kind, String key) => SyncTombstoneRepository(d.db).deletedAt(kind, key);
    Future<void> deleteRoad(_Device d) async => d.playlists.delete((await d.sync.local()).single.id);

    test('an own device\'s deletion removes the playlist row here, keeps its date, and touches no library row', () async {
      await pc.applyAll(await pc.planFrom(phone));
      final before = await libraryRows(pc);
      final uuid = (await phone.sync.local()).single.uuid;
      tick();
      await deleteRoad(phone);
      final at = await deletedAt(phone, 'playlist', uuid);

      final plan = await pc.planFrom(phone, mine: true);
      expect(plan.collections.deletes.single.key, uuid);
      await pc.applyAll(plan);
      expect(await pc.sync.local(), isEmpty);
      expect(await deletedAt(pc, 'playlist', uuid), at, reason: 'the tombstone keeps the date of the deletion, so it can go on to a third device');
      expect(await libraryRows(pc), before);
      expect((await pc.planFrom(phone, mine: true)).isEmpty, isTrue, reason: 'the second sync has nothing to do');
    });

    test('a device that is not «mine» deletes nothing and its tombstones are not stored', () async {
      await pc.applyAll(await pc.planFrom(phone));
      final uuid = (await phone.sync.local()).single.uuid;
      await deleteRoad(phone);
      final plan = await pc.planFrom(phone);
      expect(plan.collections.deletes, isEmpty);
      await pc.applyAll(plan);
      expect(await pc.titlesOf('Road'), ['a', 'b']);
      expect(await deletedAt(pc, 'playlist', uuid), isNull);
    });

    test(
      'a playlist changed here after the deletion there survives it',
      () async {
        await pc.applyAll(await pc.planFrom(phone));
        await deleteRoad(phone);
        await pc.setStamp('Road', tick());
        final plan = await pc.planFrom(phone, mine: true);
        expect(plan.collections.deletes, isEmpty);
        await pc.applyAll(plan);
        expect(await pc.titlesOf('Road'), ['a', 'b']);
      },
    );

    test('a plan older than its confirmation re-checks the dates: a playlist edited meanwhile is not deleted', () async {
      await pc.applyAll(await pc.planFrom(phone));
      await deleteRoad(phone);
      final plan = await pc.planFrom(phone, mine: true);
      await pc.setStamp(
        'Road',
        tick(),
      ); // the person edits it before confirming
      await pc.applyAll(plan);
      expect(await pc.titlesOf('Road'), ['a', 'b']);
    });

    test(
      'a hidden «Scarica album» playlist is never deleted by a tombstone',
      () async {
        final id = await pc.playlists.create('Album');
        await pc.db.customStatement(
          "INSERT INTO playlist_imports (playlist_id, source_kind, source_name, created_at, status) "
          "VALUES ($id, 'ytm-album', 'x', 1, 0)",
        );
        final uuid = (await pc.db.select(pc.db.playlists).get())
            .firstWhere((p) => p.id == id)
            .uuid!;
        final plan = await pc.planFrom(phone, mine: true);
        expect(plan.collections.learned, isEmpty);
        await pc.applyAll(
          SyncPlan(
            const [],
            CollectionPlan(
              deletes: [
                TombstoneData(
                  kind: 'playlist',
                  key: uuid,
                  deletedAt: clock + 1000,
                ),
              ],
            ),
          ),
        );
        expect(
          await pc.db
              .select(pc.db.playlists)
              .get()
              .then((l) => l.any((p) => p.id == id)),
          isTrue,
        );
      },
    );

    test('favourites converge: albums and playlists (after the playlists), then a deletion between own devices', () async {
      final uuid = (await phone.sync.local()).single.uuid;
      final fav = FavoriteCollectionsRepository(phone.db);
      await fav.add('album', 'art|alb', addedAt: tick());
      await fav.add('playlist', uuid, addedAt: tick());
      await fav.add('album', 'unknown|/local/folder', addedAt: tick());

      await pc.applyAll(await pc.planFrom(phone));
      final here = FavoriteCollectionsRepository(pc.db);
      expect(await here.isFavoriteNow('album', 'art|alb'), isTrue);
      expect(await here.isFavoriteNow('playlist', uuid), isTrue, reason: 'the playlist arrived in the same sync');
      expect(await here.isFavoriteNow('album', 'unknown|/local/folder'), isFalse, reason: 'a local folder path does not travel');
      expect((await pc.planFrom(phone)).isEmpty, isTrue);

      tick();
      await fav.remove('album', 'art|alb');
      await pc.applyAll(
        await pc.planFrom(phone),
      ); // not mine: nothing is removed
      expect(await here.isFavoriteNow('album', 'art|alb'), isTrue);
      expect(await deletedAt(pc, 'favoriteAlbum', 'art|alb'), isNull);
      await pc.applyAll(await pc.planFrom(phone, mine: true));
      expect(await here.isFavoriteNow('album', 'art|alb'), isFalse);
      expect(await here.isFavoriteNow('playlist', uuid), isTrue);
    });

    test('a favourite playlist is not applied when its playlist is not here (deleted here after)', () async {
      final uuid = (await phone.sync.local()).single.uuid;
      await FavoriteCollectionsRepository(phone.db).add('playlist', uuid, addedAt: tick());
      await SyncTombstoneRepository(pc.db).record('playlist', uuid, at: tick());
      await pc.applyAll(await pc.planFrom(phone));
      expect(
        await FavoriteCollectionsRepository(pc.db)
            .isFavoriteNow('playlist', uuid),
        isFalse,
      );
      expect(
        (await pc.planFrom(phone)).isEmpty,
        isTrue,
        reason: 'favourite playlist of a playlist deleted here: plan empty after apply',
      );
    });

    test('a heart taken away leaves favorited_at in the row, but the stream entry carries no heart nor date', () async {
      final tracks = TrackRepository(phone.db);
      await tracks.saveStream(yt('aaaaaaaaaaa', 'Song A'));
      final id = (await tracks.streamRow(keyA))!.id;
      await tracks.setFavoriteMany([id], true);
      await tracks.setFavoriteMany([id], false);
      final row = (await tracks.streamRow(keyA))!;
      expect(row.isFavorite, isFalse);
      expect(row.favoritedAt, isNotNull);
      final e = (await phone.sync.streams()).single;
      expect((e.favorite, e.favoritedAt, e.saved), (false, null, true));
    });

    test('saved and hearted streamed tracks converge with their dates; a deletion travels only to an own device', () async {
      final tracks = TrackRepository(phone.db);
      await tracks.saveStream(yt('aaaaaaaaaaa', 'Song A'));
      final savedAt = (await tracks.streamRow(keyA))!.addedAt;
      final idB = await tracks.ensureStreamRow(yt('bbbbbbbbbbb', 'Song B'));
      tick();
      await tracks.setFavoriteMany([idB], true);
      final heartAt = (await tracks.streamRow(keyB))!.favoritedAt;
      final before = await libraryRows(pc);

      await pc.applyAll(await pc.planFrom(phone));
      final mine = TrackRepository(pc.db);
      final a = (await mine.streamRow(keyA))!, b = (await mine.streamRow(keyB))!;
      expect((a.saved, a.addedAt, a.title), (true, savedAt, 'Song A'));
      expect((b.saved, b.isFavorite, b.favoritedAt), (false, true, heartAt));
      expect((await pc.planFrom(phone)).isEmpty, isTrue);
      expect(await libraryRows(pc), before);

      tick();
      await tracks.setSaved(keyA, false);
      tick();
      await tracks.setFavoriteMany([idB], false);
      await pc.applyAll(await pc.planFrom(phone));
      expect(
        (await mine.streamRow(keyA))!.saved,
        isTrue,
        reason: 'not «mine»: nothing is removed',
      );
      expect(await deletedAt(pc, 'savedStream', keyA), isNull);

      await pc.applyAll(await pc.planFrom(phone, mine: true));
      expect((await mine.streamRow(keyA))!.saved, isFalse);
      expect((await mine.streamRow(keyB))!.isFavorite, isFalse);
      expect(await deletedAt(pc, 'savedStream', keyA), await deletedAt(phone, 'savedStream', keyA));
      expect(await libraryRows(pc), before, reason: 'no library row (kind 0) touched');
      expect((await pc.planFrom(phone, mine: true)).isEmpty, isTrue);
    });

    test('what was deleted here is not brought back by any device, unless it is newer than the deletion', () async {
      final theirs = TrackRepository(phone.db);
      await theirs.saveStream(yt('aaaaaaaaaaa', 'Song A'));
      await pc.applyAll(await pc.planFrom(phone));
      tick();
      await TrackRepository(pc.db).setSaved(keyA, false); // the person removes it here

      for (final mine in [false, true]) {
        final plan = await pc.planFrom(phone, mine: mine);
        expect(plan.collections.saves, isEmpty, reason: 'mine=$mine');
        await pc.applyAll(plan);
        expect((await TrackRepository(pc.db).streamRow(keyA))!.saved, isFalse);
      }
      // Saved again there, later: it is a new decision and comes back, and the tombstone goes.
      tick();
      await theirs.setSaved(keyA, false);
      tick();
      await theirs.saveStream(yt('aaaaaaaaaaa', 'Song A'));
      await pc.applyAll(await pc.planFrom(phone));
      expect((await TrackRepository(pc.db).streamRow(keyA))!.saved, isTrue);
      expect(await deletedAt(pc, 'savedStream', keyA), isNull);
    });

    test('apply is the single door for streamed rows: a track already downloaded gets no row, a deletion made after the plan wins', () async {
      final theirs = TrackRepository(phone.db);
      await theirs.saveStream(yt('aaaaaaaaaaa', 'Song A'));
      await theirs.saveStream(yt('bbbbbbbbbbb', 'Song B'));
      final plan = await pc.planFrom(phone); // planned without knowing about a file
      tick();
      await SyncTombstoneRepository(pc.db).record(
        'savedStream',
        keyB,
      ); // deleted here after the plan, before the confirmation
      await pc.applyAll(plan, hasFile: (k) => k == keyA);
      expect(
        await TrackRepository(pc.db).streamRow(keyA),
        isNull,
        reason: 'the file is already here',
      );
      expect(
        (await TrackRepository(pc.db).streamRow(keyB))?.saved ?? false,
        isFalse,
      );
    });

    test('a tombstone never touches a library file row, even one whose key equals a streamed one', () async {
      final before = await libraryRows(pc);
      final plan = SyncPlan(
        const [],
        CollectionPlan(
          deletes: [
            TombstoneData(
              kind: 'savedStream',
              key: keyA,
              deletedAt: clock + 100,
            ),
            TombstoneData(
              kind: 'favoriteStream',
              key: keyA,
              deletedAt: clock + 100,
            ),
            TombstoneData(
              kind: 'playlist',
              key: '00000000-0000-4000-8000-0000000000ff',
              deletedAt: clock + 100,
            ),
          ],
        ),
      );
      await pc.applyAll(plan);
      expect(await libraryRows(pc), before);
      expect(streamPathOf(keyA), startsWith('stream:'));
    });

    test('apply writes the playlists only, unless the caller confirms the collections too', () async {
      final uuid = (await phone.sync.local()).single.uuid;
      await FavoriteCollectionsRepository(phone.db)
          .add('album', 'art|alb', addedAt: tick());
      await TrackRepository(phone.db).saveStream(yt('aaaaaaaaaaa', 'Song A'));
      await pc.sync.apply(await pc.planFrom(phone));
      expect(await pc.titlesOf('Road'), ['a', 'b']);
      expect(await pc.sync.favorites(), isEmpty);
      expect(await TrackRepository(pc.db).streamRow(keyA), isNull);

      await pc.applyAll(await pc.planFrom(phone));
      expect((await pc.sync.favorites()).single.key, 'art|alb');
      expect((await TrackRepository(pc.db).streamRow(keyA))!.saved, isTrue);

      await deleteRoad(phone);
      await pc.sync.apply(await pc.planFrom(phone, mine: true));
      expect(await pc.titlesOf('Road'), [
        'a',
        'b',
      ], reason: 'the deletion was not confirmed');
      expect(await deletedAt(pc, 'playlist', uuid), isNull);
    });

    test('a favourite keeps the date it has on the other device', () async {
      await FavoriteCollectionsRepository(phone.db)
          .add('album', 'art|alb', addedAt: 4321);
      await pc.applyAll(await pc.planFrom(phone));
      expect((await pc.sync.favorites()).single.addedAt, 4321);
    });

    test('a streamed key that is an episode here is not planned: a later plan is empty', () async {
      final theirs = TrackRepository(phone.db);
      await theirs.saveStream(yt('aaaaaaaaaaa', 'Song A'));
      await theirs.setFavoriteMany([
        await theirs.ensureStreamRow(yt('bbbbbbbbbbb', 'Song B')),
      ], true);
      for (final k in [keyA, keyB]) {
        await pc.db
            .into(pc.db.tracks)
            .insert(
              TracksCompanion.insert(
                path: 'stream:$k',
                title: 'Episode',
                albumKey: 'k',
                format: 'mp3',
                sizeBytes: 1,
                mtimeMs: 1,
                addedAt: 1,
                kind: const Value(1),
              ),
            );
      }
      final episodes = await pc.sync.episodeStreamKeys();
      expect(episodes, {keyA, keyB});
      final plan = await pc.planFrom(phone, hasFile: episodes.contains);
      expect(plan.collections.isEmpty, isTrue);
      await pc.applyAll(plan);
      expect(
        (await pc.planFrom(phone, hasFile: episodes.contains)).isEmpty,
        isTrue,
      );
    });

    test('a newer deletion known here after the plan stops every kind of addition, a tie lets it in', () async {
      final theirs = TrackRepository(phone.db);
      final uuid = (await phone.sync.local()).single.uuid;
      await theirs.saveStream(yt('aaaaaaaaaaa', 'Song A'));
      await theirs.setFavoriteMany([
        await theirs.ensureStreamRow(yt('bbbbbbbbbbb', 'Song B')),
      ], true);
      await FavoriteCollectionsRepository(phone.db)
          .add('album', 'art|alb', addedAt: tick());
      await FavoriteCollectionsRepository(phone.db)
          .add('playlist', uuid, addedAt: tick());
      final plan = await pc.planFrom(phone);
      final later = tick() + 1000;
      final tomb = SyncTombstoneRepository(pc.db);
      await tomb.record('playlist', uuid, at: later);
      await tomb.record('favoriteAlbum', 'art|alb', at: later);
      await tomb.record('favoritePlaylist', uuid, at: later);
      await tomb.record('savedStream', keyA, at: later);
      await tomb.record('favoriteStream', keyB, at: later);
      await pc.applyAll(plan);
      expect(await pc.sync.local(), isEmpty);
      expect(await pc.sync.favorites(), isEmpty);
      expect(await TrackRepository(pc.db).streamRow(keyA), isNull);
      expect(await TrackRepository(pc.db).streamRow(keyB), isNull);

      // On a tie with the deletion the arriving item stays, and its tombstone goes.
      final at = (await phone.sync.local()).single.updatedAt;
      await tomb.clear('playlist', uuid);
      await tomb.record('playlist', uuid, at: at);
      await pc.applyAll(
        SyncPlan([
          SyncEntry(
            action: SyncAction.add,
            remote: (await phone.sync.export()).single,
          ),
        ]),
      );
      expect((await pc.sync.local()).single.uuid, uuid);
      expect(await deletedAt(pc, 'playlist', uuid), isNull);
      await tomb.clear('favoriteAlbum', 'art|alb');
      await tomb.clear('favoritePlaylist', uuid);
      await tomb.clear('savedStream', keyA);
      await tomb.clear('favoriteStream', keyB);
      await tomb.record('favoriteAlbum', 'art|alb', at: 500);
      await tomb.record('favoriteStream', keyB, at: 500);
      await tomb.record('savedStream', keyA, at: 500);
      final tie = CollectionPlan(
        favoriteAdds: const [
          FavoriteCollectionData(kind: 'album', key: 'art|alb', addedAt: 500),
        ],
        saves: const [
          StreamEntry(key: keyA, title: 'Song A', saved: true, addedAt: 500),
        ],
        hearts: const [
          StreamEntry(
            key: keyB,
            title: 'Song B',
            favorite: true,
            favoritedAt: 500,
          ),
        ],
      );
      await pc.applyAll(SyncPlan(const [], tie));
      expect((await pc.sync.favorites()).single.key, 'art|alb');
      expect((await TrackRepository(pc.db).streamRow(keyA))!.saved, isTrue);
      expect(
        (await TrackRepository(pc.db).streamRow(keyB))!.isFavorite,
        isTrue,
      );
      expect(
        await pc.sync.tombstones(),
        isEmpty,
        reason: 'every returning item took its tombstone away',
      );
    });

    test('a heart keeps the newer of the two dates when the plan is old; an older one takes the date of the plan', () async {
      final theirs = TrackRepository(phone.db);
      await theirs.setFavoriteMany([
        await theirs.ensureStreamRow(yt('bbbbbbbbbbb', 'Song B')),
      ], true);
      final plan = await pc.planFrom(
        phone,
      ); // pc has no heart yet: it will get one
      tick();
      final mine = TrackRepository(pc.db);
      await mine.setFavoriteMany([
        await mine.ensureStreamRow(yt('bbbbbbbbbbb', 'Song B')),
      ], true); // hearted here meanwhile, more recently
      final newer = (await mine.streamRow(keyB))!.favoritedAt!;
      await pc.applyAll(plan);
      expect(
        (await mine.streamRow(keyB))!.favoritedAt,
        newer,
        reason: 'a local heart with a later date keeps it',
      );
      await pc.db.customUpdate(
        'UPDATE tracks SET favorited_at = 1 WHERE path = ?',
        variables: [Variable.withString(streamPathOf(keyB))],
        updates: {pc.db.tracks},
      );
      await pc.applyAll(SyncPlan(const [], plan.collections));
      expect(
        (await mine.streamRow(keyB))!.favoritedAt,
        (await theirs.streamRow(keyB))!.favoritedAt,
      );
    });

    test(
      'a heart that arrives takes the file check and the tombstone with it',
      () async {
        final theirs = TrackRepository(phone.db);
        await theirs.setFavoriteMany([
          await theirs.ensureStreamRow(yt('bbbbbbbbbbb', 'Song B')),
        ], true);
        final plan = await pc.planFrom(phone);
        await pc.applyAll(plan, hasFile: (k) => k == keyB);
        expect(
          await TrackRepository(pc.db).streamRow(keyB),
          isNull,
          reason: 'it is a file here',
        );
        await SyncTombstoneRepository(pc.db)
            .record('favoriteStream', keyB, at: 1);
        await pc.applyAll(SyncPlan(const [], plan.collections));
        expect(
          (await TrackRepository(pc.db).streamRow(keyB))!.isFavorite,
          isTrue,
        );
        expect(await deletedAt(pc, 'favoriteStream', keyB), isNull);
      },
    );

    test('a deletion that finds nothing to remove leaves no tombstone; one for something not here is learned', () async {
      final untouched = CollectionPlan(
        deletes: [
          TombstoneData(
            kind: 'favoriteAlbum',
            key: 'x|y',
            deletedAt: clock + 100,
          ),
          TombstoneData(
            kind: 'playlist',
            key: '00000000-0000-4000-8000-0000000000aa',
            deletedAt: clock + 100,
          ),
          TombstoneData(kind: 'savedStream', key: keyA, deletedAt: clock + 100),
          TombstoneData(
            kind: 'favoriteStream',
            key: keyA,
            deletedAt: clock + 100,
          ),
        ],
      );
      await pc.applyAll(SyncPlan(const [], untouched));
      expect(await pc.sync.tombstones(), isEmpty);
      await pc.applyAll(
        SyncPlan(const [], CollectionPlan(learned: untouched.deletes)),
      );
      expect(await pc.sync.tombstones(), hasLength(4));
    });

    test('a deletion removes only what is older than it, only its own kind and flag', () async {
      final uuid = (await phone.sync.local()).single.uuid;
      await pc.applyAll(await pc.planFrom(phone));
      final fav = FavoriteCollectionsRepository(pc.db);
      await fav.add('album', 'art|alb', addedAt: 1000);
      await fav.add('playlist', uuid, addedAt: 1000);
      final tracks = TrackRepository(pc.db);
      final id = await tracks.saveStream(yt('aaaaaaaaaaa', 'Song A'));
      await tracks.setFavoriteMany([id!], true);
      await pc.db.customUpdate(
        'UPDATE tracks SET added_at = 1000, favorited_at = 1000 WHERE id = ?',
        variables: [Variable.withInt(id)],
        updates: {pc.db.tracks},
      );
      await pc.db.customUpdate(
        'UPDATE playlists SET updated_at = 1000',
        updates: {pc.db.playlists},
      );
      Future<void> delete(String kind, String key, int at) => pc.applyAll(
        SyncPlan(
          const [],
          CollectionPlan(
            deletes: [TombstoneData(kind: kind, key: key, deletedAt: at)],
          ),
        ),
      );
      Future<List<String>> state() async {
        final row = (await tracks.streamRow(keyA))!;
        return [
          for (final f in await pc.sync.favorites()) '${f.kind}:${f.key}',
          '${(await pc.sync.local()).length}pl',
          if (row.saved) 'saved',
          if (row.isFavorite) 'heart${row.favoritedAt}',
        ];
      }

      final all = await state();
      expect(
        all,
        containsAll([
          'album:art|alb',
          'playlist:$uuid',
          '1pl',
          'saved',
          'heart1000',
        ]),
      );
      await pc.db.customUpdate(
        'DELETE FROM sync_tombstones',
        updates: {pc.db.syncTombstones},
      );
      for (final at in [1000, 999]) {
        for (final (kind, key) in [
          ('favoriteAlbum', 'art|alb'),
          ('favoritePlaylist', uuid),
          ('playlist', uuid),
          ('savedStream', keyA),
          ('favoriteStream', keyA),
        ]) {
          await delete(kind, key, at);
        }
        expect(
          await state(),
          all,
          reason: 'a deletion dated $at is not newer than 1000',
        );
        expect(await pc.sync.tombstones(), isEmpty);
      }
      await delete('favoritePlaylist', uuid, 2000);
      expect(
        await state(),
        (all.toList()..remove('playlist:$uuid')),
        reason: 'only the favourite playlist goes',
      );
      await delete('savedStream', keyA, 2000);
      expect(
        await state(),
        containsAll(['heart1000']),
        reason: 'the heart stays when the saved flag goes',
      );
      expect(await state(), isNot(contains('saved')));
      await delete('favoriteStream', keyA, 2000);
      expect((await tracks.streamRow(keyA))!.favoritedAt, isNull);
      expect((await tracks.streamRow(keyA))!.isFavorite, isFalse);
      await delete('favoriteAlbum', 'art|alb', 2000);
      expect(await pc.sync.favorites(), isEmpty);
      await fav.add('playlist', uuid, addedAt: 1000);
      await delete('playlist', uuid, 2000);
      expect(await pc.sync.local(), isEmpty);
      expect(
        await pc.sync.favorites(),
        isEmpty,
        reason: 'the favourite of a deleted playlist goes with it',
      );
      expect(await deletedAt(pc, 'playlist', uuid), 2000);
    });

    test('a heart without a date is older than any deletion; an episode row keeps its flags', () async {
      final tracks = TrackRepository(pc.db);
      final id = await tracks.ensureStreamRow(yt('aaaaaaaaaaa', 'Song A'));
      await pc.db.customUpdate(
        'UPDATE tracks SET is_favorite = 1, favorited_at = NULL WHERE id = ?',
        variables: [Variable.withInt(id)],
        updates: {pc.db.tracks},
      );
      await pc.db
          .into(pc.db.tracks)
          .insert(
            TracksCompanion.insert(
              path: 'stream:$keyB',
              title: 'Episode',
              albumKey: 'k',
              format: 'mp3',
              sizeBytes: 1,
              mtimeMs: 1,
              addedAt: 1,
              kind: const Value(1),
              isFavorite: const Value(true),
              saved: const Value(true),
            ),
          );
      final gone = CollectionPlan(
        deletes: [
          TombstoneData(kind: 'favoriteStream', key: keyA, deletedAt: 50),
          TombstoneData(kind: 'favoriteStream', key: keyB, deletedAt: 50),
          TombstoneData(kind: 'savedStream', key: keyB, deletedAt: 50),
        ],
      );
      await pc.applyAll(SyncPlan(const [], gone));
      expect((await tracks.getById(id))!.isFavorite, isFalse);
      final episode = (await pc.db.select(pc.db.tracks).get()).firstWhere(
        (t) => t.path == 'stream:$keyB',
      );
      expect((episode.isFavorite, episode.saved), (true, true));
    });

    test('what the other device is told: no local folder favourite, the dates of the facets that are on, only known tombstone kinds', () async {
      final fav = FavoriteCollectionsRepository(phone.db);
      await fav.add('album', 'unknown|/local/folder', addedAt: 1);
      await fav.add('album', 'art|alb', addedAt: 2);
      expect((await phone.sync.favorites()).map((f) => f.key), ['art|alb']);

      final tracks = TrackRepository(phone.db);
      await tracks.saveStream(yt('aaaaaaaaaaa', 'Song A'));
      await tracks.setFavoriteMany([
        await tracks.ensureStreamRow(yt('bbbbbbbbbbb', 'Song B')),
      ], true);
      final out = {for (final s in await phone.sync.streams()) s.key: s};
      expect((out[keyA]!.saved, out[keyA]!.favorite), (true, false));
      expect(out[keyA]!.favoritedAt, isNull);
      expect(out[keyA]!.addedAt, isNotNull);
      expect((out[keyB]!.saved, out[keyB]!.favorite), (false, true));
      expect(out[keyB]!.addedAt, isNull);
      expect(out[keyB]!.favoritedAt, isNotNull);

      await phone.db.customInsert(
        "INSERT INTO sync_tombstones (kind, key, deleted_at) VALUES ('mystery', 'k', 5)",
      );
      await SyncTombstoneRepository(phone.db)
          .record('favoriteAlbum', 'art|alb', at: 7);
      expect((await phone.sync.tombstones()).map((t) => t.kind), [
        'favoriteAlbum',
      ]);
    });

    test(
      'a tombstone learned from one own device goes on to a third',
      () async {
        final tablet = _Device('/tablet/music', ['a', 'b', 'c']);
        addTearDown(tablet.db.close);
        await tablet.seed();
        final uuid = (await phone.sync.local()).single.uuid;
        await tablet.applyAll(await tablet.planFrom(phone));
        expect((await tablet.sync.local()).single.uuid, uuid);
        tick();
        await deleteRoad(phone);

        await pc.applyAll(
          await pc.planFrom(phone, mine: true),
        ); // the PC never had it: it only learns the deletion
        expect(await deletedAt(pc, 'playlist', uuid), isNotNull);
        final plan = await tablet.planFrom(pc, mine: true);
        expect(plan.collections.deletes.single.key, uuid);
        await tablet.applyAll(plan);
        expect(await tablet.sync.local(), isEmpty);
      },
    );

    test('the remote unsave leaves the heart here; the removal of a favourite playlist leaves the playlist', () async {
      final uuid = (await phone.sync.local()).single.uuid;
      final theirs = TrackRepository(phone.db);
      await theirs.saveStream(yt('aaaaaaaaaaa', 'Song A'));
      await FavoriteCollectionsRepository(phone.db)
          .add('playlist', uuid, addedAt: tick());
      await pc.applyAll(await pc.planFrom(phone));
      final mine = TrackRepository(pc.db);
      await mine.setFavoriteMany([(await mine.streamRow(keyA))!.id], true);
      tick();
      await theirs.setSaved(keyA, false);
      await FavoriteCollectionsRepository(phone.db).remove('playlist', uuid);

      final plan = await pc.planFrom(phone, mine: true);
      expect(
        plan.collections.deletes.map((t) => t.kind),
        unorderedEquals(['savedStream', 'favoritePlaylist']),
      );
      await pc.applyAll(plan);
      final row = (await mine.streamRow(keyA))!;
      expect((row.saved, row.isFavorite), (false, true));
      expect(
        await FavoriteCollectionsRepository(pc.db)
            .isFavoriteNow('playlist', uuid),
        isFalse,
      );
      expect(await pc.titlesOf('Road'), ['a', 'b']);
    });

    test('two own devices that each added and deleted things end up equal after one sync each way', () async {
      final fa = FavoriteCollectionsRepository(phone.db),
          fb = FavoriteCollectionsRepository(pc.db);
      final ta = TrackRepository(phone.db), tb = TrackRepository(pc.db);
      await pc.applyAll(await pc.planFrom(phone));
      final uuid = (await phone.sync.local()).single.uuid;
      await fa.add('album', 'art|one', addedAt: tick());
      await fb.add('album', 'art|two', addedAt: tick());
      await ta.saveStream(yt('aaaaaaaaaaa', 'Song A'));
      await tb.saveStream(yt('bbbbbbbbbbb', 'Song B'));
      await fa.add('playlist', uuid, addedAt: tick());
      await tb.setFavoriteMany([
        await tb.ensureStreamRow(yt('ccccccccccc', 'Song C')),
      ], true);
      await pc.playlists.create('Only PC');
      tick();
      await deleteRoad(phone);

      Future<String> state(_Device d) async {
        final st = await d.sync.streams();
        return ([
          for (final l in await d.sync.local()) 'pl:${l.name}',
          for (final f in await d.sync.favorites()) 'fav:${f.kind}/${f.key}',
          for (final s in st) '${s.key}:${s.saved}/${s.favorite}',
        ]..sort()).join(',');
      }

      for (var i = 0; i < 2; i++) {
        await pc.applyAll(await pc.planFrom(phone, mine: true));
        await phone.applyAll(await phone.planFrom(pc, mine: true));
      }
      expect(await state(pc), await state(phone));
      expect((await pc.planFrom(phone, mine: true)).isEmpty, isTrue);
      expect((await phone.planFrom(pc, mine: true)).isEmpty, isTrue);
      expect(await state(pc), isNot(contains('pl:Road')));
      expect(
        await state(pc),
        allOf(
          contains('pl:Only PC'),
          contains('art|one'),
          contains('art|two'),
          contains(keyA),
          contains(keyB),
        ),
      );
    });
  });
}
