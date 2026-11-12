import 'package:codecore/core/platform.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/youtube_providers.dart' show downloadIndexProvider;
import 'package:codecore/services/online/download_index.dart';
import 'dart:io';
import 'package:codecore/data/repositories/folder_repository.dart';
import 'package:codecore/data/repositories/hidden_playlists.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/track_ops.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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

  // Was accent-sensitive in 107.3; flipped in 110.5 (D-500).
  test('the Library list search ignores accents: "e" finds "Café"', () async {
    await repo.upsertBatch([row('/c.mp3', 'Café'), row('/d.mp3', 'Zzz')]);
    final c = ProviderContainer(
      overrides: [trackRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    c.listen(trackSearchProvider('E'), (_, _) {});
    final r = await c.read(trackSearchProvider('E').future);
    expect(r.map((t) => t.title), ['Café']);
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

  test('watchResumable: tracks and episodes left in the middle, never kind 2, newest first, limited', () async {
    await repo.upsertBatch([for (var i = 0; i < 6; i++) row('/$i.mp3', 'T$i')]);
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
  });

  test(
    'watchResumable: an episode of a podcast that is not followed shows up',
    () async {
      final podcastId = await db
          .into(db.podcasts)
          .insert(
            PodcastsCompanion.insert(
              feedUrl: 'https://x/feed',
              title: 'Show',
              addedAt: 1,
              followed: const Value(false),
            ),
          );
      final trackId = await db
          .into(db.tracks)
          .insert(
            TracksCompanion.insert(
              path: '/p/e.mp3',
              title: 'Ep',
              albumKey: 'podcast|$podcastId',
              format: 'mp3',
              sizeBytes: 1,
              mtimeMs: 1,
              addedAt: 1,
              kind: const Value(1),
              resumePositionMs: const Value(5000),
              lastPlayedAt: const Value(9),
            ),
          );
      await db
          .into(db.podcastEpisodes)
          .insert(
            PodcastEpisodesCompanion.insert(
              podcastId: podcastId,
              guid: 'e',
              title: 'Ep',
              audioUrl: 'https://x/e.mp3',
              trackId: Value(trackId),
            ),
          );
      expect((await repo.watchResumable().first).single.title, 'Ep');
    },
  );

  test(
    'watchResumable: an episode marked as heard by hand is not offered',
    () async {
      final podcastId = await db
          .into(db.podcasts)
          .insert(
            PodcastsCompanion.insert(
              feedUrl: 'https://x/feed',
              title: 'Show',
              addedAt: 1,
            ),
          );
      Future<void> episode(String guid, {required bool played}) async {
        final trackId = await db
            .into(db.tracks)
            .insert(
              TracksCompanion.insert(
                path: 'https://x/$guid.mp3',
                title: guid,
                albumKey: 'podcast|$podcastId',
                format: 'mp3',
                sizeBytes: 0,
                mtimeMs: 0,
                addedAt: 1,
                kind: const Value(1),
                resumePositionMs: const Value(5000),
                lastPlayedAt: const Value(9),
              ),
            );
        await db
            .into(db.podcastEpisodes)
            .insert(
              PodcastEpisodesCompanion.insert(
                podcastId: podcastId,
                guid: guid,
                title: guid,
                audioUrl: 'https://x/$guid.mp3',
                trackId: Value(trackId),
                played: Value(played),
              ),
            );
      }

      await episode('open', played: false);
      await episode('heard', played: true);
      expect((await repo.watchResumable().first).map((t) => t.title), ['open']);
    },
  );

  test('a remote episode row (no folder) is invisible to the scan and never missing', () async {
    final folderId = await db
        .into(db.folders)
        .insert(FoldersCompanion.insert(path: '/music', addedAt: 1));
    await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            path: 'https://x/e.mp3',
            title: 'E',
            albumKey: 'podcast|1',
            format: 'mp3',
            sizeBytes: 0,
            mtimeMs: 0,
            addedAt: 1,
            kind: const Value(1),
          ),
        );
    expect(
      await repo.fileIndexForFolder(folderId),
      isEmpty,
      reason: 'the scan only marks what is in its index',
    );
    expect(await repo.missingPathsForFolder(folderId), isEmpty);
    expect(await repo.watchMissing().first, isEmpty);
  });

  test(
    'setLyrics byUser marks the text as the user\'s; otherwise no mark',
    () async {
      await repo.upsertBatch([row('/a.mp3', 'A')]);
      final id = (await db.select(db.tracks).getSingle()).id;
      await repo.setLyrics(id, plain: 'x');
      expect(await db.select(db.trackEnrich).get(), isEmpty);
      await db
          .into(db.trackEnrich)
          .insert(
            TrackEnrichCompanion.insert(
              trackId: Value(id),
              creditsNoneAt: const Value(7),
            ),
          );
      await repo.setLyrics(id, plain: 'y', byUser: true);
      expect((await db.select(db.trackEnrich).getSingle()).creditsNoneAt, 7);
      expect((await db.select(db.trackEnrich).getSingle()).lyricsByUser, true);
      expect((await db.select(db.tracks).getSingle()).lyricsPlain, 'y');
      await repo.setLyrics(id, plain: 'z');
      expect((await db.select(db.trackEnrich).getSingle()).lyricsByUser, true);
    },
  );

  test(
    'a rescan with a new mtime and another cover keeps a track pick',
    () async {
      await repo.upsertBatch([row('/a.mp3', 'A')]);
      final id = (await repo.byPath('/a.mp3'))!.id;
      await repo.setManualCover(id, 'mine');
      await repo.upsertBatch([
        row(
          '/a.mp3',
          'A',
          mtime: 9,
        ).copyWith(coverKey: const Value('auto2'), hasCover: const Value(true)),
      ]);
      final t = (await repo.byPath('/a.mp3'))!;
      expect([t.coverKey, t.coverSource, t.mtimeMs], ['mine', 2, 9]);
    },
  );

  test('a row that enters an album with a hand-picked cover takes its key and source', () async {
    await repo.upsertBatch([row('/a.mp3', 'A'), row('/b.mp3', 'B')]);
    await repo.setManualAlbumCover('k', 'pick');
    final entering = row('/b.mp3', 'B', mtime: 9).copyWith(
      coverKey: const Value('pick'),
      hasCover: const Value(true),
      coverSource: const Value(1),
    );
    await repo.upsertBatch([
      entering,
      row(
        '/c.mp3',
        'C',
      ).copyWith(coverKey: const Value('pick'), coverSource: const Value(1)),
    ]);
    for (final p in ['/b.mp3', '/c.mp3']) {
      final t = (await repo.byPath(p))!;
      expect([t.coverKey, t.coverSource], ['pick', 1], reason: p);
    }
  });

  group('watchDownloadedWithoutPlaylist (D-485)', () {
    Future<List<String>> titles() async => [
      for (final t in await repo.watchDownloadedWithoutPlaylist(folderId: 1).first) t.title,
    ];

    setUp(() async {
      await db.into(db.folders).insert(FoldersCompanion.insert(path: '/d', addedAt: 1));
      await db.into(db.folders).insert(FoldersCompanion.insert(path: '/o', addedAt: 1));
    });

    test('keeps favourites and smart playlists, drops the rest', () async {
      await repo.upsertBatch([
        row('/d/fav.mp3', 'fav', folderId: 1),
        row('/d/smart.mp3', 'smart', folderId: 1),
        row('/d/pl.mp3', 'inPlaylist', folderId: 1),
        row('/o/out.mp3', 'outside', folderId: 2),
        row('/d/ep.mp3', 'episode', folderId: 1),
        row('/d/shadow.mp3', 'shadow', folderId: 1),
      ]);
      Future<int> idOf(String title) async =>
          (await (db.select(db.tracks)..where((t) => t.title.equals(title))).getSingle()).id;
      await (db.update(db.tracks)..where((t) => t.title.equals('fav')))
          .write(const TracksCompanion(isFavorite: Value(true)));
      await (db.update(db.tracks)..where((t) => t.title.equals('episode')))
          .write(const TracksCompanion(kind: Value(1)));
      await (db.update(db.tracks)..where((t) => t.title.equals('shadow')))
          .write(const TracksCompanion(kind: Value(2)));
      await db.into(db.smartPlaylists).insert(
        SmartPlaylistsCompanion.insert(name: 'S', rules: '[]', createdAt: 1),
      );
      final pl = await db.into(db.playlists).insert(
        PlaylistsCompanion.insert(name: 'P', createdAt: 1),
      );
      await db.into(db.playlistTracks).insert(
        PlaylistTracksCompanion.insert(
          playlistId: pl,
          trackId: await idOf('inPlaylist'),
          position: 0,
        ),
      );
      expect(await titles(), unorderedEquals(['fav', 'smart']));
    });

    Future<int> idOf(String title) async =>
        (await (db.select(db.tracks)..where((t) => t.title.equals(title))).getSingle()).id;

    test('missing and ignored tracks are out, the sort is respected', () async {
      await repo.upsertBatch([
        row('/d/b.mp3', 'b', folderId: 1),
        row('/d/a.mp3', 'a', folderId: 1),
        row('/d/m.mp3', 'm', folderId: 1),
        row('/d/i.mp3', 'i', folderId: 1),
      ]);
      await (db.update(db.tracks)..where((t) => t.title.equals('m')))
          .write(const TracksCompanion(missing: Value(true)));
      await (db.update(db.tracks)..where((t) => t.title.equals('i')))
          .write(const TracksCompanion(ignored: Value(true)));
      await (db.update(db.tracks)..where((t) => t.title.equals('b')))
          .write(const TracksCompanion(artist: Value('A')));
      await (db.update(db.tracks)..where((t) => t.title.equals('a')))
          .write(const TracksCompanion(artist: Value('Z')));
      expect(
        [for (final t in await repo.watchDownloadedWithoutPlaylist(folderId: 1, sort: SortOption.artist).first) t.title],
        ['b', 'a'],
      );
    });

    test('follows playlist_tracks alone, and the count agrees', () async {
      await repo.upsertBatch([row('/d/a.mp3', 'a', folderId: 1)]);
      final pls = PlaylistRepository(db);
      final lists = <int>[];
      final counts = <int>[];
      final s1 = repo.watchDownloadedWithoutPlaylist(folderId: 1).listen((l) => lists.add(l.length));
      final s2 = repo.watchDownloadedWithoutPlaylistCount(folderId: 1).listen(counts.add);
      addTearDown(s1.cancel);
      addTearDown(s2.cancel);
      Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 100));
      await settle();
      expect([lists.last, counts.last], [1, 1]);
      final pl = await pls.create('P');
      await pls.addTracks(pl, [await idOf('a')]);
      await settle();
      expect([lists.last, counts.last], [0, 0], reason: 'added to a playlist');
      await pls.removeTrack(pl, await idOf('a'));
      await settle();
      expect([lists.last, counts.last], [1, 1], reason: 'removed from it');
      await pls.addTracks(pl, [await idOf('a')]);
      await settle();
      await pls.delete(pl);
      await settle();
      expect([lists.last, counts.last], [1, 1], reason: 'playlist deleted');
    });

    test('a hidden «Scarica album» playlist does not count as a playlist', () async {
      await repo.upsertBatch([row('/d/a.mp3', 'a', folderId: 1)]);
      final pls = PlaylistRepository(db);
      final pl = await pls.create('album');
      await pls.addTracks(pl, [await idOf('a')]);
      expect(await titles(), isEmpty);
      await db.into(db.playlistImports).insert(PlaylistImportsCompanion.insert(
            playlistId: pl,
            sourceName: 'album',
            createdAt: 1,
            sourceKind: const Value(ytmAlbumSourceKind),
          ));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await titles(), ['a']);
      expect(await repo.watchDownloadedWithoutPlaylistCount(folderId: 1).first, 1);
    });

    test('downloaded by path prefix or by index path, whatever the folder', () async {
      await repo.upsertBatch([
        row('/m/FreeKmusic/new.mp3', 'new', folderId: 2),
        row('/old/Music/old.mp3', 'old', folderId: 2),
        row('/lib/idx.mp3', 'idx', folderId: 2),
        row('/m/FreeKmusicX/other.mp3', 'other', folderId: 2),
      ]);
      final l = await repo
          .watchDownloadedWithoutPlaylist(prefixes: ['/m/FreeKmusic/', '/old/Music/'], paths: {'/lib/idx.mp3'})
          .first;
      expect(l.map((t) => t.title).toSet(), {'new', 'old', 'idx'});
    });

    test('a prefix with an emoji, quotes or spaces still matches', () async {
      await repo.upsertBatch([
        row('/home/u/🎵 Music/FreeKmusic/a.mp3', 'a'),
        row("/home/o'brien/Musica \"x\"/FreeKmusic/b.mp3", 'b'),
      ]);
      final l = await repo
          .watchDownloadedWithoutPlaylist(
              prefixes: ['/home/u/🎵 Music/FreeKmusic/', "/home/o'brien/Musica \"x\"/FreeKmusic/"])
          .first;
      expect(l.map((t) => t.title).toSet(), {'a', 'b'});
    });

    test('a download index bigger than the SQL variable limit still works', () async {
      await repo.upsertBatch([row('/x/1.mp3', 'a')]);
      final l = await repo.watchDownloadedWithoutPlaylist(paths: {for (var i = 0; i < 40000; i++) '/x/$i.mp3'}).first;
      expect(l.map((t) => t.title), ['a']);
    });

    test('a download root without a trailing separator does not match a sibling folder', () async {
      final root = p.join('/Music', 'FreeKmusic'); // `\Music\...` on Windows: the prefixes use the host separator
      await repo.upsertBatch([row(p.join(root, 'a.mp3'), 'in'), row(p.join('${root}2', 'b.mp3'), 'out')]);
      final c = ProviderContainer(overrides: [
        trackRepositoryProvider.overrideWithValue(repo),
        downloadRootsProvider.overrideWithValue(AsyncData(<String>[root])),
        downloadFolderIdProvider.overrideWith((ref) async => null),
        downloadIndexProvider.overrideWith((ref) async => DownloadIndex(File('/nonexistent/downloads.json'))),
      ]);
      addTearDown(c.dispose);
      c.listen(downloadedNoPlaylistProvider(const TrackQuery()), (_, _) {});
      final r = await c.read(downloadedNoPlaylistProvider(const TrackQuery()).future);
      expect(r.map((t) => t.title), ['in']);
    });

    test('the provider search ignores accents', () async {
      await repo.upsertBatch([
        row('/d/c.mp3', 'Café', folderId: 1),
        row('/d/z.mp3', 'Zzz', folderId: 1),
      ]);
      final c = ProviderContainer(overrides: [
        trackRepositoryProvider.overrideWithValue(repo),
        downloadRootsProvider.overrideWithValue(const AsyncData(<String>[])),
        downloadFolderIdProvider.overrideWith((ref) async => 1),
        downloadIndexProvider.overrideWith((ref) async => DownloadIndex(File('/nonexistent/downloads.json'))),
      ]);
      addTearDown(c.dispose);
      const q = TrackQuery(text: 'CAFE');
      c.listen(downloadedNoPlaylistProvider(q), (_, _) {});
      final r = await c.read(downloadedNoPlaylistProvider(q).future);
      expect(r.map((t) => t.title), ['Café']);
    });

    test('downloadFolderIdProvider only reads: never adds a folder', () async {
      final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
      addTearDown(c.dispose);
      final downloads = (await resolveDefaultFolders(create: false)).downloads;
      final id = (await FolderRepository(db).add(downloads)).id;
      c.listen(downloadFolderIdProvider, (_, _) {});
      expect(await c.read(downloadFolderIdProvider.future), id, reason: 'the download location');
      await db.delete(db.folders).go();
      c.invalidate(foldersProvider);
      c.invalidate(downloadFolderIdProvider);
      expect(await c.read(downloadFolderIdProvider.future), equals(null));
      expect(await FolderRepository(db).getAll(), isEmpty);
    });
  });

  group('shadow rows and playlists (D-524)', () {
    YtResult yt(String id) => YtResult(id: id, title: 'S$id', channel: 'Ch', duration: null);

    test('cache cleanup keeps a shadow row in a playlist, drops the unplayed ones outside', () async {
      final inList = await repo.ensureStreamRow(yt('in'));
      final outside = await repo.ensureStreamRow(yt('out'));
      final played = await repo.ensureStreamRow(yt('played'));
      await db.into(db.plays).insert(PlaysCompanion.insert(trackId: played, playedAt: 1));
      final pl = PlaylistRepository(db);
      final p = await pl.create('Mix');
      await pl.addStreamTracks(p, [inList]);
      expect(await repo.deleteUnplayedStreamRows(), 1);
      expect(await repo.getById(outside), equals(null));
      expect((await repo.getById(inList))?.id, inList);
      expect((await repo.getById(played))?.id, played);
      expect((await pl.watchTracks(p).first).map((t) => t.id), [inList]);
    });

    test('downloading a streamed track keeps its place in the playlist', () async {
      await repo.upsertBatch([row('/a.mp3', 'A'), row('/c.mp3', 'C'), row('/b.mp3', 'B')]);
      final lib = {for (final t in await db.select(db.tracks).get()) t.title: t.id};
      final shadow = await repo.ensureStreamRow(yt('b'));
      final pl = PlaylistRepository(db);
      final p = await pl.create('Mix');
      await pl.addStreamTracks(p, [lib['A']!, shadow, lib['C']!]);
      await repo.mergeStreamRow('youtube:b', lib['B']!);
      expect((await pl.watchTracks(p).first).map((t) => t.id), [lib['A'], lib['B'], lib['C']]);
      expect(await repo.streamRow('youtube:b'), equals(null));
    });
  });

  test('Retry: invalidating tracksProvider re-reads a plain stream that failed', () async {
    var calls = 0;
    final c = ProviderContainer(overrides: [
      trackRepositoryProvider.overrideWithValue(_FlakyRepo(db, () => calls++ == 0)),
    ]);
    addTearDown(c.dispose);
    const q = TrackQuery();
    c.listen(tracksProvider(q), (_, _) {});
    await expectLater(c.read(tracksProvider(q).future), throwsA(anything));
    c.invalidate(tracksProvider(q));
    expect(await c.read(tracksProvider(q).future), isEmpty);
    expect(calls, 2, reason: 'one retry, no loop');
  });
}

class _FlakyRepo extends TrackRepository {
  _FlakyRepo(super.db, this.fail);
  final bool Function() fail;
  @override
  Stream<List<Track>> watchTracks({
    String query = '',
    SortOption sort = SortOption.defaultOrder,
    bool favoritesOnly = false,
  }) => fail() ? Stream.error(StateError('boom')) : Stream.value(const []);
}
