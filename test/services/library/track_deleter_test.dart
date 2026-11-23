import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/library/duplicate_cleanup.dart';
import 'package:codecore/services/library/track_deleter.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late TrackRepository repo;
  late Directory dir;
  late List<Set<int>> queueCalls;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TrackRepository(db);
    dir = Directory.systemTemp.createTempSync('deltrack');
    queueCalls = [];
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  /// A library row; with [onDisk] false its file does not exist.
  Future<Track> track(String name, {bool onDisk = true, int kind = 0}) async {
    final path = p.join(dir.path, name);
    if (onDisk) File(path).writeAsBytesSync([1, 2, 3]);
    final id = await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            path: path,
            title: name,
            albumKey: 'k',
            format: 'mp3',
            sizeBytes: 3,
            mtimeMs: 1,
            addedAt: 1,
            kind: Value(kind),
          ),
        );
    return (await repo.getById(id))!;
  }

  TrackDeleter deleter({FileDeleter? files, PlatformDeleter? platform}) =>
      TrackDeleter(
        db: db,
        tracks: repo,
        removeFromQueue: (ids) async => queueCalls.add(ids),
        deleter: files,
        platform: platform,
      );

  Future<int> rows() async => (await db.select(db.tracks).get()).length;

  test(
    'deletes the file and the row, and its playlist entry with it',
    () async {
      final t = await track('a.mp3');
      final other = await track('b.mp3');
      final lists = PlaylistRepository(db);
      final pl = await lists.create('P');
      await lists.addTracks(pl, [t.id, other.id]);

      final r = await deleter().deleteTracks([t]);

      expect(r.deleted.map((x) => x.id), [t.id]);
      expect(File(t.path).existsSync(), isFalse);
      expect(await repo.getById(t.id), isNull);
      expect((await db.select(db.playlistTracks).get()).map((e) => e.trackId), [
        other.id,
      ]);
      expect(queueCalls, [
        {t.id},
      ]);
    },
  );

  test(
    'a file already gone counts as deleted without calling the deleter',
    () async {
      final t = await track('gone.mp3', onDisk: false);
      var calls = 0;

      final r = await deleter(files: (_) async => calls++).deleteTracks([t]);

      expect(r.deleted, hasLength(1));
      expect(calls, 0);
      expect(await rows(), 0);
    },
  );

  test('onDeleted that throws: the report is there anyway', () async {
    final t = await track('a.mp3');
    final r = await TrackDeleter(
      tracks: repo,
      removeFromQueue: (ids) async {},
      onDeleted: (gone) async => throw StateError('boom'),
    ).deleteTracks([t]);
    expect(r.deleted.map((x) => x.id), [t.id]);
    expect(await repo.getById(t.id), isNull);
  });

  test('a failure keeps that row with the reason; the others go on', () async {
    final bad = await track('bad.mp3');
    final good = await track('good.mp3');
    final r = await deleter(
      files: (path) async {
        if (path == bad.path) {
          throw FileSystemException('x', path, const OSError('Read-only', 30));
        }
        await File(path).delete();
      },
    ).deleteTracks([bad, good]);

    expect(r.deleted.map((x) => x.id), [good.id]);
    expect(r.failed[bad], 'Read-only');
    expect(await repo.getById(bad.id), isNotNull);
    expect(File(bad.path).existsSync(), isTrue);
    expect(await repo.getById(good.id), isNull);
  });

  test('files still there after any failure go to the platform deleter in one call', () async {
    final a = await track('a.mp3');
    final b = await track('b.mp3');
    final c = await track('c.mp3');
    final calls = <List<String>>[];

    final r = await deleter(
      files: (path) async {
        if (path == c.path) {
          await File(path).delete();
          return;
        }
        // Android's FUSE answers ENOENT for a file it will not let us delete.
        throw PathNotFoundException(
          path,
          const OSError('No such file or directory', 2),
        );
      },
      platform: (paths) async {
        calls.add(paths);
        // The user accepts for one file only.
        await File(a.path).delete();
        return [a.path];
      },
    ).deleteTracks([a, b, c]);

    expect(calls, [
      [a.path, b.path],
    ]);
    expect(r.deleted.map((x) => x.id), [c.id, a.id]);
    expect(r.failed.keys.map((x) => x.id), [b.id]);
    expect(r.refused.map((x) => x.id), [b.id], reason: 'refused at the dialog');
    expect(await repo.getById(b.id), isNotNull);
    expect(await rows(), 1);
  });

  test('onDeleted is called once when something went, never when nothing did', () async {
    var calls = 0;
    TrackDeleter d() => TrackDeleter(
      tracks: repo,
      removeFromQueue: (_) async {},
      deleter: (_) async => throw const FileSystemException('denied'),
      onDeleted: (_) async => calls++,
    );
    final stuck = await track('stuck.mp3');
    await d().deleteTracks([stuck]);
    expect(calls, 0, reason: 'the delete failed');

    final gone = await track('gone.mp3', onDisk: false);
    final gone2 = await track('gone2.mp3', onDisk: false);
    await d().deleteTracks([gone, gone2]);
    expect(calls, 1);
  });

  test('podcast episodes are left alone', () async {
    final ep = await track('ep.mp3', kind: 1);

    final r = await deleter().deleteTracks([ep]);

    expect(r.deleted, isEmpty);
    expect(File(ep.path).existsSync(), isTrue);
    expect(queueCalls, isEmpty);
  });

  test('deleting a downloaded album drops its empty technical playlist and empty folders, never a root', () async {
    final root = p.join(dir.path, 'Music');
    final albumDir = Directory(p.join(root, 'Artist - Album'))..createSync(recursive: true);
    await db.into(db.folders).insert(FoldersCompanion.insert(path: root, addedAt: 1));
    final path = p.join(albumDir.path, 'a.mp3');
    File(path).writeAsBytesSync([1]);
    final id = await db.into(db.tracks).insert(TracksCompanion.insert(
        path: path, title: 'a', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1));
    final lists = PlaylistRepository(db);
    final tech = await lists.create('Album');
    await lists.addTracks(tech, [id]);
    final imp = await db.into(db.playlistImports).insert(PlaylistImportsCompanion.insert(
        playlistId: tech, sourceName: 'Album', createdAt: 1, sourceKind: const Value('ytm-album')));
    SharedPreferences.setMockInitialValues({'importDownloadToo.$imp': true});
    final other = await lists.create('Mine');

    await deleter().deleteTracks([(await repo.getById(id))!]);

    expect(albumDir.existsSync(), isFalse);
    expect(Directory(root).existsSync(), isTrue, reason: 'a library root stays');
    expect(await db.select(db.playlistImports).get(), isEmpty);
    expect((await db.select(db.playlists).get()).map((x) => x.id), [other]);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty, reason: 'its «scarica anche» key goes too');
  });
}
