import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/stream/stream_cache.dart';
import 'package:codecore/services/stream/stream_preparer.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show debugPrint, DebugPrintCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Writes a file per download; each one ends when its gate is opened.
/// streamRow waits for [gate], so a ready() on a cached file stays in flight.
class _SlowTracks extends TrackRepository {
  _SlowTracks(super.db);
  final gate = Completer<void>();
  @override
  Future<Track?> streamRow(String key) => gate.future.then((_) => super.streamRow(key));
}

class _Yt implements YoutubeService {
  final started = <String>[];
  final failuresLeft = <String, int>{};
  final rateLimits = <String, int>{};
  final forbidden = <String, int>{};
  final ageGated = <String>{};
  var songs = <YtResult>[];
  var searches = 0;
  var searchHangs = false;
  final _gates = <String, Completer<void>>{};
  var open = 0, maxOpen = 0;
  var autoFinish = false;
  /// Progress events (received, total) before the path, `gap` apart; then `silence` of nothing.
  List<(int, int)> progress = const [];
  Duration gap = Duration.zero, silence = Duration.zero;
  /// Stream addresses handed out, one per download call (none left = no address event).
  final urls = <String>[];
  final optionsSeen = <DownloadOptions>[];
  final tokens = <String, List<CancelToken?>>{};
  final dirs = <String, List<String>>{};

  void finish(String id) => _gates[id]!.complete();

  @override
  Stream<DownloadProgress> download(YtResult r, Directory outDir,
      {CancelToken? cancel, DownloadOptions options = const DownloadOptions()}) async* {
    started.add(r.id);
    optionsSeen.add(options);
    (tokens[r.id] ??= []).add(cancel);
    (dirs[r.id] ??= []).add(outDir.path);
    maxOpen = ++open > maxOpen ? open : maxOpen;
    try {
      final gate = _gates[r.id] = Completer<void>();
      if (autoFinish) gate.complete();
      unawaited(cancel?.whenCancel.then((_) {
        if (!gate.isCompleted) gate.completeError(StateError('cancelled'));
      }));
      if (urls.isNotEmpty) {
        yield DownloadProgress(streamUrl: Uri.parse(urls.removeAt(0)), headers: const {'User-Agent': 'ua'});
      }
      await gate.future;
      if (ageGated.contains(r.id)) {
        throw const YtException(YtErrorKind.unavailable, 'ERROR: Sign in to confirm your age');
      }
      if ((rateLimits[r.id] ?? 0) > 0) {
        rateLimits[r.id] = rateLimits[r.id]! - 1;
        throw const YtException(YtErrorKind.rateLimited, '429');
      }
      if ((forbidden[r.id] ?? 0) > 0) {
        forbidden[r.id] = forbidden[r.id]! - 1;
        throw const YtException(YtErrorKind.network, 'HTTP Error 403');
      }
      if ((failuresLeft[r.id] ?? 0) > 0) {
        failuresLeft[r.id] = failuresLeft[r.id]! - 1;
        throw const YtException(YtErrorKind.network, 'boom');
      }
      for (final (rec, tot) in progress) {
        await Future<void>.delayed(gap);
        yield DownloadProgress(received: rec, total: tot);
      }
      await Future<void>.delayed(silence);
      await outDir.create(recursive: true);
      final f = File(p.join(outDir.path, 'Some title - ${r.id}.m4a'))..writeAsBytesSync([1, 2, 3]);
      yield DownloadProgress(path: f.path);
    } finally {
      open--;
    }
  }

