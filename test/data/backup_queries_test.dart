import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/backup_queries.dart';
import 'package:codecore/data/repositories/artist_country_repository.dart';
import 'package:codecore/data/repositories/track_genre_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

TracksCompanion track(String path, String title, int folderId,
        {bool fav = false, bool edited = false, String? lyrics, int plays = 0}) =>
    TracksCompanion.insert(
      path: path,
      title: title,
      albumKey: 'k',
      format: 'mp3',
      sizeBytes: 1,
      mtimeMs: 1,
      addedAt: 1,
      artist: const Value('Art'),
      folderId: Value(folderId),
      durationMs: const Value(1000),
      isFavorite: Value(fav),
      userEdited: Value(edited),
      lyricsPlain: Value(lyrics),
      playCount: Value(plays),
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('collects user data, playlist order and imports', () async {
    final f1 = await db
        .into(db.folders)
        .insert(FoldersCompanion.insert(path: '/m1', addedAt: 1));
    final f2 = await db
        .into(db.folders)
        .insert(FoldersCompanion.insert(path: '/m2', addedAt: 1));
    final a = await db.into(db.tracks).insert(track('/m1/a/x.mp3', 'X', f1, fav: true));
    final b = await db.into(db.tracks).insert(track('/m2/y.mp3', 'Y', f2, edited: true));
    final c = await db.into(db.tracks).insert(track('/m2/z.mp3', 'Z', f2, lyrics: 'la'));
    await db.into(db.tracks).insert(track('/m2/plain.mp3', 'P', f2));
    final orphan = await db.into(db.tracks).insert(track('/other/o.mp3', 'O', f1, plays: 4));

    for (final name in ['One', 'Two', 'Three']) {
      final id = await db.into(db.playlists).insert(
          PlaylistsCompanion.insert(name: name, createdAt: 1));
      if (name == 'Two') {
        for (final (i, t) in [c, a, b].indexed) {
          await db.into(db.playlistTracks).insert(PlaylistTracksCompanion.insert(
              playlistId: id, trackId: t, position: i));
        }
      }
    }
    final pl = await (db.select(db.playlists)
          ..where((p) => p.name.equals('Two')))
        .getSingle();
    final imp = await db.into(db.playlistImports).insert(
        PlaylistImportsCompanion.insert(
            playlistId: pl.id, sourceName: 'two.csv', createdAt: 3));
    await db.into(db.playlistImportItems).insert(
        PlaylistImportItemsCompanion.insert(
            importId: imp, rowIndex: 0, title: 'X', artists: 'Art'));

    final d = await collectUserData(db);

    expect(d.tracks.map((t) => t.ref.title).toSet(), {'X', 'Y', 'Z', 'O'},
        reason: 'the track without user data is left out');
    final x = d.tracks.firstWhere((t) => t.ref.title == 'X');
    expect(x.favorite, isTrue);
    expect(x.ref.folder, '/m1');
    expect(x.ref.relPath, 'a/x.mp3');
    expect(d.tracks.firstWhere((t) => t.ref.title == 'Y').edit!.title, 'Y');
    expect(d.tracks.firstWhere((t) => t.ref.title == 'Z').lyricsPlain, 'la');
    final o = d.tracks.firstWhere((t) => t.ref.title == 'O');
    expect(o.playCount, 4);
    expect(o.ref.relPath, isNull, reason: 'outside its folder');
    expect(o.ref.folder, '/other/o.mp3');
    expect(orphan, isPositive);

    expect(d.playlists.map((p) => p.name), containsAll(['One', 'Two', 'Three']));
    final two = d.playlists.firstWhere((p) => p.name == 'Two');
    expect(two.items.map((i) => i.title), ['Z', 'X', 'Y']);
    expect(d.imports.single.playlistName, 'Two');
    expect(d.imports.single.rows.single.title, 'X');
  });

  test('track genres and artist countries are collected', () async {
    final f = await db.into(db.folders).insert(FoldersCompanion.insert(path: '/m', addedAt: 1));
    final a = await db.into(db.tracks).insert(track('/m/a.mp3', 'A', f, fav: true));
    await TrackGenreRepository(db).replace(a, ['Rock', 'Pop']);
    await ArtistCountryRepository(db).upsert('queen', country: 'GB', source: 'musicbrainz', checkedAtMs: 7);
    final d = await collectUserData(db);
    expect(d.tracks.single.genres, ['Rock', 'Pop']);
    expect(d.artistCountries.single.toJson(), {'artistKey': 'queen', 'country': 'GB', 'source': 'musicbrainz', 'checkedAt': 7});
  });

  test('genres inserted out of order come back by position', () async {
    final f = await db.into(db.folders).insert(FoldersCompanion.insert(path: '/m', addedAt: 1));
    final a = await db.into(db.tracks).insert(track('/m/a.mp3', 'A', f, fav: true));
    await db.into(db.trackGenres).insert(TrackGenresCompanion.insert(trackId: a, genre: 'Pop', position: 1));
    await db.into(db.trackGenres).insert(TrackGenresCompanion.insert(trackId: a, genre: 'Rock', position: 0));
    expect((await collectUserData(db)).tracks.single.genres, ['Rock', 'Pop']);
  });
}
