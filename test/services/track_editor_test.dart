import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_genre_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/library/track_editor.dart';
import 'package:codecore/services/tags/tag_reader.dart';
import 'package:codecore/core/text_utils.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _Tags implements TagReader {
  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async =>
      const TagInfo(title: 'File Title', artist: 'File Artist', album: 'File Album');
}

class _GenreTags implements TagReader {
  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async =>
      const TagInfo(title: 'T', genre: 'Rock', genres: ['Rock', 'Pop']);
}

void main() {
  late AppDatabase db;
  late TrackRepository repo;
  late TrackEditor editor;

  TracksCompanion row(String title, {int mtime = 1}) => TracksCompanion.insert(
      path: '/m/a.mp3',
      title: title,
      albumKey: 'k',
      format: 'mp3',
      sizeBytes: 1,
      mtimeMs: mtime,
      addedAt: 1,
      artist: const Value('Old'));

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TrackRepository(db);
    editor = TrackEditor(db, _Tags());
  });
  tearDown(() => db.close());

  test('a hand-edited genre rewrites track_genres; an unchanged one leaves the tag list alone', () async {
    await repo.upsertBatch([row('Orig')]);
    final t = (await db.select(db.tracks).get()).single;
    final genres = TrackGenreRepository(db);
    await genres.replace(t.id, ['Rock', 'Pop', 'Soul']);
    await editor.save(t, const TrackEdit(title: 'Orig', genre: 'Rock; Pop'));
    expect(await genres.of(t.id), ['Rock', 'Pop']);
    final again = (await db.select(db.tracks).get()).single;
    await genres.replace(t.id, ['Rock', 'Pop', 'Soul']);
    await editor.save(again, const TrackEdit(title: 'Orig again', genre: 'Rock; Pop'));
    expect(await genres.of(t.id), ['Rock', 'Pop', 'Soul']);
    await editor.save(again, const TrackEdit(title: 'Orig again'));
    expect(await genres.of(t.id), isEmpty);
  });

  test('edit survives rescan (unchanged and modified file)', () async {
    await repo.upsertBatch([row('Orig')]);
    var t = (await db.select(db.tracks).get()).single;
    await editor.save(
        t, const TrackEdit(title: 'Unknown Pleasures', artist: 'Joy', album: 'Alb'));
    await repo.upsertBatch([row('FromFile', mtime: 5)]);
    t = (await db.select(db.tracks).get()).single;
    expect(t.title, 'Unknown Pleasures');
    expect(t.artist, 'Joy');
    expect(t.albumKey, 'joy|alb');
    expect(t.userEdited, true);
  });

  test('restore from file puts every genre of the file in track_genres', () async {
    await repo.upsertBatch([row('Orig')]);
    final t = (await db.select(db.tracks).get()).single;
    await TrackEditor(db, _GenreTags()).restoreFromFile(t);
    expect(await TrackGenreRepository(db).of(t.id), ['Rock', 'Pop']);
  });

  test('restore from file clears userEdited', () async {
    await repo.upsertBatch([row('Orig')]);
    var t = (await db.select(db.tracks).get()).single;
    await editor.save(t, const TrackEdit(title: 'X'));
    t = (await db.select(db.tracks).get()).single;
    await editor.restoreFromFile(t);
    t = (await db.select(db.tracks).get()).single;
    expect(t.title, 'File Title');
    expect(t.userEdited, false);
  });

  group('saveMany', () {
    TracksCompanion album(String path, String title, String artist, String albumName,
            {String? albumArtist, String? cover}) =>
        TracksCompanion.insert(
          path: path,
          title: title,
          albumKey: computeAlbumKey(
              albumArtist: albumArtist, artist: artist, album: albumName, directory: '/m'),
          format: 'mp3',
          sizeBytes: 1,
          mtimeMs: 1,
          addedAt: 1,
          artist: Value(artist),
          album: Value(albumName),
          albumArtist: Value(albumArtist),
          hasCover: Value(cover != null),
          coverKey: Value(cover),
        );

    Future<List<Track>> all() => (db.select(db.tracks)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();

    test('two albums with different keys end up with one key and the main cover', () async {
      await repo.upsertBatch([
        album('/m/1.mp3', 'One', 'Queen', 'Greatest Hits', cover: 'main'),
        album('/m/2.mp3', 'Two', 'Queen', 'Greatest Hits', cover: 'main'),
        album('/m/3.mp3', 'Three', 'Queen & Friends', 'Greatest Hits (Remaster)', cover: 'other'),
      ]);
      final before = await all();
      expect({for (final t in before) t.albumKey}, hasLength(2));

      await editor.saveMany(before,
          album: 'Greatest Hits', albumArtist: 'Queen', cover: (hasCover: true, coverKey: 'main'));

      final after = await all();
      expect({for (final t in after) t.albumKey}, {'queen|greatest hits'});
      expect(after.map((t) => t.coverKey), everyElement('main'));
      expect(after.map((t) => t.userEdited), everyElement(isTrue));
      expect(after.map((t) => t.artist), ['Queen', 'Queen', 'Queen & Friends'], reason: 'the track artist is untouched');
    });

    test('moving some tracks out of an album makes two albums; a name that exists merges', () async {
      await repo.upsertBatch([
        album('/m/1.mp3', 'One', 'Band', 'Live'),
        album('/m/2.mp3', 'Two', 'Band', 'Live'),
        album('/m/3.mp3', 'Three', 'Band', 'Live'),
      ]);
      final tracks = await all();

      await editor.saveMany([tracks[2]], album: 'Bonus', albumArtist: 'Band');
      expect({for (final t in await all()) t.albumKey}, {'band|live', 'band|bonus'});

      await editor.saveMany([tracks[2]], album: 'live', albumArtist: 'BAND');
      expect({for (final t in await all()) t.albumKey}, {'band|live'});
    });

    test('restoreMany puts every field back, including a track that was not edited', () async {
      await repo.upsertBatch([
        album('/m/1.mp3', 'One', 'Queen', 'A', cover: 'c1'),
        album('/m/2.mp3', 'Two', 'Queen', 'B', cover: 'c2'),
      ]);
      final before = await all();

      final snapshot = await editor.saveMany(before,
          album: 'A', albumArtist: 'Queen', cover: (hasCover: true, coverKey: 'c1'));
      await editor.restoreMany(snapshot);

      final after = await all();
      expect(after.map((t) => t.albumKey), before.map((t) => t.albumKey));
      expect(after.map((t) => t.album), ['A', 'B']);
      expect(after.map((t) => t.coverKey), ['c1', 'c2']);
      expect(after.map((t) => t.userEdited), everyElement(isFalse));
    });

    test('an edit made this way survives a rescan', () async {
      await repo.upsertBatch([album('/m/1.mp3', 'One', 'Band', 'Old')]);
      await editor.saveMany(await all(), album: 'New', albumArtist: 'Band');
      await repo.upsertBatch([album('/m/1.mp3', 'One', 'Band', 'Old').copyWith(mtimeMs: const Value(9))]);
      expect((await all()).single.albumKey, 'band|new');
    });
  });

  group('hand-picked covers', () {
    TracksCompanion r(String path, String albumKey, {String? cover}) => TracksCompanion.insert(
        path: path,
        title: path,
        albumKey: albumKey,
        format: 'mp3',
        sizeBytes: 1,
        mtimeMs: 1,
        addedAt: 1,
        artist: const Value('Band'),
        album: Value(albumKey),
        hasCover: Value(cover != null),
        coverKey: Value(cover));
    Future<Track> at(String path) => repo.byPath(path).then((t) => t!);

    test('merging with a main cover leaves track covers alone and sets the source; undo restores it', () async {
      await repo.upsertBatch([r('/m/1.mp3', 'x', cover: 'auto-x'), r('/m/2.mp3', 'x', cover: 'auto-x'), r('/m/3.mp3', 'y', cover: 'auto-y')]);
      await repo.setManualCover((await at('/m/2.mp3')).id, 'mine');
      await repo.setManualAlbumCover('y', 'pick-y');
      final before = [await at('/m/1.mp3'), await at('/m/2.mp3'), await at('/m/3.mp3')];
      final saved = await editor.saveMany(before,
          album: 'x', albumArtist: '', cover: (hasCover: true, coverKey: 'pick-y'));
      expect([for (final p in ['/m/1.mp3', '/m/2.mp3', '/m/3.mp3']) (await at(p)).coverKey], ['pick-y', 'mine', 'pick-y']);
      expect([for (final p in ['/m/1.mp3', '/m/2.mp3', '/m/3.mp3']) (await at(p)).coverSource], [1, 2, 1]);
      await editor.restoreMany(saved);
      expect([for (final p in ['/m/1.mp3', '/m/3.mp3']) (await at(p)).coverSource], [0, 1]);
      expect((await at('/m/1.mp3')).coverKey, 'auto-x');
    });

    final zKey = computeAlbumKey(albumArtist: null, artist: 'Band', album: 'z', directory: '/m');

    test('a row with an album cover that moves to another album takes that album\'s cover', () async {
      await repo.upsertBatch([r('/m/1.mp3', 'x', cover: 'auto-x'), r('/m/2.mp3', 'x', cover: 'auto-x'), r('/m/3.mp3', zKey, cover: 'auto-z')]);
      await repo.setManualAlbumCover('x', 'pick-x');
      await editor.saveMany([await at('/m/1.mp3')], album: 'z', albumArtist: '');
      final moved = await at('/m/1.mp3');
      expect([moved.albumKey, moved.coverKey, moved.coverSource], [zKey, 'auto-z', 0]);
      expect((await at('/m/2.mp3')).coverSource, 1);
    });
    String keyOf(String artist, String album) =>
        computeAlbumKey(albumArtist: null, artist: artist, album: album, directory: '/m');

    test('restoreFromFile moves an album-cover row out of the album and leaves the pick behind', () async {
      await repo.upsertBatch([r('/m/1.mp3', 'x', cover: 'auto-x'), r('/m/2.mp3', 'x', cover: 'auto-x')]);
      await repo.setManualAlbumCover('x', 'pick-x');
      await editor.restoreFromFile(await at('/m/1.mp3'));
      final t = await at('/m/1.mp3');
      expect(t.albumKey, keyOf('File Artist', 'File Album'));
      expect([t.coverKey, t.coverSource], isNot(['pick-x', 1]));
      expect((await at('/m/2.mp3')).coverKey, 'pick-x');
    });

    test('save() to another album takes that album\'s automatic cover', () async {
      await repo.upsertBatch([r('/m/1.mp3', 'x', cover: 'auto-x'), r('/m/2.mp3', 'x', cover: 'auto-x'), r('/m/3.mp3', keyOf('Band', 'other'), cover: 'auto-o')]);
      await repo.setManualAlbumCover('x', 'pick-x');
      await editor.save(await at('/m/1.mp3'), const TrackEdit(title: 't', artist: 'Band', album: 'other'));
      final t = await at('/m/1.mp3');
      expect([t.coverKey, t.coverSource], ['auto-o', 0]);
    });

    test('saveMany into an album with a hand-picked cover takes that pick', () async {
      final zk = keyOf('Band', 'zk');
      await repo.upsertBatch([r('/m/1.mp3', 'x', cover: 'auto-x'), r('/m/2.mp3', 'x', cover: 'auto-x'), r('/m/3.mp3', zk, cover: 'az')]);
      await repo.setManualAlbumCover('x', 'pick-x');
      await repo.setManualAlbumCover(zk, 'pick-z');
      await editor.saveMany([await at('/m/1.mp3')], album: 'zk', albumArtist: '');
      final t = await at('/m/1.mp3');
      expect([t.coverKey, t.coverSource], ['pick-z', 1]);
    });
  });
}
