import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

TracksCompanion row(
  String path,
  String title, {
  int mtime = 1,
  int? folderId,
}) => TracksCompanion.insert(
  path: path,
  title: title,
  albumKey: 'k',
  format: 'mp3',
  sizeBytes: 10,
  mtimeMs: mtime,
  addedAt: 5,
  folderId: Value(folderId),
);

void main() {
  late AppDatabase db;
  late TrackRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TrackRepository(db);
  });
  tearDown(() => db.close());

  test('upsert twice keeps one row and preserves favorite', () async {
    await repo.upsertBatch([row('/a.mp3', 'A')]);
    final id = (await db.select(db.tracks).getSingle()).id;
    await (db.update(db.tracks)..where((t) => t.id.equals(id))).write(
      const TracksCompanion(isFavorite: Value(true)),
    );
    await repo.upsertBatch([row('/a.mp3', 'A2', mtime: 9)]);
    final t = await db.select(db.tracks).getSingle();
    expect(t.title, 'A2');
    expect(t.mtimeMs, 9);
    expect(t.isFavorite, true);
    expect(t.addedAt, 5);
  });

  test('userEdited keeps title', () async {
    await repo.upsertBatch([row('/a.mp3', 'A')]);
    await db
        .update(db.tracks)
        .write(
          const TracksCompanion(userEdited: Value(true), title: Value('Mine')),
        );
    await repo.upsertBatch([row('/a.mp3', 'FromFile')]);
    expect((await db.select(db.tracks).getSingle()).title, 'Mine');
  });

  test('search treats % literally', () async {
    await repo.upsertBatch([
      row('/a.mp3', '100% Pure'),
      row('/b.mp3', 'Other'),
    ]);
    final r = await repo.watchTracks(query: '%').first;
    expect(r.map((t) => t.title), ['100% Pure']);
    final u = await repo.watchTracks(query: '_').first;
    expect(u, isEmpty);
  });

  test('missing excluded, getByIds keeps order', () async {
    await repo.upsertBatch([row('/a.mp3', 'A'), row('/b.mp3', 'B')]);
    await repo.markMissing({'/b.mp3'}, true);
    expect((await repo.watchTracks().first).length, 1);
    final all = await db.select(db.tracks).get();
    final ids = all.map((t) => t.id).toList().reversed.toList();
    expect((await repo.getByIds(ids)).map((t) => t.id), ids);
  });

  test('setFavoriteMany flips a whole batch and nothing else', () async {
    await repo.upsertBatch([row('/a', 'a'), row('/b', 'b'), row('/c', 'c')]);
    final ids = (await db.select(db.tracks).get()).map((t) => t.id).toList();
    await repo.setFavoriteMany([ids[0], ids[1]], true);
    expect((await repo.getByIds(ids)).map((t) => t.isFavorite), [
      true,
      true,
      false,
    ]);
    await repo.setFavoriteMany([ids[1]], false);
    expect((await repo.getByIds(ids)).map((t) => t.isFavorite), [
      true,
      false,
      false,
    ]);
    await repo.setFavoriteMany(const [], true); // nothing to do
  });

  test(
    'deleteMissingTracks removes only the tracks whose file is gone',
    () async {
      await repo.upsertBatch([row('/a', 'a'), row('/b', 'b'), row('/c', 'c')]);
      final ids = (await db.select(db.tracks).get()).map((t) => t.id).toList();
      await repo.markMissing({'/a', '/b'}, true);
      expect(
        await repo.deleteMissingTracks(ids),
        2,
        reason: 'c is still there',
      );
      expect((await db.select(db.tracks).get()).map((t) => t.title), ['c']);
      expect(await repo.deleteMissingTracks(const []), 0);
    },
  );

  test(
    'watchResumable: tracks and episodes left in the middle, never kind 2, newest first, limited',
    () async {
      await repo.upsertBatch([
        for (var i = 0; i < 6; i++) row('/$i.mp3', 'T$i'),
      ]);
      final ids = [for (final t in await db.select(db.tracks).get()) t.id];
      Future<void> set(
        int id,
        int? resume,
        int? played, {
        bool missing = false,
        int kind = 0,
      }) => (db.update(db.tracks)..where((t) => t.id.equals(id))).write(
        TracksCompanion(
          resumePositionMs: Value(resume),
          lastPlayedAt: Value(played),
          missing: Value(missing),
          kind: Value(kind),
        ),
      );
      await set(ids[0], 1000, 10);
      await set(ids[1], 1000, 30);
      await set(ids[2], null, 50); // finished: no bookmark
      await set(ids[3], 1000, 40, missing: true);
      await set(ids[4], 1000, 20, kind: 1); // an episode, followed or not
      await set(ids[5], 1000, 60, kind: 2); // a stream shadow row
      final r = await repo.watchResumable().first;
      expect(r.map((t) => t.title), ['T1', 'T4', 'T0']);
      expect((await repo.watchResumable(limit: 1).first).single.title, 'T1');
    },
  );

  test('watchResumable: an episode of a podcast that is not followed shows up', () async {
    final podcastId = await db.into(db.podcasts).insert(PodcastsCompanion.insert(
        feedUrl: 'https://x/feed', title: 'Show', addedAt: 1, followed: const Value(false)));
    final trackId = await db.into(db.tracks).insert(TracksCompanion.insert(
        path: '/p/e.mp3', title: 'Ep', albumKey: 'podcast|$podcastId', format: 'mp3', sizeBytes: 1,
        mtimeMs: 1, addedAt: 1, kind: const Value(1), resumePositionMs: const Value(5000),
        lastPlayedAt: const Value(9)));
    await db.into(db.podcastEpisodes).insert(PodcastEpisodesCompanion.insert(
        podcastId: podcastId, guid: 'e', title: 'Ep', audioUrl: 'https://x/e.mp3', trackId: Value(trackId)));
    expect((await repo.watchResumable().first).single.title, 'Ep');
  });

  test('setLyrics byUser marks the text as the user\'s; otherwise no mark', () async {
    await repo.upsertBatch([row('/a.mp3', 'A')]);
    final id = (await db.select(db.tracks).getSingle()).id;
    await repo.setLyrics(id, plain: 'x');
    expect(await db.select(db.trackEnrich).get(), isEmpty);
    await db.into(db.trackEnrich).insert(
        TrackEnrichCompanion.insert(trackId: Value(id), creditsNoneAt: const Value(7)));
    await repo.setLyrics(id, plain: 'y', byUser: true);
    expect((await db.select(db.trackEnrich).getSingle()).creditsNoneAt, 7);
    expect((await db.select(db.trackEnrich).getSingle()).lyricsByUser, true);
    expect((await db.select(db.tracks).getSingle()).lyricsPlain, 'y');
    await repo.setLyrics(id, plain: 'z');
    expect((await db.select(db.trackEnrich).getSingle()).lyricsByUser, true);
  });

  test('a rescan with a new mtime and another cover keeps a track pick', () async {
    await repo.upsertBatch([row('/a.mp3', 'A')]);
    final id = (await repo.byPath('/a.mp3'))!.id;
    await repo.setManualCover(id, 'mine');
    await repo.upsertBatch([
      row('/a.mp3', 'A', mtime: 9).copyWith(coverKey: const Value('auto2'), hasCover: const Value(true)),
    ]);
    final t = (await repo.byPath('/a.mp3'))!;
    expect([t.coverKey, t.coverSource, t.mtimeMs], ['mine', 2, 9]);
  });

  test('a row that enters an album with a hand-picked cover takes its key and source', () async {
    await repo.upsertBatch([row('/a.mp3', 'A'), row('/b.mp3', 'B')]);
    await repo.setManualAlbumCover('k', 'pick');
    final entering = row('/b.mp3', 'B', mtime: 9)
        .copyWith(coverKey: const Value('pick'), hasCover: const Value(true), coverSource: const Value(1));
    await repo.upsertBatch([entering, row('/c.mp3', 'C').copyWith(coverKey: const Value('pick'), coverSource: const Value(1))]);
    for (final p in ['/b.mp3', '/c.mp3']) {
      final t = (await repo.byPath(p))!;
      expect([t.coverKey, t.coverSource], ['pick', 1], reason: p);
    }
  });
}
