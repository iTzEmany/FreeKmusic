import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/podcast_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/podcast/episode_downloader.dart';
import 'package:codecore/services/podcast/podcast_models.dart';
import 'package:codecore/services/tags/tag_reader.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _Tags implements TagReader {
  _Tags({this.fail = false});
  final bool fail;
  final reads = <String>[];

  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async {
    reads.add(path);
    if (fail) throw StateError('unreadable');
    return TagInfo(durationMs: 1800000, bitrateKbps: 128, sampleRateHz: 44100);
  }
}

/// Waits for [gate] before it answers: the download is stopped inside the tag read.
class _GatedTags implements TagReader {
  final gate = Completer<void>();
  final entered = Completer<void>();

  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async {
    entered.complete();
    await gate.future;
    return const TagInfo();
  }
}

/// Holds nothing that cannot cross an isolate.
class _PlainTags implements TagReader {
  const _PlainTags();

  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async => const TagInfo(durationMs: 4242);
}

void main() {
  late Directory dir;
  late String base;
  late AppDatabase db;
  late PodcastRepository repo;
  late TrackRepository tracks;
  late HttpServer server;
  late int podcastId;
  late int episodeId;
  final requests = <String>[];
  final audio = List<int>.generate(3000, (i) => i % 251);
  var slowOpen = Completer<void>();

  String url(String path) => 'http://${server.address.host}:${server.port}$path';

  EpisodeDownloader build({TagReader? tags}) => EpisodeDownloader(
        repo: repo,
        tracks: tracks,
        tags: tags ?? _Tags(),
        baseDir: base,
        readTagsInIsolate: false,
      );

  Future<int> addEpisode(String guid, String audioUrl, {String? mime, String title = 'Episode One'}) async {
    await repo.upsertEpisodes(podcastId, [
      PodcastEpisodeInfo(guid: guid, title: title, audioUrl: audioUrl, mimeType: mime, duration: const Duration(minutes: 20)),
    ]);
    return (await repo.watchEpisodes(podcastId).first).firstWhere((e) => e.episode.guid == guid).episode.id;
  }

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('podcasts');
    base = p.join(dir.path, 'podcasts');
    db = AppDatabase(NativeDatabase.memory());
    repo = PodcastRepository(db);
    tracks = TrackRepository(db);
    requests.clear();
    slowOpen = Completer<void>();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      requests.add(req.uri.path);
      final res = req.response;
      switch (req.uri.path) {
        case '/a.mp3':
          res.headers.contentType = ContentType('audio', 'mpeg');
          res.contentLength = audio.length;
          res.add(audio);
        case '/noext':
          res.headers.contentType = ContentType('audio', 'mp4');
          res.add(audio);
        case '/video':
          res.headers.contentType = ContentType('video', 'mp4');
          res.add(audio);
        case '/octet':
          res.headers.contentType = ContentType('application', 'octet-stream');
          res.add(audio);
        case '/slow.mp3':
          res.headers.contentType = ContentType('audio', 'mpeg');
          res.contentLength = 100000;
          res.add(audio);
          await res.flush();
          slowOpen.complete();
          await Future<void>.delayed(const Duration(seconds: 10)); // the client gives up first
        case '/empty.mp3':
          res.headers.contentType = ContentType('audio', 'mpeg');
        default:
          res.statusCode = 404;
      }
      try {
        await res.close();
      } on Object {
        // the client went away
      }
    });
    podcastId = await repo.subscribe(
      'https://x/feed',
      const PodcastFeed(title: 'My Show', episodes: []),
      now: 1,
    );
    await repo.setCoverKey(podcastId, 'showcover');
    episodeId = await addEpisode('guid-1', url('/a.mp3'));
  });

  tearDown(() async {
    await server.close(force: true);
    await db.close();
    dir.deleteSync(recursive: true);
  });

  test('downloads into the podcast folder and makes the episode a track of kind 1', () async {
    final progress = <(int, int)>[];
    final trackId = await build().download(episodeId, onProgress: (r, t) => progress.add((r, t)));

    final t = (await tracks.getById(trackId!))!;
    expect(t.kind, 1);
    expect(t.folderId, isNull);
    expect(t.title, 'Episode One');
    expect(t.artist, 'My Show');
    expect(t.album, 'My Show');
    expect(t.genre, 'Podcast');
    expect(t.format, 'mp3');
    expect(t.durationMs, 1800000, reason: 'from the tags');
    expect(t.coverKey, 'showcover');
    expect(t.hasCover, isTrue);
    expect(t.albumKey, 'podcast|$podcastId');
    expect(p.isWithin(base, t.path), isTrue);
    expect(p.dirname(t.path), p.join(base, '$podcastId'));
    expect(File(t.path).readAsBytesSync(), audio);
    expect(File('${t.path}.part').existsSync(), isFalse);
    expect((await repo.episodeById(episodeId))!.trackId, trackId);
    expect(progress.last, (3000, 3000));
  });

  test('unsubscribing during the download leaves no file, no row and returns null', () async {
    final tags = _GatedTags();
    final pending = build(tags: tags).download(episodeId);
    await tags.entered.future;
    final paths = await repo.unsubscribe(podcastId);
    expect(paths, isEmpty);
    tags.gate.complete();
    expect(await pending, isNull);
    final files = Directory(base).listSync(recursive: true).whereType<File>().toList();
    expect(files, isEmpty);
    expect(await db.select(db.tracks).get(), isEmpty);
  });

  test('the tags are read in an isolate without taking the downloader along', () async {
    final dl = EpisodeDownloader(repo: repo, tracks: tracks, tags: const _PlainTags(), baseDir: base);
    final id = await dl.download(episodeId);
    expect((await tracks.getById(id!))!.durationMs, 4242);
  });

  group('orphans', () {
    Future<int> orphanRow(String path) => db.into(db.tracks).insert(TracksCompanion.insert(
        path: path, title: 't', albumKey: 'podcast|9', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1,
        kind: const Value(1)));

    test('removes a kind 1 row with no episode and the folder of a podcast that is gone', () async {
      final keep = (await build().download(episodeId))!;
      final lost = File(p.join(base, '9', 'x.mp3'))..createSync(recursive: true);
      final lostId = await orphanRow(lost.path);
      final other = File(p.join(base, 'notes', 'keep.txt'))..createSync(recursive: true);

      expect(await build().removeOrphans(), 2);

      expect(lost.existsSync(), isFalse);
      expect(Directory(p.join(base, '9')).existsSync(), isFalse);
      expect(await tracks.getById(lostId), isNull);
      expect(await tracks.getById(keep), isNotNull);
      expect(File((await tracks.getById(keep))!.path).existsSync(), isTrue);
      expect(other.existsSync(), isTrue, reason: 'only numbered folders are ours');
    });
  });

  test('unreadable tags do not stop it: the feed\'s length stands in', () async {
    final id = await build(tags: _Tags(fail: true)).download(episodeId);
    expect((await tracks.getById(id!))!.durationMs, 20 * 60 * 1000);
  });

  test('downloaded already: the same track comes back without another request', () async {
    final dl = build();
    final first = await dl.download(episodeId);
    requests.clear();
    expect(await dl.download(episodeId), first);
    expect(requests, isEmpty);
  });

  group('the format', () {
    test('the server\'s content type decides, then the address, then the feed', () {
      expect(episodeExtension(contentType: 'audio/mpeg', url: 'https://x/a.m4a'), 'mp3');
      expect(episodeExtension(contentType: 'audio/mp4; charset=x'), 'm4a');
      expect(episodeExtension(contentType: 'audio/x-m4a'), 'm4a');
      expect(episodeExtension(contentType: 'audio/ogg'), 'ogg');
      expect(episodeExtension(contentType: 'audio/opus'), 'opus');
      expect(episodeExtension(contentType: 'application/octet-stream', url: 'https://x/e.mp3?token=1'), 'mp3');
      expect(episodeExtension(contentType: 'binary/octet-stream', url: 'https://x/download/42', mime: 'audio/mpeg'), 'mp3');
      expect(episodeExtension(url: 'https://x/e.MP4'), 'm4a');
      expect(episodeExtension(contentType: 'video/mp4', url: 'https://x/e.mkv'), isNull);
      expect(episodeExtension(), isNull);
    });

    test('an episode without a known audio format is refused and leaves nothing', () async {
      final id = await addEpisode('guid-v', url('/video'));
      await expectLater(
        build().download(id),
        throwsA(isA<PodcastException>().having((e) => e.kind, 'kind', PodcastErrorKind.unsupportedFormat)),
      );
      expect(Directory(base).existsSync() ? Directory(base).listSync(recursive: true).whereType<File>() : <File>[], isEmpty);
      expect((await repo.episodeById(id))!.trackId, isNull);
    });

    test('octet-stream with the feed saying audio/mpeg is an mp3', () async {
      final id = await addEpisode('guid-o', url('/octet'), mime: 'audio/mpeg');
      final t = (await tracks.getById((await build().download(id))!))!;
      expect(t.format, 'mp3');
    });
  });

  test('a server error and an empty answer are network errors with no file left', () async {
    final bad = await addEpisode('guid-404', url('/missing.mp3'));
    await expectLater(
      build().download(bad),
      throwsA(isA<PodcastException>().having((e) => e.kind, 'kind', PodcastErrorKind.network)),
    );
    final empty = await addEpisode('guid-empty', url('/empty.mp3'));
    await expectLater(
      build().download(empty),
      throwsA(isA<PodcastException>().having((e) => e.kind, 'kind', PodcastErrorKind.network)),
    );
    final files = Directory(base).existsSync() ? Directory(base).listSync(recursive: true).whereType<File>().toList() : <File>[];
    expect(files, isEmpty);
    expect(await db.select(db.tracks).get(), isEmpty);
  });

  test('cancelling half way ends without a path and leaves no file behind', () async {
    final id = await addEpisode('guid-slow', url('/slow.mp3'));
    final cancel = CancelToken();
    final done = build().download(id, cancel: cancel, onProgress: (r, t) {});
    await slowOpen.future;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    cancel.cancel();

    expect(await done, isNull);
    final files = Directory(base).existsSync() ? Directory(base).listSync(recursive: true).whereType<File>().toList() : <File>[];
    expect(files, isEmpty, reason: 'no .part, no half episode');
    expect((await repo.episodeById(id))!.trackId, isNull);
    expect(await db.select(db.tracks).get(), isEmpty);
  });

  group('deleting the file', () {
    test('removes the file and the track, the episode stays listed as not downloaded; it can be downloaded again', () async {
      final dl = build();
      final trackId = (await dl.download(episodeId))!;
      final path = (await tracks.getById(trackId))!.path;

      await dl.deleteFile(episodeId);

      expect(File(path).existsSync(), isFalse);
      expect(await tracks.getById(trackId), isNull);
      final row = (await repo.watchEpisodes(podcastId).first).firstWhere((e) => e.episode.id == episodeId);
      expect(row.downloaded, isFalse);
      expect(row.episode.title, 'Episode One');

      expect(await dl.download(episodeId), isNotNull, reason: 'downloadable again');
    });

    test('a file outside the podcast folder is never deleted, but the link is cleaned', () async {
      final outside = File(p.join(dir.path, 'music', 'mine.mp3'))..createSync(recursive: true)..writeAsBytesSync([1, 2, 3]);
      final t = await db.into(db.tracks).insert(TracksCompanion.insert(
          path: outside.path, title: 'x', albumKey: 'k', format: 'mp3', sizeBytes: 3, mtimeMs: 1, addedAt: 1, kind: const Value(1)));
      await repo.setTrackId(episodeId, t);

      await build().deleteFile(episodeId);

      expect(outside.existsSync(), isTrue, reason: 'not ours to delete');
      expect((await repo.episodeById(episodeId))!.trackId, isNull);
    });

    test('a music track linked by mistake is left alone', () async {
      final music = File(p.join(base, 'm.mp3'))..createSync(recursive: true);
      final t = await db.into(db.tracks).insert(TracksCompanion.insert(
          path: music.path, title: 'music', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1));
      await repo.setTrackId(episodeId, t);
      await build().deleteFile(episodeId);
      expect(music.existsSync(), isTrue);
      expect(await tracks.getById(t), isNotNull);
    });

    test('an episode that was never downloaded: nothing happens', () async {
      await build().deleteFile(episodeId);
      await build().deleteFile(424242);
    });
  });

  test('orphan .part files are removed, nothing else', () async {
    final keep = File(p.join(base, '1', 'done.mp3'))..createSync(recursive: true);
    final orphan = File(p.join(base, '1', 'half.mp3.part'))..createSync(recursive: true);
    final orphan2 = File(p.join(base, '2', 'x.m4a.part'))..createSync(recursive: true);
    final outside = File(p.join(dir.path, 'other.part'))..createSync();

    expect(await build().removeOrphanParts(), 2);

    expect(orphan.existsSync(), isFalse);
    expect(orphan2.existsSync(), isFalse);
    expect(keep.existsSync(), isTrue);
    expect(outside.existsSync(), isTrue, reason: 'outside the podcast folder');
  });

  test('file names: safe, unique per guid, short', () {
    final a = episodeFileStem('https://api.spreaker.com/episode/47008027');
    final b = episodeFileStem('https://api.spreaker.com/episode/47008028');
    expect(a, isNot(b));
    expect(a, matches(RegExp(r'^[A-Za-z0-9._ -]+-[0-9a-f]{8}$')));
    expect(episodeFileStem('a/b\\c:d*e?'), isNot(matches(RegExp(r'[\\/:*?]'))));
    expect(episodeFileStem('x' * 500).length, lessThan(70));
    expect(episodeFileStem('???'), startsWith('episode-'));
    expect(episodeFileStem('same'), episodeFileStem('same'));
  });
}
