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

/// Size of the two ONNX files, announced to the user (karaoke sheet, models page).
const int kKaraokeModelMegabytes = 78;
const _modelBase =
    'https://huggingface.co/csukuangfj/sherpa-onnx-spleeter-2stems/resolve/7001ba316a615cacddb3f9ef3ec416661a277e26';

/// The two Spleeter models: file name and sha256.
const spleeterModels = <String, String>{
  'vocals.onnx':
      'bdc16ab6bf6117ddd4842c19e80e40e2be188fc555295064d424616b0224ac97',
  'accompaniment.onnx':
      '671ace17acd3720674a2bc14de32ac6292453dec20d9eb0ba4255d4ad8e3d8c0',
};

/// Cache key of one karaoke file ([kind]: base, voice or mix) of the track with target key [k]
/// (`karaoke:…`, as [karaokeKeyOfStream] / [karaokeKeyOfLocal] give).
String karaokeFileKey(String kind, String k) =>
    'karaoke:$kind:${k.startsWith('karaoke:') ? k.substring(8) : k}';

/// Cache key of the backing track of a streamed track.
String karaokeKeyOfStream(String streamKey) => 'karaoke:$streamKey';

/// Cache key of the backing track of a local file (the mtime invalidates it on edits).
String karaokeKeyOfLocal(int trackId, int mtimeMs) =>
    'karaoke:local:$trackId:$mtimeMs';

/// How a [SeparationService.mixFor] ended: [original] (100 %, no file), [file] ([path]: the base or
/// a mix), [failed] (nothing usable: keep what plays) or [stale] (a newer request replaced it).
enum MixStatus { original, file, failed, stale }

class MixResult {
  const MixResult(this.status, [this.path]);

