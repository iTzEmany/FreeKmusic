import 'dart:convert';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/podcast_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/online/innertube_client.dart';
import 'package:codecore/services/online/yt_dlp_args.dart' show podcastAudioSelector;
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_podcasts.dart';
import 'package:codecore/services/podcast/episode_downloader.dart';
import 'package:codecore/services/podcast/podcast_models.dart';
import 'package:codecore/services/podcast/ytm_podcast_sync.dart';
import 'package:codecore/services/tags/tag_reader.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const showId = 'MPSPPLGqhp239bqQz08jpYYsrXdCXAxqD9fXP4';

class _Adapter implements HttpClientAdapter {
  final Map more = jsonDecode(File('test/fixtures/innertube/ytm_podcast_show_more.json').readAsStringSync()) as Map;
  Map page = jsonDecode(File('test/fixtures/innertube/ytm_podcast_show.json').readAsStringSync()) as Map;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? r, Future<void>? c) async =>
      ResponseBody.fromString(jsonEncode((o.data as Map).containsKey('continuation') ? more : page), 200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  @override
  void close({bool force = false}) {}
}

class _Tags implements TagReader {
  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async => TagInfo(durationMs: 1000);
}

/// A yt-dlp that writes an m4a where it is told and remembers what it was asked.
class _Yt extends YoutubeService {
  DownloadOptions? options;
  YtResult? asked;
  Object? failWith;
  @override
  Stream<DownloadProgress> download(YtResult r, Directory outDir,
      {CancelToken? cancel, DownloadOptions options = const DownloadOptions()}) async* {
    this.options = options;
    asked = r;
    outDir.createSync(recursive: true);
    final f = File(p.join(outDir.path, '${r.downloadName}.m4a'))..writeAsBytesSync([1, 2, 3]);
    if (failWith != null) throw failWith!;
    yield DownloadProgress(received: 100, total: 100, path: f.path);
  }

  @override
  Future<List<YtResult>> search(String query) async => const [];
  @override
  Future<List<YtResult>> searchSongs(String query, {int limit = 5}) async => const [];
  @override
  Future<List<YtResult>> searchAlbums(String query, {int limit = 3}) async => const [];
  @override
  Future<List<YtResult>> albumTracks(String albumLink) async => const [];
  @override
  Future<String?> toolVersion() async => null;
}

void main() {
  late AppDatabase db;
  late PodcastRepository repo;
  late _Adapter adapter;
  late YtmPodcastSync sync;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PodcastRepository(db);
    adapter = _Adapter();
    final dio = Dio(BaseOptions(validateStatus: (_) => true))..httpClientAdapter = adapter;
    sync = YtmPodcastSync(
        repo: repo, ytm: YtmPodcasts(InnerTubeClient(dio)), now: () => DateTime.utc(2026, 11, 6));
  });
  tearDown(() => db.close());

  test('subscribing saves the show with its source and 24 episodes (two pages); again changes nothing', () async {
    final id = await sync.subscribe(showId);
    final podcast = (await repo.byId(id))!;
    expect((podcast.source, podcast.sourceId, podcast.title), (kPodcastSourceYtm, showId, 'Il Prof di Storia'));
    expect(podcast.feedUrl, ytmShowFeedUrl(showId));
    final episodes = await repo.watchEpisodes(id).first;
    expect(episodes, hasLength(24));
    expect(episodes.first.episode.guid, 'B2Tep-eGwmQ');
    expect(episodes.first.episode.audioUrl, 'https://music.youtube.com/watch?v=B2Tep-eGwmQ');
    expect(await sync.subscribe(showId), id);
    expect(await repo.all(), hasLength(1));
  });

  test('refresh adds only the new episodes; an RSS podcast is left alone', () async {
    final id = await sync.subscribe(showId);
    // The oldest episode is gone from the page; a new one is on top.
    final rows = adapter.page['contents']['twoColumnBrowseResultsRenderer']['secondaryContents']
        ['sectionListRenderer']['contents'][0]['musicShelfRenderer']['contents'] as List;
    final fresh = jsonDecode(jsonEncode(rows.first)) as Map;
    fresh['musicMultiRowListItemRenderer']['onTap']['watchEndpoint']['videoId'] = 'NEWVIDEO001';
    rows.insert(0, fresh);
    expect(await sync.refresh(id), 1);
    expect(await sync.refresh(id), 0);
    expect(await repo.watchEpisodes(id).first, hasLength(25));

    final rss = await repo.subscribe('https://x/feed', const PodcastFeed(title: 'RSS', episodes: []), now: 1);
    expect((await repo.byId(rss))!.source, 0);
    expect((await repo.byId(rss))!.sourceId, isNull);
    expect(await sync.refresh(rss), 0);
  });

  test('a YouTube Music episode is downloaded with yt-dlp, audio only, and becomes a track', () async {
    final id = await sync.subscribe(showId);
    final episode = (await repo.watchEpisodes(id).first).first.episode;
    final dir = Directory.systemTemp.createTempSync('ytmep');
    addTearDown(() => dir.deleteSync(recursive: true));
    final yt = _Yt();
    final downloader = EpisodeDownloader(
        repo: repo, tracks: TrackRepository(db), tags: _Tags(), baseDir: dir.path, readTagsInIsolate: false, youtube: yt);
    final trackId = await downloader.download(episode.id);
    expect(trackId, isNotNull);
    expect(yt.options!.selector, podcastAudioSelector);
    expect(yt.asked!.downloadUrl, 'https://music.youtube.com/watch?v=B2Tep-eGwmQ');
    final row = (await repo.downloadedEpisodes()).single;
    expect(row.track!.format, 'm4a');
    expect(row.track!.kind, 1);
    expect(row.track!.title, episode.title);
  });

  test('a failed yt-dlp keeps its reason and leaves no half file; a retry starts clean', () async {
    final id = await sync.subscribe(showId);
    final episode = (await repo.watchEpisodes(id).first).first.episode;
    final dir = Directory.systemTemp.createTempSync('ytmep');
    addTearDown(() => dir.deleteSync(recursive: true));
    final yt = _Yt()..failWith = const YtException(YtErrorKind.toolMissing);
    final downloader = EpisodeDownloader(
        repo: repo, tracks: TrackRepository(db), tags: _Tags(), baseDir: dir.path, readTagsInIsolate: false, youtube: yt);
    await expectLater(
        downloader.download(episode.id),
        throwsA(isA<PodcastException>().having((e) => e.yt, 'yt', YtErrorKind.toolMissing)));
    expect(Directory(dir.path).listSync(recursive: true).whereType<File>(), isEmpty);

    final orphan = File(p.join(dir.path, '$id', '${episodeFileStem(episode.guid)}.webm'))
      ..createSync(recursive: true)
      ..writeAsBytesSync([9]);
    yt.failWith = null;
    expect(await downloader.download(episode.id), isNotNull);
    expect(orphan.existsSync(), isFalse);
  });
}
