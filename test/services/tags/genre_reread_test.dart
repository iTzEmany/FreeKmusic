import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_genre_repository.dart';
import 'package:codecore/services/tags/genre_reread.dart';
import 'package:codecore/services/tags/tag_reader.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _Reader implements TagReader {
  _Reader(this.byPath);
  final Map<String, TagInfo> byPath;
  final reads = <String>[];

  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async {
    reads.add(path);
    return byPath[path] ?? const TagInfo();
  }
}

void main() {
  late AppDatabase db;
  late TrackGenreRepository genres;
  var after = 0;
  var done = false;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    genres = TrackGenreRepository(db);
    after = 0;
    done = false;
  });
  tearDown(() => db.close());

  Future<int> add(String path, {String? genre, bool edited = false, int kind = 0}) => db.into(db.tracks).insert(
    TracksCompanion.insert(
      path: path,
      title: path,
      albumKey: 'k',
      format: 'mp3',
      sizeBytes: 1,
      mtimeMs: 1,
      addedAt: 1,
      genre: Value(genre),
      userEdited: Value(edited),
      kind: Value(kind),
    ),
  );

  GenreReread job(_Reader r, {bool Function()? cancelled, int batch = 2}) => GenreReread(
    genres: genres,
    reader: r,
    waitIdle: () async {},
    loadAfter: () => after,
    saveAfter: (id) => after = id,
    markDone: () => done = true,
    cancelled: cancelled ?? () => false,
    batch: batch,
  );

  test('every genre of the file lands in track_genres, and a second run changes nothing', () async {
    final a = await add('/a', genre: 'Rock');
    final r = _Reader({'/a': const TagInfo(genres: ['Rock', 'Pop', 'Jazz'])});

    final first = await job(r).run();
    expect(await genres.of(a), ['Rock', 'Pop', 'Jazz']);
    expect((first.finished, first.changed), (true, 1));
    expect(done, isTrue);
    expect(after, 0, reason: 'the bookmark goes back to the start');

    final second = await job(r).run();
    expect(await genres.of(a), ['Rock', 'Pop', 'Jazz']);
    expect(second.changed, 0);
    expect((await db.select(db.tracks).getSingle()).genre, 'Rock', reason: 'tracks.genre is not touched');
  });

  test('a track with no genre anywhere gets no rows; one the file cannot give keeps its row genre', () async {
    final none = await add('/none');
    final kept = await add('/kept', genre: 'Soul;Funk');
    await job(_Reader({})).run();
    expect(await genres.of(none), isEmpty);
    expect(await genres.of(kept), ['Soul', 'Funk']);
  });

  test('a hand-edited track is not read, and episodes and missing files are skipped', () async {
    final edited = await add('/edited', genre: 'Mine', edited: true);
    await add('/episode', kind: 1);
    final gone = await add('/gone');
    await (db.update(db.tracks)..where((t) => t.id.equals(gone))).write(const TracksCompanion(missing: Value(true)));
    final r = _Reader({'/edited': const TagInfo(genres: ['File'])});
    await job(r).run();
    expect(await genres.of(edited), ['Mine']);
    expect(r.reads, isEmpty);
  });

  test('a stopped run carries on after the last saved batch and reads no track twice', () async {
    for (var i = 1; i <= 5; i++) {
      await add('/t$i');
    }
    final r = _Reader({for (var i = 1; i <= 5; i++) '/t$i': TagInfo(genres: ['G$i'])});
    // Stops once the second batch (ids 3 and 4) is saved.
    final stopped = await job(r, cancelled: () => after >= 4).run();
    expect(stopped.finished, isFalse);
    expect(r.reads.length, 4);
    expect(done, isFalse);
    expect(after, 4);

    final rest = await job(r).run();
    expect(rest.finished, isTrue);
    expect(r.reads.toSet().length, 5);
    expect(r.reads.length, 5, reason: 'nothing read twice');
    expect(done, isTrue);
    expect(await db.select(db.trackGenres).get(), hasLength(5));
  });
}
