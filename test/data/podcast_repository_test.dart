import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/podcast_repository.dart';
import 'package:codecore/services/podcast/podcast_models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

PodcastEpisodeInfo ep(
  String guid,
  String title, {
  DateTime? at,
  int seconds = 600,
  String? description,
  String? url,
}) => PodcastEpisodeInfo(
  guid: guid,
  title: title,
  audioUrl: url ?? 'https://x/$guid.mp3',
  publishedAt: at,
  duration: Duration(seconds: seconds),
  mimeType: 'audio/mpeg',
  sizeBytes: 1000,
  description: description,
);

PodcastFeed feed(List<PodcastEpisodeInfo> eps, {String title = 'Show'}) =>
    PodcastFeed(
      title: title,
      author: 'Author',
      imageUrl: 'https://x/cover.jpg',
      language: 'it',
      episodes: eps,
    );

void main() {
  late AppDatabase db;
  late PodcastRepository repo;
  const feedUrl = 'https://x/feed.xml';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PodcastRepository(db);
  });
  tearDown(() => db.close());

  Future<int> trackFor(String path, {int kind = 1}) => db
      .into(db.tracks)
      .insert(
        TracksCompanion.insert(
          path: path,
          title: 'T',
          albumKey: 'podcast|1',
          format: 'mp3',
          sizeBytes: 1,
          mtimeMs: 1,
          addedAt: 1,
          kind: Value(kind),
        ),
      );

  test('subscribing saves the show and its episodes', () async {
    final id = await repo.subscribe(
      feedUrl,
      feed([ep('a', 'A'), ep('b', 'B')]),
      now: 1000,
    );
    final p = (await repo.byId(id))!;
    expect(p.title, 'Show');
    expect(p.author, 'Author');
    expect(p.language, 'it');
    expect(p.lastCheckedAt, 1000);
    expect(p.autoDeleteDays, isNull, reason: 'cleaning is off by default');
    expect(
      (await repo.watchEpisodes(id).first).map((e) => e.episode.guid),
      unorderedEquals(['a', 'b']),
    );
  });

  test(
    'subscribing to the same address again refreshes, never duplicates',
    () async {
      final id = await repo.subscribe(feedUrl, feed([ep('a', 'A')]), now: 1);
      final again = await repo.subscribe(
        feedUrl,
        feed([ep('a', 'A'), ep('b', 'B')], title: 'Renamed'),
        now: 2,
      );
      expect(again, id);
      expect((await repo.all()), hasLength(1));
      expect((await repo.byId(id))!.title, 'Renamed');
      expect((await repo.watchEpisodes(id).first), hasLength(2));
    },
  );

  group('upsertEpisodes', () {
    test('adds only the new ones and says how many', () async {
      final id = await repo.subscribe(feedUrl, feed([ep('a', 'A')]), now: 1);
      expect(
        await repo.upsertEpisodes(id, [
          ep('a', 'A'),
          ep('b', 'B'),
          ep('c', 'C'),
        ]),
        2,
      );
      expect(
        await repo.upsertEpisodes(id, [
          ep('a', 'A'),
          ep('b', 'B'),
          ep('c', 'C'),
        ]),
        0,
      );
    });

    test('a feed that repeats an item does not make two rows', () async {
      final id = await repo.subscribe(feedUrl, feed([]), now: 1);
      expect(
        await repo.upsertEpisodes(id, [ep('a', 'A'), ep('a', 'A again')]),
        1,
      );
      expect((await repo.watchEpisodes(id).first).single.episode.title, 'A');
    });

    test(
      'changed details are updated, played and the download are not touched',
      () async {
        final id = await repo.subscribe(
          feedUrl,
          feed([ep('a', 'Old', description: 'old')]),
          now: 1,
        );
        final e = (await repo.watchEpisodes(id).first).single.episode;
        final track = await trackFor('/app/podcasts/1/a.mp3');
        await (db.update(
          db.podcastEpisodes,
        )..where((x) => x.id.equals(e.id))).write(
          PodcastEpisodesCompanion(
            played: const Value(true),
            playedAt: const Value(55),
            trackId: Value(track),
          ),
        );

        await repo.upsertEpisodes(id, [
          ep(
            'a',
            'New title',
            description: 'new',
            url: 'https://x/a2.mp3',
            seconds: 700,
          ),
        ]);

        final row = (await repo.watchEpisodes(id).first).single;
        expect(row.episode.title, 'New title');
        expect(row.episode.description, 'new');
        expect(row.episode.audioUrl, 'https://x/a2.mp3');
        expect(row.episode.durationMs, 700000);
        expect(row.episode.played, isTrue);
        expect(row.episode.playedAt, 55);
        expect(row.episode.trackId, track);
        expect(row.downloaded, isTrue);
      },
    );
  });

  test('episodes come newest first, the undated ones last', () async {
    final id = await repo.subscribe(
      feedUrl,
      feed([
        ep('old', 'Old', at: DateTime.utc(2020)),
        ep('none', 'Undated'),
        ep('new', 'New', at: DateTime.utc(2024)),
      ]),
      now: 1,
    );
    expect((await repo.watchEpisodes(id).first).map((e) => e.episode.guid), [
      'new',
      'old',
      'none',
    ]);
  });

  test('the list shows how many episodes there are and how many downloaded ones wait to be heard', () async {
    final a = await repo.subscribe(
      'https://x/a',
      feed([ep('1', '1'), ep('2', '2'), ep('3', '3')], title: 'beta'),
      now: 1,
    );
    await repo.subscribe(
      'https://x/b',
      feed([ep('1', '1')], title: 'Alpha'),
      now: 1,
    );
    final eps = (await repo.watchEpisodes(a).first)
        .map((e) => e.episode)
        .toList();
    final t1 = await trackFor('/app/podcasts/1/1.mp3');
    final t2 = await trackFor('/app/podcasts/1/2.mp3');
    await (db.update(db.podcastEpisodes)..where((e) => e.id.equals(eps[0].id)))
        .write(PodcastEpisodesCompanion(trackId: Value(t1)));
    await (db.update(
      db.podcastEpisodes,
    )..where((e) => e.id.equals(eps[1].id))).write(
      PodcastEpisodesCompanion(trackId: Value(t2), played: const Value(true)),
    );

    final list = await repo.watchPodcasts().first;
    expect(list.map((s) => s.podcast.title), [
      'Alpha',
      'beta',
    ], reason: 'by name, ignoring case');
    expect(list.last.episodeCount, 3);
    expect(
      list.last.toListen,
      1,
      reason: 'one downloaded and not played; the played one and the undownloaded one do not count',
    );
    expect(list.first.toListen, 0);
  });

  group('unsubscribe', () {
    test('removes the show, its episodes and its downloaded tracks, and hands back the files to delete', () async {
      final id = await repo.subscribe(
        feedUrl,
        feed([ep('a', 'A'), ep('b', 'B')]),
        now: 1,
      );
      final eps = (await repo.watchEpisodes(id).first)
          .map((e) => e.episode)
          .toList();
      final t = await trackFor('/app/podcasts/$id/a.mp3');
      await (db.update(db.podcastEpisodes)
            ..where((e) => e.id.equals(eps.first.id)))
          .write(PodcastEpisodesCompanion(trackId: Value(t)));
      final other = await repo.subscribe(
        'https://x/other',
        feed([ep('z', 'Z')]),
        now: 1,
      );

      final paths = await repo.unsubscribe(id);

      expect(paths, ['/app/podcasts/$id/a.mp3']);
      expect(await repo.byId(id), isNull);
      expect(
        await db.select(db.tracks).get(),
        isEmpty,
        reason: 'the episode track is gone',
      );
      expect(
        (await repo.watchEpisodes(other).first),
        hasLength(1),
        reason: 'another show is untouched',
      );
    });

    test(
      'never deletes a music track, even if an episode row pointed at one',
      () async {
        final id = await repo.subscribe(feedUrl, feed([ep('a', 'A')]), now: 1);
        final music = await trackFor('/music/song.mp3', kind: 0);
        final e = (await repo.watchEpisodes(id).first).single.episode;
        await (db.update(db.podcastEpisodes)..where((x) => x.id.equals(e.id)))
            .write(PodcastEpisodesCompanion(trackId: Value(music)));

        final paths = await repo.unsubscribe(id);

        expect(paths, isEmpty);
        expect(
          (await db.select(db.tracks).get()).single.path,
          '/music/song.mp3',
        );
      },
    );
  });

  test(
    'played: set with its time, cleared with it, also through the track',
    () async {
      final id = await repo.subscribe(feedUrl, feed([ep('a', 'A')]), now: 1);
      final e = (await repo.watchEpisodes(id).first).single.episode;
      await repo.markPlayed(e.id, true, now: 777);
      expect((await repo.episodeById(e.id))!.played, isTrue);
      expect((await repo.episodeById(e.id))!.playedAt, 777);
      await repo.markPlayed(e.id, false, now: 888);
      expect((await repo.episodeById(e.id))!.played, isFalse);
      expect((await repo.episodeById(e.id))!.playedAt, isNull);

      final t = await trackFor('/app/podcasts/1/a.mp3');
      await (db.update(db.podcastEpisodes)..where((x) => x.id.equals(e.id)))
          .write(PodcastEpisodesCompanion(trackId: Value(t)));
      await repo.markPlayedByTrack(t, true, now: 999);
      expect((await repo.episodeById(e.id))!.playedAt, 999);
    },
  );

  test('settings: cleaning days, last check, cover', () async {
    final id = await repo.subscribe(feedUrl, feed([]), now: 1);
    await repo.setAutoDeleteDays(id, 7);
    await repo.markChecked(id, 5000);
    await repo.setCoverKey(id, 'abc');
    final p = (await repo.byId(id))!;
    expect((p.autoDeleteDays, p.lastCheckedAt, p.coverKey), (7, 5000, 'abc'));
    await repo.setAutoDeleteDays(id, null);
    expect((await repo.byId(id))!.autoDeleteDays, isNull);
  });

  test('an unfollowed podcast is not in the list or the followed set; subscribing follows it again', () async {
    final id = await repo.subscribe(feedUrl, feed([ep('a', 'A')]), now: 1);
    await repo.subscribe(
      'https://x/other.xml',
      feed([ep('b', 'B')], title: 'Other'),
      now: 1,
    );
    await repo.setFollowed(id, false);
    expect((await repo.watchPodcasts().first).map((s) => s.podcast.title), [
      'Other',
    ]);
    expect((await repo.allFollowed()).map((p) => p.title), ['Other']);
    expect(await repo.byId(id), isNotNull);
    await repo.subscribe(feedUrl, feed([ep('a', 'A')]), now: 2);
    expect((await repo.watchPodcasts().first), hasLength(2));
  });
}
