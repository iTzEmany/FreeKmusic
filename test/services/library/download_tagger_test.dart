import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/library/download_tagger.dart';
import 'package:codecore/services/library/pending_tags.dart';
import 'package:codecore/services/library/track_file_sync.dart';
import 'package:codecore/services/tags/safe_tag_writer.dart';
import 'package:codecore/services/tags/tag_backups.dart';
import 'package:codecore/services/tags/tag_reader.dart';
import 'package:codecore/services/tags/tag_writer.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// A "file" is a JSON map of its tags; the fake reader and writer share it.
Map<String, Object?> _tags(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

class _Reader implements TagReader {
  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async {
    final m = _tags(path);
    return TagInfo(
      title: m['title'] as String?,
      artist: m['artist'] as String?,
      album: m['album'] as String?,
      year: m['year'] as int?,
      genre: m['genre'] as String?,
      trackNumber: m['track'] as int?,
      discNumber: m['disc'] as int?,
      coverBytes: m['cover'] == null ? null : [1],
      durationMs: 1000,
    );
  }
}

class _Writer implements TagWriter {
  int calls = 0;

  @override
  bool supports(String format) => format == 'mp3';

  @override
  Future<void> write(String path, TagChanges c) async {
    calls++;
    final m = _tags(path);
    void put(String k, Object? v) {
      if (v != null) m[k] = v;
    }

    put('title', c.title);
    put('artist', c.artist);
    put('album', c.album);
    put('year', c.year);
    put('genre', c.genre);
    put('track', c.trackNumber);
    put('disc', c.discNumber);
    put('cover', c.cover?.bytes.length);
    File(path).writeAsStringSync(jsonEncode(m));
  }
}

void main() {
  late Directory root, music;
  late AppDatabase db;
  late _Writer writer;
  late bool enabled;
  var installFails = false;
  final failed = <TagWriteReason>[];
  late String? playing;
  late StreamController<String?> playingStream;
  late DownloadTagger tagger;

  // A new tagger over the same files and pending list = an app restart.
  DownloadTagger make() {
    final tracks = TrackRepository(db);
    return DownloadTagger(
      trackById: tracks.getById,
      trackByPath: tracks.byPath,
      pending: PendingTags(() async => File(p.join(root.path, 'pending.json'))),
      sync: TrackFileSync(
        db,
        () async => SafeTagWriter(
          writer: writer,
          reader: _Reader(),
          workDir: Directory(p.join(root.path, 'work')),
          backups: TagBackupStore(Directory(p.join(root.path, 'bk'))),
          install: (a, b) async {
            if (installFails) throw const FileSystemException('refused');
            await installFile(a, b);
          },
        ),
      ),
      onFailed: (t, why) async => failed.add(why),
      reader: _Reader(),
      downloadRoot: () async => music.path,
      enabled: () => enabled,
      coverOf: (_) async => const TagCover([1, 2, 3], 'image/jpeg'),
      playingPath: () => playing,
      playingChanges: playingStream.stream,
    );
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('dtag');
    music = Directory(p.join(root.path, 'Music'))..createSync();
    db = AppDatabase(NativeDatabase.memory());
    writer = _Writer();
    enabled = true;
    installFails = false;
    failed.clear();
    playing = null;
    playingStream = StreamController<String?>.broadcast();
    tagger = make();
  });
  tearDown(() async {
    tagger.dispose();
    await playingStream.close();
    await db.close();
    root.deleteSync(recursive: true);
  });

  Future<Track> add(String dir, String name) async {
    final path = p.join(dir, name);
    File(path).writeAsStringSync(jsonEncode({'title': 'Old'}));
    await TrackRepository(db).upsertBatch([
      TracksCompanion.insert(
        path: path,
        title: 'Poetica',
        albumKey: 'k',
        format: p.extension(name).substring(1),
        artist: const Value('Cesare Cremonini'),
        album: const Value('Poetica'),
        year: const Value(2020),
        genre: const Value('Pop'),
        trackNumber: const Value(3),
        discNumber: const Value(2),
        isrc: const Value('ITABC2000001'),
        sizeBytes: 1,
        mtimeMs: 1,
        addedAt: 1,
        sha256: const Value('abc'),
      ),
    ]);
    return (await TrackRepository(db).byPath(path))!;
  }

  test('writes every field and the cover into a file inside downloads, no ISRC', () async {
    final t = await add(music.path, 'a.mp3');
    await tagger.tag(t.id);
    final m = _tags(t.path);
    expect(m, {
      'title': 'Poetica',
      'artist': 'Cesare Cremonini',
      'album': 'Poetica',
      'year': 2020,
      'genre': 'Pop',
      'track': 3,
      'disc': 2,
      'cover': 3,
    });
  });

  test('never writes a file outside the download folder', () async {
    final other = Directory(p.join(root.path, 'Other'))..createSync();
    final t = await add(other.path, 'a.mp3');
    await tagger.tag(t.id);
    expect(writer.calls, 0);
  });

  test('writes nothing when the option is off', () async {
    enabled = false;
    final t = await add(music.path, 'a.mp3');
    await tagger.tag(t.id);
    expect(writer.calls, 0);
  });

  test('a refused install is reported, not swallowed', () async {
    final t = await add(music.path, 'a.mp3');
    installFails = true;
    await tagger.tag(t.id);
    expect(failed, [TagWriteReason.ioError]);
    expect(_tags(t.path)['title'], 'Old');
  });

  test('an unwritable format (opus) is left alone without an error', () async {
    final t = await add(music.path, 'a.opus');
    await tagger.tag(t.id);
    expect(writer.calls, 0);
  });

  test('size and date are updated and the hash is cleared', () async {
    final t = await add(music.path, 'a.mp3');
    await tagger.tag(t.id);
    final row = (await TrackRepository(db).getById(t.id))!;
    expect(row.sizeBytes, File(t.path).lengthSync());
    expect(row.mtimeMs, isNot(1));
    expect(row.sha256, isNull);
  });

  test('a playing file is written after the song changes', () async {
    final t = await add(music.path, 'a.mp3');
    playing = t.path;
    await tagger.tag(t.id);
    expect(writer.calls, 0);
    playing = null;
    playingStream.add(null);
    // The deferred write is not awaitable: wait until its stamp is stored.
    final end = DateTime.now().add(const Duration(seconds: 5));
    while (writer.calls < 1 && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(writer.calls, 1);
    expect(_tags(t.path)['title'], 'Poetica');
  });

  test('a file that already has the tags is not rewritten, and no backup is made', () async {
    final t = await add(music.path, 'a.mp3');
    await tagger.tag(t.id);
    await tagger.tag(t.id);
    expect(writer.calls, 1);
    final bk = Directory(p.join(root.path, 'bk'));
    expect(bk.existsSync() ? bk.listSync() : [], isEmpty);
  });

  test('two requests for the same file make one write', () async {
    final t = await add(music.path, 'a.mp3');
    await Future.wait([tagger.tag(t.id), tagger.tag(t.id)]);
    expect(writer.calls, 1);
  });

  test('a hand-picked cover is never written into the file', () async {
    final t = await add(music.path, 'm.mp3');
    await (db.update(db.tracks)..where((r) => r.id.equals(t.id)))
        .write(const TracksCompanion(coverKey: Value('manual:track:1:1'), coverSource: Value(2)));
    await tagger.tag(t.id);
    final m = _tags(t.path);
    expect(m['title'], 'Poetica');
    expect(m.containsKey('cover'), isFalse);
  });

  group('pending tags survive a restart', () {
    test('an untagged download is tagged by the next run', () async {
      final t = await add(music.path, 'a.mp3');
      await tagger.markPending(t.id); // the app dies before tag() ends
      tagger.dispose();
      tagger = make();
      await tagger.resumePending();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(_tags(t.path)['artist'], 'Cesare Cremonini');
    });

    test('a tagged file is not run again and a failure is not retried', () async {
      final t = await add(music.path, 'a.mp3');
      await tagger.markPending(t.id);
      installFails = true;
      await tagger.tag(t.id); // refused for good
      installFails = false;
      tagger = make();
      await tagger.resumePending();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(writer.calls, 1);
      expect(_tags(t.path)['title'], 'Old');
    });

    test('resuming twice tags once', () async {
      final t = await add(music.path, 'a.mp3');
      await tagger.markPending(t.id);
      tagger.dispose();
      tagger = make();
      await tagger.resumePending();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      File(t.path).writeAsStringSync(jsonEncode({'title': 'Old'})); // a rewrite would show
      await tagger.resumePending();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(writer.calls, 1);
    });

    test('a path whose switch is off or whose file is gone leaves the pending list', () async {
      final t = await add(music.path, 'a.mp3');
      final gone = await add(music.path, 'b.mp3');
      await tagger.markPending(t.id);
      await tagger.markPending(gone.id);
      File(gone.path).deleteSync();
      enabled = false;
      tagger = make();
      await tagger.resumePending();
      enabled = true;
      expect(await PendingTags(() async => File(p.join(root.path, 'pending.json'))).paths(), isEmpty);
      expect(writer.calls, 0);
    });

    test('markPending never throws', () async {
      await db.close();
      await tagger.markPending(1);
      db = AppDatabase(NativeDatabase.memory()); // tearDown closes it
    });

    test('files never marked (old downloads) are left alone', () async {
      await add(music.path, 'a.mp3');
      await tagger.resumePending();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(writer.calls, 0);
    });
  });
}
