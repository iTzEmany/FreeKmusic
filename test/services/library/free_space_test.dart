import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/library/free_space.dart';
import 'package:codecore/services/library/duplicate_cleanup.dart' show FileDeleter;
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/youtube_service.dart' show YtResult;
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

  FreeSpaceService svc({FileDeleter? deleter, Set<int> Function()? playing, bool Function()? scan, Set<String> Function()? active}) => FreeSpaceService(
    tracks: repo, index: index, deleter: deleter, playingIds: playing, activeKeys: active, scanRunning: scan, nowMs: () => _now);

  test('candidates: only files the app downloaded, unplayed for 90 days first', () async {
    final recent = await add('recent.mp3', vid: 'r', lastPlayed: _now - 10 * _day, size: 99);
    final old = await add('old.mp3', vid: 'o', lastPlayed: _now - 100 * _day);
    final never = await add('never.mp3', vid: 'n');
    await add('mine.mp3'); // not downloaded by the app
    final c = await svc().freeSpaceCandidates();
    expect(c.map((e) => e.track.id), [old, never, recent]);
    expect(c.map((e) => e.stale), [true, true, false]);
  });

  test('a downloaded file whose tags were then written is a candidate once its signature is refreshed', () async {
    final id = await add('tagged.mp3', vid: 't');
    final path = (await repo.getById(id))!.path;
    File(path).writeAsBytesSync([1, 2, 3, 4]); // the tagger rewrote it
    expect(await svc().freeSpaceCandidates(), isEmpty, reason: 'size and mtime no longer match');
    await index.refreshSignatureByPath(path);
    expect((await svc().freeSpaceCandidates()).map((e) => e.track.id), [id]);
    final reloaded = DownloadIndex(File(p.join(dir.path, 'downloads.json')));
    await reloaded.load();
    expect(reloaded.signatureMatches('youtube:t', path), true, reason: 'persisted');
  });

  test('a legacy entry without a signature (a user file at that path) is never a candidate', () async {
    final id = await add('u.m4a');
    final path = (await repo.getById(id))!.path;
    File(p.join(dir.path, 'downloads.json')).writeAsStringSync('{"dQw4w9WgXcQ":"$path"}'); // bare id, no signature
    index = DownloadIndex(File(p.join(dir.path, 'downloads.json')));
    await index.load();
    expect(await svc().freeSpaceCandidates(), isEmpty);
    expect((await svc().freeSpace([id])).freedIds, isEmpty);
    expect(File(path).existsSync(), true);
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

  test('a song with a download queued or running is not freed (the download would write the file back)', () async {
    final id = await add('a.mp3', vid: 'a');
    expect(await svc(active: () => {'youtube:a'}).freeSpaceCandidates(), isEmpty);
    expect((await svc(active: () => {'youtube:a'}).freeSpace([id])).freedIds, isEmpty);
    expect((await svc(active: () => {'youtube:other'}).freeSpace([id])).freedIds, [id]);
  });

  test('ids that are not candidates are ignored', () async {
    final mine = await add('mine.mp3');
    final r = await svc().freeSpace([mine]);
    expect(r.freedIds, isEmpty);
    expect((await repo.getById(mine))!.kind, 0);
    expect(File((await repo.getById(mine))!.path).existsSync(), true);
  });

  test('a user file put at a stale index path is not offered nor deleted', () async {
    final id = await add('a.mp3', vid: 'a');
    final path = (await repo.getById(id))!.path;
    File(path).writeAsBytesSync([1, 2, 3, 4]); // the user's own file, same name, other size
    expect(await svc().freeSpaceCandidates(), isEmpty);
    expect((await svc().freeSpace([id])).freedIds, isEmpty);
    expect(File(path).existsSync(), true);
    expect((await repo.getById(id))!.kind, 0);
  });

  test('index entries whose file is gone are dropped', () async {
    final id = await add('a.mp3', vid: 'a');
    File((await repo.getById(id))!.path).deleteSync();
    await svc().freeSpaceCandidates();
    expect(index.entries, isEmpty);
  });

  test('the playing track is excluded', () async {
    final id = await add('a.mp3', vid: 'a');
    final s = svc(playing: () => {id});
    expect(await s.freeSpaceCandidates(), isEmpty);
    expect((await s.freeSpace([id])).freedIds, isEmpty);
  });

  test('nothing is freed while a scan runs', () async {
    final id = await add('a.mp3', vid: 'a');
    final r = await svc(scan: () => true).freeSpace([id]);
    expect([r.freedIds, File((await repo.getById(id))!.path).existsSync()], [isEmpty, true]);
  });

  test('a streamed copy of the same track is merged, not a failure', () async {
    final id = await add('a.mp3', vid: 'a');
    final shadow = await repo.ensureStreamRow(YtResult(id: 'a', title: 'S', channel: 'C', duration: null));
    final r = await svc().freeSpace([id]);
    expect(r.freedIds, [id]);
    expect(await repo.getById(shadow), equals(null));
  });

  test('two index keys on one path: one candidate, both entries removed', () async {
    final id = await add('a.mp3', vid: 'a');
    await index.add('a2', (await repo.getById(id))!.path);
    expect(await svc().freeSpaceCandidates(), hasLength(1));
    await svc().freeSpace([id]);
    expect(index.entries, isEmpty);
  });

  test('a restore that collides does not stop the rest', () async {
    final a = await add('a.mp3', vid: 'a', size: 99);
    final b = await add('b.mp3', vid: 'b');
    final pathA = (await repo.getById(a))!.path;
    final r = await svc(deleter: (f) async {
      if (f == pathA) {
        // a scan put a new row at the path while the file stays
        await db.into(db.tracks).insert(TracksCompanion.insert(
          path: pathA, title: 'x', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1));
        throw const FileSystemException('no');
      }
      await File(f).delete();
    }).freeSpace([a, b]);
    expect(r.freedIds, [b]);
  });
}