  final MixStatus status;
  final String? path;
}

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
    required String voiceOutput,
    required String vocals,
    required String accompaniment,
    void Function(double fraction)? onProgress,
  });

  /// Writes [output] = [base] + [level] × [voice] (WAV files). Throws on failure.
  Future<void> mix({
    required String base,
    required String voice,
    required double level,
    required String output,
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
    required String voiceOutput,
    required String vocals,
    required String accompaniment,
    void Function(double fraction)? onProgress,
  }) async {
    _onProgress = onProgress;
    try {
      await _channel.invokeMethod<void>('separate', {
        'input': input,
        'output': output,
        'voiceOutput': voiceOutput,
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
  Future<void> mix({
    required String base,
    required String voice,
    required double level,
    required String output,
  }) => _channel.invokeMethod<void>('mix', {
    'base': base,
    'voice': voice,
    'level': level,
    'output': output,
  });

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
    DateTime Function()? clock,
    this.idleLimit = const Duration(minutes: 15),
  }) : _download = download ?? _dioDownload,
       _clock = clock ?? DateTime.now;

  final StreamCache cache;
  final Separator separator;
  final Future<Directory> Function() modelsRoot;
  final ModelDownloader _download;

  /// File name -> sha256 of the models [ensureModels] installs.
  final Map<String, String> models;

  final DateTime Function() _clock;

  /// Karaoke files not used for this long are deleted (D-626).
  final Duration idleLimit;
  Timer? _expiryTimer;
  final _mixGen = <String, int>{};
  Future<void> _mixChain = Future.value();
  int _mixing = 0;

  final _states = <String, SeparationState>{};
  int _gen = 0;
  CancelToken? _token;
  Future<void> _last = Future.value();
  bool _active = false;
  bool _disposed = false;
  String? _activeKey;

  /// Bumped when the expiry deleted files: the providers that read the cache look again.
  final stemsVersion = ValueNotifier<int>(0);

  /// True while a mix is being made.
  bool get mixing => _mixing > 0;

  /// True while a job runs or is being set up (a prefetch must not start then).
  bool get busy => _activeKey != null;

  /// The key of the running (or starting) job.
  String? get activeKey => _activeKey;

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
      final existing = await cache.fileFor(karaokeFileKey('base', key));
      final voice = await cache.fileFor(karaokeFileKey('voice', key));
      if (_activeKey == key) return;
      if (existing != null && voice != null) {
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
      final mixes = _mixChain; // only the mixes asked before this job: later ones wait for it
      if (_active) unawaited(separator.cancel());
      final done = Completer<void>();
      _last = done.future;
      try {
        await previous;
        await mixes;
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
    _expiryTimer?.cancel();
    stemsVersion.dispose();
    _stop();
    _disposed = true;
    super.dispose();
  }

  Future<void> _run(String key, String input, int gen) async {
    bool stale() => gen != _gen;
    final token = _token = CancelToken();
    _active = true;
    final baseKey = karaokeFileKey('base', key);
    final voiceKey = karaokeFileKey('voice', key);
    File partOf(String k) =>
        File(p.join(cache.dir.path, '${streamFileName(k)}.wav.part'));
    final parts = [partOf(baseKey), partOf(voiceKey)];
    try {
      _set(key, const SeparationState(SeparationPhase.model));
      final dir = await ensureModels(token, (f) {
        if (!stale()) {
          _set(key, SeparationState(SeparationPhase.model, fraction: f));
        }
      });
      if (stale()) return _drop(key);
      _set(key, const SeparationState(SeparationPhase.separating));
      await cache.dir.create(recursive: true);
      if (stale()) return _drop(key);
      await separator.separate(
        input: input,
        output: parts[0].path,
        voiceOutput: parts[1].path,
        vocals: p.join(dir.path, 'vocals.onnx'),
        accompaniment: p.join(dir.path, 'accompaniment.onnx'),
        onProgress: (f) {
          if (!stale()) {
            _set(key, SeparationState(SeparationPhase.separating, fraction: f));
          }
        },
      );
      if (stale()) return _drop(key);
      // The base is pinned while the voice goes in: the trim must not take it out.
      cache.pin(baseKey);
      final File f;
      try {
        f = await cache.put(baseKey, parts[0], trim: false);
        await cache.put(voiceKey, parts[1]);
      } finally {
        cache.unpin(baseKey);
      }
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
      for (final part in parts) {
        try {
          if (await part.exists()) await part.delete();
        } on FileSystemException catch (e, st) {
          AppLog.w('separation: cannot delete ${part.path}', e, st);
        }
      }
    }
  }

  /// The file to play for [k] at voice [level] (0..1), see [MixResult]: original (100 %), the base
  /// (0 %) or a mix, reused from the cache when it exists (levels in steps of 5 %). Native calls are
  /// serialized: a mix waits for a running separation (and a new separation for earlier mixes), so
  /// the engine never answers `busy`. A newer call for the same [k] makes an older one [MixStatus.stale].
  /// Never throws: missing stems or a failed mix are [MixStatus.failed] (logged).
  Future<MixResult> mixFor(String k, double level) {
    final step = (level * 20).round().clamp(0, 20);
    if (level >= 0.995 || step == 20) {
      return Future.value(const MixResult(MixStatus.original));
    }
    // A job for another track is a prefetch or a stale one: playback must not wait for it.
    if (_activeKey != null && _activeKey != k) _stop();
    final gen = _mixGen[k] = (_mixGen[k] ?? 0) + 1;
    final separation =
        _last; // captured now: a job asked later waits for this mix instead
    final run = _mixChain.then((_) async {
      if (gen != _mixGen[k]) return const MixResult(MixStatus.stale);
      await separation;
      if (gen != _mixGen[k]) return const MixResult(MixStatus.stale);
      try {
        return await _mix(k, step, level <= 0.005);
      } on Object catch (e, st) {
        AppLog.w('separation: mix of $k at $step/20 failed', e, st);
        return const MixResult(MixStatus.failed);
      }
    });
    _mixChain = run.then((_) {});
    return run;
  }

  Future<MixResult> _mix(String k, int step, bool baseOnly) async {
    final baseKey = karaokeFileKey('base', k);
    final voiceKey = karaokeFileKey('voice', k);
    final base = await cache.fileFor(baseKey);
    if (base == null) return const MixResult(MixStatus.failed);
    if (baseOnly || step == 0) {
      unawaited(cache.touch(baseKey));
      return MixResult(MixStatus.file, base.path);
    }
    final mixKey = karaokeFileKey('mix', '$k:${step * 5}');
    final cached = await cache.fileFor(mixKey);
    if (cached != null) {
      for (final x in [baseKey, voiceKey, mixKey]) {
        unawaited(cache.touch(x));
      }
      return MixResult(MixStatus.file, cached.path);
    }
    final voice = await cache.fileFor(voiceKey);
    if (voice == null) return const MixResult(MixStatus.failed);
    final part = File(
      p.join(cache.dir.path, '${streamFileName(mixKey)}.wav.part'),
    );
    _mixing++;
    notifyListeners();
    // The stems must not expire or be evicted while they are read.
    cache.pin(baseKey);
    cache.pin(voiceKey);
    try {
      await cache.dir.create(recursive: true);
      await separator.mix(
        base: base.path,
        voice: voice.path,
        level: step / 20,
        output: part.path,
      );
      final f = await cache.put(mixKey, part);
      unawaited(cache.touch(baseKey));
      unawaited(cache.touch(voiceKey));
      return MixResult(MixStatus.file, f.path);
    } finally {
      cache.unpin(baseKey);
      cache.unpin(voiceKey);
      _mixing--;
      if (!_disposed) notifyListeners();
      try {
        if (await part.exists()) await part.delete();
      } on FileSystemException catch (e, st) {
        AppLog.w('separation: cannot delete ${part.path}', e, st);
      }
    }
  }

  /// Deletes the karaoke files idle for [idleLimit] and resets the states whose base went.
  Future<void> expire() async {
    try {
      final n = await cache.expire(
        _clock().subtract(idleLimit),
        stemPrefix: streamFileName('karaoke:'),
      );
      if (n == 0) return;
      for (final k in _states.keys.toList()) {
        if (_states[k]!.phase == SeparationPhase.ready &&
            await cache.fileFor(karaokeFileKey('base', k)) == null) {
          _states[k] = SeparationState.idle;
        }
      }
      if (_disposed) return;
      stemsVersion.value++; // stems of an earlier session are not in _states
      notifyListeners();
    } on Object catch (e, st) {
      AppLog.w('separation: expiry failed', e, st);
    }
  }

  /// Runs [expire] now and every [every] while the service lives.
  void startExpiry({Duration every = const Duration(minutes: 2)}) {
    unawaited(expire());
    _expiryTimer ??= Timer.periodic(every, (_) => unawaited(expire()));
  }

  /// True when the models are not on the device yet (the first run downloads [kKaraokeModelMegabytes] MB).
  Future<bool> modelsMissing() async {
    final dir = await _modelsDir();
    for (final n in models.keys) {
      if (!await File(p.join(dir.path, n)).exists()) return true;
    }
    return false;
  }

  Future<Directory> _modelsDir() async =>
      Directory(p.join((await modelsRoot()).path, 'models', _modelDir));

  /// Bytes of the model files on the device (0 when none).
  Future<int> modelsSize() async {
    final dir = await _modelsDir();
    var total = 0;
    for (final n in models.keys) {
      final f = File(p.join(dir.path, n));
      if (await f.exists()) total += await f.length();
    }
    return total;
  }

  Future<void>? _downloading;
  CancelToken? _downloadToken;
  Future<void> _modelsChain = Future.value();

  /// Runs [f] after every model operation asked before it (one at a time: the
  /// downloads share the `.part` files and a delete must not cut one).
  Future<T> _exclusive<T>(Future<T> Function() f) {
    final run = _modelsChain.then((_) => f());
    _modelsChain = run.then((_) {}, onError: (_) {});
    return run;
  }

  /// Downloads the missing models (the catalogue's «Scarica»); throws when it
  /// fails. A second call while one runs shares it.
  Future<void> downloadModels([void Function(double)? onProgress]) {
    return _downloading ??= ensureModels(
      _downloadToken = CancelToken(),
      onProgress ?? (_) {},
    ).then((_) {}).whenComplete(() {
      _downloading = null;
      _downloadToken = null;
    });
  }

  /// Deletes the models; they are downloaded again by the next separation. A job
  /// or a download in progress is stopped first. Throws when the files stay.
  Future<void> deleteModels() async {
    _downloadToken?.cancel();
    if (_activeKey != null) {
      _stop();
      await _last;
    }
    await _exclusive(() async {
      try {
        final dir = await _modelsDir();
        if (await dir.exists()) await dir.delete(recursive: true);
      } on Object catch (e, st) {
        AppLog.w('separation: cannot delete the models', e, st);
        rethrow;
      }
    });
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
  ) => _exclusive(() => _ensureModels(token, onProgress));

  Future<Directory> _ensureModels(
    CancelToken token,
    void Function(double) onProgress,
  ) async {
    // Asked before a delete that cancelled it: do not bring the files back.
    if (token.isCancelled) throw const SeparationCancelled();
    final dir = await _modelsDir();
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
