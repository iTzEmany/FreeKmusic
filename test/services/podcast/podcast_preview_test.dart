import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/podcast_repository.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/podcast_ops.dart';
import 'package:codecore/providers/podcast_providers.dart';
import 'package:codecore/services/podcast/podcast_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _feed = PodcastFeed(
  title: 'Show',
  episodes: [PodcastEpisodeInfo(guid: 'e1', title: 'One', audioUrl: 'https://x/1.mp3')],
);

PodcastPreview _ytm() => const PodcastPreview(
      feedUrl: 'https://music.youtube.com/browse/MPSP1',
      feed: _feed,
      source: kPodcastSourceYtm,
      sourceId: 'MPSP1',
    );

void main() {
  late AppDatabase db;
  late PodcastRepository repo;
  late ProviderContainer c;
  late PodcastOps ops;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PodcastRepository(db);
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      podcastCoverSaverProvider.overrideWithValue((id, url) async => null),
    ]);
    ops = c.read(podcastOpsProvider);
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  test('the first play saves the show as not followed, with its episodes, out of the Podcast list', () async {
    final track = await ops.saveForPlay(_ytm(), 'e1');
    expect(track?.path, 'stream:youtube:e1');
    final saved = (await repo.all()).single;
    expect(saved.followed, isFalse);
    expect(await repo.episodeGuids(saved.id), {'e1'});
    expect(await repo.watchPodcasts().first, isEmpty);
  });

  test('a show whose episode has no http address is not saved', () async {
    const rss = PodcastPreview(
      feedUrl: 'https://x/feed',
      feed: PodcastFeed(
        title: 'Show',
        episodes: [PodcastEpisodeInfo(guid: 'e1', title: 'One', audioUrl: 'ftp://x/1.mp3')],
      ),
    );
    expect(await ops.saveForPlay(rss, 'e1'), isNull);
    expect(await repo.all(), isEmpty);
  });

  test('an address in capitals is an address: it plays, and the saved row is on it', () async {
    const rss = PodcastPreview(
      feedUrl: 'https://x/feed',
      feed: PodcastFeed(
        title: 'Show',
        episodes: [PodcastEpisodeInfo(guid: 'e1', title: 'One', audioUrl: 'HTTP://x/1.mp3')],
      ),
    );
    final track = await ops.saveForPlay(rss, 'e1');
    expect(track?.path, 'HTTP://x/1.mp3');
    expect(await repo.all(), hasLength(1));
  });

  test('a tap on play writes the feed only when something is missing or new', () async {
    PodcastPreview feed(List<PodcastEpisodeInfo> eps, {String title = 'Show'}) =>
        PodcastPreview(feedUrl: 'https://x/feed', feed: PodcastFeed(title: title, episodes: eps));
    const one = PodcastEpisodeInfo(guid: 'e1', title: 'One', audioUrl: 'https://x/1.mp3');
    await ops.saveForPlay(feed([one]), 'e1');
    final id = (await repo.all()).single.id;
    // Same feed but for a changed show title: nothing is rewritten.
    await ops.saveForPlay(feed([one], title: 'Renamed'), 'e1');
    expect((await repo.byId(id))!.title, 'Show');
    // An episode newer than the last read: the feed is saved again.
    final fresh = PodcastEpisodeInfo(
        guid: 'e2', title: 'Two', audioUrl: 'https://x/2.mp3', publishedAt: DateTime.utc(2100));
    await ops.saveForPlay(feed([one, fresh]), 'e1');
    expect(await repo.episodeGuids(id), {'e1', 'e2'});
    // An episode the saved copy has not got: also saved, whatever its date.
    const old = PodcastEpisodeInfo(guid: 'e0', title: 'Zero', audioUrl: 'https://x/0.mp3');
    expect((await ops.saveForPlay(feed([one, fresh, old]), 'e0'))?.path, 'https://x/0.mp3');
  });

  test('an RSS episode plays from its address: one row, reused, not counted as a download', () async {
    const rss = PodcastPreview(feedUrl: 'https://x/feed', feed: _feed);
    final first = await ops.saveForPlay(rss, 'e1');
    expect([first?.kind, first?.path], [1, 'https://x/1.mp3']);
    expect((await ops.saveForPlay(rss, 'e1'))?.id, first?.id);
    final podcast = (await repo.all()).single;
    expect((await repo.episodeByGuid(podcast.id, 'e1'))!.trackId, first!.id);
    expect(await repo.downloadedEpisodes(), isEmpty);
    expect((await repo.watchEpisodes(podcast.id).first).single.downloaded, isFalse);
  });

  test('«Segui già» touched again unfollows, and the heard episodes stay', () async {
    final id = await ops.save(_ytm(), followed: true);
    expect((await repo.watchPodcasts().first).single.podcast.id, id);
    final ep = (await repo.watchEpisodes(id).first).single.episode;
    await repo.markPlayed(ep.id, true, now: 5);
    await ops.setFollowed(id, false);
    expect(await repo.watchPodcasts().first, isEmpty);
    expect((await repo.watchEpisodes(id).first).single.episode.played, isTrue);
  });

  test('playing a followed show does not unfollow it', () async {
    final id = await ops.save(_ytm(), followed: true);
    await ops.saveForPlay(_ytm(), 'e1');
    expect((await repo.byId(id))!.followed, isTrue);
  });
}
