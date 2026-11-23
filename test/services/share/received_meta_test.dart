import 'package:codecore/data/repositories/credits_repository.dart';
import 'package:codecore/services/online/credits.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:codecore/core/text_utils.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/covers/cover_store.dart';
import 'package:codecore/services/share/offers.dart' show StreamOffer;
import 'package:codecore/services/share/received_meta.dart';
import 'package:codecore/services/share/track_meta.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

TracksCompanion _row(String path, {String? artist, String? genre, int? year}) =>
    TracksCompanion.insert(
      path: path,
      title: 'file name',
      albumKey: 'old',
      format: 'mp3',
      sizeBytes: 1,
      mtimeMs: 1,
      addedAt: 1,
      artist: Value(artist),
      genre: Value(genre),
      year: Value(year),
    );

void main() {
  late AppDatabase db;
  late TrackRepository repo;
  late Directory tmp;
  late CoverStore covers;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = TrackRepository(db);
    tmp = await Directory.systemTemp.createTemp('recv_meta');
    covers = CoverStore(Directory('${tmp.path}/covers'));
  });
  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  const meta = TrackMeta(
    title: 'Poetica',
    artist: 'Cesare Cremonini',
    album: 'Logico',
    year: 2002,
    genre: 'Pop',
    trackNumber: 3,
    discNumber: 1,
    isrc: 'ITUM71200001',
    lyricsPlain: 'la la',
  );

  test(
    'file without tags takes every field of the meta and is userEdited',
    () async {
      await repo.upsertBatch([_row('/a/x.mp3')]);
      await applyReceivedPackage(repo, covers, '/a/x.mp3', meta);
      final t = (await repo.byPath('/a/x.mp3'))!;
      expect(
        [
          t.title,
          t.artist,
          t.album,
          t.year,
          t.genre,
          t.trackNumber,
          t.discNumber,
          t.isrc,
          t.lyricsPlain,
        ],
        [
          'Poetica',
          'Cesare Cremonini',
          'Logico',
          2002,
          'Pop',
          3,
          1,
          'ITUM71200001',
          'la la',
        ],
      );
      expect(t.userEdited, isTrue);
    },
  );

  test(
    'meta wins over local tags; a null meta field keeps the file value',
    () async {
      await repo.upsertBatch([
        _row('/a/x.mp3', artist: 'Local', genre: 'Rock', year: 1999),
      ]);
      await applyReceivedPackage(
        repo,
        covers,
        '/a/x.mp3',
        const TrackMeta(title: 'T', genre: 'Pop'),
      );
      final t = (await repo.byPath('/a/x.mp3'))!;
      expect([t.genre, t.artist, t.year], ['Pop', 'Local', 1999]);
    },
  );

  test('albumKey is recomputed from the new fields', () async {
    await repo.upsertBatch([_row('/a/x.mp3')]);
    await applyReceivedPackage(repo, covers, '/a/x.mp3', meta);
    final t = (await repo.byPath('/a/x.mp3'))!;
    expect(
      t.albumKey,
      computeAlbumKey(
        albumArtist: null,
        artist: 'Cesare Cremonini',
        album: 'Logico',
        directory: '/a',
      ),
    );
  });

  test('cover is saved under the new albumKey and set on the row', () async {
    await repo.upsertBatch([_row('/a/x.mp3')]);
    await applyReceivedPackage(
      repo,
      covers,
      '/a/x.mp3',
      meta,
      fetchCover: () async =>
          (bytes: Uint8List.fromList([1, 2, 3]), mime: 'image/png'),
    );
    final t = (await repo.byPath('/a/x.mp3'))!;
    expect(t.hasCover, isTrue);
    expect(t.coverKey, CoverStore.coverKeyFor(t.albumKey));
    expect(covers.fileFor(t.coverKey!), isNotNull);
  });

  test('a failing cover download still applies the meta', () async {
    await repo.upsertBatch([_row('/a/x.mp3')]);
    await applyReceivedPackage(
      repo,
      covers,
      '/a/x.mp3',
      meta,
      fetchCover: () async => null,
    );
    await applyReceivedPackage(
      repo,
      covers,
      '/a/x.mp3',
      meta,
      fetchCover: () async => throw StateError('boom'),
    );
    final t = (await repo.byPath('/a/x.mp3'))!;
    expect([t.title, t.hasCover], ['Poetica', false]);
  });

  test('rescan of the unchanged file leaves the row as it is', () async {
    await repo.upsertBatch([_row('/a/x.mp3')]);
    await applyReceivedPackage(repo, covers, '/a/x.mp3', meta);
    final before = (await repo.byPath('/a/x.mp3'))!;
    await repo.upsertBatch([_row('/a/x.mp3')]);
    final after = (await repo.byPath('/a/x.mp3'))!;
    expect(
      [after.title, after.artist, after.album, after.albumKey],
      [before.title, before.artist, before.album, before.albumKey],
    );
  });

  test('later scan with other size and no cover keeps cover and album artist', () async {
    await repo.upsertBatch([_row('/a/x.mp3')]);
    await applyReceivedPackage(repo, covers, '/a/x.mp3', const TrackMeta(albumArtist: 'AA', album: 'Logico'),
        fetchCover: () async => (bytes: Uint8List.fromList([1, 2, 3]), mime: 'image/png'));
    final before = (await repo.byPath('/a/x.mp3'))!;
    await repo.upsertBatch([
      TracksCompanion.insert(
        path: '/a/x.mp3', title: 'x', albumKey: 'k', format: 'mp3',
        sizeBytes: 99, mtimeMs: 99, addedAt: 1,
      ),
    ]);
    final after = (await repo.byPath('/a/x.mp3'))!;
    expect([after.albumArtist, after.hasCover, after.coverKey], ['AA', true, before.coverKey]);
  });

  test('received credits are saved, but never over the ones the track has', () async {
    await repo.upsertBatch([_row('/a/x.mp3'), _row('/a/y.mp3')]);
    final y = (await repo.byPath('/a/y.mp3'))!;
    final credits = CreditsRepository(db);
    await credits.saveCredits(y.id, [
      TrackCreditsCompanion.insert(trackId: y.id, name: 'Mine', nameKey: 'mine', role: 'composer', source: 'deezer')
    ]);
    final m = TrackMeta(credits: [TrackCredit('Ann', 'producer', 'deezer')], details: const TrackDetails(label: 'L'));
    await applyReceivedPackage(repo, covers, '/a/x.mp3', m, credits: credits);
    await applyReceivedPackage(repo, covers, '/a/y.mp3', m, credits: credits);
    final x = (await repo.byPath('/a/x.mp3'))!;
    expect((await credits.creditsOf(x.id)).map((c) => c.name), ['Ann']);
    expect((await credits.portableOf(x.id)).details!.label, 'L');
    expect((await credits.creditsOf(y.id)).map((c) => c.name), ['Mine']);
  });

  test('a hand-picked cover on the row is not replaced by the received one', () async {
    await repo.upsertBatch([_row('/a/x.mp3')]);
    final id = (await repo.byPath('/a/x.mp3'))!.id;
    await repo.setManualCover(id, 'manual:track:1:1');
    await applyReceivedPackage(repo, covers, '/a/x.mp3', meta,
        fetchCover: () async => (bytes: Uint8List.fromList([1, 2, 3]), mime: 'image/png'));
    final t = (await repo.byPath('/a/x.mp3'))!;
    expect([t.coverKey, t.coverSource], ['manual:track:1:1', 2]);
  });

  test('received streams become saved stream rows; the ones with a file are skipped', () async {
    const a = StreamOffer(key: 'youtube:abcdefghijk', title: 'Live', artist: 'Band', durationMs: 5000);
    const b = StreamOffer(key: 'youtube:bbbbbbbbbbb', title: 'Has file');
    final n = await saveReceivedStreams(repo, [a, b], hasFile: (r) => r.id == 'bbbbbbbbbbb');
    expect(n, 1);
    final row = (await repo.byPath('stream:youtube:abcdefghijk'))!;
    expect((row.kind, row.saved, row.title, row.artist), (2, true, 'Live', 'Band'));
    expect(await repo.byPath('stream:youtube:bbbbbbbbbbb'), isNull);
  });

  test('a stream already saved is not counted again; its credits are given once', () async {
    const a = StreamOffer(key: 'youtube:abcdefghijk', title: 'Live');
    expect(await saveReceivedStreams(repo, [a], hasFile: (_) => false), 1);
    expect(await saveReceivedStreams(repo, [a], hasFile: (_) => false), 0);
  });
}
