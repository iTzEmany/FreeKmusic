import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/library/track_editor.dart';
import 'package:codecore/services/online/youtube_service.dart' show YtResult;
import 'package:codecore/services/library/track_file_sync.dart';
import 'package:codecore/services/tags/safe_tag_writer.dart';
import 'package:codecore/services/tags/tag_backups.dart';
import 'package:codecore/services/tags/tag_reader.dart';
import 'package:codecore/services/tags/tag_writer.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

String _titleOf(String path) {
  final l = File(path).readAsLinesSync();
  return l.length > 1 ? l[1] : '';
}

class _Reader implements TagReader {
  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async =>
      TagInfo(title: _titleOf(path), durationMs: 1000);
}

class _Writer implements TagWriter {
  int calls = 0;

  @override
  bool supports(String format) => format == 'mp3';

  @override
  Future<void> write(String path, TagChanges c) async {
    calls++;
    File(path).writeAsStringSync('AUDIO\n${c.title}');
  }
}

void main() {
  late Directory root;
  late AppDatabase db;
  late _Writer writer;
  late bool enabled;
  late TrackEditor editor;

  setUp(() {
    root = Directory.systemTemp.createTempSync('tedit');
    db = AppDatabase(NativeDatabase.memory());
    writer = _Writer();
    enabled = false;
    editor = TrackEditor(
      db,
      _Reader(),
      files: TrackFileSync(
        db,
        () async => SafeTagWriter(
          writer: writer,
          reader: _Reader(),
          workDir: Directory(p.join(root.path, 'work')),
          backups: TagBackupStore(Directory(p.join(root.path, 'bk'))),
        ),
      ),
      fileWritesEnabled: () => enabled,
    );
  });
  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  Future<Track> add(String name) async {
    final path = p.join(root.path, name);
    File(path).writeAsStringSync('AUDIO\nOld');
    await TrackRepository(db).upsertBatch([
      TracksCompanion.insert(
        path: path,
        title: 'Old',
        albumKey: 'k',
        format: p.extension(name).substring(1),
        sizeBytes: 1,
        mtimeMs: 1,
        addedAt: 1,
        artist: const Value('A'),
      ),
    ]);
    return (db.select(db.tracks)..where((t) => t.path.equals(path))).getSingle();
  }

  const edit = TrackEdit(title: 'New title');

  test('option off: the writer is never called and the file is untouched', () async {
    final t = await add('a.mp3');
    await editor.save(t, edit);
    final out = await editor.writeToFiles([t], (_) => edit.toChanges());
    expect(out.attempted, 0);
    expect(writer.calls, 0);
    expect(_titleOf(t.path), 'Old');
    expect(Directory(p.join(root.path, 'bk')).existsSync(), isFalse);
  });

  test('option on: the file is rewritten and the DB row follows its new size and date', () async {
    final t = await add('a.mp3');
    enabled = true;
    await editor.save(t, edit);
    final out = await editor.writeToFiles([t], (_) => edit.toChanges());
    expect(out.hasFailures, isFalse);
    expect(writer.calls, 1);
    expect(_titleOf(t.path), 'New title');

    final row = await (db.select(db.tracks)..where((r) => r.id.equals(t.id))).getSingle();
    expect(row.title, 'New title');
    expect(row.sizeBytes, File(t.path).lengthSync());
    expect(row.mtimeMs, File(t.path).statSync().modified.millisecondsSinceEpoch);
  });

  test('a file that cannot be written is reported, never thrown, and the DB edit stands', () async {
    final t = await add('b.flac');
    enabled = true;
    await editor.save(t, edit);
    final out = await editor.writeToFiles([t], (_) => edit.toChanges());
    expect(out.failures[t.id], TagWriteReason.unsupported);
    expect(out.mainReason, TagWriteReason.unsupported);
    expect(writer.calls, 0);
    final row = await (db.select(db.tracks)..where((r) => r.id.equals(t.id))).getSingle();
    expect(row.title, 'New title');
    expect(row.sizeBytes, 1, reason: 'file untouched, row untouched');
  });

  test('blank fields are not sent to the file (the tag cannot be erased)', () {
    final c = const TrackEdit(title: ' T ', artist: '  ', album: 'Al', year: 2001).toChanges();
    expect(c.title, 'T');
    expect(c.artist, isNull);
    expect(c.album, 'Al');
    expect(c.year, 2001);
    expect(c.genre, isNull);
  });

  test('a saved stream row: the album key keeps `stream|`, and no tag is written to a file', () async {
    final tracks = TrackRepository(db);
    const r = YtResult(id: 'x', title: 'S', channel: 'C', duration: Duration(seconds: 9), artists: ['Art']);
    final id = (await tracks.saveStream(r))!;
    final row = await (db.select(db.tracks)..where((t) => t.id.equals(id))).getSingle();
    enabled = true;
    await editor.saveMany([row], album: 'Alb', albumArtist: 'AA');
    final after = await (db.select(db.tracks)..where((t) => t.id.equals(id))).getSingle();
    expect(after.albumKey, 'stream|aa|alb');
    final out = await editor.writeToFiles([after], (_) => edit.toChanges());
    expect((out.attempted, writer.calls), (0, 0));
  });
}
