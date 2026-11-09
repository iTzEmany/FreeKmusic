import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/podcast_repository.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/podcast_ops.dart';
import 'package:codecore/providers/podcast_providers.dart';
import 'package:codecore/services/podcast/podcast_models.dart';
import 'package:codecore/services/podcast/ytm_podcast_sync.dart';
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
    final play = await ops.saveForPlay(_ytm(), 'e1');
    expect(play?.stream?.id, 'e1');
    final saved = (await repo.all()).single;
    expect(saved.followed, isFalse);
    expect(await repo.episodeGuids(saved.id), {'e1'});
    expect(await repo.watchPodcasts().first, isEmpty);
  });

  test('a show that cannot play yet is not saved', () async {
    const rss = PodcastPreview(feedUrl: 'https://x/feed', feed: _feed);
    expect(await ops.saveForPlay(rss, 'e1'), isNull);
    expect(await repo.all(), isEmpty);
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
