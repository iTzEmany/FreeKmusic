import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/library/free_space.dart';
import 'package:codecore/services/library/duplicate_cleanup.dart' show FileDeleter;
import 'package:codecore/services/online/download_index.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _now = 1000 * 24 * 3600 * 1000;
const _day = 24 * 3600 * 1000;

void main() {
  late AppDatabase db;
  late TrackRepository repo;
  late Directory dir;
  late DownloadIndex index;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TrackRepository(db);
    dir = Directory.systemTemp.createTempSync('freespace');
    index = DownloadIndex(File(p.join(dir.path, 'downloads.json')));
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  /// A file row; [vid] != null means the app downloaded it.
  Future<int> add(String name, {String? vid, int? lastPlayed, int size = 10}) async {
    final f = File(p.join(dir.path, name))..writeAsBytesSync([1]);
    await db.into(db.tracks).insert(TracksCompanion.insert(
      path: f.path, title: name, albumKey: 'k', format: 'mp3', sizeBytes: size, mtimeMs: 1, addedAt: 1,
      lastPlayedAt: Value(lastPlayed),
    ));
    if (vid != null) await index.add(vid, f.path);
    return (await repo.byPath(f.path))!.id;
  }

  FreeSpaceService svc({FileDeleter? deleter}) =>
      FreeSpaceService(tracks: repo, index: index, deleter: deleter, nowMs: () => _now);

  test('candidates: only files the app downloaded, unplayed for 90 days first', () async {
    final recent = await add('recent.mp3', vid: 'r', lastPlayed: _now - 10 * _day, size: 99);
    final old = await add('old.mp3', vid: 'o', lastPlayed: _now - 100 * _day);
    final never = await add('never.mp3', vid: 'n');
    await add('mine.mp3'); // not downloaded by the app
    final c = await svc().freeSpaceCandidates();
    expect(c.map((e) => e.track.id), [old, never, recent]);
    expect(c.map((e) => e.stale), [true, true, false]);
  });

  test('freeSpace demotes the row, then deletes the file and forgets the download', () async {
    final id = await add('a.mp3', vid: 'a');
    final path = (await repo.getById(id))!.path;
    var rowWhenDeleted = '';
    final r = await svc(deleter: (f) async {
      rowWhenDeleted = (await repo.getById(id))!.path;
      await File(f).delete();
    }).freeSpace([id]);
    expect(rowWhenDeleted, 'stream:youtube:a', reason: 'row first, file after');
    expect(r.freedIds, [id]);
    expect(File(path).existsSync(), false);
    expect(index.entries, isEmpty);
    expect((await repo.getById(id))!.kind, 2);
  });

  test('a failed delete puts the row back and keeps the download', () async {
    final id = await add('a.mp3', vid: 'a');
    final path = (await repo.getById(id))!.path;
    final r = await svc(deleter: (_) async => throw const FileSystemException('no')).freeSpace([id]);
    expect(r.failedIds, [id]);
    expect(File(path).existsSync(), true);
    final t = (await repo.getById(id))!;
    expect([t.path, t.kind, t.saved], [path, 0, false]);
    expect(index.contains('a'), true);
  });

  test('ids that are not candidates are ignored', () async {
    final mine = await add('mine.mp3');
    final r = await svc().freeSpace([mine]);
    expect(r.freedIds, isEmpty);
    expect((await repo.getById(mine))!.kind, 0);
    expect(File((await repo.getById(mine))!.path).existsSync(), true);
  });
}
