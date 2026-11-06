import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/folder_repository.dart';
import 'package:codecore/data/repositories/track_genre_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/covers/cover_store.dart';
import 'package:codecore/services/scanner/library_scanner.dart';
import 'package:codecore/services/tags/tag_reader.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _Reader implements TagReader {
  _Reader(this.byName);
  final Map<String, TagInfo> byName;

  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async => byName[p.basename(path)] ?? const TagInfo();
}

void main() {
  late Directory tmp;
  late AppDatabase db;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('genres');
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  Future<void> scan(Map<String, TagInfo> tags) async {
    final dir = Directory(p.join(tmp.path, 'music'))..createSync();
    for (final n in tags.keys) {
      File(p.join(dir.path, n)).writeAsBytesSync([0, 1]);
    }
    final folder = await FolderRepository(db).add(dir.path);
    final scanner = LibraryScanner(_Reader(tags), TrackRepository(db), CoverStore(Directory(p.join(tmp.path, 'covers'))), useIsolate: false);
    await scanner.scan(folder).drain<void>();
  }

  test('a file with three genres gets three rows and tracks.genre is the first', () async {
    await scan({
      'a.mp3': const TagInfo(title: 'A', genres: ['Rock', 'Pop', 'Jazz']),
      'b.mp3': const TagInfo(title: 'B'),
    });
    final tracks = await db.select(db.tracks).get();
    final a = tracks.firstWhere((t) => t.title == 'A');
    final b = tracks.firstWhere((t) => t.title == 'B');
    final repo = TrackGenreRepository(db);
    expect(await repo.of(a.id), ['Rock', 'Pop', 'Jazz']);
    expect(a.genre, 'Rock');
    expect(await repo.of(b.id), isEmpty);
    expect(b.genre, isNull);
  });

  test('a changed file replaces its genres', () async {
    await scan({'a.mp3': const TagInfo(title: 'A', genres: ['Rock', 'Pop'])});
    final id = (await db.select(db.tracks).getSingle()).id;
    await TrackRepository(db).upsertBatch(
      [(await db.select(db.tracks).getSingle()).toCompanion(true)],
      genresByPath: {(await db.select(db.tracks).getSingle()).path: ['Jazz']},
    );
    expect(await TrackGenreRepository(db).of(id), ['Jazz']);
  });
}
