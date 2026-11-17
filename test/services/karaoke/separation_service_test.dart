import 'dart:async';
import 'dart:io';

import 'package:codecore/services/karaoke/separation_service.dart';
import 'package:codecore/services/stream/stream_cache.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class FakeSeparator implements Separator {
  int runs = 0;
  Object? error;
  Completer<void>? gate;
  final cancels = <int>[];

  @override
  Future<void> separate({
    required String input,
    required String output,
    required String vocals,
    required String accompaniment,
    void Function(double fraction)? onProgress,
  }) async {
    runs++;
    final run = runs;
    onProgress?.call(0.5);
    if (gate != null && run == 1) {
      await gate!.future;
      if (cancels.contains(run)) throw const SeparationCancelled();
    }
    if (error != null) throw error!;
    File(output).writeAsBytesSync([1, 2, 3]);
  }

  @override
  Future<void> cancel() async {
    cancels.add(runs);
    if (gate != null && !gate!.isCompleted) gate!.complete();
  }
}

void main() {
  late Directory root;
  late StreamCache cache;
  late FakeSeparator sep;
  var downloads = 0;

  // Writes bytes whose sha256 is the expected one only when not [corrupt].
  Future<void> fakeDownload(
    String url,
    String dest,
    CancelToken t,
    void Function(double) onProgress,
  ) async {
    downloads++;
    final name = url.split('/').last;
    onProgress(1);
    File(dest).writeAsStringSync('model:$name');
  }

  SeparationService service() => SeparationService(
    cache: cache,
    separator: sep,
    modelsRoot: () async => root,
    download: fakeDownload,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('separation_test');
    cache = StreamCache(
      Directory(p.join(root.path, 'cache')),
      freeSpace: () async => null,
    );
    await cache.open();
    sep = FakeSeparator();
    downloads = 0;
  });
  tearDown(() => root.delete(recursive: true));

  test('wrong sha256 -> failed, no model file left', () async {
    final s = service();
    await s.request('karaoke:k', '/in.mp3');
    expect(s.stateOf('karaoke:k').phase, SeparationPhase.failed);
    expect(sep.runs, 0);
    final models = Directory(p.join(root.path, 'models'));
    expect(models.listSync(recursive: true).whereType<File>(), isEmpty);
  });

  group('with valid hashes', () {
    // The fake files can't match the pinned hashes: swap the table's check by
    // pre-installing the models, which ensureModels trusts.
    setUp(() {
      final dir = Directory(
        p.join(root.path, 'models', 'spleeter-2stems-7001ba31'),
      )..createSync(recursive: true);
      for (final n in spleeterModels.keys) {
        File(p.join(dir.path, n)).writeAsStringSync('x');
      }
    });

    test(
      'progress is reported and the base lands in the cache under the key',
      () async {
        final s = service();
        final seen = <SeparationPhase>[];
        s.addListener(() => seen.add(s.stateOf('karaoke:k').phase));
        await s.request('karaoke:k', '/in.mp3');
        final st = s.stateOf('karaoke:k');
        expect(seen, containsAll([SeparationPhase.separating]));
        expect(st.phase, SeparationPhase.ready);
        expect((await cache.fileFor('karaoke:k'))!.path, st.path);
        expect(File(st.path!).readAsBytesSync(), [1, 2, 3]);
        expect(downloads, 0);
      },
    );

    test('a base already in the cache starts no job', () async {
      final s = service();
      await s.request('karaoke:k', '/in.mp3');
      await s.request('karaoke:k', '/in.mp3');
      expect(sep.runs, 1);
      expect(s.stateOf('karaoke:k').phase, SeparationPhase.ready);
    });

    test('a separator error -> failed, no part left, nothing thrown', () async {
      sep.error = StateError('boom');
      final s = service();
      await s.request('karaoke:k', '/in.mp3');
      expect(s.stateOf('karaoke:k').phase, SeparationPhase.failed);
      expect(cache.dir.listSync().whereType<File>(), isEmpty);
    });

    test('a second request cancels the first', () async {
      sep.gate = Completer<void>();
      final s = service();
      final first = s.request('karaoke:a', '/a.mp3');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await s.request('karaoke:b', '/b.mp3');
      await first;
      expect(s.stateOf('karaoke:a').phase, SeparationPhase.idle);
      expect(s.stateOf('karaoke:b').phase, SeparationPhase.ready);
      expect(await cache.fileFor('karaoke:a'), isNull);
    });
  });
}
