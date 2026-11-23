import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/backup_queries.dart';
import 'package:codecore/data/repositories/duplicate_repository.dart';
import 'package:codecore/data/repositories/filter_counts_repository.dart';
import 'package:codecore/data/repositories/stats_queries.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/memory_queries.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/review_queries.dart';
import 'package:codecore/data/repositories/track_kinds.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/library/rules/rule_ast.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/data/repositories/credits_repository.dart';
import 'package:codecore/data/repositories/artist_country_repository.dart';
import 'package:codecore/data/repositories/track_genre_repository.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/share_providers.dart';
import 'package:codecore/services/library/track_deleter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// K-02: a shadow row (kind = 2) of a streamed track, even played and tagged,
// is in no library view. Stays for phases 45-49: add the new views here.
Future<void> _play(AppDatabase d, TrackRepository t) async => d.into(d.plays).insert(
  PlaysCompanion.insert(
    trackId: (await t.streamRow('youtube:abc'))!.id,
    playedAt: DateTime.now().millisecondsSinceEpoch,
  ),
);

final _refProvider = Provider<Ref>((ref) => ref);

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

  test('addTracks refuses a shadow row, addStreamTracks takes it (D-524)', () async {
    final pl = PlaylistRepository(db);
    final id = (await db.select(db.playlists).getSingle()).id;
    final fresh = (await tracks.streamRow('youtube:zero'))!.id;
    expect(await pl.addTracks(id, [fresh]), 0);
    expect(
      await (db.select(
        db.playlistTracks,
      )..where((t) => t.trackId.equals(fresh))).get(),
      isEmpty,
    );
    expect(await pl.addStreamTracks(id, [fresh]), 1);
  });

  test('a shadow row is shown, counted and timed in its playlist only', () async {
    final pl = PlaylistRepository(db);
    final summary = (await pl.watchAll().first).single;
    expect((summary.trackCount, summary.durationMs), (1, 200000));
    final id = summary.playlist.id;
    expect((await pl.watchTracks(id).first).map((t) => t.kind), [kStreamKind]);
  });

  test('user_data.json playlists keep a shadow row as its stream key, tracks do not list it', () async {
    final items = (await collectUserData(db)).playlists.single.items;
    expect(items.map((i) => (i.streamKey, i.title, i.relPath, i.folder)), [('youtube:abc', 'Shadow', null, null)]);
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
  // D-607: once the user saves a streamed track, its shadow row is a library row.
  final saved = <String, Future<Object?> Function(AppDatabase, TrackRepository)>{
    'watchTracks': (_, t) => t.watchTracks(query: 'shadow').first,
    'musicLight': (_, t) => t.musicLight(),
    'albums': (d, _) => LibraryQueries(d).watchAlbums().first,
    'artists': (d, _) => LibraryQueries(d).watchArtists().first,
    'artist albums': (d, _) => LibraryQueries(d).watchArtistAlbums('shadow artist').first,
    'artist tracks': (d, _) => LibraryQueries(d).watchArtistTracks('shadow artist').first,
    'tracksOfArtist': (_, t) => t.tracksOfArtist('Shadow Artist'),
    'genres': (d, _) => LibraryQueries(d).watchGenres().first,
    'genre tracks': (d, _) => LibraryQueries(d).watchGenreTracks('Pop').first,
    'album tracks': (d, _) => LibraryQueries(d).watchAlbumTracks('stream|youtube:abc').first,
    'genreCounts': (d, t) async => LibraryQueries(d).genreCounts([(await t.streamRow('youtube:abc'))!.id]),
    'Home top tracks': (d, _) => LibraryQueries(d).watchTopTracks().first,
    'Home recently added': (_, t) => t.watchRecentlyAdded().first,
    'Shuffle+ random': (d, _) => LibraryQueries(d).randomTracks(),
    'tracksOfAlbums': (_, t) => t.tracksOfAlbums(['stream|youtube:abc']),
    'smart playlist': (_, t) => t.watchByRules(const RuleText('Shadow')).first,
    'liteEntries': (_, t) => t.liteEntries(),
    'countAll': (_, t) => t.countAll(),
    'watchCount': (_, t) => t.watchCount().first,
    'filter counts': (d, _) => FilterCountsRepository(d).counts(FilterList.genres),
    'stats listens': (d, t) async {
      await _play(d, t);
      return StatsQueries(d).listensSince(DateTime.fromMillisecondsSinceEpoch(0));
    },
    'stats top artist cover': (d, t) async {
      await _play(d, t);
      final p = await StatsQueries(d).period(StatsPeriod.year(DateTime.now().year));
      return [for (final a in p.topArtists) if (a.coverKey != null) a];
    },
  };
  for (final e in saved.entries) {
    test('saved shadow row is in: ${e.key}', () async {
      await tracks.setSaved('youtube:abc', true);
      var v = await e.value(db, tracks);
      if (v is SizeTotals) v = v.trackCount;
      expect(v, v is int ? 1 : isNotEmpty);
    });
  }

  group('a SAVED shadow row (D-607)', () {
    setUp(() async {
      await tracks.setSaved('youtube:abc', true);
      await tracks.setSaved('youtube:zero', true);
    });

    test('stays out of the views that work on files', () async {
      for (final k in [
        'duplicates',
        'Memory totals',
        'Memory never played',
        'Memory heaviest',
        'review',
        'review count',
        'hidden tracks',
        'missing tracks',
      ]) {
        var v = await lib[k]!(db, tracks);
        if (v is SizeTotals) v = v.trackCount;
        expect(v, v is int ? 0 : isEmpty, reason: k);
      }
      final down = await tracks
          .watchDownloadedWithoutPlaylist(paths: {'stream:youtube:zero'}, prefixes: ['stream:'])
          .first;
      expect(down, isEmpty);
      final gone = <String>[];
      final report = await TrackDeleter(
        tracks: tracks,
        removeFromQueue: (_) async {},
        deleter: (path) async => gone.add(path),
      ).deleteTracks([(await tracks.streamRow('youtube:zero'))!]);
      expect(gone, isEmpty);
      expect(report.deleted, isEmpty);
    });

    test('an artist with only saved tracks has a cover and a summary', () async {
      final q = LibraryQueries(db);
      expect((await q.watchArtists().first).single.coverKey, 'c');
      expect((await q.artistNamed('Shadow Artist'))?.trackCount, 2);
    });

    test('credits, artist countries and genres see the saved row', () async {
      final id = (await tracks.streamRow('youtube:abc'))!.id;
      await db.into(db.trackCredits).insert(
            TrackCreditsCompanion.insert(trackId: id, name: 'N', nameKey: 'n', role: 'composer', source: 'deezer'),
          );
      expect((await CreditsRepository(db).creditedTracks('n')).map((r) => r.track.id), [id]);
      expect(await ArtistCountryRepository(db).libraryArtistNames(), contains('Shadow Artist'));
      await TrackGenreRepository(db).write(id, ['Pop']);
      expect((await TrackGenreRepository(db).musicGenres()).keys, contains(id));
    });

    test('a share offer carries a saved stream by key, no file', () async {
      final c = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        coversDirProvider.overrideWithValue(tmp),
      ]);
      addTearDown(c.dispose);
      final row = (await tracks.streamRow('youtube:abc'))!;
      final local = await db.into(db.tracks).insert(TracksCompanion.insert(
            path: '/m/a.mp3', title: 'Local', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1));
      final entries = await buildShareEntries(c.read(_refProvider), [row, (await tracks.getByIds([local])).single]);
      expect(entries.map((e) => e.id), [row.id, local]);
      expect((entries.first.streamKey, entries.first.path), ('youtube:abc', ''));
      expect(entries.last.streamKey, isNull);
    });
  });

  for (final e in lib.entries) {
    test('not in: ${e.key}', () async {
      var v = await e.value(db, tracks);
      if (v is SizeTotals) v = v.trackCount;
      expect(v, v is int ? 0 : isEmpty);
    });
  }
}
