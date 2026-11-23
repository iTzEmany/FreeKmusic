import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/karaoke/separation_service.dart';
import 'package:codecore/services/stream/stream_cache.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class FakeSeparator implements Separator {
  int runs = 0;
  Object? error;
  Completer<void>? gate;
  final cancels = <int>[];
  final mixes = <double>[];
  Completer<void>? gate2; // holds the second separation
  Object? mixError;
  var _separating = false;

  @override
  Future<void> separate({
    required String input,
    required String output,
    required String voiceOutput,
    required String vocals,
    required String accompaniment,
    void Function(double fraction)? onProgress,
  }) async {
    runs++;
    final run = runs;
    _separating = true;
    try {
      await _separate(run, output, voiceOutput, onProgress);
    } finally {
      _separating = false;
    }
  }

  Future<void> _separate(
    int run,
    String output,
    String voiceOutput,
    void Function(double)? onProgress,
  ) async {
    onProgress?.call(0.5);
    if (gate2 != null && run == 2) await gate2!.future;
    if (gate != null && run == 1) {
      await gate!.future;
      if (cancels.contains(run)) throw const SeparationCancelled();
    }
    if (error != null) throw error!;
    File(output).writeAsBytesSync([1, 2, 3]);
    File(voiceOutput).writeAsBytesSync([4, 5]);
  }

  @override
  Future<void> mix({
    required String base,
    required String voice,
    required double level,
    required String output,
  }) async {
    if (_separating) throw StateError('busy');
    if (mixError != null) throw mixError!;
    mixes.add(level);
    File(output).writeAsBytesSync([9, level.round()]);
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

  // Writes 'model:<name>'; that never matches the pinned hashes.
  Future<void> fakeDownload(
    String url,
    String dest,
    CancelToken t,
    void Function(double) onProgress,
  ) async {
    downloads++;
    final name = url.split('/').last;
    onProgress(0.5);
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
    // Pre-installed models: ensureModels trusts files already there.
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
        final fractions = <double>[];
        s.addListener(() => fractions.add(s.stateOf('karaoke:k').fraction));
        await s.request('karaoke:k', '/in.mp3');
        final st = s.stateOf('karaoke:k');
        expect(fractions, contains(0.5));
        expect(st.phase, SeparationPhase.ready);
        expect((await cache.fileFor('karaoke:base:k'))!.path, st.path);
        expect(
          File((await cache.fileFor('karaoke:voice:k'))!.path)
              .readAsBytesSync(),
          [4, 5],
        );
        expect(File(st.path!).readAsBytesSync(), [1, 2, 3]);
      },
    );

    test('installed models are not downloaded again', () async {
      await service().request('karaoke:k', '/in.mp3');
      expect(downloads, 0);
    });

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
      expect(await cache.fileFor('karaoke:base:a'), isNull);
    });
  });

  group('mix and expiry', () {
    setUp(() {
      final dir = Directory(
        p.join(root.path, 'models', 'spleeter-2stems-7001ba31'),
      )..createSync(recursive: true);
      for (final n in spleeterModels.keys) {
        File(p.join(dir.path, n)).writeAsStringSync('x');
      }
    });

    test(
      'mixFor: 100 % is the original, 0 % the base, 50 % a mix made once',
      () async {
        final s = service();
        await s.request('karaoke:k', '/in.mp3');
        final base = (await cache.fileFor('karaoke:base:k'))!.path;
        expect((await s.mixFor('karaoke:k', 1)).status, MixStatus.original);
        expect((await s.mixFor('karaoke:k', 0)).path, base);
        expect(sep.mixes, isEmpty);
        final mix = (await s.mixFor('karaoke:k', 0.5)).path;
        expect(mix, (await cache.fileFor('karaoke:mix:k:50'))!.path);
        expect(File(mix!).readAsBytesSync(), [9, 1]);
        expect((await s.mixFor('karaoke:k', 0.5)).path, mix); // cached
        expect((await s.mixFor('karaoke:k', 0.51)).path, mix); // same 5 % step
        expect(sep.mixes, [0.5]);
        expect(
          cache.dir.listSync().where((e) => e.path.endsWith('.part')),
          isEmpty,
        );
      },
    );

    test(
      'mixFor without stems or with a failing mix is failed, not original',
      () async {
        final s = service();
        expect((await s.mixFor('karaoke:none', 0.5)).status, MixStatus.failed);
        await s.request('karaoke:k', '/in.mp3');
        sep.mixError = StateError('io');
        final r = await s.mixFor('karaoke:k', 0.5);
        expect(r.status, MixStatus.failed);
        expect(r.path, isNull);
        expect(
          cache.dir.listSync().where((e) => e.path.contains('mix')),
          isEmpty,
        );
      },
    );

    test('a mix asked during a separation waits for it and succeeds', () async {
      final s = service();
      await s.request('karaoke:k', '/in.mp3');
      sep.gate2 = Completer<void>();
      final other = s.request('karaoke:b', '/b.mp3'); // run 2, held
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final mix = s.mixFor('karaoke:k', 0.5);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(sep.mixes, isEmpty);
      sep.gate2!.complete();
      await other;
      final r = await mix;
      expect(
        r.status,
        MixStatus.file,
      ); // the fake answers busy if they overlapped
      expect(sep.mixes, [0.5]);
    });

    test('two quick requests for one track: the latest wins', () async {
      final s = service();
      await s.request('karaoke:k', '/in.mp3');
      final first = s.mixFor('karaoke:k', 0.3);
      final second = s.mixFor('karaoke:k', 0.5);
      expect((await first).status, MixStatus.stale);
      expect((await second).status, MixStatus.file);
      expect(sep.mixes, [0.5]);
    });

    test('the stems are pinned while a mix is made and free after', () async {
      final s = service();
      await s.request('karaoke:k', '/in.mp3');
      await s.mixFor('karaoke:k', 0.5);
      expect(cache.isPinned('karaoke:base:k'), isFalse);
      expect(cache.isPinned('karaoke:voice:k'), isFalse);
    });

    test('expiry deletes old unpinned karaoke files only', () async {
      final now = DateTime(2026, 1, 1, 12);
      final s = SeparationService(
        cache: cache,
        separator: sep,
        modelsRoot: () async => root,
        clock: () => now,
      );
      await s.request('karaoke:k', '/in.mp3');
      await s.request('karaoke:old', '/in.mp3');
      File(p.join(cache.dir.path, 'yt_abc.m4a')).writeAsStringSync('song');
      File(p.join(cache.dir.path, 'video_karaoke_youtube_v.mp4')).writeAsStringSync('video');
      for (final e in cache.dir.listSync().whereType<File>()) {
        e.setLastModifiedSync(now.subtract(const Duration(minutes: 20)));
      }
      // k: base is pinned (playing), voice used 1 minute ago.
      cache.pin('karaoke:base:k');
      (await cache.fileFor('karaoke:voice:k'))!
          .setLastModifiedSync(now.subtract(const Duration(minutes: 1)));
      await s.expire();
      expect(await cache.fileFor('karaoke:base:old'), isNull);
      expect(await cache.fileFor('karaoke:voice:old'), isNull);
      expect(await cache.fileFor('karaoke:base:k'), isNotNull);
      expect(await cache.fileFor('karaoke:voice:k'), isNotNull);
      expect(await cache.fileFor('yt:abc'), isNotNull);
      expect(await cache.fileFor('video:karaoke:youtube:v'), isNotNull); // a karaoke video is not a stem
      expect(s.stateOf('karaoke:old').phase, SeparationPhase.idle);
      expect(s.stateOf('karaoke:k').phase, SeparationPhase.ready);
    });
  });

  group('model download', () {
    String hash(String name) =>
        sha256.convert(utf8.encode('model:$name')).toString();
    SeparationService svc(ModelDownloader d) => SeparationService(
      cache: cache,
      separator: sep,
      modelsRoot: () async => root,
      download: d,
      models: {'a.onnx': hash('a.onnx'), 'b.onnx': hash('b.onnx')},
    );
    Iterable<File> files() =>
        Directory(p.join(root.path, 'models'))
            .listSync(recursive: true)
            .whereType<File>();

    test(
      'succeeds: both files installed, no .part, progress only goes up',
      () async {
        final s = svc(fakeDownload);
        final seen = <double>[];
        s.addListener(() {
          final st = s.stateOf('karaoke:k');
          if (st.phase == SeparationPhase.model) seen.add(st.fraction);
        });
        await s.request('karaoke:k', '/in.mp3');
        expect(s.stateOf('karaoke:k').phase, SeparationPhase.ready);
        expect(files().map((f) => p.basename(f.path)).toSet(), {
          'a.onnx',
          'b.onnx',
        });
        expect(seen, isNotEmpty);
        expect(seen, orderedEquals([...seen]..sort()));
      },
    );

    test('a cancel during the download -> idle, no .part left', () async {
      final s = svc((url, dest, t, onProgress) async {
        File(dest).writeAsStringSync('half');
        throw DioException.requestCancelled(
          requestOptions: RequestOptions(),
          reason: 'cancelled',
        );
      });
      await s.request('karaoke:k', '/in.mp3');
      expect(s.stateOf('karaoke:k').phase, SeparationPhase.idle);
      expect(files(), isEmpty);
    });
  });

  group('model operations of the catalogue', () {
    final hashes = {
      'a.onnx': sha256.convert('model:a.onnx'.codeUnits).toString(),
      'b.onnx': sha256.convert('model:b.onnx'.codeUnits).toString(),
    };
    Completer<void>? hold;

    SeparationService withModels() => SeparationService(
      cache: cache,
      separator: sep,
      modelsRoot: () async => root,
      models: hashes,
      download: (url, dest, token, onProgress) async {
        downloads++;
        if (hold != null) {
          await Future.any([hold!.future, token.whenCancel]);
          if (token.isCancelled) throw DioException.requestCancelled(requestOptions: RequestOptions(), reason: 'x');
        }
        File(dest).writeAsStringSync('model:${url.split('/').last}');
      },
    );

    Directory modelsDir() => Directory(p.join(root.path, 'models', 'spleeter-2stems-7001ba31'));
    setUp(() => hold = null);

    test('a second download while one runs shares it: each file is fetched once', () async {
      hold = Completer<void>();
      final s = withModels();
      final a = s.downloadModels();
      final b = s.downloadModels();
      expect(identical(a, b), isTrue);
      hold!.complete();
      await a;
      expect(downloads, 2);
      expect(await s.modelsMissing(), isFalse);
    });

    test('a delete during a download cancels it and leaves no file', () async {
      hold = Completer<void>();
      final s = withModels();
      final d = s.downloadModels();
      final failed = expectLater(d, throwsA(isA<DioException>()));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await s.deleteModels();
      await failed;
      expect(modelsDir().existsSync(), isFalse);
      expect(await s.modelsMissing(), isTrue);
    });

    test('«Elimina» raises the removed mark (D-707); a download or an explicit request lowers it', () async {
      final s = withModels();
      await s.downloadModels();
      expect(await s.modelsRemovedByUser(), isFalse);
      await s.deleteModels();
      expect(await s.modelsRemovedByUser(), isTrue);
      await s.request('karaoke:k', '/in.mp3');
      expect(await s.modelsRemovedByUser(), isTrue);
      await s.request('karaoke:k', '/in.mp3', explicit: true);
      expect(await s.modelsRemovedByUser(), isFalse);
      await s.deleteModels();
      await s.downloadModels();
      expect(await s.modelsRemovedByUser(), isFalse);
    });

    test('a delete during a separation stops it first', () async {
      final s = withModels();
      await s.downloadModels();
      sep.gate = Completer<void>();
      final job = s.request('karaoke:k', '/in.mp3');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(s.busy, isTrue);
      await s.deleteModels();
      await job;
      expect(s.busy, isFalse);
      expect(s.stateOf('karaoke:k').phase, isNot(SeparationPhase.ready));
      expect(modelsDir().existsSync(), isFalse);
    });

    test('a delete that cannot remove the files throws', () async {
      final s = withModels();
      await s.downloadModels();
      await Process.run('chmod', ['555', modelsDir().parent.path]);
      addTearDown(() => Process.run('chmod', ['755', modelsDir().parent.path]));
      await expectLater(s.deleteModels(), throwsA(isA<FileSystemException>()));
      expect(modelsDir().existsSync(), isTrue);
    });
  });
}
