import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/import_repository.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/import/import_candidate.dart';
import 'package:codecore/services/import/import_options.dart';
import 'package:codecore/services/import/imported_playlist.dart';
import 'package:codecore/services/import/import_chain.dart';
import 'package:codecore/services/import/playlist_import_service.dart';
import 'package:codecore/services/import/track_matcher.dart' show MatchThresholds;
import 'package:codecore/services/online/download_queue.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers searches from a map; records how many searches were made.
class FakeYoutube implements YoutubeService {
  final Map<String, List<YtResult>> songs = {};
  final Map<String, List<YtResult>> plain = {};
  final Map<String, List<YtResult>> albums = {};
  int albumSearches = 0, albumPages = 0;
  YtException? failWith;

  /// With [failWith]: how many calls fail before the answers come back
  /// (null = all of them).
  int? failTimes;

  /// Album pages that cannot be read.
  YtException? albumPageFails;

  void _maybeFail() {
    final f = failWith;
    if (f == null) return;
    final left = failTimes;
    if (left != null) {
      if (left == 0) return;
      failTimes = left - 1;
    }
    throw f;
  }
  int searches = 0;
  final queries = <String>[];

  @override
  Future<List<YtResult>> searchSongs(String query, {int limit = 5}) async {
    searches++;
    queries.add('songs:$query');
    _maybeFail();
    return songs.entries
        .firstWhere((e) => query.contains(e.key),
            orElse: () => const MapEntry('', []))
        .value;
  }

  @override
  Future<List<YtResult>> search(String query) async {
    searches++;
    queries.add('plain:$query');
    _maybeFail();
    return plain.entries
        .firstWhere((e) => query.contains(e.key),
            orElse: () => const MapEntry('', []))
        .value;
  }

  @override
  Future<PlaylistListing> listPlaylist(String url, {int limit = 500}) async =>
      const PlaylistListing.empty();

  @override
  Future<List<YtResult>> searchAlbums(String query, {int limit = 3}) async {
    albumSearches++;
    queries.add('albums:$query');
    _maybeFail();
    return [
      for (final k in albums.keys)
        if (query.toLowerCase().contains(k))
          YtResult(id: 'link:$k', title: k, channel: '', duration: null),
    ];
  }

  @override
  Future<List<YtResult>> albumTracks(String albumLink) async {
    albumPages++;
    if (albumPageFails != null) throw albumPageFails!;
    return albums[albumLink.substring(5)] ?? const [];
  }

  @override
  Stream<DownloadProgress> download(YtResult r, Directory outDir,
          {CancelToken? cancel,
          DownloadOptions options = const DownloadOptions()}) =>
      const Stream.empty();

  @override
  Future<String?> toolVersion() async => '2026.08.19';

  @override
  void close() {}
}

YtResult topic(String id, String title, String artist, int seconds) => YtResult(
    id: id,
    title: title,
    channel: '$artist - Topic',
    duration: Duration(seconds: seconds),
    artists: [artist]);

ImportRow row(int i, String title, String artist, int seconds) => ImportRow(
    index: i,
    title: title,
    artists: [artist],
    durationMs: seconds * 1000,
    isrc: 'ISRC$i');

