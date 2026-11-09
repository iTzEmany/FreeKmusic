import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/podcast_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/podcast/episode_downloader.dart';
import 'package:codecore/services/podcast/podcast_cleanup.dart';
import 'package:codecore/services/podcast/podcast_models.dart';
import 'package:codecore/services/tags/tag_reader.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _NoTags implements TagReader {
  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async => const TagInfo();
}

void main() {
  late Directory dir;
  late String base;
  late AppDatabase db;
  late PodcastRepository repo;
  late TrackRepository tracks;
  late int podcastId;
  late DateTime clock;
  var inUse = <int>{};
  const day = Duration.millisecondsPerDay;

  PodcastCleanup build() => PodcastCleanup(
        repo: repo,
        downloader: EpisodeDownloader(repo: repo, tracks: tracks, tags: _NoTags(), baseDir: base),
        baseDir: base,
        inUse: () => inUse,
        now: () => clock,
      );

  /// An episode with its file and track; returns (episode id, track id, path).
  Future<(int, int, String)> episode(
    String guid, {
    bool played = false,
    int? playedDaysAgo,
    int kind = 1,
    String? outsideDir,
  }) async {
    await repo.upsertEpisodes(podcastId, [PodcastEpisodeInfo(guid: guid, title: guid, audioUrl: 'https://x/$guid.mp3')]);
    final e = (await repo.watchEpisodes(podcastId).first).firstWhere((r) => r.episode.guid == guid).episode;
    final file = File(p.join(outsideDir ?? p.join(base, '$podcastId'), '$guid.mp3'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    final t = await db.into(db.tracks).insert(TracksCompanion.insert(
        path: file.path, title: guid, albumKey: 'podcast|$podcastId', format: 'mp3',
        sizeBytes: 3, mtimeMs: 1, addedAt: 1, kind: Value(kind)));
    await repo.setTrackId(e.id, t);
    if (played) {
      await repo.markPlayed(e.id, true, now: clock.millisecondsSinceEpoch - (playedDaysAgo ?? 0) * day);
    }
    return (e.id, t, file.path);
  }

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('cleanup');
    base = p.join(dir.path, 'podcasts');
    db = AppDatabase(NativeDatabase.memory());
    repo = PodcastRepository(db);
    tracks = TrackRepository(db);
    clock = DateTime.utc(2026, 10, 17, 12);
    inUse = {};
    podcastId = await repo.subscribe('https://x/f', const PodcastFeed(title: 'Show', episodes: []), now: 1);
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  test('off by default: nothing is deleted however old', () async {
    final (_, _, path) = await episode('a', played: true, playedDaysAgo: 400);
    expect(await build().run(), 0);
    expect(File(path).existsSync(), isTrue);
  });

  test('heard longer ago than the limit: file and track go, the episode stays listed', () async {
    await repo.setAutoDeleteDays(podcastId, 7);
    final (epId, trackId, path) = await episode('old', played: true, playedDaysAgo: 8);

    expect(await build().run(), 1);

    expect(File(path).existsSync(), isFalse);
    expect(await tracks.getById(trackId), isNull);
    final row = (await repo.watchEpisodes(podcastId).first).single;
    expect(row.episode.id, epId);
    expect(row.downloaded, isFalse);
    expect(row.episode.played, isTrue, reason: 'it is still marked as heard');
  });

  test('a podcast that is not followed is never cleaned (D-470)', () async {
    await repo.setAutoDeleteDays(podcastId, 7);
    await repo.setFollowed(podcastId, false);
    final (_, _, path) = await episode('old', played: true, playedDaysAgo: 30);
    expect(await build().run(), 0);
    expect(File(path).existsSync(), isTrue);
  });

  test('not heard, heard recently, or never downloaded: untouched', () async {
    await repo.setAutoDeleteDays(podcastId, 7);
    final (_, _, unplayed) = await episode('unplayed');
    final (_, _, recent) = await episode('recent', played: true, playedDaysAgo: 3);
    final (_, _, edge) = await episode('edge', played: true, playedDaysAgo: 6);
    await repo.upsertEpisodes(podcastId, [const PodcastEpisodeInfo(guid: 'nofile', title: 'n', audioUrl: 'https://x/n.mp3')]);

    expect(await build().run(), 0);
    for (final path in [unplayed, recent, edge]) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('the limit is per podcast; one with cleaning off is left alone', () async {
    await repo.setAutoDeleteDays(podcastId, 1);
    final (_, _, mine) = await episode('mine', played: true, playedDaysAgo: 2);
    final other = await repo.subscribe('https://y/f', const PodcastFeed(title: 'Other', episodes: []), now: 1);
    await repo.upsertEpisodes(other, [const PodcastEpisodeInfo(guid: 'o', title: 'o', audioUrl: 'https://y/o.mp3')]);
    final oe = (await repo.watchEpisodes(other).first).single.episode;
    final file = File(p.join(base, '$other', 'o.mp3'))..createSync(recursive: true);
    final t = await db.into(db.tracks).insert(TracksCompanion.insert(
        path: file.path, title: 'o', albumKey: 'podcast|$other', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1, kind: const Value(1)));
    await repo.setTrackId(oe.id, t);
    await repo.markPlayed(oe.id, true, now: clock.millisecondsSinceEpoch - 30 * day);

    expect(await build().run(), 1);
    expect(File(mine).existsSync(), isFalse);
    expect(file.existsSync(), isTrue, reason: 'cleaning is off for that podcast');
  });

  test('an episode that is playing or in the queue is skipped', () async {
    await repo.setAutoDeleteDays(podcastId, 1);
    final (_, queued, queuedPath) = await episode('queued', played: true, playedDaysAgo: 5);
    final (_, _, freePath) = await episode('free', played: true, playedDaysAgo: 5);
    inUse = {queued};

    expect(await build().run(), 1);
    expect(File(queuedPath).existsSync(), isTrue);
    expect(File(freePath).existsSync(), isFalse);

    inUse = {};
    expect(await build().run(), 1, reason: 'once it is out of the queue it goes too');
    expect(File(queuedPath).existsSync(), isFalse);
  });

  test('a file outside the podcast folder is never deleted, whatever the row says', () async {
    await repo.setAutoDeleteDays(podcastId, 1);
    final outsideDir = p.join(dir.path, 'music');
    final (_, _, path) = await episode('sneaky', played: true, playedDaysAgo: 9, outsideDir: outsideDir);

    expect(await build().run(), 0);
    expect(File(path).existsSync(), isTrue);
  });

  test('a music track linked to an episode by mistake is never deleted', () async {
    await repo.setAutoDeleteDays(podcastId, 1);
    final (_, trackId, path) = await episode('wrongkind', played: true, playedDaysAgo: 9, kind: 0);

    expect(await build().run(), 0);
    expect(File(path).existsSync(), isTrue);
    expect(await tracks.getById(trackId), isNotNull);
  });
}
