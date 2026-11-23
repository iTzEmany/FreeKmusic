import 'dart:io';

import 'package:codecore/services/online/download_index.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('add writes atomically: valid file, no .tmp left, reloadable', () async {
    final tmp = Directory.systemTemp.createTempSync('dl_idx');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final song = File(p.join(tmp.path, 's.m4a'))..writeAsStringSync('x');
    final file = File(p.join(tmp.path, 'downloads.json'));
    final idx = DownloadIndex(file);
    await Future.wait([for (var i = 0; i < 5; i++) idx.add('id$i', song.path)]);
    expect(File('${file.path}.tmp').existsSync(), isFalse);
    final again = DownloadIndex(file);
    await again.load();
    expect(again.pathFor('id4'), song.path);
    expect(again.pathForKey('youtube:id0'), song.path);
  });

  test('pruneGone keeps an entry that was replaced by a new download meanwhile', () async {
    final tmp = Directory.systemTemp.createTempSync('dl_idx');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final idx = DownloadIndex(File(p.join(tmp.path, 'downloads.json')));
    final fresh = File(p.join(tmp.path, 'new.m4a'))..writeAsStringSync('x');
    await idx.add('id', p.join(tmp.path, 'old.m4a')); // file never existed
    final pruning = idx.pruneGone();
    await idx.add('id', fresh.path); // lands while pruneGone is checking the disk
    await pruning;
    expect(idx.pathForKey('youtube:id'), fresh.path);
  });

  test('removeByPath forgets every entry of a path, also when its folder is gone', () async {
    final tmp = Directory.systemTemp.createTempSync('dl_idx');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final idx = DownloadIndex(File(p.join(tmp.path, 'downloads.json')));
    final gone = p.join(tmp.path, 'album', 'a.m4a'); // its folder does not exist: pruneGone would keep it
    await idx.add('id', gone);
    await idx.pruneGone();
    expect(idx.pathForKey('youtube:id'), gone);
    await idx.removeByPath(gone);
    expect(idx.pathForKey('youtube:id'), isNull);
  });

  test('the state reads the index without touching the disk; the file check is explicit', () async {
    final tmp = Directory.systemTemp.createTempSync('dl_idx');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final song = File(p.join(tmp.path, 's.m4a'))..writeAsStringSync('x');
    final idx = DownloadIndex(File(p.join(tmp.path, 'downloads.json')));
    await idx.add('id', song.path);
    song.deleteSync();
    expect(idx.pathForKey('youtube:id'), song.path, reason: 'memory is the truth for the UI');
    expect(await idx.existingPathForKey('youtube:id'), isNull, reason: 'playback checks the file');
    await idx.pruneGone();
    expect(idx.pathForKey('youtube:id'), isNull);
  });

  test(
    'removeByPaths forgets only the given paths, with one reload-proof write',
    () async {
      final tmp = Directory.systemTemp.createTempSync('dl_idx');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final file = File(p.join(tmp.path, 'downloads.json'));
      final idx = DownloadIndex(file);
      await idx.add('a', '/m/a.m4a');
      await idx.add('b', '/m/b.m4a');
      await idx.add('c', '/m/c.m4a');
      await idx.removeByPaths(['/m/a.m4a', '/m/c.m4a', '/m/none.m4a']);
      final again = DownloadIndex(file);
      await again.load();
      expect(again.entries.map((e) => e.key), ['youtube:b']);
    },
  );

  test(
    'a legacy bare-id key is found and forgotten through its youtube: key',
    () async {
      final tmp = Directory.systemTemp.createTempSync('dl_idx');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final file = File(p.join(tmp.path, 'downloads.json'))
        ..writeAsStringSync('{"bare":"/m/x.m4a"}');
      final idx = DownloadIndex(file);
      await idx.load();
      expect(idx.pathForKey('youtube:bare'), '/m/x.m4a');
      await idx.remove('youtube:bare');
      expect(idx.pathForKey('youtube:bare'), isNull);
    },
  );

  test('signatureMatches: false for another size, another mtime or a directory; matchesPath needs the same path', () async {
    final tmp = Directory.systemTemp.createTempSync('dl_idx');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final song = File(p.join(tmp.path, 's.m4a'))..writeAsStringSync('xx');
    final idx = DownloadIndex(File(p.join(tmp.path, 'downloads.json')));
    await idx.add('id', song.path);
    expect(await idx.signatureMatches('youtube:id', song.path), isTrue);
    expect(await idx.signatureMatchesPath(song.path), isTrue);
    expect(
      await idx.signatureMatchesPath(p.join(tmp.path, 'other.m4a')),
      isFalse,
    );
    final mtime = song.lastModifiedSync();
    song.setLastModifiedSync(mtime.add(const Duration(seconds: 5)));
    expect(
      await idx.signatureMatches('youtube:id', song.path),
      isFalse,
      reason: 'mtime',
    );
    song.setLastModifiedSync(mtime);
    song.writeAsStringSync('xxx');
    song.setLastModifiedSync(mtime);
    expect(
      await idx.signatureMatches('youtube:id', song.path),
      isFalse,
      reason: 'size',
    );
    final dirPath = p.join(tmp.path, 'd');
    Directory(dirPath).createSync();
    expect(
      await idx.signatureMatches('youtube:id', dirPath),
      isFalse,
      reason: 'a directory',
    );
  });

  test('containsOnDisk forgets a file deleted outside the app, but not when its folder is gone', () async {
    final tmp = Directory.systemTemp.createTempSync('dl_idx');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final song = File(p.join(tmp.path, 's.m4a'))..writeAsStringSync('x');
    final idx = DownloadIndex(File(p.join(tmp.path, 'downloads.json')));
    await idx.add('id', song.path);
    await idx.add('card', p.join(tmp.path, 'sdcard', 'c.m4a'));
    expect(await idx.containsOnDisk('id'), isTrue);
    song.deleteSync();
    expect(await idx.containsOnDisk('id'), isFalse);
    expect(idx.contains('id'), isFalse, reason: 'forgotten');
    expect(await idx.containsOnDisk('card'), isFalse);
    expect(
      idx.contains('card'),
      isTrue,
      reason: 'an unplugged card keeps its entries',
    );
  });
}
