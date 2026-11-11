import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/cover_ops.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/services/covers/cover_store.dart';
import 'package:codecore/services/tags/tag_reader.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _NoTags implements TagReader {
  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async => const TagInfo();
}

void main() {
  late Directory tmp;
  late AppDatabase db;
  late TrackRepository tracks;
  late CoverStore store;
  late ProviderContainer c;
  late CoverOps ops;
  late String original;

  Future<Track> row(int i) async => (await tracks.byPath('/m/$i.mp3'))!;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('cops');
    db = AppDatabase(NativeDatabase.memory());
    tracks = TrackRepository(db);
    store = CoverStore(Directory(p.join(tmp.path, 'covers')));
    original = (await store.saveFromBytes('alb', [1, 2, 3], 'image/jpeg'))!;
    await tracks.upsertBatch([
      for (final i in [1, 2, 3])
        TracksCompanion.insert(
          path: '/m/$i.mp3',
          title: 't$i',
          albumKey: 'alb',
          format: 'mp3',
          sizeBytes: 1,
          mtimeMs: 1,
          addedAt: 1,
          hasCover: const Value(true),
          coverKey: Value(original),
        ),
    ]);
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      coverStoreProvider.overrideWithValue(store),
      tagReaderProvider.overrideWithValue(_NoTags()),
    ]);
    ops = c.read(coverOpsProvider);
  });
  tearDown(() async {
    c.dispose();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('album cover changes the tracks without their own, restore brings the original back', () async {
    expect(await ops.setTrackCover((await row(3)).id, [9, 9], 'image/png'), isTrue);
    final own = (await row(3)).coverKey!;
    expect(await ops.setAlbumCover('alb', [7, 7], 'image/png'), isTrue);

    final a = await row(1), b = await row(2), mine = await row(3);
    expect(a.coverKey, b.coverKey);
    expect([a.coverSource, b.coverSource, mine.coverSource], [1, 1, 2]);
    expect(mine.coverKey, own);

    await ops.restoreAlbumCover('alb');
    expect([(await row(1)).coverKey, (await row(2)).coverKey], [original, original]);
    expect((await row(1)).coverSource, 0);
    expect((await row(3)).coverKey, own);
    expect(store.fileFor(a.coverKey!), isNull, reason: 'the album pick is gone from disk');

    await ops.restoreTrackCover(mine.id);
    final back = await row(3);
    expect([back.coverKey, back.coverSource], [original, 0]);
    expect(store.fileFor(own), isNull);
  });

  test('a second pick deletes the first hand-picked file and its thumbnail, never the original', () async {
    final id = (await row(1)).id;
    await ops.setTrackCover(id, [1], null);
    final first = (await row(1)).coverKey!;
    File(p.join(store.dir.path, CoverStore.thumbName(first))).writeAsBytesSync([0]);
    await ops.setTrackCover(id, [2], null);

    expect(store.fileFor(first), isNull);
    expect(File(p.join(store.dir.path, CoverStore.thumbName(first))).existsSync(), isFalse);
    expect(store.fileFor(original), isNotNull);
    expect(store.fileFor((await row(1)).coverKey!), isNotNull);
  });

  test('empty or too large bytes are not saved', () async {
    expect(await ops.setTrackCover((await row(1)).id, [], null), isFalse);
    expect(await ops.setAlbumCover('alb', List.filled(CoverStore.maxBytes + 1, 0), null), isFalse);
    expect((await row(1)).coverSource, 0);
  });

  test('clearing the cache keeps hand-picked covers, thumbnails and playlist covers, and forces a rescan', () async {
    await ops.setTrackCover((await row(1)).id, [5, 5], null);
    final mine = (await row(1)).coverKey!;
    await ops.setAlbumCover('alb', [6], null);
    final pick = (await row(2)).coverKey!;
    final thumb = File(p.join(store.dir.path, CoverStore.thumbName(pick)))..writeAsBytesSync([0]);
    final pid = await db.into(db.playlists).insert(PlaylistsCompanion.insert(name: 'pl', createdAt: 1));
    await ops.setPlaylistCover(pid, [3], null);
    final pk = (await (db.select(db.playlists)..where((q) => q.id.equals(pid))).getSingle()).coverKey!;
    await ops.clearCache();

    expect([store.fileFor(mine), store.fileFor(pick), store.fileFor(pk)], everyElement(isNotNull));
    expect(thumb.existsSync(), isTrue);
    expect(store.fileFor(original), isNull);
    final t = await row(1), a = await row(2);
    expect([t.coverKey, t.coverSource], [mine, 2]);
    expect([a.coverKey, a.coverSource], [pick, 1]);
    expect((await db.select(db.tracks).get()).map((r) => r.mtimeMs), everyElement(0));
    expect((await (db.select(db.playlists)..where((q) => q.id.equals(pid))).getSingle()).coverKey, pk);
  });

  test('a second album pick deletes the first album pick file', () async {
    await ops.setAlbumCover('alb', [1], null);
    final first = (await row(1)).coverKey!;
    await ops.setAlbumCover('alb', [2], null);
    expect(store.fileFor(first), isNull);
    expect(store.fileFor(original), isNotNull);
  });

  test('a key still used by another row survives a new pick', () async {
    final id = (await row(1)).id;
    await ops.setTrackCover(id, [1], null);
    final shared = (await row(1)).coverKey!;
    await tracks.setManualCover((await row(2)).id, shared);
    await ops.setTrackCover(id, [2], null);
    expect(store.fileFor(shared), isNotNull);
  });

  test('a cover for a track that does not exist is refused without leaving a file', () async {
    final before = store.dir.listSync().length;
    expect(await ops.setTrackCover(9999, [1, 2], null), isFalse);
    expect(store.dir.listSync().length, before);
  });

  test('an artist image is read back, replaced without leaving the old file, and reset to automatic', () async {
    expect(await ops.setArtistCover('art', [1, 1], 'image/png'), isTrue);
    final first = (await c.read(artistInfoRepositoryProvider).images())['art']!;
    expect(store.fileFor(first), isNotNull);
    expect(await ops.setArtistCover('art', [2, 2], 'image/png'), isTrue);
    final second = (await db.select(db.artistInfos).get()).single.body;
    expect(second, isNot(first));
    expect(store.fileFor(first), isNull);

    await ops.clearCache();
    expect(store.fileFor(second), isNotNull, reason: 'the cache clear keeps hand-picked images');

    await ops.restoreArtistCover('art');
    expect(await db.select(db.artistInfos).get(), isEmpty);
    expect(store.fileFor(second), isNull);
  });
}
