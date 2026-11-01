import 'package:codecore/core/import_row.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/import_repository.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ImportRepository repo;
  late int playlistId;

  List<ImportRow> rows(int n) => [
    for (var i = 0; i < n; i++)
      ImportRow(
        index: i,
        title: 'T$i',
        artists: const ['A', 'B'],
        album: 'Al',
        durationMs: 1000 + i,
        isrc: 'I$i',
      ),
  ];

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ImportRepository(db);
    playlistId = await PlaylistRepository(db).create('Imported');
  });
  tearDown(() => db.close());

  test('creates the import with all rows in order', () async {
    final id = await repo.create(
      playlistId: playlistId,
      sourceName: 'x.csv',
      rows: rows(3),
    );
    final items = await repo.items(id);
    expect(items.map((i) => i.title), ['T0', 'T1', 'T2']);
    expect(items.first.artistList, ['A', 'B']);
    expect(items.first.state, ImportItemStatus.pending);
    expect(items.first.toRow().durationMs, 1000);
    expect((await repo.get(id))!.state, ImportStatus.running);
  });

  test('nextPending follows the CSV order and skips handled rows', () async {
    final id = await repo.create(
      playlistId: playlistId,
      sourceName: 'x',
      rows: rows(3),
    );
    expect((await repo.nextPending(id))!.rowIndex, 0);
    await repo.setItem(
      id,
      0,
      status: ImportItemStatus.linked,
      trackId: const Value(null),
    );
    await repo.setItem(
      id,
      1,
      status: ImportItemStatus.review,
      candidates: const Value('[{"id":"a"}]'),
      score: const Value(0.6),
    );
    expect((await repo.nextPending(id))!.rowIndex, 2);
    final item = (await repo.item(id, 1))!;
    expect(item.state, ImportItemStatus.review);
    expect(item.candidates, '[{"id":"a"}]');
    expect(item.score, 0.6);
  });

  test('counts per status', () async {
    final id = await repo.create(
      playlistId: playlistId,
      sourceName: 'x',
      rows: rows(4),
    );
    await repo.setItem(id, 0, status: ImportItemStatus.downloaded);
    await repo.setItem(id, 1, status: ImportItemStatus.downloaded);
    await repo.setItem(id, 2, status: ImportItemStatus.notFound);
    final c = await repo.counts(id);
    expect(c[ImportItemStatus.downloaded], 2);
    expect(c[ImportItemStatus.notFound], 1);
    expect(c[ImportItemStatus.pending], 1);
  });

  test('watched counts follow the rows', () async {
    final id = await repo.create(
      playlistId: playlistId,
      sourceName: 'x',
      rows: rows(3),
    );
    final seen = <Map<ImportItemStatus, int>>[];
    final sub = repo.watchCounts(id).listen(seen.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    await repo.setItem(id, 0, status: ImportItemStatus.downloaded);
    await pumpEventQueue();
    expect(seen.first, {ImportItemStatus.pending: 3});
    expect(seen.last, {
      ImportItemStatus.pending: 2,
      ImportItemStatus.downloaded: 1,
    });
  });

  test(
    'restart: running becomes paused, queued goes back to pending',
    () async {
      final id = await repo.create(
        playlistId: playlistId,
        sourceName: 'x',
        rows: rows(2),
      );
      await repo.setItem(id, 0, status: ImportItemStatus.queued);
      await repo.setItem(id, 1, status: ImportItemStatus.downloaded);
      await repo.recoverAfterRestart();
      expect((await repo.get(id))!.state, ImportStatus.paused);
      expect((await repo.item(id, 0))!.state, ImportItemStatus.pending);
      expect((await repo.item(id, 1))!.state, ImportItemStatus.downloaded);
      final unfinished = await repo.watchUnfinished().first;
      expect(unfinished.single.id, id);
    },
  );

  test('finished imports are not listed as unfinished', () async {
    final id = await repo.create(
      playlistId: playlistId,
      sourceName: 'x',
      rows: rows(1),
    );
    await repo.setStatus(id, ImportStatus.finished);
    expect(await repo.watchUnfinished().first, isEmpty);
  });

  test('retry puts failed and not-found rows back to pending', () async {
    final id = await repo.create(
      playlistId: playlistId,
      sourceName: 'x',
      rows: rows(3),
    );
    await repo.setItem(id, 0, status: ImportItemStatus.notFound);
    await repo.setItem(id, 1, status: ImportItemStatus.failed);
    await repo.setItem(id, 2, status: ImportItemStatus.downloaded);
    await repo.resetItems(id, {
      ImportItemStatus.notFound,
      ImportItemStatus.failed,
    });
    final c = await repo.counts(id);
    expect(c[ImportItemStatus.pending], 2);
    expect(c[ImportItemStatus.downloaded], 1);
  });

  test('deleting the playlist deletes the import and its rows', () async {
    final id = await repo.create(
      playlistId: playlistId,
      sourceName: 'x',
      rows: rows(2),
    );
    await PlaylistRepository(db).delete(playlistId);
    expect(await repo.get(id), isNull);
    expect(await repo.items(id), isEmpty);
  });

  test('import options, notes and locations are stored', () async {
    final id = await repo.create(
      playlistId: playlistId,
      sourceName: 'P',
      sourceKind: 'm3u',
      folderPath: 'P',
      numberFiles: true,
      linkOnly: true,
      planFirst: true,
      fetchCovers: true,
      rows: const [
        ImportRow(index: 0, title: 'A', artists: ['X'], location: '/m/a.mp3'),
      ],
    );
    final imp = (await repo.get(id))!;
    expect(
      [
        imp.sourceKind,
        imp.folderPath,
        imp.numberFiles,
        imp.linkOnly,
        imp.planFirst,
        imp.fetchCovers,
      ],
      ['m3u', 'P', true, true, true, true],
    );
    await repo.setItem(
      id,
      0,
      status: ImportItemStatus.notFound,
      note: const Value('nessun risultato'),
    );
    final it = (await repo.item(id, 0))!;
    expect(it.location, '/m/a.mp3');
    expect(it.note, 'nessun risultato');
    await repo.setItem(id, 0, status: ImportItemStatus.planned);
    expect((await repo.item(id, 0))!.state, ImportItemStatus.planned);
    expect(
      (await repo.item(id, 0))!.note,
      'nessun risultato',
      reason: 'an untouched note stays',
    );
    await repo.setItem(id, 0, status: ImportItemStatus.removed);
    expect((await repo.item(id, 0))!.state, ImportItemStatus.removed);
  });

  test(
    'linking a row writes its ISRC into the track only when empty',
    () async {
      final id = await repo.create(
        playlistId: playlistId,
        sourceName: 'x',
        rows: rows(2),
      );
      Future<int> track(String path, {String? isrc}) => db
          .into(db.tracks)
          .insert(
            TracksCompanion.insert(
              path: path,
              title: path,
              albumKey: 'k',
              format: 'mp3',
              sizeBytes: 1,
              mtimeMs: 1,
              addedAt: 1,
              isrc: Value(isrc),
            ),
          );
      final empty = await track('/e.mp3');
      final set = await track('/s.mp3', isrc: 'KEEP');
      await repo.setItem(
        id,
        0,
        status: ImportItemStatus.linked,
        trackId: Value(empty),
      );
      await repo.setItem(
        id,
        1,
        status: ImportItemStatus.linked,
        trackId: Value(set),
      );
      final all = await db.select(db.tracks).get();
      expect(all.firstWhere((t) => t.id == empty).isrc, 'I0');
      expect(all.firstWhere((t) => t.id == set).isrc, 'KEEP');
    },
  );

  test('videoIdOfTrack answers only for a downloaded row', () async {
    final id = await repo.create(playlistId: playlistId, sourceName: 'x', rows: rows(2));
    Future<int> track(String path) => db.into(db.tracks).insert(TracksCompanion.insert(
        path: path, title: path, albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1));
    final got = await track('/d.mp3'), guessed = await track('/l.mp3');
    await repo.setItem(id, 0,
        status: ImportItemStatus.downloaded, videoId: const Value('sZrTJesvJeo'), trackId: Value(got));
    await repo.setItem(id, 1,
        status: ImportItemStatus.linked, videoId: const Value('aaaaaaaaaaa'), trackId: Value(guessed));
    expect([await repo.videoIdOfTrack(got), await repo.videoIdOfTrack(guessed)], ['sZrTJesvJeo', null]);
  });
}
