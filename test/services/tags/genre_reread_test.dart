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

class _Racing implements TagReader {
  _Racing(this.inner, this.onRead);
  final _Reader inner;
  final Future<void> Function() onRead;

  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async {
    final info = await inner.read(path, withCover: withCover);
    await onRead();
    return info;
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
    expect(await genres.of(kept), ['Soul', 'Funk'], reason: 'a file with no genre splits the row genre on «;»');
  });

  test('a web genre with a slash and a file with no genre stays whole', () async {
    final a = await add('/a', genre: 'Hip-Hop/Rap');
    await genres.write(a, ['Hip-Hop/Rap']);
    await job(_Reader({})).run();
    expect(await genres.of(a), ['Hip-Hop/Rap']);
    expect((await db.select(db.tracks).getSingle()).genre, 'Hip-Hop/Rap');
  });

  test('a hand-edited genre keeps its spelling in tracks.genre when the file list is used', () async {
    final a = await add('/a', genre: 'rock', edited: true);
    await job(_Reader({'/a': const TagInfo(genres: ['Rock', 'Pop'])})).run();
    expect(await genres.of(a), ['Rock', 'Pop']);
    expect((await db.select(db.tracks).getSingle()).genre, 'rock');
  });

  test('cancelled while waiting for idle: nothing is read', () async {
    await add('/a');
    final r = _Reader({});
    var stop = false;
    await GenreReread(
      genres: genres, reader: r, loadAfter: () => after, saveAfter: (id) => after = id, markDone: () {},
      waitIdle: () async => stop = true,
      cancelled: () => stop,
    ).run();
    expect(r.reads, isEmpty);
  });

  test('a hand-edited track keeps its genre, and the file list is used only when it starts with it', () async {
    final other = await add('/other', genre: 'Mine', edited: true);
    final same = await add('/same', genre: 'rock', edited: true);
    final r = _Reader({
      '/other': const TagInfo(genres: ['File', 'Pop']),
      '/same': const TagInfo(genres: ['Rock', 'Pop']),
    });
    await job(r).run();
    expect(await genres.of(other), ['Mine']);
    expect(await genres.of(same), ['Rock', 'Pop']);
  });

  test('tracks.genre goes back to the first genre on a row not edited by hand', () async {
    final raw = await add('/raw', genre: 'Rock; Pop');
    await job(_Reader({'/raw': const TagInfo(genres: ['Rock', 'Pop'])})).run();
    expect((await (db.select(db.tracks)..where((t) => t.id.equals(raw))).getSingle()).genre, 'Rock');
  });

  test('a genre edited by hand while the files are read is not overwritten', () async {
    final a = await add('/a', genre: 'Old');
    final r = _Reader({'/a': const TagInfo(genres: ['Old', 'Pop'])});
    final racing = _Racing(r, () => (db.update(db.tracks)..where((t) => t.id.equals(a)))
        .write(const TracksCompanion(genre: Value('Mine'), userEdited: Value(true))));
    await GenreReread(
      genres: genres, reader: racing, waitIdle: () async {}, loadAfter: () => after, saveAfter: (id) => after = id, markDone: () {},
    ).run();
    expect(await genres.of(a), ['Mine']);
  });

  test('episodes and missing files are skipped', () async {
    await add('/episode', kind: 1);
    final gone = await add('/gone');
    await (db.update(db.tracks)..where((t) => t.id.equals(gone))).write(const TracksCompanion(missing: Value(true)));
    final r = _Reader({});
    await job(r).run();
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
