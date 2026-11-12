import 'dart:io';

import 'package:codecore/core/text_utils.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/folder_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/covers/cover_store.dart';
import 'package:codecore/services/scanner/library_scanner.dart';
import 'package:codecore/services/scanner/shared_cover_fix.dart';
import 'package:codecore/services/tags/tag_reader.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class _Reader implements TagReader {
  _Reader(this.byName);
  final Map<String, TagInfo> byName;
  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async =>
      byName[p.basename(path)] ?? const TagInfo();
}

void main() {
  late Directory tmp;
  late AppDatabase db;
  late TrackRepository tracks;
  late CoverStore store;
  late _Reader reader;
  late LibraryScanner scanner;

  const pic = TagInfo(coverBytes: [1, 2, 3], coverMime: 'image/jpeg');

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('sharedcover');
    db = AppDatabase(NativeDatabase.memory());
    tracks = TrackRepository(db);
    store = CoverStore(Directory(p.join(tmp.path, 'covers')));
    reader = _Reader({'a.mp3': pic, 'b.mp3': pic});
    scanner = LibraryScanner(reader, tracks, store, useIsolate: false);
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  Directory music() {
    final d = Directory(p.join(tmp.path, 'music'))..createSync();
    for (final n in ['a.mp3', 'b.mp3']) {
      File(p.join(d.path, n)).writeAsBytesSync([0, 1]);
    }
    return d;
  }

  test('untagged files in one folder each keep their own embedded picture', () async {
    reader.byName['a.mp3'] = const TagInfo(coverBytes: [1], coverMime: 'image/jpeg');
    reader.byName['b.mp3'] = const TagInfo(coverBytes: [2], coverMime: 'image/jpeg');
    final d = music();
    final folder = await FolderRepository(db).add(d.path);
    await scanner.scan(folder).drain<void>();
    final rows = await db.select(db.tracks).get();
    expect(rows.every((t) => t.hasCover), true);
    expect(rows.map((t) => t.coverKey).toSet().length, 2);
    expect(rows.any((t) => t.coverKey == CoverStore.coverKeyFor(computeAlbumKey(directory: d.path))), false);
  });

  test('an untagged album folder with cover.jpg still shares its cover', () async {
    reader.byName.clear();
    final d = music();
    File(p.join(d.path, 'cover.jpg')).writeAsBytesSync([7, 7]);
    final folder = await FolderRepository(db).add(d.path);
    await scanner.scan(folder).drain<void>();
    final rows = await db.select(db.tracks).get();
    expect(rows.map((t) => t.coverKey).toSet().length, 1);
    expect(rows.every((t) => t.hasCover), true);
  });

  test('the repair frees a row with the shared key, keeps a manual cover', () async {
    SharedPreferences.setMockInitialValues({});
    final d = music();
    final shared = (await store.saveFromBytes(
      computeAlbumKey(directory: d.path),
      [9, 9],
      'image/jpeg',
    ))!;
    Future<void> add(String name, int source) => tracks.upsertBatch([
          TracksCompanion.insert(
            path: p.join(d.path, name),
            title: name,
            albumKey: 'art|$name',
            format: 'mp3',
            sizeBytes: 2,
            mtimeMs: 1,
            addedAt: 1,
            hasCover: const Value(true),
            coverKey: Value(shared),
            coverSource: Value(source),
          ),
        ]);
    await add('a.mp3', 0);
    await add('b.mp3', 2);
    final n = await SharedCoverFix(
      tracks,
      scanner,
      await SharedPreferences.getInstance(),
    ).runOnce();
    expect(n, 1);
    final a = (await tracks.byPath(p.join(d.path, 'a.mp3')))!;
    final b = (await tracks.byPath(p.join(d.path, 'b.mp3')))!;
    expect(a.coverKey, CoverStore.coverKeyFor('art|a.mp3'));
    expect(b.coverKey, shared);
  });
}
