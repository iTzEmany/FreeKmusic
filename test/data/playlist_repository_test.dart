import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/track_kinds.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PlaylistRepository repo;
  late List<int> ids;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = PlaylistRepository(db);
    await TrackRepository(db).upsertBatch([
      for (final n in ['a', 'b', 'c'])
        TracksCompanion.insert(
            path: '/$n',
            title: n,
            albumKey: 'k',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 1,
            artist: const Value('x')),
    ]);
    ids = (await db.select(db.tracks).get()).map((t) => t.id).toList();
  });
  tearDown(() => db.close());

  test('duplicates are ignored', () async {
    final p = await repo.create('Mix');
    expect(await repo.addTracks(p, [ids[0], ids[1]]), 2);
    expect(await repo.addTracks(p, [ids[1], ids[2]]), 1);
    final tracks = await repo.watchTracks(p).first;
    expect(tracks.map((t) => t.id), ids);
    final all = await repo.watchAll().first;
    expect(all.single.trackCount, 3);
  });

  test('plays and duration sum each track once per playlist', () async {
    await db.customStatement('UPDATE tracks SET play_count = 2, duration_ms = 1000');
    final p = await repo.create('Mix');
    final q = await repo.create('Other');
    await repo.addTracks(p, [ids[0], ids[1]]);
    await repo.addTracks(p, [ids[1]]);
    await repo.addTracks(q, ids);
    final all = {for (final x in await repo.watchAll().first) x.playlist.name: x};
    expect((all['Mix']!.playCount, all['Mix']!.durationMs), (4, 2000));
    expect((all['Other']!.playCount, all['Other']!.durationMs), (6, 3000));
  });

  test('the technical playlist of «Scarica album» is not listed', () async {
    final shown = await repo.create('Mix');
    final hidden = await repo.create('Album — Band');
    for (final (playlist, kind) in [(shown, 'youtube'), (hidden, 'ytm-album')]) {
      await db.into(db.playlistImports).insert(PlaylistImportsCompanion.insert(
          playlistId: playlist, sourceName: 'x', createdAt: 1, sourceKind: Value(kind)));
    }
    expect((await repo.watchAll().first).map((p) => p.playlist.name), ['Mix']);
  });

  test('reorder is stable and removal renumbers', () async {
    final p = await repo.create('Mix');
    await repo.addTracks(p, ids);
    await repo.reorder(p, 0, 2);
    expect((await repo.watchTracks(p).first).map((t) => t.id),
        [ids[1], ids[2], ids[0]]);
    await repo.removeTrack(p, ids[2]);
    final rows = await db.select(db.playlistTracks).get();
    expect(rows.map((r) => r.position).toList()..sort(), [0, 1]);
    expect((await repo.watchTracks(p).first).map((t) => t.id), [ids[1], ids[0]]);
  });

  test('deleting a track or playlist cascades', () async {
    await db.customStatement('PRAGMA foreign_keys = ON');
    final p = await repo.create('Mix');
    await repo.addTracks(p, ids);
    await (db.delete(db.tracks)..where((t) => t.id.equals(ids[0]))).go();
    expect((await db.select(db.playlistTracks).get()).length, 2);
    await repo.delete(p);
    expect(await db.select(db.playlistTracks).get(), isEmpty);
  });

  test('favorite toggle', () async {
    final tracks = TrackRepository(db);
    await tracks.setFavorite(ids[0], true);
    expect((await tracks.getById(ids[0]))!.isFavorite, true);
    await tracks.setFavorite(ids[0], false);
    expect((await tracks.getById(ids[0]))!.isFavorite, false);
    expect((await tracks.watchTracks(favoritesOnly: true).first), isEmpty);
  });

  test('custom cover wins over the first track cover', () async {
    final p = await repo.create('Mix');
    await repo.addTracks(p, [ids[0]]);
    await TrackRepository(db).setCoverForAlbum('k', true, 'auto-key');
    var s = (await repo.watchAll().first).single;
    expect(s.coverKey, 'auto-key');
    await repo.setCover(p, 'mine');
    s = (await repo.watchAll().first).single;
    expect(s.coverKey, 'mine');
    await repo.setCover(p, null);
    expect((await repo.watchAll().first).single.coverKey, 'auto-key');
  });

  group('removing several tracks, and the undo', () {
    Future<List<int>> order(int p) async =>
        [for (final t in await repo.watchTracks(p).first) t.id];

    test('removeTracks takes them out in one go and renumbers', () async {
      final p = await repo.create('Mix');
      await repo.addTracks(p, ids);
      final before = await repo.removeTracks(p, [ids[0], ids[2]]);
      expect(before, ids);
      expect(await order(p), [ids[1]]);
    });

    test('restoreTracks puts them back at their places', () async {
      final p = await repo.create('Mix');
      await repo.addTracks(p, ids);
      final before = await repo.removeTracks(p, [ids[0], ids[2]]);
      await repo.restoreTracks(p, before, [ids[0], ids[2]]);
      expect(await order(p), ids);
    });

    test('a track added after the removal stays, at the end', () async {
      final p = await repo.create('Mix');
      await repo.addTracks(p, [ids[0], ids[1]]);
      final before = await repo.removeTracks(p, [ids[0]]);
      await repo.addTracks(p, [ids[2]]);
      await repo.restoreTracks(p, before, [ids[0]]);
      expect(await order(p), [ids[0], ids[1], ids[2]]);
    });

    test('restoring twice, or a track that came back by hand, does not duplicate', () async {
      final p = await repo.create('Mix');
      await repo.addTracks(p, ids);
      final before = await repo.removeTracks(p, [ids[1]]);
      await repo.addTracks(p, [ids[1]]);
      await repo.restoreTracks(p, before, [ids[1]]);
      await repo.restoreTracks(p, before, [ids[1]]);
      expect(await order(p), ids);
    });

    test('other playlists are not touched', () async {
      final a = await repo.create('A');
      final b = await repo.create('B');
      await repo.addTracks(a, ids);
      await repo.addTracks(b, ids);
      await repo.removeTracks(a, ids);
      expect(await order(a), isEmpty);
      expect(await order(b), ids);
    });
  });

  group('streamed tracks (D-524)', () {
    Future<int> shadow(String id, {int secs = 100}) => TrackRepository(db).ensureStreamRow(
        YtResult(id: id, title: 'S$id', channel: 'Ch', duration: Duration(seconds: secs), artists: const ['Art']));

    test('ensureStreamRow makes one kind-2 row per key', () async {
      final a = await shadow('v1');
      expect(await shadow('v1'), a);
      final row = (await TrackRepository(db).getById(a))!;
      expect((row.kind, row.path, row.title, row.artist, row.durationMs),
          (kStreamKind, 'stream:youtube:v1', 'Sv1', 'Art', 100000));
    });

    test('addStreamTracks takes library and shadow rows in order, addTracks still refuses shadows', () async {
      final p = await repo.create('Mix');
      final s1 = await shadow('v1'), s2 = await shadow('v2');
      expect(await repo.addTracks(p, [s1]), 0);
      expect(await repo.addStreamTracks(p, [ids[0], s1, s2, s1]), 3);
      expect((await repo.watchTracks(p).first).map((t) => t.id), [ids[0], s1, s2]);
    });

    test('addStreamTracks refuses an episode', () async {
      final p = await repo.create('Mix');
      await db.customStatement("UPDATE tracks SET kind = 1 WHERE id = ${ids[0]}");
      expect(await repo.addStreamTracks(p, [ids[0]]), 0);
    });

    test('watchAll counts and sums the shadow rows', () async {
      final p = await repo.create('Mix');
      await db.customStatement('UPDATE tracks SET duration_ms = 1000');
      await repo.addStreamTracks(p, [ids[0], await shadow('v1', secs: 2)]);
      final s = (await repo.watchAll().first).single;
      expect((s.trackCount, s.durationMs), (2, 3000));
    });

    test('addAtTop puts the track first and renumbers, in one go', () async {
      final p = await repo.create('Mix');
      await repo.addTracks(p, ids);
      final s1 = await shadow('v1');
      expect(await repo.addAtTop(p, s1), isTrue);
      expect((await repo.watchTracks(p).first).map((t) => t.id), [s1, ...ids]);
      final positions = [for (final r in await db.select(db.playlistTracks).get()) r.position]..sort();
      expect(positions, [0, 1, 2, 3]);
    });

    test('addAtTop leaves a track already there where it is', () async {
      final p = await repo.create('Mix');
      await repo.addTracks(p, ids);
      expect(await repo.addAtTop(p, ids[2]), isFalse);
      expect((await repo.watchTracks(p).first).map((t) => t.id), ids);
    });

    test('addAtTop refuses an episode', () async {
      final p = await repo.create('Mix');
      await db.customStatement('UPDATE tracks SET kind = 1 WHERE id = ${ids[0]}');
      expect(await repo.addAtTop(p, ids[0]), isFalse);
      expect(await repo.watchTracks(p).first, isEmpty);
    });

    test('nameTaken folds non-ASCII letters and ignores the hidden «Scarica album» playlist', () async {
      await repo.create('Éclair');
      expect(await repo.nameTaken(' éCLAIR '), isTrue);
      final h = await repo.create('Hidden');
      await db.into(db.playlistImports).insert(PlaylistImportsCompanion.insert(
          playlistId: h, sourceKind: const Value('ytm-album'), sourceName: 'x', createdAt: 1));
      expect(await repo.nameTaken('Hidden'), isFalse);
    });

    test('nameTaken ignores case and spaces', () async {
      await repo.create('Mix');
      expect(await repo.nameTaken(' mix '), isTrue);
      expect(await repo.nameTaken('Mix (2)'), isFalse);
    });
  });
}