  @override
  Future<List<YtResult>> searchSongs(String query, {int limit = 5}) async {
    searches++;
    if (searchHangs) await Completer<void>().future;
    return songs;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

YtResult _r(String id) => YtResult(id: id, title: 'T $id', channel: 'C', duration: null);
StreamItem _i(String id) => StreamItem('youtube:$id', _r(id));
/// Polls until [cond] holds (2 s at most).
Future<void> _until(bool Function() cond) async {
  final end = DateTime.now().add(const Duration(seconds: 2));
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('condition not reached in 2 s');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Lets the scheduler run, to prove nothing else starts.
Future<void> _quiet() => Future<void>.delayed(const Duration(milliseconds: 40));

void main() {
  late Directory root;
  late AppDatabase db;
  late TrackRepository tracks;
  late StreamCache cache;
  late _Yt yt;
  var metered = false;
  late StreamPreparer prep;

  StreamPreparer make({
    Duration cooldown = const Duration(minutes: 5),
    Duration attemptTimeout = const Duration(minutes: 5),
    Duration stallTimeout = const Duration(minutes: 5),
    Duration startTimeout = const Duration(minutes: 5),
    Duration ageSearchTimeout = const Duration(seconds: 20),
    DateTime Function()? clock,
  }) =>
      prep = StreamPreparer(
        attemptTimeout: attemptTimeout,
        stallTimeout: stallTimeout,
        startTimeout: startTimeout,
        ageSearchTimeout: ageSearchTimeout,
        cache: cache,
        tracks: tracks,
        youtube: yt,
        isMetered: () async => metered,
        cooldown: cooldown,
        clock: clock ?? DateTime.now,
      );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('preparer');
    db = AppDatabase(NativeDatabase.memory());
    tracks = TrackRepository(db);
    cache = StreamCache(Directory(p.join(root.path, 'c')), freeSpace: () async => null);
    await cache.open();
    yt = _Yt();
    metered = false;
    make();
  });
  tearDown(() async {
    prep.dispose();
    await db.close();
    await root.delete(recursive: true);
  });

  test('4 queued tracks: never more than 2 downloads, in queue order', () async {
    prep.setQueue([for (final n in ['a', 'b', 'c', 'd']) _i(n)]);
    await _until(() => yt.started.length == 2);
    await _quiet();
    expect(yt.started, ['a', 'b']);
    yt.finish('a');
    await _until(() => yt.started.length == 3);
    yt.finish('b');
    await _until(() => yt.started.length == 4);
    yt.finish('c');
    yt.finish('d');
    await _until(() => prep.phases.value.length == 4 && prep.phases.value.values.every((v) => v == StreamPhase.ready));
    expect(yt.started, ['a', 'b', 'c', 'd']);
    expect(yt.maxOpen, 2);
  });

  test('metered network and 10 tracks: only the next 3 are prepared', () async {
    metered = true;
    yt.autoFinish = true;
    prep.setQueue([for (var n = 0; n < 10; n++) _i('$n')]);
    await _until(() => yt.started.length >= 3);
    await _quiet();
    expect(yt.started, ['0', '1', '2']);
  });

  test('a user pick on a metered network is prepared even out of the window', () async {
    metered = true;
    yt.autoFinish = true;
    final f = await prep.ready('youtube:z', _r('z'));
    expect(p.basename(f.path), 'youtube_z.m4a');
    expect(await tracks.streamRow('youtube:z'), isNotNull);
  });

  test('a download failing twice: one retry, then ready throws', () async {
    yt.autoFinish = true;
    yt.failuresLeft['bad'] = 2;
    await expectLater(prep.ready('youtube:bad', _r('bad')), throwsA(isA<YtException>()));
    expect(yt.started, ['bad', 'bad']);
    expect(prep.phases.value['youtube:bad'], StreamPhase.failed);
  });

  group('age-restricted fallback', () {
    YtResult song(String id, int secs) =>
        YtResult(id: id, title: 'T', channel: 'C', duration: Duration(seconds: secs));

    test('a substitute within 10 s is downloaded; the file is cached under the original key', () async {
      yt.autoFinish = true;
      yt.ageGated.add('age');
      yt.songs = [song('age', 200), song('far', 300), song('sub', 205)];
      final f = await prep.ready('youtube:age', song('age', 200));
      expect(yt.started, ['age', 'sub']);
      expect(p.basename(f.path), 'youtube_age.m4a');
      expect(await tracks.streamRow('youtube:age'), isNotNull);
    });

    test('no good substitute: the age error reaches the caller, nothing else is downloaded', () async {
      yt.autoFinish = true;
      yt.ageGated.add('age');
      yt.songs = [song('far', 300)]; // 100 s off
      await expectLater(prep.ready('youtube:age', song('age', 200)), throwsA(predicate(isAgeRestricted)));
      expect(yt.started, ['age']);
    });

    test('a substitute that is age-restricted too: the age error, one substitute only', () async {
      yt.autoFinish = true;
      yt.ageGated.addAll(['age', 'sub']);
      yt.songs = [song('sub', 205)];
      await expectLater(prep.ready('youtube:age', song('age', 200)), throwsA(predicate(isAgeRestricted)));
      expect(yt.started, ['age', 'sub']);
      expect(yt.searches, 1);
    });

    test('a search that never answers is given up: the age error, the slot is free', () async {
      make(ageSearchTimeout: const Duration(milliseconds: 50));
      yt.autoFinish = true;
      yt.ageGated.add('age');
      yt.searchHangs = true;
      await expectLater(prep.ready('youtube:age', song('age', 200)), throwsA(predicate(isAgeRestricted)));
      expect(yt.started, ['age']);
    });

    test('isAgeRestricted reads both wordings of the error', () {
      expect(isAgeRestricted(const YtException(YtErrorKind.unavailable, 'This video is age-restricted')), isTrue);
      expect(isAgeRestricted(const YtException(YtErrorKind.unavailable, 'Video unavailable')), isFalse);
      expect(isAgeRestricted(StateError('confirm your age')), isFalse);
    });
  });

  group('stream timing line', () {
    late DebugPrintCallback saved;
    late List<String> lines;
    // Each clock read is 10 ms after the previous one.
    DateTime Function() stepClock() {
      var n = 0;
      return () => DateTime(2026).add(Duration(milliseconds: 10 * n++));
    }

    setUp(() {
      saved = debugPrint;
      lines = [];
      debugPrint = (String? m, {int? wrapWidth}) => lines.add(m ?? '');
    });
    tearDown(() => debugPrint = saved);

    String timing() => lines.singleWhere((l) => l.contains('stream timing'));

    test('ok: spawn, downloaded, post and cached in order', () async {
      make(clock: stepClock());
      yt.autoFinish = true;
      yt.progress = const [(100, 100)];
      await prep.ready('youtube:a', _r('a'));
      expect(timing(),
          '[I] stream timing key=youtube:a requested=1 attempt=1 spawn=10 url=- downloaded=20 post=30 cached=40 result=ok');
    });

    test('url: the moment the stream address arrived', () async {
      make(clock: stepClock());
      yt.autoFinish = true;
      yt.urls.add('https://v/a?expire=4102444800');
      await prep.ready('youtube:a', _r('a'));
      expect(timing(), contains('spawn=10 url=20 downloaded=30'));
    });

    test('failure: missing values are dashes', () async {
      make(clock: stepClock());
      yt.autoFinish = true;
      yt.failuresLeft['bad'] = 2;
      await expectLater(prep.ready('youtube:bad', _r('bad')), throwsA(isA<YtException>()));
      expect(timing(),
          '[I] stream timing key=youtube:bad requested=1 attempt=2 spawn=- url=- downloaded=- post=- cached=- result=failed');
    });
  });

  group('start and restart', () {
    const far = 'https://v/a?expire=4102444800'; // year 2100
    String urlOf(StreamStart s) => s.url.toString();

    test('file in cache: the file, yt-dlp not started', () async {
      yt.autoFinish = true;
      await prep.ready('youtube:a', _r('a'));
      yt.started.clear();
      final s = await prep.start('youtube:a', _r('a'));
      expect(s.file, isNotNull);
      expect(s.url, isNull);
      expect(yt.started, isEmpty);
    });

    test('address before file: the address with its headers; the download goes on with emitStreamUrl', () async {
      yt.urls.add(far);
      final s = await prep.start('youtube:a', _r('a'));
      expect(urlOf(s), far);
      expect(s.file, isNull);
      expect(s.headers, {'User-Agent': 'ua'});
      expect(yt.optionsSeen.single.emitStreamUrl, isTrue);
      yt.finish('a');
      await _until(() => prep.phases.value['youtube:a'] == StreamPhase.ready);
    });

    test('file before address: the file', () async {
      yt.autoFinish = true;
      final s = await prep.start('youtube:a', _r('a'));
      expect(s.file, isNotNull);
      expect(s.url, isNull);
    });

    test('an address already expired by expire= is not handed out: the file wins', () async {
      yt.autoFinish = true;
      yt.urls.add('https://v/a?expire=1');
      final s = await prep.start('youtube:a', _r('a'));
      expect(s.file, isNotNull);
    });

    test('an absurd expire= does not break the attempt: the address is taken as valid for 5 h', () async {
      yt.urls.add('https://v/a?expire=99999999999999999');
      final s = await prep.start('youtube:a', _r('a'));
      expect(s.url, isNotNull);
      expect(yt.started, ['a']);
      yt.finish('a');
    });

    test('an address expiring within a minute is not handed out: the file wins', () async {
      yt.autoFinish = true;
      yt.urls.add('https://v/a?expire=${DateTime.now().millisecondsSinceEpoch ~/ 1000 + 30}');
      expect((await prep.start('youtube:a', _r('a'))).file, isNotNull);
    });

    test('restart with the file ready: the file, no new yt-dlp', () async {
      yt.urls.add(far);
      expect(urlOf(await prep.start('youtube:a', _r('a'))), far);
      yt.finish('a');
      await _until(() => prep.phases.value['youtube:a'] == StreamPhase.ready);
      final s = await prep.restart('youtube:a', _r('a'));
      expect(s.file, isNotNull);
      expect(yt.started, ['a']);
    });

    test('restart without the file: the attempt runs again for a new address; the key stays pinned', () async {
      yt.urls.addAll([far, 'https://v/b?expire=4102444800']);
      prep.setQueue([_i('a')]);
      await prep.start('youtube:a', _r('a'));
      final s = await prep.restart('youtube:a', _r('a'));
      expect(urlOf(s), 'https://v/b?expire=4102444800');
      expect(yt.started, ['a', 'a']);
      expect(yt.tokens['a']![0]!.isCancelled, isTrue);
      expect(prep.phases.value['youtube:a'], StreamPhase.downloading); // a cancel is not a failure
      yt.finish('a');
      await _until(() => prep.phases.value['youtube:a'] == StreamPhase.ready);
    });

    test('the prefetch already has the address: start hands it out, no new yt-dlp', () async {
      yt.urls.add(far);
      prep.setQueue([_i('a')]);
      await _until(() => yt.started.isNotEmpty);
      await _quiet();
      expect(urlOf(await prep.start('youtube:a', _r('a'))), far);
      expect(yt.started, ['a']);
      yt.finish('a');
    });

    test('the address of the prefetch expired meanwhile: start runs a new attempt for a fresh one', () async {
      var shift = Duration.zero;
      make(clock: () => DateTime.now().add(shift));
      final soon = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600;
      yt.urls.addAll(['https://v/a?expire=$soon', far]);
      prep.setQueue([_i('a')]);
      await _until(() => yt.started.isNotEmpty);
      await _quiet();
      shift = const Duration(minutes: 20);
      expect(urlOf(await prep.start('youtube:a', _r('a'))), far);
      expect(yt.started, ['a', 'a']);
      yt.finish('a');
    });

    test('the address expired but the download is through: no new attempt, the file arrives', () async {
      var shift = Duration.zero;
      make(clock: () => DateTime.now().add(shift));
      yt.urls.add('https://v/a?expire=${DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600}');
      yt.progress = const [(100, 100)];
      yt.silence = const Duration(milliseconds: 200); // post-processing after 100%
      prep.setQueue([_i('a')]);
      yt.autoFinish = true;
      await _until(() => yt.started.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      shift = const Duration(minutes: 20);
      expect((await prep.start('youtube:a', _r('a'))).file, isNotNull);
      expect(yt.started, ['a']);
      expect(yt.tokens['a']!.single!.isCancelled, isFalse);
    });

    test('restart after a failed job: a new job', () async {
      yt.failuresLeft['a'] = 2;
      yt.autoFinish = true;
      await expectLater(prep.start('youtube:a', _r('a')), throwsA(isA<YtException>()));
      expect((await prep.restart('youtube:a', _r('a'))).file, isNotNull);
      expect(yt.started, ['a', 'a', 'a']);
    });
  });

  test('one failure is retried and succeeds', () async {
    yt.autoFinish = true;
    yt.failuresLeft['flaky'] = 1;
    await prep.ready('youtube:flaky', _r('flaky'));
    expect(yt.started, ['flaky', 'flaky']);
  });

  test('two requests for the same key start one download', () async {
    yt.autoFinish = true;
    prep.setQueue([_i('a')]);
    final both = await Future.wait([
      prep.ready('youtube:a', _r('a')),
      prep.ready('youtube:a', _r('a')),
    ]);
    expect(both[0].path, both[1].path);
    expect(yt.started, ['a']);
  });

  test('prefetch hit by a 429 pauses, then is retried without failing', () async {
    make(cooldown: const Duration(milliseconds: 50));
    yt.autoFinish = true;
    yt.rateLimits['a'] = 1;
    prep.setQueue([_i('a')]);
    await _until(() => prep.phases.value['youtube:a'] == StreamPhase.ready);
    expect(yt.started, ['a', 'a']);
  });

  test('a 429 under a waiting ready() is a failed attempt: retry once, then error', () async {
    yt.autoFinish = true;
    yt.rateLimits['a'] = 1;
    await prep.ready('youtube:a', _r('a'));
    expect(yt.started, ['a', 'a']);
    yt.rateLimits['b'] = 2;
    await expectLater(prep.ready('youtube:b', _r('b')), throwsA(isA<YtException>()));
    expect(yt.started, ['a', 'a', 'b', 'b']);
  });

  test('a failed key is downloaded again by the next ready()', () async {
    yt.autoFinish = true;
    yt.failuresLeft['x'] = 2;
    await expectLater(prep.ready('youtube:x', _r('x')), throwsA(isA<YtException>()));
    await prep.ready('youtube:x', _r('x'));
    expect(yt.started, ['x', 'x', 'x']);
  });

  test('ready() on a key already downloading starts no second download', () async {
    prep.setQueue([_i('a')]);
    await _until(() => yt.started.contains('a'));
    final f = prep.ready('youtube:a', _r('a'));
    yt.finish('a');
    await f;
    expect(yt.started, ['a']);
  });

  test('requested jobs start in queue order: after fast skipping the current one is first', () async {
    prep.setQueue([for (final n in ['w', 'x', 'c', 'd']) _i(n)]);
    await _until(() => yt.started.length == 2);
    // Both slots are held by requested jobs; the user then skipped to d, back to c.
    final w = prep.ready('youtube:w', _r('w'));
    final x = prep.ready('youtube:x', _r('x'));
    final d = prep.ready('youtube:d', _r('d'));
    final c = prep.ready('youtube:c', _r('c'));
    yt.finish('w');
    await _until(() => yt.started.length == 3);
    expect(yt.started[2], 'c');
    yt.finish('x');
    await _until(() => yt.started.length == 4);
    yt.finish('c');
    yt.finish('d');
    await Future.wait([w, x, c, d]);
  });

  test('a user pick never waits for prefetches: one yields, the total stays at 2', () async {
    prep.setQueue([_i('a'), _i('b')]);
    await _until(() => yt.started.length == 2);
    final z = prep.ready('youtube:z', _r('z'));
    await _until(() => yt.started.contains('z'));
    await _quiet();
    expect(yt.started.first, 'a');
    expect(yt.started.skip(2).first, 'z');
    expect(yt.maxOpen, 2);
    yt.finish('z');
    await z;
  });

  test('two user picks over two prefetches: both prefetches yield, the total stays at 2', () async {
    prep.setQueue([_i('a'), _i('b')]);
    await _until(() => yt.started.length == 2);
    final y = prep.ready('youtube:y', _r('y'));
    final z = prep.ready('youtube:z', _r('z'));
    await _until(() => yt.started.contains('y') && yt.started.contains('z'));
    await _quiet();
    expect(yt.maxOpen, 2);
    yt.finish('y');
    yt.finish('z');
    await Future.wait([y, z]);
  });

  test('unmetered prefetch stops at a full cache and never evicts what it downloaded', () async {
    cache.limitBytes = 10; // 3-byte files
    yt.autoFinish = true;
    prep.setQueue([for (final n in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) _i(n)]);
    await _quiet();
    await _quiet();
    expect(yt.started.length, lessThan(8));
    for (final id in yt.started) {
      expect(await cache.fileFor('youtube:$id'), isNotNull, reason: id);
    }
    expect(yt.started.take(3), ['a', 'b', 'c']);
  });

  test('an evicted key loses its ready phase and is fetched again', () async {
    yt.autoFinish = true;
    prep.setQueue([for (final n in ['a', 'b', 'c', 'd']) _i(n)]);
    await _until(() => ['a', 'b', 'c', 'd'].every((n) => prep.phases.value['youtube:$n'] == StreamPhase.ready));
    final limit = cache.limitBytes;
    cache.limitBytes = 0;
    await cache.evict(); // d is not pinned
    expect(prep.phases.value.containsKey('youtube:d'), isFalse);
    expect(prep.phases.value['youtube:c'], StreamPhase.ready);
    cache.limitBytes = limit;
    prep.setQueue([for (final n in ['a', 'b', 'c', 'd']) _i(n)]);
    await _until(() => prep.phases.value['youtube:d'] == StreamPhase.ready);
    expect(yt.started.where((id) => id == 'd').length, 2);
  });

  for (final kind in ['429', '403']) {
    test('after a $kind no new prefetch starts before the cooldown', () async {
      make(cooldown: const Duration(minutes: 1));
      yt.autoFinish = true;
      (kind == '429' ? yt.rateLimits : yt.forbidden)['a'] = 1;
      prep.setQueue([_i('a')]);
      await _until(() => yt.started.isNotEmpty);
      await _quiet();
      prep.setQueue([_i('a'), _i('b')]); // pumps again
      await _quiet();
      expect(yt.started, ['a']);
    });
  }

  test('a rate-limited prefetch is forgotten, a requested ready() still runs', () async {
    make(cooldown: const Duration(minutes: 1));
    yt.autoFinish = true;
    yt.rateLimits['a'] = 1;
    prep.setQueue([_i('a')]);
    await _until(() => yt.started.isNotEmpty);
    await _quiet();
    expect(prep.phases.value.containsKey('youtube:a'), isFalse);
    await prep.ready('youtube:a', _r('a')); // runs during the pause
    expect(yt.started, ['a', 'a']);
  });

  test('ready() on a cached file pins it, refreshes its mtime and releases the pin', () async {
    yt.autoFinish = true;
    await prep.ready('youtube:a', _r('a'));
    final f = (await cache.fileFor('youtube:a'))!;
    await f.setLastModified(DateTime(2020));
    cache.limitBytes = 0;
    final slow = tracks = _SlowTracks(db);
    make();
    final r = prep.ready('youtube:a', _r('a'));
    await cache.evict(); // ready's pin is still set
    slow.gate.complete();
    expect((await r).existsSync(), isTrue);
    expect((await r).lastModifiedSync().year, greaterThan(2020));
    await cache.evict(); // pin released
    expect(await cache.fileFor('youtube:a'), isNull);
  });

  test('an attempt that hangs counts as failed: retry once, then error', () async {
    make(attemptTimeout: const Duration(milliseconds: 30));
    await expectLater(prep.ready('youtube:slow', _r('slow')), throwsA(isA<TimeoutException>()));
    expect(yt.started, ['slow', 'slow']);
  });

  test('a stalled attempt is aborted long before attemptTimeout and retried', () async {
    make(startTimeout: const Duration(milliseconds: 30), stallTimeout: const Duration(milliseconds: 30));
    await expectLater(prep.ready('youtube:slow', _r('slow')), throwsA(isA<TimeoutException>()));
    expect(yt.started, ['slow', 'slow']);
    expect(yt.tokens['slow']!.every((t) => t!.isCancelled), isTrue);
  });

  test('a slow first event (extraction) is not a stall', () async {
    make(stallTimeout: const Duration(milliseconds: 30), startTimeout: const Duration(seconds: 2));
    final r = prep.ready('youtube:a', _r('a'));
    await _until(() => yt.started.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    yt.finish('a');
    expect((await r).existsSync(), isTrue);
    expect(yt.started, ['a']);
  });

  test('steady progress keeps re-arming the watchdog: no stall', () async {
    make(startTimeout: const Duration(milliseconds: 100), stallTimeout: const Duration(seconds: 1));
    yt
      ..autoFinish = true
      ..progress = [for (var n = 1; n <= 8; n++) (n, 100)]
      ..gap = const Duration(milliseconds: 60);
    expect((await prep.ready('youtube:a', _r('a'))).existsSync(), isTrue);
    expect(yt.started, ['a']);
  });

  test('an address-only event does not shorten the start timeout', () async {
    make(startTimeout: const Duration(seconds: 2), stallTimeout: const Duration(milliseconds: 30));
    yt
      ..urls.add('https://x/a')
      ..autoFinish = true
      ..progress = [(10, 100)]
      ..gap = const Duration(milliseconds: 120);
    expect((await prep.ready('youtube:a', _r('a'))).existsSync(), isTrue);
    expect(yt.started, ['a']);
  });

  test('silence after real progress is a stall', () async {
    make(startTimeout: const Duration(seconds: 2), stallTimeout: const Duration(milliseconds: 40));
    yt
      ..autoFinish = true
      ..progress = [(10, 100)]
      ..silence = const Duration(milliseconds: 200);
    await expectLater(prep.ready('youtube:a', _r('a')), throwsA(isA<TimeoutException>()));
    expect(yt.started, ['a', 'a']);
  });

  test('silence after 100% (post-processing) is not a stall', () async {
    make(startTimeout: const Duration(seconds: 2), stallTimeout: const Duration(milliseconds: 40));
    yt
      ..autoFinish = true
      ..progress = [(50, 100), (100, 100)]
      ..silence = const Duration(milliseconds: 150);
    expect((await prep.ready('youtube:a', _r('a'))).existsSync(), isTrue);
    expect(yt.started, ['a']);
  });

  test('onForgotten for a key that is not ready leaves the phases untouched', () async {
    yt.autoFinish = true;
    await prep.ready('youtube:a', _r('a'));
    final before = prep.phases.value;
    cache.forget('youtube:zzz');
    expect(identical(prep.phases.value, before), isTrue);
    expect(prep.phases.value['youtube:a'], StreamPhase.ready);
  });

  test('a forgotten key is not served stale: ready() downloads again', () async {
    yt.autoFinish = true;
    final first = await prep.ready('youtube:a', _r('a'));
    expect(prep.phases.value['youtube:a'], StreamPhase.ready);
    first.deleteSync(); // StreamPromoter moves the file out, then forgets the key
    cache.forget('youtube:a');
    expect(prep.phases.value['youtube:a'], isNull);
    await prep.ready('youtube:a', _r('a'));
    expect(yt.started, ['a', 'a']);
  });

  test('a timed-out attempt is cancelled and the retry gets a fresh token and folder', () async {
    make(attemptTimeout: const Duration(milliseconds: 30));
    await expectLater(prep.ready('youtube:slow', _r('slow')), throwsA(isA<TimeoutException>()));
    final t = yt.tokens['slow']!, d = yt.dirs['slow']!;
    expect(t[0]!.isCancelled, isTrue);
    expect(t[1], isNot(same(t[0])));
    expect(d[1], isNot(d[0]));
  });

  test('a prefetch that leaves the queue is cancelled, a requested one keeps running', () async {
    prep.setQueue([_i('a'), _i('b')]);
    await _until(() => yt.started.length == 2);
    final b = prep.ready('youtube:b', _r('b')); // requested
    await _quiet(); // ready() marks its job after a cache lookup
    prep.setQueue([_i('c')]);
    expect(yt.tokens['a']!.single!.isCancelled, isTrue);
    expect(yt.tokens['b']!.single!.isCancelled, isFalse);
    yt.finish('b');
    await b;
  });

  test('a key re-queued while its dropped download winds down gets one new job', () async {
    prep.setQueue([_i('a'), _i('b')]);
    await _until(() => yt.started.length == 2);
    prep.setQueue([_i('b')]);
    prep.setQueue([_i('a'), _i('b')]);
    await _until(() => yt.started.where((id) => id == 'a').length == 2);
    await _quiet();
    expect(yt.started.where((id) => id == 'a').length, 2);
    expect(prep.phases.value['youtube:a'], StreamPhase.downloading);
    yt.finish('a');
    await _until(() => prep.phases.value['youtube:a'] == StreamPhase.ready);
  });

  test('a cache hit without a shadow row makes the row', () async {
    yt.autoFinish = true;
    await prep.ready('youtube:a', _r('a'));
    await db.delete(db.tracks).go();
    await prep.ready('youtube:a', _r('a'));
    expect(await tracks.streamRow('youtube:a'), isNotNull);
    expect(yt.started, ['a']);
  });

  test('a queue change drops stale jobs: the next one to start is the new head', () async {
    prep.setQueue([for (final n in ['a', 'b', 'c', 'd', 'e', 'f']) _i(n)]);
    await _until(() => yt.started.length == 2);
    prep.setQueue([_i('e'), _i('f')]); // a and b are cancelled and free their slots
    await _until(() => yt.started.length >= 3);
    expect(yt.started[2], 'e');
  });

  test('dispose mid-download: nothing else starts and nothing is thrown', () async {
    prep.setQueue([for (final n in ['a', 'b', 'c']) _i(n)]);
    await _until(() => yt.started.length == 2);
    final f = prep.ready('youtube:a', _r('a'));
    final failed = expectLater(f, throwsA(isA<StateError>()));
    prep.dispose();
    yt.finish('a');
    yt.finish('b');
    await failed;
    await _quiet();
    expect(yt.started, ['a', 'b']);
  });

  test('current and next 2 are pinned, and unpinned when they leave the queue', () async {
    yt.autoFinish = true;
    prep.setQueue([for (final n in ['a', 'b', 'c', 'd']) _i(n)]);
    await _until(() => ['a', 'b', 'c', 'd'].every((n) => prep.phases.value['youtube:$n'] == StreamPhase.ready));
    Future<bool> pinned(String k) async {
      // Evict at zero limit: only pinned files survive.
      cache.limitBytes = 0;
      await cache.evict();
      return await cache.fileFor(k) != null;
    }

    expect(await pinned('youtube:c'), isTrue);
    expect(await pinned('youtube:d'), isFalse);
    prep.setQueue([_i('d')]);
    expect(await pinned('youtube:c'), isFalse);
  });
}
