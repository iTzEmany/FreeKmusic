import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/backup_queries.dart';
import 'package:codecore/data/repositories/duplicate_repository.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/memory_queries.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/review_queries.dart';
import 'package:codecore/data/repositories/track_kinds.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/library/rules/rule_ast.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// K-02: a shadow row (kind = 2) of a streamed track, even played and tagged,
// is in no library view. Stays for phases 45-49: add the new views here.
void main() {
  late AppDatabase db;
  late TrackRepository tracks;
  late Directory tmp;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tracks = TrackRepository(db);
    tmp = await Directory.systemTemp.createTemp('shadow');
    final file = File('${tmp.path}/a.m4a')..writeAsBytesSync([1, 2, 3]);
    const r = YtResult(
      id: 'abc',
      title: 'Shadow',
      channel: 'Chan',
      duration: Duration(seconds: 200),
      artists: ['Shadow Artist'],
      album: 'Shadow Album',
    );
    final id = await tracks.upsertStreamRow('youtube:abc', r, file);
    await (db.update(db.tracks)..where((t) => t.id.equals(id))).write(
      const TracksCompanion(
        playCount: Value(5),
        genre: Value('Pop'),
        isFavorite: Value(true),
        lastPlayedAt: Value(1000),
        resumePositionMs: Value(5000),
        coverKey: Value('c'),
        enrichStatus: Value(2),
      ),
    );
    // Hidden and missing variants, for the two views that list those.
    for (final (n, col) in [
      ('ign', const TracksCompanion(ignored: Value(true))),
      ('mis', const TracksCompanion(missing: Value(true))),
      ('zero', const TracksCompanion()),
    ]) {
      final other = await tracks.upsertStreamRow('youtube:$n', r, file);
      await (db.update(db.tracks)..where((t) => t.id.equals(other))).write(col);
    }
    // A podcast episode not downloaded (kind 1, an address) is no library row either.
    await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            path: 'https://feed.example/ep.mp3',
            title: 'Shadow',
            albumKey: 'stream|youtube:abc',
            format: 'mp3',
            sizeBytes: 0,
            mtimeMs: 0,
            addedAt: 1,
            artist: const Value('Shadow Artist'),
            album: const Value('Shadow Album'),
            genre: const Value('Pop'),
            playCount: const Value(5),
            isFavorite: const Value(true),
            lastPlayedAt: const Value(1000),
            enrichStatus: const Value(2),
            kind: const Value(kEpisodeKind),
          ),
        );
    final pl = await db
        .into(db.playlists)
        .insert(
          PlaylistsCompanion.insert(
            name: 'P',
            createdAt: 0,
            updatedAt: const Value(0),
          ),
        );
    await db
        .into(db.playlistTracks)
        .insert(
          PlaylistTracksCompanion.insert(
            playlistId: pl,
            trackId: id,
            position: 0,
          ),
        );
  });
  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  test('upsertStreamRow keeps one kind-2 row per key', () async {
    final row = (await tracks.streamRow('youtube:abc'))!;
    expect(row.kind, kStreamKind);
    expect(row.path, 'stream:youtube:abc');
    expect(row.folderId, isNull);
    expect(row.artist, 'Shadow Artist');
    expect(row.format, 'm4a');
    expect(row.durationMs, 200000);
    await (db.update(db.tracks)..where((t) => t.id.equals(row.id))).write(
      const TracksCompanion(missing: Value(true)),
    );
    final again = await tracks.upsertStreamRow(
      'youtube:abc',
      const YtResult(
        id: 'abc',
        title: 'Shadow',
        channel: 'Chan',
        duration: null,
      ),
      File('${tmp.path}/a.m4a'),
    );
    expect(again, row.id);
    final after = (await tracks.streamRow('youtube:abc'))!;
    expect(after.missing, isFalse);
    expect(after.albumKey, 'stream|youtube:abc');
    expect(
      await (db.select(db.tracks)).get(),
      hasLength(5),
      reason: 'four shadow rows and the episode row',
    );
  });

  test('streamRowsAmong returns the kind-2 rows and the `stream:` rows of episodes, not library rows or addresses', () async {
    final shadow = (await tracks.streamRow('youtube:abc'))!;
    final lib = await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            path: '/m/a.mp3',
            title: 'Local',
            albumKey: 'k',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 1,
          ),
        );
    final remote = (await tracks.byPath('https://feed.example/ep.mp3'))!.id;
    final got = await tracks.streamRowsAmong([lib, remote, shadow.id, 9999]);
    expect(got.map((r) => r.id), [shadow.id]);
    expect(await tracks.streamRowsAmong(const []), isEmpty);
  });

  test('a playlist refuses a shadow row and counts only music', () async {
    final pl = PlaylistRepository(db);
    final id = (await db.select(db.playlists).getSingle()).id;
    // Not in the playlist yet: only the kind check can keep it out.
    final fresh = (await tracks.streamRow('youtube:zero'))!.id;
    expect(await pl.addTracks(id, [fresh]), 0);
    expect(
      await (db.select(
        db.playlistTracks,
      )..where((t) => t.trackId.equals(fresh))).get(),
      isEmpty,
    );
    // The row seeded in setUp is in the playlist anyway: not counted.
    expect((await pl.watchAll().first).single.trackCount, 0);
  });

  test('user_data.json playlists do not list a shadow row', () async {
    expect((await collectUserData(db)).playlists.single.items, isEmpty);
  });

  test('missing paths of a folder are the library rows only', () async {
    final f = await db
        .into(db.folders)
        .insert(FoldersCompanion.insert(path: '/m', addedAt: 0));
    await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            path: '/m/a.mp3',
            title: 'A',
            albumKey: 'k',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 1,
            folderId: Value(f),
            missing: const Value(true),
          ),
        );
    expect(await tracks.missingPathsForFolder(f), {'/m/a.mp3'});
  });

  final lib = <String, Future<Object?> Function(AppDatabase, TrackRepository)>{
    'watchTracks': (_, t) => t.watchTracks(query: 'shadow').first,
    'albums': (d, _) => LibraryQueries(d).watchAlbums().first,
    'artists': (d, _) => LibraryQueries(d).watchArtists().first,
    'artist albums': (d, _) =>
        LibraryQueries(d).watchArtistAlbums('shadow artist').first,
    'artist tracks': (d, _) =>
        LibraryQueries(d).watchArtistTracks('shadow artist').first,
    'genres': (d, _) => LibraryQueries(d).watchGenres().first,
    'genre tracks': (d, _) => LibraryQueries(d).watchGenreTracks('Pop').first,
    'album tracks': (d, _) =>
        LibraryQueries(d).watchAlbumTracks('stream|youtube:abc').first,
    'Home top tracks': (d, _) => LibraryQueries(d).watchTopTracks().first,
    'Home resume': (_, t) => t.watchResumable().first,
    'tracksOfAlbums': (_, t) => t.tracksOfAlbums(['stream|youtube:abc']),
    'smart playlist': (_, t) => t.watchByRules(const RuleText('Shadow')).first,
    'playlist': (d, _) => _playlistTracks(d),
    'duplicates': (d, _) => DuplicateRepository(d).entries(),
    'hidden tracks': (_, t) => t.watchIgnored().first,
    'missing tracks': (_, t) => t.watchMissing().first,
    'liteEntries': (_, t) => t.liteEntries(),
    'countAll': (_, t) => t.countAll(),
    'watchCount': (_, t) => t.watchCount().first,
    'Memory totals': (d, _) => MemoryQueries(d).watchTotals().first,
    'Memory never played': (d, _) => MemoryQueries(d).neverPlayed(),
    'Memory heaviest': (d, _) => MemoryQueries(d).heaviestTracks(),
    // An episode row is user data like any other (its place and plays); a shadow row is not.
    'user_data.json': (d, _) async => [
      for (final t in (await collectUserData(d)).tracks)
        if (t.ref.folder?.startsWith('stream:') ?? false) t,
    ],
    'review': (d, _) => ReviewQueries(d).watch().first,
    'review count': (d, _) => ReviewQueries(d).watchCount().first,
  };
  for (final e in lib.entries) {
    test('not in: ${e.key}', () async {
      var v = await e.value(db, tracks);
      if (v is SizeTotals) v = v.trackCount;
      expect(v, v is int ? 0 : isEmpty);
    });
  }
}

Future<List<Track>> _playlistTracks(AppDatabase db) async {
  final id = (await db.select(db.playlists).getSingle()).id;
  return (await PlaylistRepository(db).watchTracks(id).first);
}
