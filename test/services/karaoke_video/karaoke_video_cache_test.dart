import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/karaoke_video/karaoke_video_cache.dart';
import 'package:codecore/services/karaoke_video/karaoke_video_source.dart';
import 'package:codecore/services/stream/stream_cache.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _Adapter implements HttpClientAdapter {
  final sent = <RequestOptions>[];
  var failures = 0; // the next requests that fail
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    sent.add(o);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (failures > 0) {
      failures--;
      throw StateError('network');
    }
    return ResponseBody.fromBytes([1, 2, 3], 200);
  }

  @override
  void close({bool force = false}) {}
}

Track track(String path, String title) => Track(
  saved: false, coverSource: 0, id: 1, path: path, title: title, artist: 'a', albumKey: 'k',
  durationMs: 1000, format: 'mp3', sizeBytes: 1, mtimeMs: 1, hasCover: false, isFavorite: false,
  enrichStatus: 0, userEdited: false, missing: false, ignored: false, kind: 0, addedAt: 1, playCount: 0,
);

void main() {
  late Directory root;
  late StreamCache cache;
  late _Adapter adapter;
  late List<String> resolved;
  var metered = false, failUrl = false, probeThrows = false;
  final now = DateTime.now(); // touch() stamps the real time

  KaraokeVideoCache make() => KaraokeVideoCache(
    cache: cache,
    source: KaraokeVideoSource((id) async {
      resolved.add(id);
      if (failUrl) throw StateError('no url');
      return (url: Uri.parse('https://v/$id'), headers: {'h': '1'}, expires: null);
    }),
    dio: Dio()..httpClientAdapter = adapter,
    canPrefetch: () async => probeThrows ? throw StateError('probe') : !metered,
    clock: () => now,
  );

  // A video of [id] as the cache would hold it, last used [ago] ago.
  Future<void> put(String id, Duration ago) async {
    final part = File(p.join(root.path, 'video_karaoke_youtube_$id.mp4.part'))..writeAsBytesSync([1]);
    final f = await cache.put('video:karaoke:youtube:$id', part);
    await f.setLastModified(now.subtract(ago));
  }

  Future<bool> has(String id) async => await cache.fileFor('video:karaoke:youtube:$id') != null;

  Future<void> until(Future<bool> Function() ok) async {
    for (var i = 0; i < 100 && !await ok(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kvc');
    cache = StreamCache(Directory(p.join(root.path, 'c')), limitBytes: 1 << 20, freeSpace: () async => null);
    await cache.open();
    adapter = _Adapter();
    resolved = [];
    metered = false;
    failUrl = probeThrows = false;
  });
  tearDown(() => root.delete(recursive: true));

  test('used 16 minutes ago goes, used 14 minutes ago stays', () async {
    await put('old', const Duration(minutes: 16));
    await put('new', const Duration(minutes: 14));
    await make().expire();
    expect(await has('old'), isFalse);
    expect(await has('new'), isTrue);
  });

  test('a video that is playing stays, however old', () async {
    await put('a', const Duration(hours: 2));
    final c = make();
    expect(await c.cached('a'), isNotNull);
    expect(cache.isPinned('video:karaoke:youtube:a'), isTrue);
    await c.expire();
    expect(await has('a'), isTrue);
  });

  test('a second play within the expiry finds the file; other cache files are never expired', () async {
    await put('a', const Duration(minutes: 3));
    await cache.put('youtube:x', File(p.join(root.path, 'youtube_x.m4a.part'))..writeAsBytesSync([1]))
        .then((f) => f.setLastModified(now.subtract(const Duration(days: 1))));
    final c = make();
    await c.expire();
    expect(await c.cached('a'), isNotNull);
    expect(await cache.fileFor('youtube:x'), isNotNull);
  });

  test('a failed download is retried with the newer address of a second call, never two at once', () async {
    final c = make();
    adapter.failures = 1;
    c.download('a', (url: Uri.parse('https://v/old'), headers: {'h': '1'}, expires: null));
    c.download('a', (url: Uri.parse('https://v/new'), headers: {'h': '1'}, expires: null));
    await until(() => has('a'));
    expect(adapter.sent.map((o) => o.uri.toString()), ['https://v/old', 'https://v/new']);
    expect(await has('a'), isTrue);
  });

  test('downloading the same id twice makes one request, and the file stays fixed until release', () async {
    final c = make();
    final s = (url: Uri.parse('https://v/a'), headers: {'h': '1'}, expires: null);
    c.download('a', s);
    c.download('a', s);
    await until(() => has('a'));
    expect(adapter.sent, hasLength(1));
    expect(adapter.sent.single.headers['h'], '1');
    expect(await has('a'), isTrue);
    await (await cache.fileFor('video:karaoke:youtube:a'))!.setLastModified(now.subtract(const Duration(hours: 1)));
    await c.expire();
    expect(await has('a'), isTrue); // two pins: still held
    c.release('a');
    c.release('a');
    await Future<void>.delayed(const Duration(milliseconds: 50)); // release touches the file
    await (await cache.fileFor('video:karaoke:youtube:a'))!.setLastModified(now.subtract(const Duration(hours: 1)));
    await c.expire();
    expect(await has('a'), isFalse);
  });

  test('the expiry leaves a separation base alone', () async {
    final part = File(p.join(root.path, 'karaoke_base_x.wav.part'))..writeAsBytesSync([1]);
    final f = await cache.put('karaoke:base:x', part);
    await f.setLastModified(now.subtract(const Duration(hours: 1)));
    await make().expire();
    expect(await cache.fileFor('karaoke:base:x'), isNotNull);
  });

  test('the manual queue prefetches its two karaoke videos, not the plain track', () async {
    final c = make();
    c.prefetchQueue([
      track('online:youtube:k1', 'Song Karaoke'),
      track('online:youtube:n1', 'Song'),
      track('online:youtube:k2', 'Other karaoke'),
    ]);
    await until(() async => await has('k1') && await has('k2'));
    expect(resolved, ['k1', 'k2']);
    expect(await has('k1'), isTrue);
    expect(await has('k2'), isTrue);
  });

  test('on a metered network with prefetch off nothing is fetched', () async {
    metered = true;
    final c = make();
    c.prefetchQueue([track('online:youtube:k1', 'Song Karaoke')]);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(resolved, isEmpty);
  });

  test('a track taken out of the queue is released and expires 15 minutes later', () async {
    final c = make();
    c.prefetchQueue([track('online:youtube:k1', 'Song Karaoke')]);
    await until(() => has('k1'));
    await (await cache.fileFor('video:karaoke:youtube:k1'))!.setLastModified(now.subtract(const Duration(hours: 1)));
    await c.expire();
    expect(await has('k1'), isTrue); // queued: fixed
    c.prefetchQueue([]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await c.expire();
    expect(await has('k1'), isTrue); // release touched it: the 15 minutes start now
    await (await cache.fileFor('video:karaoke:youtube:k1'))!.setLastModified(now.subtract(const Duration(minutes: 16)));
    await c.expire();
    expect(await has('k1'), isFalse);
  });

  test('the same id twice in the queue is fixed once: leaving the queue frees it and it expires', () async {
    await put('k1', const Duration(hours: 1));
    final c = make();
    c.prefetchQueue([track('online:youtube:k1', 'a karaoke'), track('online:youtube:k1', 'a karaoke')]);
    c.prefetchQueue([]);
    await until(() async => !cache.isPinned('video:karaoke:youtube:k1'));
    expect(cache.isPinned('video:karaoke:youtube:k1'), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await (await cache.fileFor('video:karaoke:youtube:k1'))!.setLastModified(now.subtract(const Duration(hours: 1)));
    await c.expire();
    expect(await has('k1'), isFalse);
  });

  test('a video already in the cache is not downloaded again, by the player or by the prefetch', () async {
    await put('a', const Duration(minutes: 1));
    final c = make();
    c.download('a', (url: Uri.parse('https://v/a'), headers: {}, expires: null));
    c.prefetchQueue([track('online:youtube:a', 'a karaoke')]);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(adapter.sent, isEmpty);
    expect(resolved, isEmpty);
  });

  test('the prefetch evicts nothing, the player download does', () async {
    await put('old', const Duration(minutes: 5));
    cache.limitBytes = 3; // `old` (1 byte) plus a video (3 bytes) do not fit
    final c = make();
    c.prefetchQueue([track('online:youtube:k1', 'a karaoke')]);
    await until(() => has('k1'));
    expect(await has('old'), isTrue);
    c.download('a', (url: Uri.parse('https://v/a'), headers: {}, expires: null));
    await until(() => has('a'));
    expect(await has('old'), isFalse);
  });

  test('an id that failed is tried again once it is taken out of the queue and put back', () async {
    failUrl = true;
    final c = make();
    final k1 = track('online:youtube:k1', 'a karaoke');
    c.prefetchQueue([k1]);
    await until(() async => resolved.isNotEmpty);
    c.prefetchQueue([k1]); // still queued: a failure is not retried
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(resolved, ['k1']);
    c.prefetchQueue([]);
    failUrl = false;
    c.prefetchQueue([k1]);
    await until(() => has('k1'));
    expect(resolved, ['k1', 'k1']);
  });

  test('a failing network check is not a failed video: the next queue change asks again', () async {
    probeThrows = true;
    final c = make();
    final k1 = track('online:youtube:k1', 'a karaoke');
    c.prefetchQueue([k1]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(resolved, isEmpty);
    probeThrows = false;
    c.prefetchQueue([k1]);
    await until(() => has('k1'));
    expect(await has('k1'), isTrue);
  });

  test('startExpiry deletes by itself, now and on its timer', () async {
    await put('old', const Duration(minutes: 20));
    final c = make()..startExpiry(every: const Duration(milliseconds: 30));
    await until(() async => !await has('old'));
    expect(await has('old'), isFalse);
    await put('old2', const Duration(minutes: 20));
    await until(() async => !await has('old2'));
    expect(await has('old2'), isFalse);
    c.dispose();
  });
}
