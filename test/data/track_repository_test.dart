import 'package:codecore/core/platform.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_kinds.dart' show LibraryFilter;
import 'package:codecore/providers/youtube_providers.dart' show downloadIndexProvider;
import 'package:codecore/services/online/download_index.dart';
import 'dart:io';
import 'package:codecore/data/repositories/folder_repository.dart';
import 'package:codecore/data/repositories/hidden_playlists.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/favorite_collections_repository.dart';
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

YtResult yt(String id) => YtResult(id: id, title: 'S\$id', channel: 'Ch', duration: null);

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

  group('rekeyStream (R-242)', () {
    Future<int> saved(String id) async {
      final rowId = (await repo.saveStream(yt(id)))!;
      await (db.update(db.tracks)..where((t) => t.id.equals(rowId))).write(
        const TracksCompanion(isFavorite: Value(true), playCount: Value(7)),
      );
      return rowId;
    }

    test('the same row moves to the new key and keeps its id, plays and favourite', () async {
      final id = await saved('old');
      expect(await repo.rekeyStream(id, 'youtube:new'), true);
      final t = (await repo.getById(id))!;
      expect([t.path, t.albumKey, t.saved, t.isFavorite, t.playCount], ['stream:youtube:new', 'stream|youtube:new', true, true, 7]);
      expect(await repo.streamRow('youtube:old'), null);
    });

    test('the merge reports the deleted shadow row and the kept one', () async {
      final id = await saved('old');
      final shadow = await repo.ensureStreamRow(yt('new'));
      final merged = <(int, int)>[];
      await repo.rekeyStream(id, 'youtube:new', onMerged: (g, k) => merged.add((g, k)));
      expect(merged, [(shadow, id)]);
    });

    test('a shadow row already at the new key is merged into the moved row', () async {
      final id = await saved('old');
      final shadow = await repo.ensureStreamRow(yt('new'));
      expect(await repo.rekeyStream(id, 'youtube:new'), true);
      expect(await repo.getById(shadow), null);
      expect((await repo.getById(id))!.path, 'stream:youtube:new');
    });

    test('a hand-edited row already at the new key keeps its title, artist and album', () async {
      final id = await saved('old');
      final shadow = await repo.ensureStreamRow(yt('new'));
      await (db.update(db.tracks)..where((t) => t.id.equals(shadow))).write(
        const TracksCompanion(title: Value('Mine'), artist: Value('Me'), album: Value('Al'), userEdited: Value(true), albumKey: Value('stream|mine')),
      );
      expect(await repo.rekeyStream(id, 'youtube:new'), true);
      final t = (await repo.getById(id))!;
      expect([t.title, t.artist, t.album, t.albumKey, t.userEdited], ['Mine', 'Me', 'Al', 'stream|mine', true]);
    });

    test('not a stream row, or the same key: nothing changes', () async {
      await repo.upsertBatch([row('/a.mp3', 'a')]);
      final file = (await repo.byPath('/a.mp3'))!.id;
      expect(await repo.rekeyStream(file, 'youtube:x'), false);
      final id = await saved('old');
      expect(await repo.rekeyStream(id, 'youtube:old'), false);
      expect(await repo.rekeyStream(9999, 'youtube:x'), false);
    });
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

    test('saveStream makes a saved shadow row with an album key, setSaved toggles, a saved row is kept', () async {
      final r = YtResult(id: 'a', title: 'T', channel: 'Ch', duration: null, artists: ['Art'], album: 'Alb');
      final id = await repo.saveStream(r);
      var t = (await repo.getById(id!))!;
      expect([t.kind, t.saved, t.albumKey], [2, true, 'stream|art|alb']);
      expect(await repo.deleteUnplayedStreamRows(), 0);
      await repo.setSaved(r.indexKey, false);
      expect((await repo.getById(id))!.saved, isFalse);
      expect(await repo.deleteUnplayedStreamRows(), 1);
    });

    test('saveStream on an existing row: new addedAt, album and first artist filled in, key from them', () async {
      final bare = YtResult(id: 'b', title: 'T', channel: 'Ch', duration: null);
      final id = await repo.ensureStreamRow(bare);
      await (db.update(db.tracks)..where((t) => t.id.equals(id))).write(const TracksCompanion(addedAt: Value(1)));
      final r = YtResult(id: 'b', title: 'T', channel: 'Ch', duration: null, artists: ['Art', 'Feat'], album: 'Alb');
      expect(await repo.saveStream(r), id);
      final t = (await repo.getById(id))!;
      expect([t.artist, t.album, t.albumKey], ['Art', 'Alb', 'stream|art|alb']);
      expect(t.addedAt, greaterThan(1));
      // Saving again keeps the date.
      await (db.update(db.tracks)..where((t) => t.id.equals(id))).write(const TracksCompanion(addedAt: Value(1)));
      await repo.saveStream(r);
      expect((await repo.getById(id))!.addedAt, 1);
    });

    test('saveStream with no album keeps the album key; an episode on the path is not saved', () async {
      final r = YtResult(id: 'n', title: 'T', channel: 'Ch', duration: null);
      final id = await repo.saveStream(r);
      expect((await repo.getById(id!))!.albumKey, 'stream|youtube:n');
      final ep = YtResult(id: 'e', title: 'E', channel: 'Ch', duration: null);
      final epId = await repo.ensureStreamRow(ep);
      await (db.update(db.tracks)..where((t) => t.id.equals(epId))).write(const TracksCompanion(kind: Value(1)));
      expect(await repo.saveStream(ep), equals(null));
      expect((await repo.getById(epId))!.saved, isFalse);
      expect(await repo.setSaved(ep.indexKey, true), 0);
      expect(await repo.setSaved(r.indexKey, false), 1);
    });

    test('saveStream keeps the fields and the album key of a row edited by hand', () async {
      final id = await repo.ensureStreamRow(YtResult(id: 'u', title: 'T', channel: 'Ch', duration: null));
      await (db.update(db.tracks)..where((t) => t.id.equals(id))).write(const TracksCompanion(
          userEdited: Value(true), artist: Value('Mine'), album: Value(''), albumKey: Value('stream|hand|pick')));
      await repo.saveStream(YtResult(id: 'u', title: 'T', channel: 'Ch', duration: null, artists: ['Art'], album: 'Alb'));
      final t = (await repo.getById(id))!;
      expect([t.saved, t.artist, t.album, t.albumKey], [true, 'Mine', '', 'stream|hand|pick']);
    });

    test('saveStream takes the channel as artist when the result has no artists, and moves a hand-picked cover', () async {
      final id = await repo.ensureStreamRow(YtResult(id: 'c', title: 'T', channel: 'Ch', duration: null));
      await (db.update(db.tracks)..where((t) => t.id.equals(id))).write(const TracksCompanion(
          artist: Value(''), coverSource: Value(1), coverKey: Value('pick'), hasCover: Value(true)));
      await repo.saveStream(YtResult(id: 'c', title: 'T', channel: 'Ch', duration: null, album: 'Alb'));
      final t = (await repo.getById(id))!;
      expect([t.artist, t.albumKey, t.coverSource, t.coverKey], ['Ch', 'stream|ch|alb', 0, null]);
    });

    test('favoriteStreamKeys lists favourite shadow rows only', () async {
      await repo.ensureStreamRow(YtResult(id: 'f1', title: 'A', channel: 'Ch', duration: null));
      await repo.ensureStreamRow(YtResult(id: 'f2', title: 'B', channel: 'Ch', duration: null));
      await db.customStatement("UPDATE tracks SET is_favorite = 1 WHERE path = 'stream:youtube:f1'");
      expect(await repo.favoriteStreamKeys(), {'youtube:f1'});
    });

    test('a saved row that becomes a file is no longer saved', () async {
      final folderId = (await FolderRepository(db).add('/m')).id;
      final id = (await repo.saveStream(YtResult(id: 'p', title: 'T', channel: 'Ch', duration: null)))!;
      final dir = Directory.systemTemp.createTempSync('promo');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File(p.join(dir.path, 'p.mp3'))..writeAsBytesSync([1]);
      final t = await repo.promoteStreamRow('youtube:p', file.path, folderId, file);
      expect([t!.id, t.kind, t.saved], [id, 0, false]);
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

  group('albumBrowseId survives', () {
    test('mergeStreamRow: the shadow fills a gap, the kept value is not overwritten', () async {
      await repo.upsertBatch([row('/a.mp3', 'A'), row('/b.mp3', 'B')]);
      final lib = {for (final t in await db.select(db.tracks).get()) t.title: t.id};
      await repo.ensureStreamRow(yt('a'));
      await repo.ensureStreamRow(yt('b'));
      await db.customStatement("UPDATE tracks SET album_browse_id = 'MPREa' WHERE path = 'stream:youtube:a'");
      await db.customStatement("UPDATE tracks SET album_browse_id = 'MPREb' WHERE path = 'stream:youtube:b'");
      await db.customStatement("UPDATE tracks SET album_browse_id = 'MPREmine' WHERE title = 'B'");
      await repo.mergeStreamRow('youtube:a', lib['A']!);
      await repo.mergeStreamRow('youtube:b', lib['B']!);
      expect((await repo.getById(lib['A']!))!.albumBrowseId, 'MPREa');
      expect((await repo.getById(lib['B']!))!.albumBrowseId, 'MPREmine');
    });

    test('mergeStreamRow leaves a user-edited row alone', () async {
      await repo.upsertBatch([row('/a.mp3', 'A')]);
      final id = (await db.select(db.tracks).getSingle()).id;
      await repo.ensureStreamRow(yt('a'));
      await db.customStatement("UPDATE tracks SET album_browse_id = 'MPREa' WHERE path = 'stream:youtube:a'");
      await db.customStatement('UPDATE tracks SET user_edited = 1 WHERE id = $id');
      await repo.mergeStreamRow('youtube:a', id);
      expect((await repo.getById(id))!.albumBrowseId, null);
    });
  });

  group('demoteToStream', () {
    test('keeps id, playlist row, plays, favourite and lyrics; sets path, kind and saved', () async {
      final folderId = (await FolderRepository(db).add('/m')).id;
      await repo.upsertBatch([row('/m/a.mp3', 'A', folderId: folderId)]);
      final id = (await db.select(db.tracks).getSingle()).id;
      await (db.update(db.tracks)..where((t) => t.id.equals(id))).write(
        const TracksCompanion(isFavorite: Value(true), lyricsPlain: Value('la la'), artist: Value('Art'), album: Value('Alb')),
      );
      await db.into(db.plays).insert(PlaysCompanion.insert(trackId: id, playedAt: 7));
      final pl = PlaylistRepository(db);
      final plId = await pl.create('Mix');
      await pl.addTracks(plId, [id]);

      final before = await repo.demoteToStream(id, 'youtube:a');

      expect(before!.path, '/m/a.mp3');
      final t = (await repo.getById(id))!;
      expect([t.path, t.kind, t.saved, t.folderId], ['stream:youtube:a', 2, true, null]);
      expect(t.albumKey, startsWith('stream|'));
      expect([t.isFavorite, t.lyricsPlain], [true, 'la la']);
      expect(await db.select(db.plays).get(), hasLength(1));
      expect((await pl.watchTracks(plId).first).map((x) => x.id), [id]);
      expect(await repo.streamRow('youtube:a'), isNot(equals(null)));
    });

    test('the merge of the streamed copy is reported once committed', () async {
      await repo.upsertBatch([row('/a.mp3', 'A')]);
      final id = (await db.select(db.tracks).getSingle()).id;
      final shadow = await repo.ensureStreamRow(yt('a'));
      final merged = <(int, int)>[];
      await repo.demoteToStream(id, 'youtube:a', onMerged: (g, k) => merged.add((g, k)));
      expect(merged, [(shadow, id)]);
    });

    test('a favourite album follows the row to its stream album key', () async {
      await repo.upsertBatch([row('/a.mp3', 'A')]);
      final id = (await db.select(db.tracks).getSingle()).id;
      await db.customStatement("UPDATE tracks SET user_edited = 1, album_key = 'hand' WHERE id = $id");
      await FavoriteCollectionsRepository(db).add('album', 'hand');
      await repo.demoteToStream(id, 'youtube:a');
      // The hand-picked key stays (with the stream prefix): the album does not split and the favourite stays.
      expect((await repo.getById(id))!.albumKey, 'stream|hand');
      expect(await FavoriteCollectionsRepository(db).watch('album').first, ['hand']);
    });

    test('a stream row is not demoted, and restoreRow puts the file row back', () async {
      await repo.upsertBatch([row('/a.mp3', 'A')]);
      final id = (await db.select(db.tracks).getSingle()).id;
      final shadow = await repo.ensureStreamRow(yt('s'));
      expect(await repo.demoteToStream(shadow, 'youtube:s'), equals(null));
      final before = (await repo.demoteToStream(id, 'youtube:a'))!;
      await repo.restoreRow(before);
      final t = (await repo.getById(id))!;
      expect([t.path, t.kind, t.saved], ['/a.mp3', 0, false]);
    });

    test('restoreRow puts the favourite back on the file album', () async {
      await repo.upsertBatch([row('/a.mp3', 'A')]);
      final id = (await db.select(db.tracks).getSingle()).id;
      final favs = FavoriteCollectionsRepository(db);
      await favs.add('album', 'k');
      final before = (await repo.demoteToStream(id, 'youtube:a'))!; // no artist or album: the key becomes stream|youtube:a
      expect(await favs.watch('album').first, ['youtube:a']);
      await repo.restoreRow(before);
      expect(await favs.watch('album').first, ['k']);
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
    LibraryFilter filter = LibraryFilter.all,
  }) => fail() ? Stream.error(StateError('boom')) : Stream.value(const []);
}
