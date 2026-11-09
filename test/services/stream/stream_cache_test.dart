import 'dart:io';

import 'package:codecore/services/stream/stream_cache.dart';
import 'package:codecore/services/stream/stream_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _mb = 1024 * 1024;

void main() {
  late Directory root;
  late Directory dir;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('stream_cache_test');
    dir = Directory(p.join(root.path, 'stream_cache'));
  });
  tearDown(() => root.delete(recursive: true));

  Future<File> part(String name, int mb) async =>
      File(p.join(root.path, '$name.part'))..writeAsBytesSync(List.filled(mb * _mb, 1));

  StreamCache cache({int limit = 10 * _mb, Future<void> Function(File)? delete}) =>
      StreamCache(dir, limitBytes: limit, freeSpace: () async => null, delete: delete);

  test('key helpers round-trip and reject other paths', () {
    expect(streamPathOf('youtube:abc'), 'stream:youtube:abc');
    expect(keyOfStreamPath('stream:youtube:abc'), 'youtube:abc');
    expect(keyOfStreamPath('/music/a.mp3'), isNull);
    expect(keyOfStreamPath('stream:youtube:abc#cc-ep=7'), 'youtube:abc');
    expect(streamFileName('youtube:abc'), 'youtube_abc');
  });

  // Puts [mb] MB as [key] and stamps its last use, so LRU order is deterministic.
  Future<void> add(StreamCache c, String key, int mb, int age) async {
    final f = await c.put(key, await part('${streamFileName(key)}.m4a', mb));
    await f.setLastModified(DateTime(2026, 1, 1).add(Duration(minutes: age)));
  }

  test('4 files of 4 MB at a 10 MB limit: oldest goes, pinned stays', () async {
    final c = cache();
    await c.open();
    c.pin('a:1'); // the oldest, but playing
    for (var i = 1; i <= 4; i++) {
      await add(c, 'a:$i', 4, i);
    }
    expect(c.usedBytes, lessThanOrEqualTo(10 * _mb));
    expect(await c.fileFor('a:1'), isNotNull);
    expect(await c.fileFor('a:2'), isNull);
    expect(await c.fileFor('a:4'), isNotNull);
  });

  test('without pins the least recently used file goes', () async {
    final c = cache();
    await c.open();
    await add(c, 'a:1', 4, 1);
    await add(c, 'a:2', 4, 2);
    await (await c.fileFor('a:1'))!.setLastModified(DateTime(2026, 2, 1));
    await c.put('a:3', await part('a_3', 4));
    expect(await c.fileFor('a:2'), isNull);
    expect(await c.fileFor('a:1'), isNotNull);
  });

  test('put keeps the extension and replaces the same key', () async {
    final c = cache();
    await c.open();
    await add(c, 'a:1', 1, 1);
    final f = await c.put('a:1', await part('a_1.webm', 1));
    expect(p.extension(f.path), '.webm');
    expect((await c.fileFor('a:1'))!.path, f.path);
    expect(dir.listSync().length, 1);
  });

  test('a pinned key with an extension survives eviction; pins count', () async {
    final c = cache(limit: 1 * _mb);
    await c.open();
    c.pin('a:1');
    c.pin('a:1');
    await add(c, 'a:1', 2, 1); // bigger than the limit, still kept
    c.unpin('a:1');
    await c.evict();
    expect(p.extension((await c.fileFor('a:1'))!.path), '.m4a');
    c.unpin('a:1');
    await c.evict();
    expect(await c.fileFor('a:1'), isNull);
  });

  test('put never evicts the file it just added, even below the margin', () async {
    final c = StreamCache(dir, limitBytes: 100 * _mb, freeSpace: () async => 0);
    await c.open();
    File(p.join(dir.path, 'old_1.m4a'))..createSync(recursive: true)..writeAsBytesSync([1]);
    await c.put('a:1', await part('a_1.m4a', 1));
    expect(await c.fileFor('a:1'), isNotNull);
    expect(File(p.join(dir.path, 'old_1.m4a')).existsSync(), isFalse);
  });

  test('evict measures the folder before computing the limit', () async {
    // Free space shrinks as the folder grows: free = 600 MB - folder size.
    late StreamCache c;
    c = StreamCache(dir, limitBytes: 100 * _mb, freeSpace: () async {
      var used = 0;
      for (final e in dir.listSync()) {
        if (e is File) used += e.lengthSync();
      }
      return 600 * _mb - used;
    });
    await c.open();
    File(p.join(dir.path, 'x_1.m4a'))..createSync(recursive: true)..writeAsBytesSync(List.filled(2 * _mb, 1));
    // c.usedBytes is stale (0); fresh limit = (600-2) + 2 - 500 = 100 MB, so nothing is evicted.
    await c.evict();
    expect(c.usedBytes, 2 * _mb);
    expect(await c.fileFor('x:1'), isNotNull);
  });

  test('free space minus the margin lowers the limit', () async {
    final c = StreamCache(dir, limitBytes: 100 * _mb, freeSpace: () async => StreamCache.freeMargin + 3 * _mb);
    await c.open();
    expect(await c.effectiveLimit(), 3 * _mb);
  });

  test('open deletes .part files and measures the rest', () async {
    await dir.create(recursive: true);
    File(p.join(dir.path, 'x.part')).writeAsBytesSync([1, 2, 3]);
    File(p.join(dir.path, 'a_1')).writeAsBytesSync([1, 2]);
    File(p.join(dir.path, '.dl-a_1', 'y.m4a'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1]);
    final c = cache();
    await c.open();
    expect(File(p.join(dir.path, 'x.part')).existsSync(), isFalse);
    expect(Directory(p.join(dir.path, '.dl-a_1')).existsSync(), isFalse);
    expect(c.usedBytes, 2);
  });

  test('clear(keep) leaves only the kept key', () async {
    final c = cache();
    await c.open();
    await c.put('a:1', await part('a1', 1));
    await c.put('a:2', await part('a2', 1));
    c.pin('a:3');
    await c.put('a:3', await part('a_3', 1));
    await c.clear(keep: {'a:2'});
    expect(await c.fileFor('a:1'), isNull);
    expect(await c.fileFor('a:2'), isNotNull);
    expect(await c.fileFor('a:3'), isNotNull); // pinned
    expect(c.usedBytes, 2 * _mb);
  });

  test('a file that cannot be deleted is kept, then retried at the next evict', () async {
    var fail = true;
    final c = cache(limit: 1 * _mb, delete: (f) async {
      if (fail) throw const FileSystemException('in use');
      await f.delete();
    });
    await c.open();
    await c.put('a:1', await part('a1', 2));
    expect(await c.fileFor('a:1'), isNotNull);
    expect(c.usedBytes, 2 * _mb);
    fail = false;
    await c.evict();
    expect(await c.fileFor('a:1'), isNull);
    expect(c.usedBytes, 0);
  });

  test('effectiveLimit counts the cache bytes as free space', () async {
    final c = StreamCache(dir, limitBytes: 100 * _mb, freeSpace: () async => StreamCache.freeMargin + 3 * _mb);
    await c.open();
    expect(await c.effectiveLimit(2 * _mb), 5 * _mb);
  });

  test('a cache exactly at the limit evicts nothing', () async {
    final c = cache(limit: 4 * _mb);
    await c.open();
    await add(c, 'a:1', 2, 1);
    await add(c, 'a:2', 2, 2);
    await c.evict();
    expect(await c.fileFor('a:1'), isNotNull);
    expect(await c.fileFor('a:2'), isNotNull);
  });

  test('a .part file is neither measured nor evicted', () async {
    final c = cache(limit: 10 * _mb);
    await c.open();
    await add(c, 'a:1', 1, 1);
    final stray = File(p.join(dir.path, 'x.m4a.part'))..writeAsBytesSync(List.filled(20 * _mb, 1));
    await c.evict();
    expect(c.usedBytes, 1 * _mb);
    expect(await c.measure(), 1 * _mb);
    expect(await c.fileFor('a:1'), isNotNull);
    expect(stray.existsSync(), isTrue);
  });

  test('put without trim keeps everything; evict reports what it deletes', () async {
    final c = cache(limit: 1 * _mb);
    await c.open();
    final gone = <String>[];
    c.onEvicted = (f) => gone.add(p.basename(f.path));
    await add(c, 'a:0', 2, 0); // older, unpinned: a trimming put would evict it
    gone.clear();
    await c.put('a:1', await part('a1.m4a', 2), trim: false);
    expect(await c.fileFor('a:0'), isNotNull);
    expect(await c.fileFor('a:1'), isNotNull);
    expect(gone, isEmpty);
    await c.evict();
    expect(gone.first, 'a_0.m4a'); // least recently used first
  });

  test('fileFor follows put, evict and clear', () async {
    final c = cache();
    await c.open();
    await add(c, 'a:1', 1, 1);
    await add(c, 'a:2', 1, 2);
    expect(await c.fileFor('a:1'), isNotNull);
    c.limitBytes = 1 * _mb;
    await c.evict(); // drops a:1, the oldest
    expect(await c.fileFor('a:1'), isNull);
    expect(await c.fileFor('a:2'), isNotNull);
    await c.clear();
    expect(await c.fileFor('a:2'), isNull);
  });

  test('a file deleted behind the cache back: fileFor is null and touch does not throw', () async {
    final c = cache();
    final f = await c.put('a:1', await part('a_1.m4a', 1));
    expect(await c.fileFor('a:1'), isNotNull); // index is warm
    f.deleteSync();
    expect(await c.fileFor('a:1'), isNull);
    await c.touch('a:1');
    // touch racing with the deletion
    final g = await c.put('a:2', await part('a_2.m4a', 1));
    await c.fileFor('a:2');
    g.deleteSync();
    await c.touch('a:2');
  });
}
