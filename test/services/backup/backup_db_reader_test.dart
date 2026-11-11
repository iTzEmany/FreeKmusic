import 'dart:io';

import 'package:codecore/services/backup/backup_db_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('reader'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('an old schema with missing tables and columns reads without throwing', () {
    final f = File('${dir.path}/old.sqlite');
    final db = sqlite3.open(f.path);
    db.execute('CREATE TABLE folders (id INTEGER PRIMARY KEY, path TEXT)');
    db.execute('CREATE TABLE tracks (id INTEGER PRIMARY KEY, path TEXT, folder_id INTEGER, title TEXT)');
    db.execute("INSERT INTO folders VALUES (1, '/music')");
    db.execute("INSERT INTO tracks VALUES (7, '/music/a/x.mp3', 1, 'X')");
    db.close();

    final d = readBackupDb(f);
    expect(d.plays, isEmpty);
    expect(d.podcasts, isEmpty);
    expect(d.tracks.single['cover_key'], isNull);
    final ref = d.refs[7]!;
    expect((ref.folder, ref.relPath, ref.title), ('/music', 'a/x.mp3', 'X'));
  });

  test('a stream shadow row becomes a stream reference', () {
    final f = File('${dir.path}/s.sqlite');
    final db = sqlite3.open(f.path);
    db.execute('CREATE TABLE tracks (id INTEGER PRIMARY KEY, path TEXT, title TEXT, kind INTEGER)');
    db.execute("INSERT INTO tracks VALUES (1, 'stream:ytm:abc#cc-ep=2', 'S', 2)");
    db.close();
    expect(readBackupDb(f).refs[1]!.streamKey, 'ytm:abc');
  });

  test('an unreadable file gives empty data', () {
    final f = File('${dir.path}/none.sqlite');
    final d = readBackupDb(f);
    expect(d.refs, isEmpty);
    expect(d.error, isNotNull, reason: 'the caller logs it: AppLog is lost in another isolate');
  });
}
