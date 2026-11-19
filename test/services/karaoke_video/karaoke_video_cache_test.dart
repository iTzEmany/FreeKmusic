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
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    sent.add(o);
    await Future<void>.delayed(const Duration(milliseconds: 20));
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
  var metered = false;
  final now = DateTime.now(); // touch() stamps the real time

  KaraokeVideoCache make() => KaraokeVideoCache(
    cache: cache,
    source: KaraokeVideoSource((id) async {
      resolved.add(id);
      return (url: Uri.parse('https://v/$id'), headers: {'h': '1'}, expires: null);
    }),
    dio: Dio()..httpClientAdapter = adapter,
    canPrefetch: () async => !metered,
    clock: () => now,
  );

  // A video of [id] as the cache would hold it, last used [ago] ago.
  Future<void> put(String id, Duration ago) async {
    final part = File(p.join(root.path, 'karaoke_video_youtube_$id.mp4.part'))..writeAsBytesSync([1]);
    final f = await cache.put('karaoke:video:youtube:$id', part);
    await f.setLastModified(now.subtract(ago));
  }

  Future<bool> has(String id) async => await cache.fileFor('karaoke:video:youtube:$id') != null;

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

  test('downloading the same id twice makes one request, and the file stays fixed until release', () async {
    final c = make();
    final s = (url: Uri.parse('https://v/a'), headers: {'h': '1'}, expires: null);
    c.download('a', s);
    c.download('a', s);
    await until(() => has('a'));
    expect(adapter.sent, hasLength(1));
    expect(adapter.sent.single.headers['h'], '1');
    expect(await has('a'), isTrue);
    await (await cache.fileFor('karaoke:video:youtube:a'))!.setLastModified(now.subtract(const Duration(hours: 1)));
    await c.expire();
    expect(await has('a'), isTrue); // two pins: still held
    c.release('a');
    c.release('a');
    await Future<void>.delayed(const Duration(milliseconds: 50)); // release touches the file
    await (await cache.fileFor('karaoke:video:youtube:a'))!.setLastModified(now.subtract(const Duration(hours: 1)));
    await c.expire();
    expect(await has('a'), isFalse);
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
    await (await cache.fileFor('karaoke:video:youtube:k1'))!.setLastModified(now.subtract(const Duration(hours: 1)));
    await c.expire();
    expect(await has('k1'), isTrue); // queued: fixed
    c.prefetchQueue([]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await c.expire();
    expect(await has('k1'), isTrue); // release touched it: the 15 minutes start now
    await (await cache.fileFor('karaoke:video:youtube:k1'))!.setLastModified(now.subtract(const Duration(minutes: 16)));
    await c.expire();
    expect(await has('k1'), isFalse);
  });
}
