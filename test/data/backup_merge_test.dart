import 'package:codecore/data/repositories/credits_repository.dart';
import 'package:codecore/services/online/credits.dart';
import 'package:codecore/data/db/app_database.dart';
import 'dart:convert';
import 'dart:io';

import 'package:codecore/data/repositories/backup_merge.dart';
import 'package:codecore/data/repositories/backup_queries.dart';
import 'package:codecore/data/repositories/artist_alias_repository.dart';
import 'package:codecore/data/repositories/artist_country_repository.dart';
import 'package:codecore/data/repositories/follow_repository.dart';
import 'package:codecore/data/repositories/track_genre_repository.dart';
import 'package:codecore/data/repositories/playlist_sync_repository.dart';
import 'package:codecore/data/repositories/release_repository.dart';
import 'package:codecore/services/online/ytm_artist_parser.dart';
import 'package:codecore/services/releases/release_checker.dart';
import 'package:codecore/services/backup/user_data.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

TrackRef ref(String name) => TrackRef(title: name, relPath: '$name.mp3', artist: 'Art', durationMs: 60000);

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final folder = await db.into(db.folders).insert(FoldersCompanion.insert(path: '/music', addedAt: 1));
    for (final n in ['a', 'b', 'c']) {
      await db.into(db.tracks).insert(TracksCompanion.insert(
          path: '/music/$n.mp3', title: n, albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1,
          artist: const Value('Art'), durationMs: const Value(60000), folderId: Value(folder)));
    }
  });
  tearDown(() => db.close());

  Future<MergeReport> merge(UserData d) async =>
      mergeUserData(db, d, await PlaylistSyncRepository(db).resolver());

  Future<Track> track(String t) => (db.select(db.tracks)..where((r) => r.title.equals(t))).getSingle();

  test('a favourite is added, plays keep the max and the latest date, lyrics fill only empty fields', () async {
    await (db.update(db.tracks)..where((r) => r.title.equals('b'))).write(const TracksCompanion(
        playCount: Value(9), lastPlayedAt: Value(500), lyricsPlain: Value('mine')));
    final r = await merge(UserData(createdAt: 1, tracks: [
      TrackUserData(ref: ref('a'), favorite: true, playCount: 4, lastPlayedAt: 100, lyricsPlain: 'theirs', curiosities: 'fun'),
      TrackUserData(ref: ref('b'), playCount: 3, lastPlayedAt: 900, lyricsPlain: 'theirs'),
    ]));
    expect(r.recognized, 2);
    expect(r.favoritesAdded, 1);
    final a = await track('a');
    expect(a.isFavorite, isTrue);
    expect((a.playCount, a.lastPlayedAt, a.lyricsPlain, a.curiosities), (4, 100, 'theirs', 'fun'));
    final b = await track('b');
    expect((b.playCount, b.lastPlayedAt, b.lyricsPlain), (9, 900, 'mine'));
  });

  test('a hand cover is taken only when its file is there; old backups leave covers alone', () async {
    final covers = Directory.systemTemp.createTempSync('bm');
    addTearDown(() => covers.deleteSync(recursive: true));
    File('${covers.path}/manual_a.jpg').writeAsBytesSync([1]);
    final r = await mergeUserData(
        db,
        UserData(createdAt: 1, tracks: [
          TrackUserData(ref: ref('a'), coverSource: 2, coverKey: 'manual_a'),
          TrackUserData(ref: ref('b'), coverSource: 1, coverKey: 'manual_gone'),
          TrackUserData(ref: ref('c'), favorite: true),
        ]),
        await PlaylistSyncRepository(db).resolver(),
        coversDir: covers);
    expect(r.recognized, 3);
    expect(((await track('a')).coverSource, (await track('a')).coverKey), (2, 'manual_a'));
    expect((await track('a')).hasCover, isTrue);
    expect((await track('b')).hasCover, isFalse);
    expect(((await track('b')).coverSource, (await track('b')).coverKey), (0, null));
    expect(((await track('c')).coverSource, (await track('c')).coverKey), (0, null));
  });

  group('hand cover safety', () {
    final badKeys = ['../escape', '..', 'a/b'];

    Future<MergeReport> mergeCovers(Directory covers, List<TrackUserData> tracks) async =>
        mergeUserData(db, UserData(createdAt: 1, tracks: tracks),
            await PlaylistSyncRepository(db).resolver(), coversDir: covers);

    test('hostile coverKeys are ignored even when a file exists', () async {
      final covers = Directory.systemTemp.createTempSync('bm');
      final escape = File('${covers.parent.path}/escape.jpg')..writeAsBytesSync([1]);
      addTearDown(() {
        covers.deleteSync(recursive: true);
        if (escape.existsSync()) escape.deleteSync();
      });
      File('${covers.path}/a').createSync();
      File('${covers.path}/a.jpg').writeAsBytesSync([1]);
      await mergeCovers(covers, [
        for (final (i, k) in badKeys.indexed) TrackUserData(ref: ref(['a', 'b', 'c'][i]), coverSource: 1, coverKey: k),
      ]);
      for (final n in ['a', 'b', 'c']) {
        expect(((await track(n)).coverSource, (await track(n)).coverKey), (0, null), reason: n);
      }
    });

    test('coverSource 0 with a coverKey changes nothing', () async {
      final covers = Directory.systemTemp.createTempSync('bm');
      addTearDown(() => covers.deleteSync(recursive: true));
      File('${covers.path}/k.jpg').writeAsBytesSync([1]);
      await mergeCovers(covers, [TrackUserData(ref: ref('a'), coverKey: 'k')]);
      final a = await track('a');
      expect((a.coverSource, a.coverKey, a.hasCover), (0, null, false));
    });

    test('backup album pick does not split a locally picked album', () async {
      final covers = Directory.systemTemp.createTempSync('bm');
      addTearDown(() => covers.deleteSync(recursive: true));
      File('${covers.path}/theirs.jpg').writeAsBytesSync([1]);
      await (db.update(db.tracks)).write(const TracksCompanion(
          coverSource: Value(1), coverKey: Value('mine'), hasCover: Value(true)));
      await mergeCovers(covers, [TrackUserData(ref: ref('a'), coverSource: 1, coverKey: 'theirs')]);
      expect({for (final n in ['a', 'b', 'c']) (await track(n)).coverKey}, {'mine'});
    });

    test('a backup edit that moves an album-pick row to another album leaves the old pick behind', () async {
      await (db.update(db.tracks)).write(const TracksCompanion(
          coverSource: Value(1), coverKey: Value('mine'), hasCover: Value(true)));
      await merge(UserData(createdAt: 1, tracks: [
        TrackUserData(ref: ref('a'), edit: const TrackEditData(title: 'a', artist: 'Art', album: 'Other')),
      ]));
      final a = await track('a');
      expect((a.coverSource, a.coverKey), (0, null));
      expect((await track('b')).coverKey, 'mine');
    });
  });

  test('a hand edit applies to an untouched track but never over a local edit', () async {
    await (db.update(db.tracks)..where((r) => r.title.equals('c'))).write(
        const TracksCompanion(userEdited: Value(true), genre: Value('Local')));
    await merge(UserData(createdAt: 1, tracks: [
      TrackUserData(ref: ref('a'), edit: const TrackEditData(title: 'A!', artist: 'New', album: 'Alb', genre: 'Pop')),
      TrackUserData(ref: ref('c'), edit: const TrackEditData(title: 'C!', genre: 'Theirs')),
    ]));
    final a = await (db.select(db.tracks)..where((r) => r.path.equals('/music/a.mp3'))).getSingle();
    expect((a.title, a.artist, a.album, a.genre, a.userEdited), ('A!', 'New', 'Alb', 'Pop', true));
    final c = await track('c');
    expect((c.title, c.genre), ('c', 'Local'));
  });

  test('a playlist with a free name is created, an existing name becomes «(ripristinata)»; missing items are counted', () async {
    final id = await db.into(db.playlists).insert(PlaylistsCompanion.insert(name: 'Mix', createdAt: 1));
    await db.into(db.playlistTracks).insert(PlaylistTracksCompanion.insert(playlistId: id, trackId: 1, position: 0));
    final r = await merge(UserData(createdAt: 1, playlists: [
      PlaylistData(name: 'Mix', createdAt: 5, items: [ref('c'), ref('zzz'), ref('a'), ref('c')]),
      const PlaylistData(name: 'Nuova', createdAt: 6),
    ]));
    expect(r.playlistsCreated, 2);
    expect(r.playlistItemsSkipped, 1);
    final names = [for (final p in await db.select(db.playlists).get()) p.name];
    expect(names, unorderedEquals(['Mix', 'Mix (ripristinata)', 'Nuova']));
    final restored = await (db.select(db.playlists)..where((p) => p.name.equals('Mix (ripristinata)'))).getSingle();
    final items = await (db.select(db.playlistTracks)..where((t) => t.playlistId.equals(restored.id))).get();
    expect((items..sort((a, b) => a.position.compareTo(b.position))).map((i) => i.trackId), [3, 1]);
    // The original playlist is untouched.
    expect((await (db.select(db.playlistTracks)..where((t) => t.playlistId.equals(id))).get()), hasLength(1));
    expect(restored.uuid, isNot((await (db.select(db.playlists)..where((p) => p.id.equals(id))).getSingle()).uuid));
  });

  test('merging a playlist already here (same uuid) appends only the missing tracks, no copy', () async {
    final id = await db.into(db.playlists).insert(PlaylistsCompanion.insert(name: 'Mix', createdAt: 1));
    final uuid = (await (db.select(db.playlists)..where((p) => p.id.equals(id))).getSingle()).uuid;
    await db.into(db.playlistTracks).insert(PlaylistTracksCompanion.insert(playlistId: id, trackId: 1, position: 0));
    final r = await merge(UserData(createdAt: 1, playlists: [
      PlaylistData(name: 'Renamed', uuid: uuid, createdAt: 1, items: [ref('a'), ref('b')]),
    ]));
    expect(r.playlistsCreated, 0);
    expect(await db.select(db.playlists).get(), hasLength(1));
    final items = await (db.select(db.playlistTracks)..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    expect(items.map((i) => i.trackId), [1, 2]);
  });

  test('without a uuid, same name and same tracks is the same playlist; merging twice never doubles', () async {
    final id = await db.into(db.playlists).insert(PlaylistsCompanion.insert(name: 'Mix', createdAt: 1));
    await db.into(db.playlistTracks).insert(PlaylistTracksCompanion.insert(playlistId: id, trackId: 1, position: 0));
    final d = UserData(createdAt: 1, playlists: [PlaylistData(name: 'Mix', createdAt: 1, items: [ref('a')])]);
    await merge(d);
    await merge(d);
    expect(await db.select(db.playlists).get(), hasLength(1));
    expect(await db.select(db.playlistTracks).get(), hasLength(1));
  });

  test('a new playlist keeps the backup uuid, so a second merge does not copy it', () async {
    final d = UserData(createdAt: 1, playlists: [
      PlaylistData(name: 'Nuova', uuid: 'u-1', createdAt: 1, items: [ref('a')]),
    ]);
    await merge(d);
    await merge(d);
    final all = await db.select(db.playlists).get();
    expect(all.map((p) => (p.name, p.uuid)), [('Nuova', 'u-1')]);
    expect(await db.select(db.playlistTracks).get(), hasLength(1));
  });

  test('a track the library lacks is listed as not found, and nothing is deleted', () async {
    final before = (await db.select(db.tracks).get()).length;
    final r = await merge(UserData(createdAt: 1, tracks: [
      TrackUserData(ref: ref('ghost'), favorite: true),
      TrackUserData(ref: ref('a')),
    ]));
    expect(r.notFound, ['ghost']);
    expect((await db.select(db.tracks).get()).length, before);
  });

  group('saved radio stations', () {
    RadioData radio(String id, String name, {String url = 'http://s'}) =>
        RadioData(stationId: id, name: name, streamUrl: '$url/$id', tags: 'pop,rock', bitrate: 128, hls: id == 'b');

    Future<List<SavedRadio>> saved() => (db.select(db.radioStations)
          ..orderBy([(r) => OrderingTerm.asc(r.position)]))
        .get();

    test('export, JSON, merge into an empty database: same stations in the same order', () async {
      for (final (i, id) in ['c', 'a', 'b'].indexed) {
        await db.into(db.radioStations).insert(RadioStationsCompanion.insert(
            stationId: id, name: 'N$id', streamUrl: 'http://s/$id', position: i,
            tags: const Value('pop,rock'), hls: Value(id == 'b'), lastPlayedAt: const Value(7)));
      }
      final exported = await collectUserData(db);
      final json = jsonDecode(jsonEncode(exported.toJson())) as Map<String, dynamic>;
      final restored = UserData.fromJson(json);
      expect([for (final r in restored.radios) r.stationId], ['c', 'a', 'b']);

      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      final r = await mergeUserData(other, restored, await PlaylistSyncRepository(other).resolver());
      expect(r.radiosAdded, 3);
      final rows = await (other.select(other.radioStations)..orderBy([(x) => OrderingTerm.asc(x.position)])).get();
      expect([for (final x in rows) (x.stationId, x.name, x.streamUrl, x.tags, x.hls, x.lastPlayedAt)], [
        ('c', 'Nc', 'http://s/c', 'pop,rock', false, 7),
        ('a', 'Na', 'http://s/a', 'pop,rock', false, 7),
        ('b', 'Nb', 'http://s/b', 'pop,rock', true, 7),
      ]);
    });

    test('merging twice adds nothing; a station already here is untouched; new ones go last', () async {
      await db.into(db.radioStations).insert(RadioStationsCompanion.insert(
          stationId: 'a', name: 'Mine', streamUrl: 'http://mine/a', position: 0));
      final data = UserData(createdAt: 1, radios: [radio('b', 'B'), radio('a', 'Theirs'), radio('c', 'C')]);
      expect((await merge(data)).radiosAdded, 2);
      expect((await merge(data)).radiosAdded, 0);
      final rows = await saved();
      expect([for (final r in rows) (r.stationId, r.name)], [('a', 'Mine'), ('b', 'B'), ('c', 'C')]);
    });

    test('a hand-typed address is recognised by its URL even under another id', () async {
      await db.into(db.radioStations).insert(RadioStationsCompanion.insert(
          stationId: 'manual:1', name: 'Mine', streamUrl: 'http://s/manual:2', position: 0));
      final r = await merge(UserData(createdAt: 1, radios: [radio('manual:2', 'Same address')]));
      expect(r.radiosAdded, 0);
      expect(await saved(), hasLength(1));
    });

    test('a user_data.json without radios still reads, and writes none', () {
      final old = UserData.fromJson({'format': 1, 'createdAt': 5, 'tracks': [], 'playlists': []});
      expect(old.radios, isEmpty);
      expect(old.toJson().containsKey('radios'), isFalse);
    });
  });

  group('followed artists', () {
    Future<List<FollowedArtist>> saved() =>
        (db.select(db.followedArtists)..orderBy([(a) => OrderingTerm.asc(a.ytmId)])).get();

    test('export, JSON, merge into an empty database: same artists, flags and origin', () async {
      await db.into(db.followedArtists).insert(FollowedArtistsCompanion.insert(
          ytmId: 'UC1', name: 'One', thumbUrl: const Value('http://t/1'), muted: const Value(true)));
      await db.into(db.followedArtists).insert(FollowedArtistsCompanion.insert(
          ytmId: 'UC2', name: 'Two', origin: const Value(1), excluded: const Value(true),
          lastCheckedAt: const Value(5)));
      final json = jsonDecode(jsonEncode((await collectUserData(db)).toJson())) as Map<String, dynamic>;

      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      final r = await mergeUserData(
          other, UserData.fromJson(json), await PlaylistSyncRepository(other).resolver());
      expect(r.followedArtistsAdded, 2);
      final rows = await (other.select(other.followedArtists)..orderBy([(a) => OrderingTerm.asc(a.ytmId)])).get();
      expect([for (final a in rows) (a.ytmId, a.name, a.thumbUrl, a.origin, a.excluded, a.muted, a.lastCheckedAt)], [
        ('UC1', 'One', 'http://t/1', 0, false, true, null),
        ('UC2', 'Two', null, 1, true, false, null),
      ]);
    });

    test('merging by id: no duplicates, local rows stay, a hand follow wins over automatic/excluded', () async {
      await db.into(db.followedArtists).insert(FollowedArtistsCompanion.insert(
          ytmId: 'UC1', name: 'Mine', muted: const Value(true)));
      await db.into(db.followedArtists).insert(FollowedArtistsCompanion.insert(
          ytmId: 'UC2', name: 'Auto', origin: const Value(1), excluded: const Value(true)));
      final data = UserData(createdAt: 1, followedArtists: const [
        FollowedArtistData(ytmId: 'UC1', name: 'Theirs'),
        FollowedArtistData(ytmId: 'UC2', name: 'Theirs2'),
        FollowedArtistData(ytmId: 'UC3', name: 'New'),
        FollowedArtistData(ytmId: 'UC3', name: 'New again'),
      ]);
      expect((await merge(data)).followedArtistsAdded, 1);
      expect((await merge(data)).followedArtistsAdded, 0);
      final rows = await saved();
      expect([for (final a in rows) (a.ytmId, a.name, a.origin, a.excluded, a.muted)], [
        ('UC1', 'Mine', 0, false, true),
        ('UC2', 'Auto', 0, false, false),
        ('UC3', 'New', 0, false, false),
      ]);
    });

    test('an old backup without followedArtists reads as empty and writes none', () {
      final old = UserData.fromJson({'format': 1, 'createdAt': 5, 'tracks': [], 'playlists': []});
      expect(old.followedArtists, isEmpty);
      expect(old.toJson().containsKey('followedArtists'), isFalse);
    });

    test('after a merge the first round stores the releases as seen: nothing new', () async {
      await merge(UserData(createdAt: 1, followedArtists: const [
        FollowedArtistData(ytmId: 'UC1', name: 'One'),
      ]));
      final page = parseArtistPage(
          jsonDecode(File('test/fixtures/innertube/ytm_artist_releases.json').readAsStringSync()) as Map, 'UC1');
      final out = await ReleaseChecker((_) async => page, FollowRepository(db), ReleaseRepository(db),
          now: () => DateTime(2026, 10, 22), wait: (_) async {}).run();
      expect(out.checked, 1);
      expect(out.fresh, isEmpty);
    });
  });

  test('credits and details come back from a backup, and never replace the ones a track has', () async {
    final repo = CreditsRepository(db);
    final a = (await track('a')).id, b = (await track('b')).id;
    TrackCreditsCompanion c(int id, String n) =>
        TrackCreditsCompanion.insert(trackId: id, name: n, nameKey: n, role: 'composer', source: 'deezer');
    await repo.save(a, [c(a, 'Ann')], TrackEnrichCompanion(trackId: Value(a), details: const Value('{"label":"L"}')));
    final data = await collectUserData(db);
    expect(data.tracks.single.credits.single.name, 'Ann');
    await repo.saveCredits(b, [c(b, 'Mine')]);
    await db.customStatement('DELETE FROM track_credits WHERE track_id = $a');
    await db.customStatement('DELETE FROM track_enrich WHERE track_id = $a');
    await merge(data);
    expect((await repo.creditsOf(a)).map((x) => x.name), ['Ann']);
    expect((await repo.portableOf(a)).details!.label, 'L');
    await merge(UserData(createdAt: 1, tracks: [
      TrackUserData(ref: ref('b'), credits: [TrackCredit('Other', 'guitar', 'deezer')]),
    ]));
    expect((await repo.creditsOf(b)).map((x) => x.name), ['Mine']);
  });

  group('genres and artist countries (D-390)', () {
    Future<List<String>> genresOf(String title) async =>
        TrackGenreRepository(db).of((await track(title)).id);

    test('the backup genres go to the matching tracks by ref; a track that has some keeps them', () async {
      await TrackGenreRepository(db).replace((await track('b')).id, ['Jazz']);
      await merge(UserData(createdAt: 1, tracks: [
        TrackUserData(ref: ref('c'), genres: const ['Rock', 'Pop']),
        TrackUserData(ref: ref('b'), genres: const ['Metal']),
        TrackUserData(ref: ref('gone'), genres: const ['Folk']),
      ]));
      expect(await genresOf('c'), ['Rock', 'Pop']);
      expect(await genresOf('b'), ['Jazz']);
      expect(await db.select(db.trackGenres).get(), hasLength(3));
    });

    test('a hand edit applied here sets the genres from its text', () async {
      await merge(UserData(createdAt: 1, tracks: [
        TrackUserData(ref: ref('a'), edit: const TrackEditData(title: 'a', genre: 'Blues; Soul'), genres: const ['Blues', 'Soul']),
      ]));
      expect(await genresOf('a'), ['Blues', 'Soul']);
    });

    test('a hand edit with the backup list starting at the same genre keeps the whole list', () async {
      await merge(UserData(createdAt: 1, tracks: [
        TrackUserData(ref: ref('a'), edit: const TrackEditData(title: 'x', genre: 'Rock'), genres: const ['rock', 'Pop']),
      ]));
      expect(await genresOf('x'), ['rock', 'Pop']);
    });

    test('the genres survive collect -> json -> merge into another library', () async {
      final a = await track('a');
      await TrackGenreRepository(db).replace(a.id, ['Rock', 'Pop']);
      await (db.update(db.tracks)..where((r) => r.id.equals(a.id))).write(const TracksCompanion(isFavorite: Value(true)));
      final data = UserData.fromJson(jsonDecode(jsonEncode((await collectUserData(db)).toJson())) as Map<String, dynamic>);
      await (db.delete(db.trackGenres)).go();
      await merge(data);
      expect(await genresOf('a'), ['Rock', 'Pop']);
    });

    test('a backup without the new fields merges as before', () async {
      final data = UserData.fromJson({'format': 1, 'createdAt': 1, 'tracks': [{'ref': ref('a').toJson(), 'favorite': true}]});
      expect((await merge(data)).favoritesAdded, 1);
      expect(await db.select(db.trackGenres).get(), isEmpty);
      expect(await db.select(db.artistCountries).get(), isEmpty);
    });

    test('artist countries: new keys are added, the more recent check wins, an older one never replaces', () async {
      final repo = ArtistCountryRepository(db);
      await repo.upsert('queen', country: 'GB', source: 'musicbrainz', checkedAtMs: 100);
      await repo.upsert('abba', country: 'SE', source: 'wikidata', checkedAtMs: 100);
      await merge(UserData(createdAt: 1, artistCountries: const [
        ArtistCountryData(artistKey: 'queen', country: 'US', source: 'wikidata', checkedAt: 50),
        ArtistCountryData(artistKey: 'abba', country: null, source: null, checkedAt: 200),
        ArtistCountryData(artistKey: 'zz', country: null, source: null, checkedAt: 5),
        ArtistCountryData(artistKey: 'bjork', country: 'is', source: 'musicbrainz', checkedAt: 10),
      ]));
      final all = {for (final c in await db.select(db.artistCountries).get()) c.artistKey: c};
      expect(all['queen']!.country, 'GB');
      expect((all['abba']!.country, all['abba']!.checkedAt), ('SE', 100), reason: 'a newer «not found» never erases a country');
      expect(all['zz']!.country, isNull);
      expect(all['bjork']!.country, 'IS');
    });

    test('artist countries: a country that is not two letters counts as «not found»', () async {
      await merge(UserData(createdAt: 1, artistCountries: const [
        ArtistCountryData(artistKey: 'a', country: '', source: 'x', checkedAt: 1),
        ArtistCountryData(artistKey: 'b', country: 'ita', source: 'x', checkedAt: 1),
        ArtistCountryData(artistKey: 'c', country: '3', source: 'x', checkedAt: 1),
      ]));
      final all = await db.select(db.artistCountries).get();
      expect(all, hasLength(3));
      expect(all.map((c) => c.country), everyElement(isNull));
    });

    test('artist countries: a found one beats a newer «not found», in both directions', () async {
      final repo = ArtistCountryRepository(db);
      await repo.upsert('x', checkedAtMs: 100);
      await repo.upsert('y', country: 'FR', checkedAtMs: 50);
      await merge(UserData(createdAt: 1, artistCountries: const [
        ArtistCountryData(artistKey: 'x', country: 'GB', source: 'musicbrainz', checkedAt: 50),
        ArtistCountryData(artistKey: 'y', country: null, source: null, checkedAt: 200),
      ]));
      final all = {for (final c in await db.select(db.artistCountries).get()) c.artistKey: c.country};
      expect(all, {'x': 'GB', 'y': 'FR'});
    });
  });

  group('artist aliases and not-same pairs (D-402, D-414)', () {
    test('they survive collect -> json -> merge into another library', () async {
      final repo = ArtistAliasRepository(db);
      await repo.merge('A', 'B');
      await repo.markNotSame('X', 'Y');
      final data = UserData.fromJson(jsonDecode(jsonEncode((await collectUserData(db)).toJson())) as Map<String, dynamic>);
      await db.delete(db.artistAliases).go();
      await db.delete(db.artistNotSame).go();
      await merge(data);
      expect(await repo.groupOf('A'), ['A', 'B']);
      expect(await repo.isNotSame('Y', 'X'), isTrue);
    });

    test('an alias of the backup resolves to the local main; one already an alias here keeps the local choice', () async {
      final repo = ArtistAliasRepository(db);
      await repo.merge('M', 'A');
      await repo.merge('Q', 'B');
      await merge(const UserData(createdAt: 1, artistAliases: [
        ArtistAliasData(aliasId: 'C', mainId: 'A'),
        ArtistAliasData(aliasId: 'B', mainId: 'M'),
        ArtistAliasData(aliasId: 'D', mainId: 'D'),
      ], artistNotSame: [
        ['M', 'C'],
        ['M', 'Z'],
      ]));
      expect(await repo.groupOf('M'), ['M', 'A', 'C']);
      expect(await repo.groupOf('B'), ['Q', 'B']);
      expect(await repo.isNotSame('M', 'C'), isFalse, reason: 'same group here');
      expect(await repo.isNotSame('Z', 'M'), isTrue);
    });

    test('a backup without them merges as before', () async {
      await merge(UserData.fromJson({'format': 1, 'createdAt': 1}));
      expect(await db.select(db.artistAliases).get(), isEmpty);
      expect(await db.select(db.artistNotSame).get(), isEmpty);
    });
  });
}
