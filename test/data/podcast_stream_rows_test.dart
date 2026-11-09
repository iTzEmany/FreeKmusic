import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/podcast_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/online/youtube_service.dart' show YtResult;
import 'package:codecore/services/podcast/podcast_models.dart';
import 'package:codecore/services/podcast/ytm_podcast_sync.dart' show kPodcastSourceYtm;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

PodcastEpisodeInfo _ep(String guid, String url) => PodcastEpisodeInfo(guid: guid, title: 'T $guid', audioUrl: url);

void main() {
  late AppDatabase db;
  late PodcastRepository repo;
  late TrackRepository tracks;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PodcastRepository(db);
    tracks = TrackRepository(db);
  });
  tearDown(() => db.close());

  Future<int> show(String feed, List<PodcastEpisodeInfo> eps, {int source = 0}) =>
      repo.subscribe(feed, PodcastFeed(title: 'Show $feed', episodes: eps), now: 1, source: source);

  Future<int> epId(int podcastId, String guid) async => (await repo.episodeByGuid(podcastId, guid))!.id;

  Future<int> insertTrack(String path, {int kind = 1, int size = 0, int? resume}) => db.into(db.tracks).insert(
      TracksCompanion.insert(
          path: path, title: 'x', albumKey: 'k', format: 'mp3', sizeBytes: size, mtimeMs: 0, addedAt: 1,
          kind: Value(kind), resumePositionMs: Value(resume)));

  group('the YouTube Music path is shared with the shadow rows (kind 2)', () {
    test('a shadow row of the same video becomes the episode row (kind 1, the show\'s album)', () async {
      final shadow = await insertTrack('stream:youtube:v1', kind: 2);
      final pid = await show('https://music.youtube.com/browse/M1', [_ep('v1', 'https://music.youtube.com/watch?v=v1')],
          source: kPodcastSourceYtm);
      final t = (await repo.playableTrack(await epId(pid, 'v1')))!;
      expect(t.id, shadow);
      expect(t.kind, 1);
      expect(t.albumKey, 'podcast|$pid');
      expect(t.artist, 'Show https://music.youtube.com/browse/M1');
      expect(await tracks.streamRow('youtube:v1'), isNull, reason: 'no longer a shadow row: promote and merge leave it alone');
    });

    test('a cached file arriving for an episode row changes nothing on it', () async {
      final id = await insertTrack('stream:youtube:x');
      final f = File('${Directory.systemTemp.path}/cc_t4_${DateTime.now().microsecondsSinceEpoch}.m4a')..writeAsBytesSync([1, 2, 3]);
      addTearDown(f.deleteSync);
      const r = YtResult(id: 'x', title: 't', channel: 'c', duration: null);
      expect(await tracks.upsertStreamRow('youtube:x', r, f), id);
      final t = (await tracks.getById(id))!;
      expect([t.kind, t.sizeBytes, t.format], [1, 0, 'mp3'], reason: 'its size is the download\'s, not the cache\'s');
    });

    test('streamRow only finds kind 2', () async {
      await insertTrack('stream:youtube:e', kind: 1);
      await insertTrack('stream:youtube:s', kind: 2);
      expect(await tracks.streamRow('youtube:e'), isNull);
      expect(await tracks.streamRow('youtube:s'), isNotNull);
    });

    test('streamRowsAmong: kind 2 and kind 1 `stream:`, not a kind 1 address nor music', () async {
      final shadow = await insertTrack('stream:youtube:s', kind: 2);
      final ytm = await insertTrack('stream:youtube:e');
      final http = await insertTrack('https://x/e.mp3');
      final music = await insertTrack('/m/a.mp3', kind: 0);
      final ids = (await tracks.streamRowsAmong([shadow, ytm, http, music])).map((t) => t.id).toSet();
      expect(ids, {shadow, ytm});
    });
  });

  group('one row per episode', () {
    test('two episodes with the same address do not share a row (nor a bookmark)', () async {
      final pid = await show('https://x/feed', [_ep('a', 'https://x/same.mp3'), _ep('b', 'https://x/same.mp3')]);
      final a = (await repo.playableTrack(await epId(pid, 'a')))!;
      final b = (await repo.playableTrack(await epId(pid, 'b')))!;
      expect(a.id, isNot(b.id));
      expect(a.path, 'https://x/same.mp3');
      expect(b.path, 'https://x/same.mp3#cc-ep=${await epId(pid, 'b')}');
      expect((await repo.playableTrack(await epId(pid, 'b')))!.id, b.id, reason: 'and it is kept');
    });

    test('a row with that address that no episode links is taken over', () async {
      final orphan = await insertTrack('https://x/e.mp3');
      final pid = await show('https://x/feed', [_ep('a', 'https://x/e.mp3')]);
      expect((await repo.playableTrack(await epId(pid, 'a')))!.id, orphan);
    });

    test('a downloaded episode keeps its file row, with no address written on it', () async {
      final pid = await show('https://x/feed', [_ep('a', 'https://x/e.mp3')]);
      final id = await epId(pid, 'a');
      final file = await insertTrack('/data/podcasts/1/a.mp3', size: 99);
      await repo.setTrackId(id, file);
      final t = (await repo.playableTrack(id))!;
      expect([t.id, t.path, t.sizeBytes], [file, '/data/podcasts/1/a.mp3', 99]);
    });

    test('a streamed episode is not a download', () async {
      final pid = await show('https://music.youtube.com/browse/M', [_ep('x', 'https://music.youtube.com/watch?v=x')],
          source: kPodcastSourceYtm);
      await repo.playableTrack(await epId(pid, 'x'));
      expect(await repo.downloadedEpisodes(), isEmpty);
      expect((await repo.watchEpisodes(pid).first).single.downloaded, isFalse);
      expect((await repo.watchPodcasts().first).isEmpty, isFalse);
      expect((await repo.watchPodcasts().first).single.toListen, 0);
    });
  });

  group('the feed moves the audio', () {
    test('the streaming row follows the new address, in the same refresh', () async {
      final pid = await show('https://x/feed', [_ep('a', 'https://x/old.mp3')]);
      final row = (await repo.playableTrack(await epId(pid, 'a')))!;
      await repo.upsertEpisodes(pid, [_ep('a', 'https://x/new.mp3')]);
      expect((await tracks.getById(row.id))!.path, 'https://x/new.mp3');
    });

    test('a new address that another row has is not taken', () async {
      final pid = await show('https://x/feed', [_ep('a', 'https://x/old.mp3')]);
      final row = (await repo.playableTrack(await epId(pid, 'a')))!;
      await insertTrack('https://x/new.mp3');
      await repo.upsertEpisodes(pid, [_ep('a', 'https://x/new.mp3')]);
      expect((await tracks.getById(row.id))!.path, 'https://x/old.mp3');
    });

    test('a downloaded file is not rewritten with the address', () async {
      final pid = await show('https://x/feed', [_ep('a', 'https://x/old.mp3')]);
      final file = await insertTrack('/data/podcasts/1/a.mp3', size: 5);
      await repo.setTrackId(await epId(pid, 'a'), file);
      await repo.upsertEpisodes(pid, [_ep('a', 'https://x/new.mp3')]);
      expect((await tracks.getById(file))!.path, '/data/podcasts/1/a.mp3');
    });
  });

  test('unsubscribing returns the files to delete, not the addresses of streamed episodes', () async {
    final pid = await show('https://x/feed', [_ep('a', 'https://x/a.mp3'), _ep('b', 'https://x/b.mp3'), _ep('c', 'https://x/c.mp3')]);
    await repo.playableTrack(await epId(pid, 'a'));
    await repo.setTrackId(await epId(pid, 'b'), await insertTrack('/data/podcasts/1/b.mp3', size: 5));
    expect(await repo.unsubscribe(pid), ['/data/podcasts/1/b.mp3']);
    expect(await db.select(db.tracks).get(), isEmpty, reason: 'the streaming rows go too');
  });

  group('«Riprendi»', () {
    test('the list follows an episode being marked as heard, and heard again as not', () async {
      final pid = await show('https://x/feed', [_ep('a', 'https://x/a.mp3')]);
      final id = await epId(pid, 'a');
      final row = (await repo.playableTrack(id))!;
      await tracks.setResumePosition(row.id, 5000);
      await (db.update(db.tracks)..where((t) => t.id.equals(row.id))).write(const TracksCompanion(lastPlayedAt: Value(9)));
      final seen = <List<String>>[];
      final sub = tracks.watchResumable().listen((l) => seen.add([for (final t in l) t.title]));
      addTearDown(sub.cancel);
      await pumpEventQueue();
      await repo.markPlayed(id, true, now: 1);
      await pumpEventQueue();
      await repo.markPlayed(id, false, now: 1);
      await pumpEventQueue();
      expect(seen, [['T a'], <String>[], ['T a']]);
    });
  });
}

