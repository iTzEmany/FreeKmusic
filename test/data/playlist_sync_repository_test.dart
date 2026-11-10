import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/playlist_sync_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/online/youtube_service.dart';
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

  /// What a sync from [other] does to this device.
  Future<SyncPlan> planFrom(_Device other) async {
    final resolver = await sync.resolver();
    return planSync(await sync.local(), await other.sync.export(), resolver.resolve);
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

    await pc.sync.apply(plan);
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
}
