import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

TracksCompanion t(String path, String album, String artist, String key,
        {int? track, String? albumArtist}) =>
    TracksCompanion.insert(
      path: path,
      title: path,
      albumKey: key,
      format: 'mp3',
      sizeBytes: 1,
      mtimeMs: 1,
      addedAt: 1,
      album: Value(album),
      artist: Value(artist),
      albumArtist: Value(albumArtist),
      trackNumber: Value(track),
      durationMs: const Value(1000),
    );

void main() {
  late AppDatabase db;
  late LibraryQueries q;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    q = LibraryQueries(db);
    await TrackRepository(db).upsertBatch([
      t('/1', 'Greatest Hits', 'Queen', 'queen|greatest hits', track: 2),
      t('/2', 'Greatest Hits', 'Queen', 'queen|greatest hits', track: 1),
      t('/3', 'Greatest Hits', 'ABBA', 'abba|greatest hits'),
      t('/4', 'Mix', 'A', 'unknown|/mix'),
      t('/5', 'Mix', 'B', 'unknown|/mix'),
    ]);
  });
  tearDown(() => db.close());

  test('watchCount leaves out missing and hidden tracks, also for favourites', () async {
    final repo = TrackRepository(db);
    final ids = [for (final p in ['/1', '/2', '/3']) (await repo.byPath(p))!.id];
    await repo.setFavoriteMany(ids, true);
    await repo.markMissing({'/1'}, true);
    await repo.setIgnored({ids[1]}, true);
    expect(await repo.watchCount().first, 3);
    expect(await repo.watchCount(favoritesOnly: true).first, 1);
  });

  test('same album name, different artists -> two albums', () async {
    final albums = await q.watchAlbums().first;
    expect(albums.where((a) => a.title == 'Greatest Hits').length, 2);
  });

  test('compilation detected', () async {
    final albums = await q.watchAlbums().first;
    expect(albums.firstWhere((a) => a.title == 'Mix').variousArtists, true);
    expect(albums.firstWhere((a) => a.artist == 'Queen').trackCount, 2);
  });

  test('artists and album tracks order', () async {
    final artists = await q.watchArtists().first;
    expect(artists.map((a) => a.key), ['a', 'abba', 'b', 'queen']);
    final tr = await q.watchAlbumTracks('queen|greatest hits').first;
    expect(tr.map((e) => e.path), ['/2', '/1']);
    final al = await q.watchArtistAlbums('queen').first;
    expect(al.single.albumKey, 'queen|greatest hits');
  });

  test('last played / added are the latest of the album\'s and artist\'s tracks',
      () async {
    await db.customStatement(
        "UPDATE tracks SET last_played_at = 500 WHERE path = '/1'");
    await db.customStatement(
        "UPDATE tracks SET last_played_at = 900, added_at = 77 WHERE path = '/2'");
    final albums = await q.watchAlbums().first;
    final queen = albums.firstWhere((a) => a.artist == 'Queen');
    expect(queen.lastPlayedAt, 900);
    expect(queen.addedAt, 77);
    expect(albums.firstWhere((a) => a.artist == 'ABBA').lastPlayedAt, isNull);
    final artists = await q.watchArtists().first;
    expect(artists.firstWhere((a) => a.key == 'queen').lastPlayedAt, 900);
  });

  test('artist cover is the most frequent cover among their tracks', () async {
    await db.customStatement(
        "UPDATE tracks SET cover_key = 'c1' WHERE path IN ('/1','/2')");
    await db.customStatement("UPDATE tracks SET cover_key = 'c2' WHERE path = '/3'");
    final artists = await q.watchArtists().first;
    expect(artists.firstWhere((a) => a.key == 'queen').coverKey, 'c1');
    expect(artists.firstWhere((a) => a.key == 'abba').coverKey, 'c2');
    expect(artists.firstWhere((a) => a.key == 'a').coverKey, isNull);
  });

  test('album with no hand-picked cover: the lowest cover_key, as before', () async {
    await db.customStatement("UPDATE tracks SET cover_key = 'b' WHERE path = '/1'");
    await db.customStatement("UPDATE tracks SET cover_key = 'a' WHERE path = '/2'");
    final albums = await q.watchAlbums().first;
    expect(albums.firstWhere((a) => a.artist == 'Queen').coverKey, 'a');
  });

  test('album cover picked by hand (cover_source 1) wins over automatic ones', () async {
    await db.customStatement("UPDATE tracks SET cover_key = 'a' WHERE path = '/1'");
    await db.customStatement(
        "UPDATE tracks SET cover_key = 'z', cover_source = 1 WHERE path = '/2'");
    final albums = await q.watchAlbums().first;
    expect(albums.firstWhere((a) => a.artist == 'Queen').coverKey, 'z');
  });

  test('a single track cover (cover_source 2) never becomes album or artist cover', () async {
    await db.customStatement(
        "UPDATE tracks SET cover_key = 'c1' WHERE path = '/1'");
    await db.customStatement(
        "UPDATE tracks SET cover_key = 'a', cover_source = 2 WHERE path = '/2'");
    final albums = await q.watchAlbums().first;
    expect(albums.firstWhere((a) => a.artist == 'Queen').coverKey, 'c1');
    final artists = await q.watchArtists().first;
    expect(artists.firstWhere((a) => a.key == 'queen').coverKey, 'c1');
  });

  test('album and artist with only single-track covers (cover_source 2) still get one', () async {
    await db.customStatement(
        "UPDATE tracks SET cover_key = 'a', cover_source = 2 WHERE path = '/1'");
    final albums = await q.watchAlbums().first;
    expect(albums.firstWhere((a) => a.artist == 'Queen').coverKey, 'a');
    final artists = await q.watchArtists().first;
    expect(artists.firstWhere((a) => a.key == 'queen').coverKey, 'a');
  });

  test('Jam suggestions: genre counts by lower(trim(genre)), random tracks visible only', () async {
    TracksCompanion g(String path, String? genre, {int kind = 0, bool missing = false}) =>
        TracksCompanion.insert(
          path: path,
          title: path,
          albumKey: 'k',
          format: 'mp3',
          sizeBytes: 1,
          mtimeMs: 1,
          addedAt: 1,
          genre: Value(genre),
          kind: Value(kind),
          missing: Value(missing),
        );
    await db.batch((b) => b.insertAll(db.tracks, [
          g('/g1', 'Rock'),
          g('/g2', ' rock '),
          g('/g3', 'Édith'),
          g('/g4', null),
          g('/g5', 'Rock', kind: 2),
          g('/g6', 'Jazz', missing: true),
        ]));
    final ids = [
      for (final p in ['/g1', '/g2', '/g3', '/g4', '/g5', '/g6'])
        (await (db.select(db.tracks)..where((t) => t.path.equals(p))).getSingle()).id,
    ];
    // SQLite lower() is ASCII only: the accent stays, as in every other genre query.
    expect(await q.genreCounts(ids), {'rock': 2, 'Édith': 1});
    expect(await q.genreCounts(const []), isEmpty);
    expect((await q.randomTracks(genre: 'ROCK ')).map((e) => e.path).toSet(), {'/g1', '/g2'});
    expect((await q.randomTracks(limit: 3)).length, 3);
    expect((await q.randomTracks()).any((e) => e.path == '/g5' || e.path == '/g6'), false);
  });
}
