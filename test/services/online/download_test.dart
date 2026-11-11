import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:codecore/services/online/download_queue.dart';
import 'package:codecore/services/online/retry_policy.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:flutter_test/flutter_test.dart';

YtResult r(String id, {String title = 'Song', String channel = 'Band'}) =>
    YtResult(id: id, title: title, channel: channel, duration: null);

void main() {
  test('uniquePath adds numeric suffixes without overwriting', () {
    final taken = {p.join('/d', 'a.m4a'), p.join('/d', 'a (2).m4a')};
    expect(uniquePath('/d', 'a', 'm4a', taken.contains), p.join('/d', 'a (3).m4a'));
    expect(uniquePath('/d', 'b', 'm4a', taken.contains), p.join('/d', 'b.m4a'));
  });

  test('downloadBaseName sanitises', () {
    expect(downloadBaseName(r('1', title: 'Queen - Who/Wants: Forever (Official Video)', channel: 'Queen')),
        'Queen - WhoWants Forever');
  });

  test('only real youtube hosts are URLs', () {
    expect(isYoutubeUrl('https://www.youtube.com/watch?v=abc'), true);
    expect(isYoutubeUrl('https://youtu.be/abc'), true);
    expect(isYoutubeUrl('https://evil.com/youtube.com'), false);
    expect(isYoutubeUrl('youtube.com is great'), false);
  });

  test('queue runs one at a time and reports done', () async {
    var active = 0, maxActive = 0;
    final done = <String>[];
    final snapshots = <List<DownloadItem>>[];
    final q = DownloadQueue(
      downloader: (res, dir, cancel) async* {
        active++;
        maxActive = active > maxActive ? active : maxActive;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        yield const DownloadProgress(received: 5, total: 10);
        active--;
        yield DownloadProgress(received: 10, total: 10, path: '/o/${res.id}.m4a');
      },
      outDir: () async => Directory.systemTemp,
      onChanged: snapshots.add,
      onDownloaded: (p) async => done.add(p),
      uiInterval: Duration.zero,
    );
    q.add(r('a'));
    q.add(r('b'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(maxActive, 1);
    expect(done, ['/o/a.m4a', '/o/b.m4a']);
    expect(q.items.every((e) => e.status == DownloadStatus.done), true);
    q.clearFinished();
    expect(q.items, isEmpty);
  });

  test('a failure that is not a YtException is internal and not retried', () async {
    final q = DownloadQueue(
      downloader: (res, dir, cancel) async* {
        yield const DownloadProgress(received: 1, total: 1, path: '/o/a.m4a');
      },
      outDir: () async => Directory.systemTemp,
      onChanged: (_) {},
      onDownloaded: (p) async => throw StateError('publish'),
      retryPolicy: RetryPolicy(),
    );
    q.add(r('a'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(q.items.single.status, DownloadStatus.failed);
    expect(q.items.single.error, YtErrorKind.internal);
  });

  test('cancel stops the active item and later ones continue', () async {
    final started = Completer<void>();
    final q = DownloadQueue(
      downloader: (res, dir, cancel) async* {
        if (res.id == 'a') {
          started.complete();
          while (!cancel.isCancelled) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          return;
        }
        yield DownloadProgress(received: 1, total: 1, path: '/o/${res.id}');
      },
      outDir: () async => Directory.systemTemp,
      onChanged: (_) {},
    );
    q.add(r('a'));
    q.add(r('b'));
    await started.future;
    q.cancel(1);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(q.items[0].status, DownloadStatus.cancelled);
    expect(q.items[1].status, DownloadStatus.done);
  });

  test('tag reaches onSettled for done, failed and cancelled items', () async {
    final settled = <String>[];
    final q = DownloadQueue(
      downloader: (res, dir, cancel) async* {
        if (res.id == 'bad') throw const YtException(YtErrorKind.network);
        if (res.id == 'slow') {
          while (!cancel.isCancelled) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          return;
        }
        yield DownloadProgress(received: 1, total: 1, path: '/o/${res.id}');
      },
      outDir: () async => Directory.systemTemp,
      onChanged: (_) {},
      onSettled: (i) => settled.add('${i.tag}:${i.status.name}'),
    );
    q.add(r('ok'), tag: 'import:1:0');
    q.add(r('bad'), tag: 'import:1:1');
    q.add(r('slow'), tag: 'import:1:2');
    q.add(r('queued'), tag: 'other');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    q.cancelWhere((i) => i.tag != null && i.tag!.startsWith('import:1:'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(settled, containsAll(['import:1:0:done', 'import:1:1:failed', 'import:1:2:cancelled']));
    expect(settled.where((s) => s.startsWith('other')), ['other:done']);
  });

  test('downloadName replaces the name derived from the video title', () {
    const res = YtResult(
        id: '1',
        title: 'Queen - Bohemian Rhapsody (Official Video)',
        channel: 'Queen',
        duration: null,
        downloadName: 'Queen - Bohemian Rhapsody: 2011 Remaster');
    expect(downloadBaseName(res), 'Queen - Bohemian Rhapsody 2011 Remaster');
  });

  group('parallel queue', () {
    /// Each download waits for its own completer; lets the test see how many
    /// are running at any moment.
    ({DownloadQueue q, Map<String, Completer<void>> gates, List<String> started})
        make(int parallel) {
      final gates = <String, Completer<void>>{};
      final started = <String>[];
      final q = DownloadQueue(
        maxParallel: parallel,
        downloader: (res, dir, cancel) async* {
          started.add(res.id);
          final gate = gates.putIfAbsent(res.id, Completer<void>.new);
          await Future.any([gate.future, cancel.whenCancel]);
          if (cancel.isCancelled) return;
          yield DownloadProgress(received: 1, total: 1, path: '/o/${res.id}');
        },
        outDir: () async => Directory.systemTemp,
        onChanged: (_) {},
        uiInterval: Duration.zero,
      );
      return (q: q, gates: gates, started: started);
    }

    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

    test('never more than N at once, started in arrival order', () async {
      final t = make(2);
      for (final id in ['a', 'b', 'c', 'd']) {
        t.q.add(r(id));
      }
      await settle();
      expect(t.started, ['a', 'b']);
      t.gates['a']!.complete();
      await settle();
      expect(t.started, ['a', 'b', 'c']);
      t.gates['b']!.complete();
      t.gates['c']!.complete();
      await settle();
      expect(t.started, ['a', 'b', 'c', 'd']);
      t.gates['d']!.complete();
      await settle();
      expect(t.q.items.every((e) => e.status == DownloadStatus.done), isTrue);
    });

    test('cancelling one does not stop the others', () async {
      final t = make(2);
      t.q.add(r('a'));
      t.q.add(r('b'));
      t.q.add(r('c'));
      await settle();
      t.q.cancel(1);
      await settle();
      expect(t.q.items[0].status, DownloadStatus.cancelled);
      expect(t.q.items[1].status, DownloadStatus.downloading);
      expect(t.started, ['a', 'b', 'c'], reason: 'the freed slot starts c');
      t.gates['b']!.complete();
      t.gates['c']!.complete();
      await settle();
      expect(t.q.items[1].status, DownloadStatus.done);
      expect(t.q.items[2].status, DownloadStatus.done);
    });

    test('raising maxParallel starts more at once; lowering stops nothing',
        () async {
      final t = make(1);
      for (final id in ['a', 'b', 'c']) {
        t.q.add(r(id));
      }
      await settle();
      expect(t.started, ['a']);
      t.q.maxParallel = 3;
      await settle();
      expect(t.started, ['a', 'b', 'c']);
      t.q.maxParallel = 1;
      await settle();
      expect(t.q.items.where((e) => e.status == DownloadStatus.downloading),
          hasLength(3));
      t.q.add(r('d'));
      t.gates['a']!.complete();
      t.gates['b']!.complete();
      await settle();
      expect(t.started, isNot(contains('d')),
          reason: 'one still running and the limit is 1');
      t.gates['c']!.complete();
      await settle();
      expect(t.started, contains('d'));
      t.gates['d']!.complete();
      await settle();
    });

    test('the limit is kept between 1 and 3', () {
      expect(make(9).q.maxParallel, 3);
      expect(make(0).q.maxParallel, 1);
    });
  });

  test('subdir sends the download to a sanitised sub-folder', () async {
    final seen = <String>[];
    final root = Directory.systemTemp.createTempSync('cc_sub');
    addTearDown(() => root.deleteSync(recursive: true));
    final q = DownloadQueue(
      downloader: (res, dir, cancel) async* {
        seen.add(dir.path);
        yield DownloadProgress(received: 1, total: 1, path: '${dir.path}/x');
      },
      outDir: () async => root,
      onChanged: (_) {},
    );
    q.add(const YtResult(
        id: 'a', title: 't', channel: 'c', duration: null, subdir: 'Road/Trip: 2026'));
    q.add(const YtResult(id: 'b', title: 't', channel: 'c', duration: null));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(seen, [p.join(root.path, 'RoadTrip 2026'), root.path]);
  });
}
