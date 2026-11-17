import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../stream/stream_cache.dart';
import '../stream/stream_key.dart';

const _modelDir = 'spleeter-2stems-7001ba31';
const _modelBase =
    'https://huggingface.co/csukuangfj/sherpa-onnx-spleeter-2stems/resolve/7001ba316a615cacddb3f9ef3ec416661a277e26';

/// The two Spleeter models: file name and sha256.
const spleeterModels = <String, String>{
  'vocals.onnx':
      'bdc16ab6bf6117ddd4842c19e80e40e2be188fc555295064d424616b0224ac97',
  'accompaniment.onnx':
      '671ace17acd3720674a2bc14de32ac6292453dec20d9eb0ba4255d4ad8e3d8c0',
};

/// Cache key of the backing track of a streamed track.
String karaokeKeyOfStream(String streamKey) => 'karaoke:$streamKey';

/// Cache key of the backing track of a local file (the mtime invalidates it on edits).
String karaokeKeyOfLocal(int trackId, int mtimeMs) =>
    'karaoke:local:$trackId:$mtimeMs';

enum SeparationPhase { idle, model, separating, ready, failed }

class SeparationState {
  const SeparationState(this.phase, {this.fraction = 0, this.path});

  static const idle = SeparationState(SeparationPhase.idle);

  final SeparationPhase phase;

  /// 0..1 while [SeparationPhase.model] or [SeparationPhase.separating].
  final double fraction;

  /// The backing track file, when [SeparationPhase.ready].
  final String? path;
}

/// The engine that splits [input] and writes the accompaniment WAV to [output].
abstract class Separator {
  /// Throws on failure; [SeparationCancelled] when [cancel] stopped it.
  Future<void> separate({
    required String input,
    required String output,
    required String vocals,
    required String accompaniment,
    void Function(double fraction)? onProgress,
  });

  Future<void> cancel();
}

class SeparationCancelled implements Exception {
  const SeparationCancelled();
}

/// The Kotlin engine, over `codecore/separation`.
class ChannelSeparator implements Separator {
  ChannelSeparator([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('codecore/separation') {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'progress') {
        final f = (call.arguments as Map?)?['fraction'];
        if (f is num) _onProgress?.call(f.toDouble().clamp(0.0, 1.0));
      }
    });
  }

  final MethodChannel _channel;
  void Function(double)? _onProgress;

  @override
  Future<void> separate({
    required String input,
    required String output,
    required String vocals,
    required String accompaniment,
    void Function(double fraction)? onProgress,
  }) async {
    _onProgress = onProgress;
    try {
      await _channel.invokeMethod<void>('separate', {
        'input': input,
        'output': output,
        'vocals': vocals,
        'accompaniment': accompaniment,
      });
    } on PlatformException catch (e) {
      if (e.code == 'cancelled') throw const SeparationCancelled();
      rethrow;
    } finally {
      _onProgress = null;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on PlatformException catch (e, st) {
      AppLog.w('separation: cancel failed', e, st);
    }
  }
}

typedef ModelDownloader = Future<void> Function(
  String url,
  String dest,
  CancelToken token,
  void Function(double fraction) onProgress,
);

/// Makes the backing track («Alta qualità» karaoke) of a track: downloads the
/// models once, runs the [Separator], hands the result to the stream cache.
/// One job at a time; a new [request] cancels the old one. Never throws to callers.
class SeparationService extends ChangeNotifier {
  SeparationService({
    required this.cache,
    required this.separator,
    required this.modelsRoot,
    ModelDownloader? download,
    this.models = spleeterModels,
  }) : _download = download ?? _dioDownload;

  final StreamCache cache;
  final Separator separator;
  final Future<Directory> Function() modelsRoot;
  final ModelDownloader _download;

  /// File name -> sha256 of the models [ensureModels] installs.
  final Map<String, String> models;

  final _states = <String, SeparationState>{};
  int _gen = 0;
  CancelToken? _token;
  Future<void> _last = Future.value();
  bool _active = false;
  bool _disposed = false;
  String? _activeKey;

  SeparationState stateOf(String key) => _states[key] ?? SeparationState.idle;

  void _set(String key, SeparationState s) {
    if (_disposed) return;
    _states[key] = s;
    notifyListeners();
  }