void main() {
  late AppDatabase db;
  late ImportRepository imports;
  late PlaylistRepository playlists;
  late TrackRepository tracks;
  late FakeYoutube yt;
  late StreamController<DownloadItem> settled;
  late List<(YtResult, String)> queued;
  late List<String> tagged;
  late List<int?> trackNumbers;
  late List<int> enriched;
  late List<ImportSteps> stepsDuringTags;
  late List<ImportEvent> events;
  late PlaylistImportService service;
  var cancelCalls = 0;
  final coverCalls = <String>[];
  var coverFails = false;
  final forgotten = <List<String>>[];
  var enabled = true;
  var maxInFlight = 3;
  // No wait by default: a network error or a rate limit pauses at once.
  var backoff = <Duration>[];
  late List<ImportWait?> waits;

  Future<int> addTrack(String path, String title, String artist, int seconds) async {
    await tracks.upsertBatch([
      TracksCompanion.insert(
          path: path,
          title: title,
          albumKey: 'k',
          format: 'mp3',
          sizeBytes: 1,
          mtimeMs: 1,
          addedAt: 1,
          artist: Value(artist),
          durationMs: Value(seconds * 1000)),
    ]);
    return (await tracks.idForPath(path))!;
  }

  PlaylistImportService build() {
    final s = PlaylistImportService(
      imports: imports,
      playlists: playlists,
      loadLibrary: tracks.liteEntries,
      youtube: yt,
      enqueue: (r, tag) => queued.add((r, tag)),
      cancelDownloads: (_) => cancelCalls++,
      forgetSearches: forgotten.add,
      trackDurationMs: (id) async => (await tracks.getById(id))?.durationMs,
      settled: settled.stream,
      trackIdForPath: tracks.idForPath,
      pathForVideo: (_) async => null,
      applyTags: (id, r) async {
        tagged.add('$id:${r.title}');
        trackNumbers.add(r.trackNumber);
        stepsDuringTags.add(service.currentSteps);
      },
      enrichLater: enriched.add,
      fetchCover: (id, row) async {
        coverCalls.add('$id:${row.album}');
        if (coverFails) throw StateError('iTunes down');
      },
      youtubeEnabled: enabled,
      searchGap: Duration.zero,
      pollDelay: Duration.zero,
      maxInFlight: maxInFlight,
      networkBackoff: backoff,
      rateLimitBackoff: backoff,
    );
    s.events.listen(events.add);
    s.waits.listen(waits.add);
    return s;
  }

  /// A service with the settings changed in the test (the one from setUp
  /// would also answer the same downloads).
  void rebuild() {
    service.dispose();
    service = build();
  }

  /// Lets the engine and the settled handlers run to quiescence. Every timer
  /// on their path is zero-length (searchGap, pollDelay, drift's Timer.run on
  /// an in-memory database), so a fixed number of event-loop turns is enough:
  /// no wall-clock wait, and the same interleaving on any machine.
  Future<void> idle() async {
    for (var i = 0; i < 200; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  ImportedPlaylist csv(List<ImportRow> rows) =>
      ImportedPlaylist(name: 'Mood', rows: rows);

  Future<List<String>> order(int playlistId) async =>
      (await playlists.watchTracks(playlistId).first).map((t) => t.title).toList();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    imports = ImportRepository(db);
    playlists = PlaylistRepository(db);
    tracks = TrackRepository(db);
    yt = FakeYoutube();
    settled = StreamController<DownloadItem>.broadcast();
    queued = [];
    tagged = [];
    trackNumbers = [];
    enriched = [];
    stepsDuringTags = [];
    events = [];
    cancelCalls = 0;
    coverCalls.clear();
    coverFails = false;
    forgotten.clear();
    enabled = true;
    maxInFlight = 3;
    backoff = [];
    waits = [];
    service = build();
  });
  tearDown(() async {
    service.dispose();
    await settled.close();
    await db.close();
  });

  Future<void> finish(String tag, String path, {int? seconds}) async {
    // By default the file is as long as the CSV says.
    final ref = parseImportTag(tag)!;
    final want = (await imports.item(ref.$1, ref.$2))?.durationMs;
    await addTrack(
        path, path, 'x', seconds ?? (want == null ? 100 : (want / 1000).round()));
    settled.add(DownloadItem(
        id: 1,
        result: const YtResult(id: 'v', title: 't', channel: 'c', duration: null),
        status: DownloadStatus.done,
        path: path,
        tag: tag));
    await idle();
  }

  test('a track already in the library is linked without any search', () async {
    await addTrack('/m/felicita.mp3', 'Felicità', 'Lucio Dalla', 345);
    final id = await service.start(csv([row(0, 'Felicità', 'Lucio Dalla', 345)]));
    await idle();
    expect(yt.searches, 0);
    expect(queued, isEmpty);
    final imp = (await imports.get(id))!;
    expect(imp.state, ImportStatus.finished);
    expect(await order(imp.playlistId), ['Felicità']);
    expect((await imports.item(id, 0))!.state, ImportItemStatus.linked);
    expect(events.single.kind, ImportEventKind.completed);
  });

  test('a sure match is downloaded, tagged and placed in CSV order', () async {
    yt.songs['one'] = [topic('v1', 'One', 'Band', 200)];
    yt.songs['two'] = [topic('v2', 'Two', 'Band', 210)];
    final id = await service.start(
        csv([row(0, 'One', 'Band', 200), row(1, 'Two', 'Band', 210)]));
    await idle();
    expect(queued.map((q) => q.$2), [importTag(id, 0), importTag(id, 1)]);
    expect(queued.first.$1.downloadName, 'Band - One');
    expect(queued.first.$1.subdir, isNull, reason: 'no folder option');
    expect((await imports.item(id, 0))!.state, ImportItemStatus.queued);
    expect((await imports.get(id))!.state, ImportStatus.running);

    // Second one arrives first.
    await finish(importTag(id, 1), '/m/two.mp3');
    await finish(importTag(id, 0), '/m/one.mp3');
    final imp = (await imports.get(id))!;
    expect(imp.state, ImportStatus.finished);
    expect(await order(imp.playlistId), ['/m/one.mp3', '/m/two.mp3']);
    expect(tagged, hasLength(2));
    expect((await imports.item(id, 0))!.state, ImportItemStatus.downloaded);
    expect(events.last.kind, ImportEventKind.completed);
  });

  test('a saved song is «enriching» while it gets the CSV tags, then goes to '
      'the background enrichment', () async {
    yt.songs['one'] = [topic('v1', 'One', 'Band', 200)];
    final id = await service.start(csv([row(0, 'One', 'Band', 200)]));
    await idle();
    expect(service.currentSteps, isEmpty, reason: 'the search is over');
    await finish(importTag(id, 0), '/m/one.mp3');
    expect(stepsDuringTags.single, {(id, 0): ImportStepKind.enriching});
    expect(service.currentSteps, isEmpty);
    expect(enriched, [(await imports.item(id, 0))!.trackId]);
  });

  test('an unsure match waits for the user with its candidates', () async {
    yt.songs['mother'] = [
      YtResult(
          id: 'c1',
          title: 'Pink Floyd - Mother',
          channel: 'SomeUploader',
          duration: null),
    ];
    final id = await service.start(csv([row(0, 'Mother', 'Pink Floyd', 334)]));
    await idle();
    final it = (await imports.item(id, 0))!;
    expect(it.state, ImportItemStatus.review);
    expect(decodeCandidates(it.candidates).single.id, 'c1');
    expect(queued, isEmpty);
    expect((await imports.get(id))!.state, ImportStatus.finished);

    // The user picks it: the import goes back to running.
    await service.download(id, 0, decodeCandidates(it.candidates).single.toYtResult());
    expect(queued.single.$2, importTag(id, 0));
    expect((await imports.get(id))!.state, ImportStatus.running);
    await finish(importTag(id, 0), '/m/mother.mp3');
    expect((await imports.get(id))!.state, ImportStatus.finished);
  });

  test('nothing found is saved as not found and the import goes on', () async {
    yt.songs['two'] = [topic('v2', 'Two', 'Band', 210)];
    final id = await service.start(
        csv([row(0, 'Zzz Unknown', 'Nobody', 100), row(1, 'Two', 'Band', 210)]));
    await idle();
    expect((await imports.item(id, 0))!.state, ImportItemStatus.notFound);
    expect(queued.single.$2, importTag(id, 1));
  });

  group('candidates saved with a source', () {
    test('a SoundCloud candidate saved by an older version is still read and downloads from its page', () {
      final c = decodeCandidates('[{"id":"s2","title":"Band - Rare Song","channel":"dj","durationSec":206,'
              '"score":0.7,"src":"soundcloud","url":"https://soundcloud.com/dj/s2"}]')
          .single;
      expect(c.source, MediaSource.soundcloud);
      expect(c.toYtResult().source, MediaSource.soundcloud);
      expect(c.toYtResult().downloadUrl, 'https://soundcloud.com/dj/s2');
    });

    test('a candidate saved before sources existed reads back as YouTube', () {
      final c = decodeCandidates('[{"id":"abc","title":"T","channel":"C","durationSec":10,"score":0.9}]').single;
      expect(c.source, MediaSource.youtube);
      expect(c.webpageUrl, isNull);
      expect(c.toYtResult().downloadUrl, 'https://www.youtube.com/watch?v=abc');
    });
  });

  group('a night alone: errors wait and try again', () {
    test('a network error waits and searches the same row again', () async {
      backoff = [Duration.zero, Duration.zero];
      rebuild();
      yt
        ..failWith = const YtException(YtErrorKind.network)
        ..failTimes = 2
        ..songs['one'] = [topic('v1', 'One', 'Band', 200)];
      final id = await service.start(csv([row(0, 'One', 'Band', 200)]));
      await idle();
      expect(queued.single.$2, importTag(id, 0));
      expect(events, isEmpty, reason: 'no pause');
      expect(waits.whereType<ImportWait>().map((w) => w.reason),
          [ImportEventKind.network, ImportEventKind.network]);
      expect(service.currentWait, isNull);
    });

    test('when the waits run out the import pauses, the row still to do', () async {
      backoff = [Duration.zero, Duration.zero];
      rebuild();
      yt.failWith = const YtException(YtErrorKind.network);
      final id = await service.start(csv([row(0, 'One', 'Band', 200)]));
      await idle();
      expect((await imports.get(id))!.state, ImportStatus.paused);
      expect((await imports.item(id, 0))!.state, ImportItemStatus.pending);
      expect(events.single.kind, ImportEventKind.network);
      expect(yt.searches, greaterThanOrEqualTo(3));
    });

    test('YouTube asks to slow down: wait, then go on', () async {
      backoff = [Duration.zero];
      rebuild();
      yt
        ..failWith = const YtException(YtErrorKind.rateLimited)
        ..failTimes = 1
        ..songs['one'] = [topic('v1', 'One', 'Band', 200)];
      await service.start(csv([row(0, 'One', 'Band', 200)]));
      await idle();
      expect(queued, hasLength(1));
      expect(events, isEmpty);
      expect(waits.whereType<ImportWait>().single.reason, ImportEventKind.rateLimited);
    });

    test('a download refused for too many requests is done again after the wait', () async {
      backoff = [Duration.zero];
      rebuild();
      yt.songs['one'] = [topic('v1', 'One', 'Band', 200)];
      final id = await service.start(csv([row(0, 'One', 'Band', 200)]));
      await idle();
      settled.add(DownloadItem(
          id: 1,
          result: queued.single.$1,
          status: DownloadStatus.failed,
          error: YtErrorKind.rateLimited,
          tag: importTag(id, 0)));
      await idle();
      expect(queued, hasLength(2), reason: 'queued again');
      expect((await imports.item(id, 0))!.state, ImportItemStatus.queued);
      expect((await imports.get(id))!.state, ImportStatus.running);
      expect(events, isEmpty);
    });

    test('pause and resume during a long wait try again at once', () async {
      backoff = [const Duration(hours: 1)];
      rebuild();
      yt
        ..failWith = const YtException(YtErrorKind.network)
        ..failTimes = 1
        ..songs['one'] = [topic('v1', 'One', 'Band', 200)];
      final id = await service.start(csv([row(0, 'One', 'Band', 200)]));
      await idle();
      expect(service.currentWait?.reason, ImportEventKind.network);
      expect(queued, isEmpty);
      await service.pause(id);
      await service.resume(id);
      await idle();
      expect(queued.single.$2, importTag(id, 0));
    });
  });

  test('rate limiting pauses the import when there is no wait left; resume continues',
      () async {
    yt.failWith = const YtException(YtErrorKind.rateLimited);
    final id = await service.start(csv([row(0, 'One', 'Band', 200)]));
    await idle();
    expect((await imports.get(id))!.state, ImportStatus.paused);
    expect((await imports.item(id, 0))!.state, ImportItemStatus.pending);
    expect(events.map((e) => e.kind), contains(ImportEventKind.rateLimited));

    yt.failWith = null;
    yt.songs['one'] = [topic('v1', 'One', 'Band', 200)];
    await service.resume(id);
    await idle();
    expect(queued.single.$2, importTag(id, 0));
  });

  test('a second recoverAfterRestart mid-session does not queue live downloads again', () async {
    yt.songs['one'] = [topic('v1', 'One', 'Band', 200)];
    yt.songs['two'] = [topic('v2', 'Two', 'Band', 200)];
    await service.recoverAfterRestart(); // app start
    final id = await service.start(csv([row(0, 'One', 'Band', 200), row(1, 'Two', 'Band', 200)]));
    await idle();
    expect(queued.length, 2);
    await service.recoverAfterRestart(); // the shell rebuilt its listener
    await idle();
    expect(queued.length, 2, reason: 'downloads already in the queue must not be queued again');
    expect((await imports.get(id))!.state, ImportStatus.running);
  });

  group('after an app restart', () {
    Future<int> cutImport(ImportStatus status) async {
      yt.songs['one'] = [topic('v1', 'One', 'Band', 200)];
      final id = await imports.create(
          playlistId: await playlists.create('Mood'), sourceName: 'Mood', rows: [row(0, 'One', 'Band', 200)]);
      await imports.setStatus(id, status);
      return id;
    }

    test('an import cut off by the app closing goes on by itself', () async {
      final id = await cutImport(ImportStatus.running);
      await service.recoverAfterRestart();
      await idle();
      expect(queued.single.$2, importTag(id, 0));
      expect((await imports.get(id))!.state, ImportStatus.running);
    });

    test('a pause chosen by the user stays paused', () async {
      final id = await cutImport(ImportStatus.paused);
      await service.recoverAfterRestart();
      await idle();
      expect(queued, isEmpty);
      expect((await imports.get(id))!.state, ImportStatus.paused);
    });
  });

  group('a pasted YouTube playlist (startFromResults)', () {
    YtResult video(String id, String title, String channel, int seconds) => YtResult(
          id: id,
          title: title,
          channel: channel,
          duration: Duration(seconds: seconds),
        );

    test('every video is downloaded as listed, in order, with no search at all', () async {
      final id = await service.startFromResults('My mix', [
        video('a1', 'Daft Punk - One More Time', 'Daft Punk', 320),
        video('b2', 'Some Talk - Computerphile', 'Computerphile', 900),
        video('c3', 'Third', 'Chan', 100),
      ]);
      await idle();

      expect(yt.searches, 0, reason: 'nothing is searched: the videos are known');
      expect(yt.albumSearches, 0);
      expect(queued.map((q) => q.$2), [importTag(id, 0), importTag(id, 1), importTag(id, 2)]);
      expect(queued.map((q) => q.$1.id), ['a1', 'b2', 'c3']);
      expect(queued.first.$1.downloadUrl, 'https://www.youtube.com/watch?v=a1');
      expect(queued.first.$1.downloadName, 'Daft Punk - One More Time', reason: 'the title read as «Artist - Title»');
      final imp = (await imports.get(id))!;
      expect(imp.sourceName, 'My mix');
      expect(imp.sourceKind, 'youtube');
      expect((await imports.item(id, 2))!.state, ImportItemStatus.queued);
    });

    test('a video already in the library is linked, not downloaded again', () async {
      await addTrack('/m/one.mp3', 'One More Time', 'Daft Punk', 320);
      final id = await service.startFromResults('Mix', [
        video('a1', 'Daft Punk - One More Time', 'Daft Punk', 320),
        video('b2', 'Other', 'Chan', 100),
      ]);
      await idle();
      expect(queued.map((q) => q.$1.id), ['b2']);
      expect((await imports.item(id, 0))!.state, ImportItemStatus.linked);
    });

    test('an album import numbers the songs by their place in the album; a plain one does not', () async {
      final album = await service.startFromResults(
        'Album — Band',
        [video('a1', 'Second to download', 'Band', 100), video('b2', 'Other', 'Band', 100)],
        sourceKind: ytmAlbumSourceKind,
      );
      await idle();
      expect((await imports.get(album))!.sourceKind, ytmAlbumSourceKind);
      // The second row finishes first: its number is still its place, 2.
      await finish(queued[1].$2, '/m/b.mp3');
      await finish(queued[0].$2, '/m/a.mp3');
      expect(trackNumbers, [2, 1]);

      trackNumbers.clear();
      queued.clear();
      await service.startFromResults('Mix', [video('c3', 'Third', 'Chan', 100)]);
      await idle();
      await finish(queued.single.$2, '/m/c.mp3');
      expect(trackNumbers, [null]);
    });

    test('an empty list finishes at once and an unnamed one is called YouTube', () async {
      final id = await service.startFromResults('  ', const []);
      expect((await imports.get(id))!.state, ImportStatus.finished);
      expect((await imports.get(id))!.sourceName, 'YouTube');
    });

    test('rowFromResult: channel as artist when the title does not say, credited artists first', () {
      final plain = PlaylistImportService.rowFromResult(3, video('x', 'Just A Title', 'Some Channel', 60));
      expect(plain.title, 'Just A Title');
      expect(plain.artists, ['Some Channel']);
      expect(plain.index, 3);
      final topicChannel = PlaylistImportService.rowFromResult(0, video('x', 'Song', 'Band - Topic', 60));
      expect(topicChannel.artists, ['Band']);
      final credited = PlaylistImportService.rowFromResult(
          0, const YtResult(id: 'x', title: 'Song', channel: 'c', duration: null, artists: ['A', 'B']));
      expect(credited.artists, ['A', 'B']);
      final none = PlaylistImportService.rowFromResult(0, video('x', 'Song', '', 60));
      expect(none.artists, isEmpty);
    });
  });

  test('cancel stops searching and drops queued downloads', () async {
    yt.songs['one'] = [topic('v1', 'One', 'Band', 200)];
    maxInFlight = 1;
    service.dispose();
    service = build();
    final id = await service.start(
        csv([row(0, 'One', 'Band', 200), row(1, 'Two', 'Band', 210)]));
    await idle();
    expect(queued, hasLength(1)); // second row waits: only one in flight
    await service.cancel(id);
    await idle();
    expect(cancelCalls, 1);
    expect((await imports.get(id))!.state, ImportStatus.cancelled);
    expect((await imports.item(id, 1))!.state, ImportItemStatus.pending);
  });

  test('no more than maxInFlight downloads wait at the same time', () async {
    const names = ['alpha', 'bravo', 'charlie', 'delta'];
    for (final n in names) {
      yt.songs[n] = [topic('v$n', n, 'Band', 100)];
    }
    maxInFlight = 2;
    service.dispose();
    service = build();
    final id = await service.start(csv([
      for (var i = 0; i < 4; i++) row(i, names[i], 'Band', 100),
    ]));
    await idle();
    expect(queued, hasLength(2));
    await finish(importTag(id, 0), '/m/alpha.mp3');
    expect(queued, hasLength(3));
  });

  test('with YouTube disabled only library tracks are linked', () async {
    enabled = false;
    service.dispose();
    service = build();
    await addTrack('/m/a.mp3', 'A', 'Band', 100);
    final id = await service.start(
        csv([row(0, 'A', 'Band', 100), row(1, 'B', 'Band', 100)]));
    await idle();
    expect(yt.searches, 0);
    expect((await imports.item(id, 0))!.state, ImportItemStatus.linked);
    expect((await imports.item(id, 1))!.state, ImportItemStatus.notFound);
  });

  test('importing the same CSV again into the playlist adds only new rows', () async {
    await addTrack('/m/a.mp3', 'A', 'Band', 100);
    final first = await service.start(csv([row(0, 'A', 'Band', 100)]));
    await idle();
    final playlistId = (await imports.get(first))!.playlistId;

    yt.songs['b'] = [topic('vb', 'B', 'Band', 100)];
    final second = await service.start(
        csv([row(0, 'A', 'Band', 100), row(1, 'B', 'Band', 100)]),
        intoPlaylistId: playlistId);
    await idle();
    final items = await imports.items(second);
    expect(items.map((i) => i.title), ['B']);
    expect(queued.single.$2, importTag(second, 1));
  });

  test('a failed download marks the row failed, an unavailable video forgets '
      'its cached searches, and the row can be retried', () async {
    yt.songs['one'] = [topic('v1', 'One', 'Band', 200)];
    final id = await service.start(csv([row(0, 'One', 'Band', 200)]));
    await idle();
    settled.add(DownloadItem(
        id: 1,
        result: queued.single.$1,
        status: DownloadStatus.failed,
        error: YtErrorKind.unavailable,
        tag: importTag(id, 0)));
    await idle();
    expect((await imports.item(id, 0))!.state, ImportItemStatus.failed);
    expect((await imports.get(id))!.state, ImportStatus.finished);
    expect(queued, hasLength(1),
        reason: 'the service does not re-enqueue: retries live in the queue');
    expect(forgotten.single, containsAll(['ISRC0', 'band one', 'Band - One']));

    await service.retry(id);
    await idle();
    expect(queued, hasLength(2));
  });

  group('ISRC first', () {
    test('a sure match by ISRC needs a single search', () async {
      yt.songs['ISRC0'] = [topic('v1', 'One', 'Band', 200)];
      final id = await service.start(csv([row(0, 'One', 'Band', 200)]));
      await idle();
      expect(yt.queries, ['songs:ISRC0']);
      expect((await imports.item(id, 0))!.state, ImportItemStatus.queued);
      expect(queued.single.$1.id, 'v1');
    });

    test('a doubtful ISRC result falls back to title and artist', () async {
      // Right video but a different length: only «review» by ISRC.
      yt.songs['ISRC0'] = [topic('wrong', 'One', 'Band', 215)];
      yt.songs['band one'] = [topic('v1', 'One', 'Band', 200)];
      final id = await service.start(csv([row(0, 'One', 'Band', 200)]));
      await idle();
      expect(yt.queries.first, 'songs:ISRC0');
      expect(yt.queries[1], contains('band one'));
      expect(queued.single.$1.id, 'v1',
          reason: 'the ISRC result must not be reused');
      expect((await imports.item(id, 0))!.state, ImportItemStatus.queued);
    });

    test('a row without ISRC searches as before', () async {
      yt.songs['band one'] = [topic('v1', 'One', 'Band', 200)];
      final r = ImportRow(
          index: 0, title: 'One', artists: const ['Band'], durationMs: 200000);
      await service.start(csv([r]));
      await idle();
      expect(yt.queries, hasLength(1));
      expect(yt.queries.single, contains('band one'));
    });
  });

  group('length check after the download', () {
    Future<int> startOne() async {
      yt.songs['one'] = [topic('v1', 'One', 'Band', 200)];
      final id = await service.start(csv([row(0, 'One', 'Band', 200)]));
      await idle();
      return id;
    }

    test('a 4 s difference is fine', () async {
      final id = await startOne();
      await finish(importTag(id, 0), '/m/one.mp3', seconds: 204);
      expect((await imports.item(id, 0))!.state, ImportItemStatus.downloaded);
    });

    test('a 40 s difference goes to review with a note, file and playlist '
        'entry kept; «Tieni questo» confirms it', () async {
      final id = await startOne();
      await finish(importTag(id, 0), '/m/one.mp3', seconds: 240);
      final it = (await imports.item(id, 0))!;
      expect(it.state, ImportItemStatus.review);
      expect(it.note, ImportNote.lengthOff);
      expect(it.trackId, isNotNull, reason: 'the downloaded track is linked');
      final imp = (await imports.get(id))!;
      expect(await order(imp.playlistId), ['/m/one.mp3']);

      await service.keepDownloaded(id, 0);
      expect((await imports.item(id, 0))!.state, ImportItemStatus.downloaded);
    });

    test('a CSV row without a length is never questioned', () async {
      yt.songs['one'] = [topic('v1', 'One', 'Band', 200)];
      final r = ImportRow(index: 0, title: 'One', artists: const ['Band']);
      final id = await service.start(csv([r]));
      await idle();
      await finish(importTag(id, 0), '/m/one.mp3', seconds: 999);
      expect((await imports.item(id, 0))!.state, ImportItemStatus.downloaded);
    });
  });

  group('link only', () {
    test('links what the library has and never calls YouTube', () async {
      await addTrack('/m/felicita.mp3', 'Felicità', 'Lucio Dalla', 345);
      final id = await service.start(
          csv([row(0, 'Felicità', 'Lucio Dalla', 345), row(1, 'One', 'Band', 200)]),
          options: const ImportOptions(linkOnly: true));
      await idle();
      expect(yt.searches, 0);
      expect(queued, isEmpty);
      expect((await imports.item(id, 0))!.state, ImportItemStatus.linked);
      final other = (await imports.item(id, 1))!;
      expect(other.state, ImportItemStatus.notFound);
      expect(other.note, ImportNote.linkOnly);
      expect((await imports.get(id))!.state, ImportStatus.finished);
      expect((await imports.get(id))!.linkOnly, isTrue);
    });
  });

  group('review before downloading', () {
    setUp(() {
      yt.songs['one'] = [topic('v1', 'One', 'Band', 200)];
      yt.songs['two'] = [
        topic('v2', 'Two', 'Band', 210),
        topic('v2b', 'Two (alt)', 'Band', 211),
      ];
    });

    Future<int> plan() async {
      final id = await service.start(
          csv([row(0, 'One', 'Band', 200), row(1, 'Two', 'Band', 210)]),
          options: const ImportOptions(planFirst: true));
      await idle();
      return id;
    }

    test('searches everything, downloads nothing and waits', () async {
      final id = await plan();
      expect(queued, isEmpty);
      expect((await imports.item(id, 0))!.state, ImportItemStatus.planned);
      expect((await imports.item(id, 1))!.state, ImportItemStatus.planned);
      expect((await imports.item(id, 0))!.videoId, 'v1');
      expect(decodeCandidates((await imports.item(id, 1))!.candidates), isNotEmpty);
      expect((await imports.get(id))!.state, ImportStatus.paused);
      expect(events.map((e) => e.kind), contains(ImportEventKind.planned));
    });

    test('«Scarica» sends the plan through the normal engine and the import '
        'then finishes as usual', () async {
      final id = await plan();
      expect(await service.startPlanned(id), 2);
      await idle();
      expect(queued.map((q) => q.$1.id), ['v1', 'v2']);
      expect((await imports.item(id, 0))!.state, ImportItemStatus.queued);
      expect((await imports.get(id))!.state, ImportStatus.running);
      expect(yt.queries.where((q) => q.startsWith('songs:band')).length, 2,
          reason: 'no new searches for the approved rows');

      await finish(importTag(id, 0), '/m/one.mp3');
      await finish(importTag(id, 1), '/m/two.mp3');
      expect((await imports.get(id))!.state, ImportStatus.finished);
    });

    test('another candidate can be chosen first; a skipped row is not downloaded',
        () async {
      final id = await plan();
      final alt = decodeCandidates((await imports.item(id, 1))!.candidates)
          .firstWhere((c) => c.id == 'v2b');
      await service.choosePlanned(id, 1, alt);
      await service.skip(id, 0);
      expect(await service.startPlanned(id), 1);
      await idle();
      expect(queued.map((q) => q.$1.id), ['v2b']);
    });

  });

  group('thresholds from the settings', () {
    test('a stricter «sure» sends the same match to review', () async {
      yt.songs['one'] = [topic('v1', 'One', 'Band', 200)];
      final strict = PlaylistImportService(
        imports: imports,
        playlists: playlists,
        loadLibrary: tracks.liteEntries,
        youtube: yt,
        enqueue: (r, tag) => queued.add((r, tag)),
        cancelDownloads: (_) {},
        settled: settled.stream,
        trackIdForPath: tracks.idForPath,
        pathForVideo: (_) async => null,
        applyTags: (id, r) async {},
        searchGap: Duration.zero,
        thresholds: () => const MatchThresholds(sure: 1.01, review: 0.5),
      );
      addTearDown(strict.dispose);
      final id = await strict.start(csv([row(0, 'One', 'Band', 200)]));
      await idle();
      expect((await imports.item(id, 0))!.state, ImportItemStatus.review);
      expect(queued, isEmpty);
    });
  });

  group('big files in blocks', () {
    ImportedPlaylist rows250() => csv([
          for (var i = 0; i < 250; i++) row(i, 'Song $i', 'Band', 200),
        ]);

    test('250 rows become 3 imports with their row numbers kept', () async {
      final first = await service.start(rows250(),
          options: const ImportOptions(linkOnly: true), blockSize: 100);
      await idle();
      final all = await imports.forPlaylist((await imports.get(first))!.playlistId);
      expect(all, hasLength(3));
      expect(all.map((i) => i.sourceName), ['Mood (1/3)', 'Mood (2/3)', 'Mood (3/3)']);
      expect([for (final i in all) (await imports.items(i.id)).length], [100, 100, 50]);
      expect((await imports.items(all[1].id)).first.rowIndex, 100);
      expect((await imports.items(all[2].id)).last.rowIndex, 249);
    });

    test('the blocks run one after the other', () async {
      final small = csv([
        for (var i = 0; i < 30; i++) row(i, 'Song $i', 'Band', 200),
      ]);
      final first = await service.start(small,
          options: const ImportOptions(linkOnly: true), blockSize: 10);
      final pl = (await imports.get(first))!.playlistId;
      final right = await imports.forPlaylist(pl);
      expect(right[1].state, ImportStatus.paused,
          reason: 'waits for the block before it');
      expect(right[2].state, ImportStatus.paused);
      var done = await imports.forPlaylist(pl);
      for (var i = 0;
          i < 20 && !done.every((x) => x.state == ImportStatus.finished);
          i++) {
        await idle();
        done = await imports.forPlaylist(pl);
      }
      expect(done.every((i) => i.state == ImportStatus.finished), isTrue,
          reason: '${done.map((i) => i.state)}');
    });

    test('a small file is a single import', () async {
      final first = await service.start(csv([row(0, 'One', 'Band', 200)]),
          options: const ImportOptions(linkOnly: true), blockSize: 100);
      await idle();
      final all = await imports.forPlaylist((await imports.get(first))!.playlistId);
      expect(all, hasLength(1));
      expect(all.single.sourceName, 'Mood');
    });

    test('after a restart the blocks still follow one another (nothing in memory)', () async {
      final first = await service.start(
          csv([for (var i = 0; i < 30; i++) row(i, 'Song $i', 'Band', 200)]),
          options: const ImportOptions(linkOnly: true),
          blockSize: 10);
      await service.pause(first);
      service.dispose();
      service = build(); // a new process: the chain is read from the blocks
      final pl = (await imports.get(first))!.playlistId;
      await service.resumeChain(first);
      var all = await imports.forPlaylist(pl);
      for (var i = 0; i < 30 && !all.every((x) => x.state == ImportStatus.finished); i++) {
        await idle();
        all = await imports.forPlaylist(pl);
      }
      expect(all.map((i) => i.state), everyElement(ImportStatus.finished));
    });

    test('the same file imported twice into one playlist makes two imports, not one', () async {
      final first = await service.start(rows250(),
          options: const ImportOptions(planFirst: true), blockSize: 100);
      final pl = (await imports.get(first))!.playlistId;
      await service.cancelChain(first);
      final again = await service.start(rows250(),
          intoPlaylistId: pl, options: const ImportOptions(planFirst: true), blockSize: 100);
      final chains = groupImportChains(await imports.forPlaylist(pl));
      expect(chains.map((c) => c.length), [3, 3]);
      expect((await service.chainOf(again)).first.id, again);
      expect(chains.first.map((i) => i.state), everyElement(ImportStatus.cancelled),
          reason: 'the second one does not wake the old blocks');
    });

    test('pause, resume and cancel act on the whole import, from any block', () async {
      final first = await service.start(rows250(),
          options: const ImportOptions(planFirst: true), blockSize: 100);
      final pl = (await imports.get(first))!.playlistId;
      final blocks = await imports.forPlaylist(pl);
      expect((await service.chainOf(blocks[2].id)).map((b) => b.id), blocks.map((b) => b.id));
      await service.pauseChain(blocks[2].id);
      expect((await imports.forPlaylist(pl)).map((i) => i.state), everyElement(ImportStatus.paused));
      await service.resumeChain(blocks[1].id);
      expect((await imports.get(first))!.state, ImportStatus.running, reason: 'the first one goes on');
      expect((await imports.get(blocks[1].id))!.state, ImportStatus.paused);
      await service.cancelChain(blocks[1].id);
      await idle();
      expect((await imports.forPlaylist(pl)).map((i) => i.state), everyElement(ImportStatus.cancelled));
    });

    test('cancelling a block leaves the next ones waiting, not started', () async {
      final first = await service.start(rows250(),
          options: const ImportOptions(planFirst: true), blockSize: 100);
      await service.cancel(first);
      await idle();
      final all = await imports.forPlaylist((await imports.get(first))!.playlistId);
      expect(all[0].state, ImportStatus.cancelled);
      expect(all[1].state, ImportStatus.paused);
    });
  });

  group('folder and numbered file names', () {
    ImportRow nth(int i) =>
        ImportRow(index: i, title: 'Song', artists: const ['Band']);

    test('importDownloadName: width follows the total, at least two digits', () {
      expect(importDownloadName(nth(6), number: true, total: 34), '07 - Band - Song');
      expect(importDownloadName(nth(6), number: true, total: 120), '007 - Band - Song');
      expect(importDownloadName(nth(0), number: true, total: 5), '01 - Band - Song');
      expect(importDownloadName(nth(6), number: false, total: 120), 'Band - Song');
    });

    test('the queued download carries the number and the folder', () async {
      yt.songs['one'] = [topic('v1', 'One', 'Band', 200)];
      final rows = [row(0, 'One', 'Band', 200)];
      final id = await service.start(csv(rows),
          options: const ImportOptions(numberFiles: true, folderPath: 'Mood'));
      await idle();
      expect(queued.single.$1.downloadName, '01 - Band - One');
      expect(queued.single.$1.subdir, 'Mood');
      expect((await imports.get(id))!.folderPath, 'Mood');
    });

    test('blocks share one number width, sized on the whole playlist', () async {
      yt.songs['song'] = [topic('v', 'Song 0', 'Band', 200)];
      final first = await service.start(
          csv([for (var i = 0; i < 120; i++) row(i, 'Song $i', 'Band', 200)]),
          options: const ImportOptions(numberFiles: true, planFirst: true),
          blockSize: 40);
      await service.cancel(first);
      expect(await imports.maxRowIndexForPlaylist(
              (await imports.get(first))!.playlistId),
          119);
    });
  });

  group('covers and notes', () {
    ImportRow withAlbum(int i, String album) => ImportRow(
        index: i,
        title: 'One',
        artists: const ['Band'],
        album: album,
        durationMs: 200000,
        isrc: 'ISRC$i');

    test('«Cerca le copertine» looks the album cover up after the download',
        () async {
      yt.songs['one'] = [topic('v1', 'One', 'Band', 200)];
      final id = await service.start(csv([withAlbum(0, 'Mood')]),
          options: const ImportOptions(fetchCovers: true));
      await idle();
      await finish(importTag(id, 0), '/m/one.mp3');
      expect(coverCalls, hasLength(1));
      expect(coverCalls.single, endsWith(':Mood'));
      expect((await imports.item(id, 0))!.state, ImportItemStatus.downloaded);
    });

    test('with the option off no cover is requested', () async {
      yt.songs['one'] = [topic('v1', 'One', 'Band', 200)];
      final id = await service.start(csv([withAlbum(0, 'Mood')]));
      await idle();
      await finish(importTag(id, 0), '/m/one.mp3');
      expect(coverCalls, isEmpty);
    });

    test('a row without an album asks for nothing', () async {
      yt.songs['one'] = [topic('v1', 'One', 'Band', 200)];
      final id = await service.start(csv([row(0, 'One', 'Band', 200)]),
          options: const ImportOptions(fetchCovers: true));
      await idle();
      await finish(importTag(id, 0), '/m/one.mp3');
      expect(coverCalls, isEmpty);
    });

    test('a failing cover lookup never fails the import', () async {
      coverFails = true;
      yt.songs['one'] = [topic('v1', 'One', 'Band', 200)];
      final id = await service.start(csv([withAlbum(0, 'Mood')]),
          options: const ImportOptions(fetchCovers: true));
      await idle();
      await finish(importTag(id, 0), '/m/one.mp3');
      expect((await imports.item(id, 0))!.state, ImportItemStatus.downloaded);
      expect((await imports.get(id))!.state, ImportStatus.finished);
    });

    test('rows that did not make it say why', () async {
      yt.songs['one'] = [topic('v1', 'Another', 'Other', 90)];
      final id = await service.start(csv([
        row(0, 'One', 'Band', 200),
        row(1, 'Gone', 'Band', 200),
      ]));
      await idle();
      expect((await imports.item(id, 0))!.note, isIn([ImportNote.noResults, ImportNote.lowScore]));
      settled.add(DownloadItem(
          id: 1,
          result: const YtResult(id: 'x', title: 't', channel: 'c', duration: null),
          status: DownloadStatus.failed,
          error: YtErrorKind.network,
          tag: importTag(id, 1)));
      await idle();
      expect((await imports.item(id, 1))!.note, ImportNote.downloadFailed);
    });
  });

  group('sync from a refreshed file', () {
    late int pid;

    /// The ISRC belongs to the song, not to its row.
    ImportRow song(int i, String title) => ImportRow(
        index: i,
        title: title,
        artists: const ['Band'],
        durationMs: 200000,
        isrc: 'I-$title');

    /// A..E in the library, imported (all linked), plus a track X added by hand
    /// right after B.
    Future<void> setUpPlaylist() async {
      for (final t in ['A', 'B', 'C', 'D', 'E']) {
        await addTrack('/m/$t.mp3', t, 'Band', 200);
      }
      final first = await service.start(csv([
        for (var i = 0; i < 5; i++) song(i, 'ABCDE'[i]),
      ]));
      await idle();
      pid = (await imports.get(first))!.playlistId;
      final x = await addTrack('/m/X.mp3', 'X', 'Other', 100);
      await playlists.addTracks(pid, [x]);
      await playlists.reorder(pid, 5, 2);
      expect(await order(pid), ['A', 'B', 'X', 'C', 'D', 'E']);
    }

    test('adds the new, removes the gone, follows the new order, keeps the hand-made',
        () async {
      await setUpPlaylist();
      yt.songs['band f'] = [topic('vf', 'F', 'Band', 200)];
      final fresh = csv([
        song(0, 'C'),
        song(1, 'A'),
        song(2, 'F'),
        song(3, 'E'),
      ]);
      final diff = await service.previewSync(fresh, pid);
      expect(diff.added.map((r) => r.title), ['F']);
      expect(diff.removed.map((o) => o.title), ['B', 'D']);

      final id = await service.sync(fresh, pid);
      await idle();
      expect(queued.single.$1.id, 'vf', reason: 'only the new row is searched');
      await finish(importTag(id, 2), '/m/F.mp3');
      expect(await order(pid), ['C', 'A', 'X', '/m/F.mp3', 'E']);
      expect((await imports.get(id))!.state, ImportStatus.finished);
    });

    test('removed songs leave only the playlist, never the library', () async {
      await setUpPlaylist();
      final id = await service.sync(
          csv([song(0, 'A'), song(1, 'C')]), pid);
      await idle();
      expect(await order(pid), ['A', 'X', 'C']);
      expect(await tracks.countAll(), 6, reason: 'B, D and E are still in the library');
      final old = await imports.forPlaylist(pid);
      final oldItems = await imports.items(old.first.id);
      expect(oldItems.where((i) => i.state == ImportItemStatus.removed),
          hasLength(3), reason: 'B, D, E are marked «removed from the source»');
      expect((await imports.get(id))!.state, ImportStatus.finished);
    });

    test('the same file again changes nothing', () async {
      await setUpPlaylist();
      final before = await order(pid);
      final id = await service.sync(
          csv([for (var i = 0; i < 5; i++) song(i, 'ABCDE'[i])]), pid);
      await idle();
      expect(await order(pid), before);
      expect(queued, isEmpty);
      final items = await imports.items(id);
      expect(items.every((i) => i.note == ImportNote.unchanged), isTrue);
      expect((await imports.get(id))!.state, ImportStatus.finished);
    });

    test('a second sync works from the first one', () async {
      await setUpPlaylist();
      await service.sync(
          csv([song(0, 'B'), song(1, 'A')]), pid);
      await idle();
      // X was after B and goes with it.
      expect(await order(pid), ['B', 'X', 'A']);
      final diff = await service.previewSync(
          csv([song(0, 'A')]), pid);
      expect(diff.removed.map((o) => o.title), ['B']);
      expect(diff.kept, hasLength(1));
    });

    test('a row «not found» last time is not new: the preview and the sync leave it',
        () async {
      await setUpPlaylist();
      final five = [for (var i = 0; i < 5; i++) song(i, 'ABCDE'[i])];
      await service.sync(csv([...five, song(5, 'Z')]), pid);
      await idle();
      queued.clear();
      yt.songs['band f'] = [topic('vf', 'F', 'Band', 200)];
      final again = csv([...five, song(5, 'Z'), song(6, 'F')]);

      final diff = await service.previewSync(again, pid);
      expect(diff.added.map((r) => r.title), ['F'], reason: 'only F is really new');
      expect(diff.parked.map((k) => k.fresh.title), ['Z']);

      final id = await service.sync(again, pid);
      await idle();
      expect(queued.map((q) => q.$1.id), ['vf'], reason: 'Z is not searched again');
      expect((await imports.item(id, 5))!.state, ImportItemStatus.notFound);
    });
  });

  group('whole albums', () {
    ImportRow inAlbum(int i, String title, String album) => ImportRow(
        index: i,
        title: title,
        artists: const ['Band'],
        album: album,
        durationMs: 200000);

    YtResult albumTrack(String id, String title, String album) => YtResult(
        id: id,
        title: title,
        channel: 'Band - Topic',
        duration: const Duration(seconds: 200),
        artists: const ['Band'],
        album: album);

    test('4 songs of one album: one album search, one page, no single searches',
        () async {
      yt.albums['mood'] = [
        for (var i = 0; i < 4; i++) albumTrack('a$i', 'Song $i', 'Mood'),
      ];
      maxInFlight = 10;
      service = build();
      final id = await service.start(csv([
        for (var i = 0; i < 4; i++) inAlbum(i, 'Song $i', 'Mood'),
      ]));
      await idle();
      expect(yt.albumSearches, 1);
      expect(yt.albumPages, 1);
      expect(yt.queries.where((q) => !q.startsWith('albums:')), isEmpty);
      expect(queued.map((q) => q.$1.id), ['a0', 'a1', 'a2', 'a3']);
      expect((await imports.item(id, 2))!.state, ImportItemStatus.queued);
    });

    test('an album page that cannot be read (too slow, gone) pauses nothing: '
        'each song is searched on its own', () async {
      yt.albums['mood'] = [
        for (var i = 0; i < 4; i++) albumTrack('a$i', 'Song $i', 'Mood'),
      ];
      yt.albumPageFails = const YtException(YtErrorKind.network, 'search timed out');
      for (var i = 0; i < 4; i++) {
        yt.songs['song $i'] = [topic('s$i', 'Song $i', 'Band', 200)];
      }
      maxInFlight = 10;
      rebuild();
      final id = await service.start(csv([
        for (var i = 0; i < 4; i++) inAlbum(i, 'Song $i', 'Mood'),
      ]));
      await idle();
      expect(events.map((e) => e.kind), isEmpty);
      expect((await imports.get(id))!.state, ImportStatus.running);
      expect(queued.map((q) => q.$1.id), ['s0', 's1', 's2', 's3']);
      expect(yt.albumPages, 1, reason: 'the album is not asked again for every song');
    });

    test('a sure match by ISRC comes before the album page', () async {
      for (var i = 0; i < 3; i++) {
        yt.songs['ISRC$i'] = [topic('i$i', 'Song $i', 'Band', 200)];
      }
      yt.albums['mood'] = [
        for (var i = 0; i < 3; i++) albumTrack('a$i', 'Song $i', 'Mood'),
      ];
      maxInFlight = 10;
      service = build();
      await service.start(csv([
        for (var i = 0; i < 3; i++)
          ImportRow(
              index: i,
              title: 'Song $i',
              artists: const ['Band'],
              album: 'Mood',
              durationMs: 200000,
              isrc: 'ISRC$i'),
      ]));
      await idle();
      expect(yt.albumSearches, 0);
      expect(yt.queries, ['songs:ISRC0', 'songs:ISRC1', 'songs:ISRC2']);
      expect(queued.map((q) => q.$1.id), ['i0', 'i1', 'i2']);
    });

    test('fewer than 3 songs in the album: the usual single searches', () async {
      yt.albums['mood'] = [albumTrack('a0', 'Song 0', 'Mood')];
      yt.songs['song'] = [topic('s', 'Song 0', 'Band', 200)];
      await service.start(csv([
        inAlbum(0, 'Song 0', 'Mood'),
        inAlbum(1, 'Song 1', 'Mood'),
      ]));
      await idle();
      expect(yt.albumSearches, 0);
    });

    test('a song missing from the album page falls back to its own search',
        () async {
      yt.albums['mood'] = [
        albumTrack('a0', 'Song 0', 'Mood'),
        albumTrack('a1', 'Song 1', 'Mood'),
      ];
      yt.songs['song 2'] = [topic('solo', 'Song 2', 'Band', 200)];
      await service.start(csv([
        for (var i = 0; i < 3; i++) inAlbum(i, 'Song $i', 'Mood'),
      ]));
      await idle();
      expect(yt.albumSearches, 1);
      expect(queued.map((q) => q.$1.id), ['a0', 'a1', 'solo']);
    });

    test('the album found must be the one in the file', () async {
      yt.albums['mood'] = [
        for (var i = 0; i < 3; i++) albumTrack('x$i', 'Song $i', 'Greatest Hits'),
      ];
      yt.songs['song'] = [topic('s', 'Song 0', 'Band', 200)];
      await service.start(csv([
        for (var i = 0; i < 3; i++) inAlbum(i, 'Song $i', 'Mood'),
      ]));
      await idle();
      expect(queued.map((q) => q.$1.id), isNot(contains('x0')));
    });
  });

  test('tag parsing', () {
    expect(parseImportTag('import:3:12'), (3, 12));
    expect(parseImportTag('other'), isNull);
    expect(parseImportTag('import:x:1'), isNull);
    expect(parseImportTag(null), isNull);
  });
}
