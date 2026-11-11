import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/backup_merge_tables.dart';
import 'package:codecore/data/repositories/playlist_sync_repository.dart';
import 'package:codecore/services/stream/stream_key.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

Future<void> addTracks(AppDatabase db, {String? coverKeyOfA}) async {
  final folder = await db.into(db.folders).insert(FoldersCompanion.insert(path: '/music', addedAt: 1));
  for (final n in ['a', 'b']) {
    await db.into(db.tracks).insert(TracksCompanion.insert(
        path: '/music/$n.mp3', title: n, albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1,
        artist: const Value('Art'), durationMs: const Value(60000), folderId: Value(folder),
        coverKey: Value(n == 'a' ? coverKeyOfA : null), hasCover: Value(n == 'a' && coverKeyOfA != null)));
  }
}

void main() {
  late Directory dir;
  late AppDatabase local;
  late File backup;
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  /// Backup DB: track 'a' (id 1) and 'c' (id 2, unknown here), with data on both.
  Future<void> buildBackup({String? coverKey}) async {
    final b = AppDatabase(NativeDatabase(backup));
    final folder = await b.into(b.folders).insert(FoldersCompanion.insert(path: '/other', addedAt: 1));
    for (final n in ['a', 'c']) {
      await b.into(b.tracks).insert(TracksCompanion.insert(
          path: '/other/$n.mp3', title: n, albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1,
          artist: const Value('Art'), durationMs: const Value(60000), folderId: Value(folder),
          coverKey: Value(n == 'a' ? coverKey : null), hasCover: Value(n == 'a' && coverKey != null)));
    }
    await b.into(b.plays).insert(PlaysCompanion.insert(
        trackId: 1, playedAt: 1000, msPlayed: const Value(5000), context: const Value(2), contextName: const Value('Mix')));
    await b.into(b.plays).insert(PlaysCompanion.insert(trackId: 2, playedAt: 2000));
    final rock = await b.into(b.userTags).insert(UserTagsCompanion.insert(name: 'Rock', color: const Value(3)));
    await b.into(b.trackTags).insert(TrackTagsCompanion.insert(trackId: 1, tagId: rock));
    await b.into(b.trackTags).insert(TrackTagsCompanion.insert(trackId: 2, tagId: rock));
    await b.into(b.smartPlaylists).insert(SmartPlaylistsCompanion.insert(name: 'Mine', rules: 'tag:Rock', createdAt: 5));
    await b.into(b.smartPlaylists).insert(SmartPlaylistsCompanion.insert(name: 'Same', rules: 'x', createdAt: 5));
    final pod = await b.into(b.podcasts).insert(PodcastsCompanion.insert(feedUrl: 'http://f', title: 'Pod', addedAt: 1));
    await b.into(b.podcastEpisodes).insert(PodcastEpisodesCompanion.insert(
        podcastId: pod, guid: 'g1', title: 'E1', audioUrl: 'http://e1', trackId: const Value(1), played: const Value(true), playedAt: const Value(900)));
    await b.into(b.podcastEpisodes).insert(PodcastEpisodesCompanion.insert(
        podcastId: pod, guid: 'g2', title: 'E2', audioUrl: 'http://e2', trackId: const Value(2)));
    await b.close();
  }

  Future<TablesMergeReport> merge({Directory? covers}) async =>
      mergeBackupTables(local, backup, await PlaylistSyncRepository(local).resolver(), coversDir: covers);

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('mt');
    backup = File('${dir.path}/codecore.sqlite');
    local = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await local.close();
    dir.deleteSync(recursive: true);
  });

  test('plays of a recognised track arrive; the others are counted as unlinked', () async {
    await addTracks(local);
    await buildBackup();
    final r = await merge();
    expect((r.playsAdded, r.playsUnlinked), (1, 1));
    final p = await local.select(local.plays).getSingle();
    expect((p.playedAt, p.msPlayed, p.context, p.contextName), (1000, 5000, 2, 'Mix'));
  });

  test('tags arrive by name and sit only on recognised tracks', () async {
    await addTracks(local);
    await local.into(local.userTags).insert(UserTagsCompanion.insert(name: 'rock'));
    await buildBackup();
    final r = await merge();
    expect((r.tagsAdded, r.trackTagsAdded), (0, 1));
    expect((await local.select(local.userTags).get()).length, 1);
  });

  test('a smart playlist with the same name and rules is skipped, other rules make a suffixed copy', () async {
    await addTracks(local);
    await local.into(local.smartPlaylists).insert(SmartPlaylistsCompanion.insert(name: 'Same', rules: 'x', createdAt: 1));
    await local.into(local.smartPlaylists).insert(SmartPlaylistsCompanion.insert(name: 'Mine', rules: 'other', createdAt: 1));
    await buildBackup();
    final r = await merge();
    expect(r.smartPlaylistsAdded, 1);
    final names = [for (final s in await local.select(local.smartPlaylists).get()) s.name];
    expect(names..sort(), ['Mine', 'Mine (ripristinata)', 'Same']);
  });

  test('podcasts and episodes arrive; the episode track is remapped or null', () async {
    await addTracks(local);
    await buildBackup();
    final r = await merge();
    expect((r.podcastsAdded, r.episodesAdded), (1, 2));
    final eps = {for (final e in await local.select(local.podcastEpisodes).get()) e.guid: e};
    expect(eps['g1']!.trackId, isNotNull);
    expect((eps['g1']!.played, eps['g1']!.playedAt), (true, 900));
    expect(eps['g2']!.trackId, isNull);
  });

  test('an existing episode keeps the furthest progress', () async {
    await addTracks(local);
    final pod = await local.into(local.podcasts).insert(PodcastsCompanion.insert(feedUrl: 'http://f', title: 'P', addedAt: 1));
    await local.into(local.podcastEpisodes).insert(PodcastEpisodesCompanion.insert(
        podcastId: pod, guid: 'g1', title: 'E1', audioUrl: 'u', playedAt: const Value(5000)));
    await buildBackup();
    final r = await merge();
    expect((r.podcastsAdded, r.episodesAdded), (0, 1));
    final e = await (local.select(local.podcastEpisodes)..where((x) => x.guid.equals('g1'))).getSingle();
    expect((e.played, e.playedAt), (true, 5000));
  });

  test('an old-schema backup does not throw', () async {
    await addTracks(local);
    final db = sqlite3.open(backup.path);
    db.execute('CREATE TABLE tracks (id INTEGER PRIMARY KEY, path TEXT, title TEXT, artist TEXT, duration_ms INTEGER)');
    db.execute('CREATE TABLE plays (track_id INTEGER, played_at INTEGER)');
    db.execute("INSERT INTO tracks VALUES (1, '/x/a.mp3', 'a', 'Art', 60000)");
    db.execute('INSERT INTO plays VALUES (1, 77)');
    db.close();
    final r = await merge();
    expect(r.playsAdded, 1);
    expect((await local.select(local.plays).getSingle()).msPlayed, 0);
  });

  test('an old backup gives its automatic cover to a track with none', () async {
    await addTracks(local);
    await buildBackup(coverKey: 'abc');
    final covers = Directory('${dir.path}/covers')..createSync();
    File('${covers.path}/abc.webp').writeAsBytesSync([1]);
    final r = await merge(covers: covers);
    expect(r.coversLinked, 1);
    final a = await (local.select(local.tracks)..where((t) => t.title.equals('a'))).getSingle();
    expect((a.hasCover, a.coverKey, a.coverSource), (true, 'abc', 0));
  });

  test('merging twice adds nothing the second time', () async {
    await addTracks(local);
    await buildBackup(coverKey: 'abc');
    final covers = Directory('${dir.path}/covers')..createSync();
    File('${covers.path}/abc.jpg').writeAsBytesSync([1]);
    await merge(covers: covers);
    Future<List<int>> counts() async => [
          (await local.select(local.plays).get()).length,
          (await local.select(local.userTags).get()).length,
          (await local.select(local.trackTags).get()).length,
          (await local.select(local.smartPlaylists).get()).length,
          (await local.select(local.podcasts).get()).length,
          (await local.select(local.podcastEpisodes).get()).length,
        ];
    final first = await counts();
    final r = await merge(covers: covers);
    expect(await counts(), first);
    expect((r.playsAdded, r.tagsAdded, r.trackTagsAdded, r.smartPlaylistsAdded, r.podcastsAdded, r.episodesAdded, r.coversLinked),
        (0, 0, 0, 0, 0, 0, 0));
  });

  test('a play of a stream track is linked to its existing shadow row, otherwise unlinked', () async {
    Future<void> streamTrack(AppDatabase d, String path, {int? at}) async {
      await d.into(d.tracks).insert(TracksCompanion.insert(
          path: path, title: 's', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1, kind: const Value(2)));
      if (at != null) await d.into(d.plays).insert(PlaysCompanion.insert(trackId: 1, playedAt: at));
    }

    final path = streamPathOf('youtube:v1');
    final b = AppDatabase(NativeDatabase(backup));
    await streamTrack(b, path, at: 10);
    await b.close();

    await streamTrack(local, path);
    var r = await merge();
    expect((r.playsAdded, r.playsUnlinked), (1, 0));
    expect((await local.select(local.plays).getSingle()).trackId, 1);

    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    r = await mergeBackupTables(other, backup, await PlaylistSyncRepository(other).resolver());
    expect((r.playsAdded, r.playsUnlinked), (0, 1));
    expect(await other.select(other.tracks).get(), isEmpty);
  });

  test('an unreadable backup database is reported', () async {
    backup.writeAsStringSync('not sqlite');
    expect((await merge()).backupDbUnreadable, isTrue);
  });
}
