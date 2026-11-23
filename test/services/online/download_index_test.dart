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
}
