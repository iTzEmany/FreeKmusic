import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/memory_queries.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late MemoryQueries q;

  Future<int> add(
    String title,
    int size, {
    String format = 'mp3',
    int kind = 0,
    bool missing = false,
    bool favorite = false,
    int? folderId,
    String album = 'A',
    int playCount = 0,
    int durationMs = 1000,
  }) => db
      .into(db.tracks)
      .insert(
        TracksCompanion.insert(
          path: '/m/$title.$format',
          title: title,
          albumKey: 'k|$album',
          album: Value(album),
          format: format,
          sizeBytes: size,
          mtimeMs: 1,
          addedAt: 1,
          kind: Value(kind),
          missing: Value(missing),
          isFavorite: Value(favorite),
          folderId: Value(folderId),
          playCount: Value(playCount),
          durationMs: Value(durationMs),
        ),
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    q = MemoryQueries(db);
  });
  tearDown(() => db.close());

  test(
    'totals sum music that exists; episodes and missing files are out',
    () async {
      await add('a', 100, durationMs: 2000);
      await add('b', 50);
      await add('gone', 999, missing: true);
      await add('episode', 777, kind: 1);
      final t = await q.watchTotals().first;
      expect((t.sizeBytes, t.trackCount, t.durationMs), (150, 2, 3000));
      expect(await q.podcastBytes(), 777);
    },
  );

  test('playlists: biggest first, Preferiti included, a shared track counts in both', () async {
    final a = await add('a', 100, favorite: true);
    final b = await add('b', 30);
    final c = await add('c', 500, missing: true);
    final big = await db
        .into(db.playlists)
        .insert(PlaylistsCompanion.insert(name: 'Big', createdAt: 1));
    final small = await db
        .into(db.playlists)
        .insert(PlaylistsCompanion.insert(name: 'Small', createdAt: 1));
    await db
        .into(db.playlists)
        .insert(PlaylistsCompanion.insert(name: 'Empty', createdAt: 1));
    for (final (pl, tr, pos) in [
      (big, a, 0),
      (big, b, 1),
      (big, c, 2),
      (small, a, 0),
    ]) {
      await db
          .into(db.playlistTracks)
          .insert(
            PlaylistTracksCompanion.insert(
              playlistId: pl,
              trackId: tr,
              position: pos,
            ),
          );
    }
    final groups = await q.byPlaylist();
    expect(
      [for (final g in groups) g.isFavorites ? '*' : g.name],
      ['Big', '*', 'Small', 'Empty'],
    );
    final big_ = groups.first;
    expect((big_.totals.sizeBytes, big_.totals.trackCount), (130, 2));
    expect(groups[1].totals.sizeBytes, 100);
    expect(groups[2].totals.sizeBytes, 100);
  });

  test(
    'playlist auto cover is the first track in order that has one',
    () async {
      final a = await add('a', 1);
      final b = await add('b', 1);
      final c = await add('c', 1);
      await (db.update(db.tracks)..where((t) => t.id.isIn([b, c]))).write(
        const TracksCompanion(coverKey: Value('K')),
      );
      await (db.update(db.tracks)..where((t) => t.id.equals(c))).write(
        const TracksCompanion(coverKey: Value('C')),
      );
      final pl = await db
          .into(db.playlists)
          .insert(PlaylistsCompanion.insert(name: 'P', createdAt: 1));
      await db
          .into(db.playlists)
          .insert(PlaylistsCompanion.insert(name: 'None', createdAt: 1));
      for (final (tr, pos) in [(a, 0), (c, 1), (b, 2)]) {
        await db
            .into(db.playlistTracks)
            .insert(
              PlaylistTracksCompanion.insert(
                playlistId: pl,
                trackId: tr,
                position: pos,
              ),
            );
      }
      final byName = {
        for (final g in await q.byPlaylist()) g.name: g.autoCoverKey,
      };
      expect(byName['P'], 'C');
      expect(byName['None'], isNull);
    },
  );

  test(
    'auto cover also shows when every track of the playlist is missing',
    () async {
      final m = await add('m', 1, missing: true);
      await (db.update(db.tracks)..where((t) => t.id.equals(m))).write(
        const TracksCompanion(coverKey: Value('M')),
      );
      final pl = await db
          .into(db.playlists)
          .insert(PlaylistsCompanion.insert(name: 'Gone', createdAt: 1));
      await db
          .into(db.playlistTracks)
          .insert(
            PlaylistTracksCompanion.insert(
              playlistId: pl,
              trackId: m,
              position: 0,
            ),
          );
      final g = (await q.byPlaylist()).firstWhere((g) => g.name == 'Gone');
      expect((g.autoCoverKey, g.totals.trackCount), ('M', 0));
    },
  );

  test('formats group by lower-case extension, biggest first', () async {
    await add('a', 10, format: 'MP3');
    await add('b', 20, format: 'mp3');
    await add('c', 100, format: 'flac');
    final g = await q.byFormat();
    expect([for (final x in g) x.name], ['flac', 'mp3']);
    expect(g.last.totals.sizeBytes, 30);
    expect(g.last.totals.trackCount, 2);
  });

  test(
    'folders: label or last segment, and tracks outside any folder',
    () async {
      final f1 = await db
          .into(db.folders)
          .insert(FoldersCompanion.insert(path: '/storage/Music', addedAt: 1));
      final f2 = await db
          .into(db.folders)
          .insert(
            FoldersCompanion.insert(
              path: '/storage/Dl',
              addedAt: 1,
              label: const Value('Downloads'),
            ),
          );
      await add('a', 10, folderId: f1);
      await add('b', 40, folderId: f2);
      await add('c', 5);
      final g = await q.byFolder();
      expect([for (final x in g) x.name], ['Downloads', 'Music', '']);
      expect(g.last.path, isNull);
      expect(g.first.path, '/storage/Dl');
    },
  );

  test(
    'never played ignores tracks with a play, a play count or a hidden flag',
    () async {
      await add('fresh', 100);
      await add('counted', 200, playCount: 3);
      final heard = await add('heard', 300);
      await db
          .into(db.plays)
          .insert(PlaysCompanion.insert(trackId: heard, playedAt: 5));
      final hidden = await add('hidden', 400);
      await (db.update(db.tracks)..where((t) => t.id.equals(hidden))).write(
        const TracksCompanion(ignored: Value(true)),
      );
      final n = await q.neverPlayed();
      expect((n.sizeBytes, n.trackCount), (100, 1));
      final list = await q.watchNeverPlayed().first;
      expect([for (final t in list) t.title], ['fresh']);
    },
  );

  test('heaviest tracks and albums are limited and ordered by size', () async {
    for (var i = 0; i < 12; i++) {
      await add('t$i', 10 + i, album: 'Album ${i % 3}');
    }
    final tracks = await q.heaviestTracks();
    expect(tracks.length, 10);
    expect(tracks.first.title, 't11');
    final albums = await q.heaviestAlbums(limit: 2);
    expect(albums.length, 2);
    expect(albums.first.album.title, 'Album 2');
    expect(albums.first.sizeBytes, 66);
  });

  test('enrichmentBytes counts the UTF-8 bytes kept, per part', () async {
    final id = await add('a', 100);
    await (db.update(db.tracks)..where((t) => t.id.equals(id))).write(
      const TracksCompanion(
        lyricsPlain: Value('abcd'),
        lyricsSynced: Value('è'), // 2 bytes
        curiosities: Value('xyz'),
      ),
    );
    await add('no-text', 100);
    await db
        .into(db.artistInfos)
        .insert(
          ArtistInfosCompanion.insert(
            artistKey: 'k',
            body: 'bio!',
            sourceUrl: 'u',
            lang: 'it',
            fetchedAt: 1,
          ),
        );
    await db
        .into(db.trackCredits)
        .insert(
          TrackCreditsCompanion.insert(
            trackId: id,
            name: 'Ann',
            nameKey: 'ann',
            role: 'writer',
            source: 'mb',
          ),
        );
    await db
        .into(db.trackEnrich)
        .insert(
          TrackEnrichCompanion.insert(
            trackId: Value(id),
            details: const Value('12345'),
          ),
        );
    final e = await q.enrichmentBytes();
    expect(e.lyrics, 6);
    expect(e.curiosities, 3 + 4);
    expect(e.credits, (3 + 6 + 2) + 5);
    expect(e.total, 6 + 7 + 16);
  });

  test('enrichmentBytes is zero on an empty database', () async {
    expect((await q.enrichmentBytes()).total, 0);
  });
}