  /// Starts the job for [key] on [input] (a file path), replacing any running one.
  /// Follow it with [stateOf]; a base already in the cache makes no job.
  Future<void> request(String key, String input) async {
    if (_activeKey == key) return;
    int? gen;
    try {
      final existing = await cache.fileFor(key);
      if (_activeKey == key) return;
      if (existing != null) {
        _stop();
        _set(
          key,
          SeparationState(
            SeparationPhase.ready,
            fraction: 1,
            path: existing.path,
          ),
        );
        return;
      }
      gen = ++_gen;
      _activeKey = key;
      // Stop the old job and wait for it, so the engine is free (no `busy`).
      _token?.cancel();
      final previous = _last;
      if (_active) unawaited(separator.cancel());
      final done = Completer<void>();
      _last = done.future;
      try {
        await previous;
        if (gen != _gen) return;
        await _run(key, input, gen);
      } finally {
        done.complete();
      }
    } on Object catch (e, st) {
      _fail(key, e, st);
    } finally {
      if (gen == _gen) _activeKey = null;
    }
  }

  void _stop() {
    _gen++;
    _activeKey = null;
    _token?.cancel();
    if (_active) unawaited(separator.cancel());
  }

  Future<void> cancel() async => _stop();

  @override
  void dispose() {
    _stop();
    _disposed = true;
    super.dispose();
  }

  Future<void> _run(String key, String input, int gen) async {
    bool stale() => gen != _gen;
    final token = _token = CancelToken();
    _active = true;
    File? part;
    try {
      _set(key, const SeparationState(SeparationPhase.model));
      final dir = await ensureModels(token, (f) {
        if (!stale()) {
          _set(key, SeparationState(SeparationPhase.model, fraction: f));
        }
      });
      if (stale()) return _drop(key);
      _set(key, const SeparationState(SeparationPhase.separating));
      part = File(p.join(cache.dir.path, '${streamFileName(key)}.wav.part'));
      await cache.dir.create(recursive: true);
      if (stale()) return _drop(key);
      await separator.separate(
        input: input,
        output: part.path,
        vocals: p.join(dir.path, 'vocals.onnx'),
        accompaniment: p.join(dir.path, 'accompaniment.onnx'),
        onProgress: (f) {
          if (!stale()) {
            _set(key, SeparationState(SeparationPhase.separating, fraction: f));
          }
        },
      );
      if (stale()) return _drop(key);
      final f = await cache.put(key, part);
      part = null;
      _set(
        key,
        SeparationState(SeparationPhase.ready, fraction: 1, path: f.path),
      );
    } on SeparationCancelled {
      _drop(key);
    } on DioException catch (e, st) {
      if (CancelToken.isCancel(e)) {
        _drop(key);
      } else {
        _fail(key, e, st);
      }
    } on Object catch (e, st) {
      _fail(key, e, st);
    } finally {
      _active = false;
      if (part != null && await part.exists()) {
        try {
          await part.delete();
        } on FileSystemException catch (e, st) {
          AppLog.w('separation: cannot delete ${part.path}', e, st);
        }
      }
    }
  }

  void _drop(String key) => _set(key, SeparationState.idle);

  void _fail(String key, Object e, StackTrace st) {
    AppLog.w('separation: $key failed', e, st);
    _set(key, const SeparationState(SeparationPhase.failed));
  }

  /// The folder with both models, downloading (and checking) what is missing.
  Future<Directory> ensureModels(
    CancelToken token,
    void Function(double) onProgress,
  ) async {
    final dir = Directory(
      p.join((await modelsRoot()).path, 'models', _modelDir),
    );
    await dir.create(recursive: true);
    var i = 0;
    for (final e in models.entries) {
      final file = File(p.join(dir.path, e.key));
      final base = i++ / models.length;
      if (await file.exists()) continue;
      final part = File('${file.path}.part');
      try {
        await _download(
          '$_modelBase/${e.key}',
          part.path,
          token,
          (f) => onProgress(base + f / models.length),
        );
        final actual = (await sha256.bind(part.openRead()).first).toString();
        if (actual != e.value) {
          throw StateError('${e.key}: expected ${e.value} got $actual');
        }
        await part.rename(file.path);
      } finally {
        try {
          if (await part.exists()) await part.delete();
        } on FileSystemException catch (err, st) {
          AppLog.w('separation: cannot delete ${part.path}', err, st);
        }
      }
    }
    onProgress(1);
    return dir;
  }
}

Future<void> _dioDownload(
  String url,
  String dest,
  CancelToken token,
  void Function(double) onProgress,
) async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  try {
    await dio.download(
      url,
      dest,
      cancelToken: token,
      onReceiveProgress: (got, total) {
        if (total > 0) onProgress(got / total);
      },
    );
  } finally {
    dio.close();
  }
}
