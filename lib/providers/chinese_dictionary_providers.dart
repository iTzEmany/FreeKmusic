import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/app_log.dart';
import '../core/paths.dart';
import '../services/lyrics/cedict_download.dart';
import '../services/lyrics/pinyin_dictionary.dart';
import '../services/online/http_client.dart' show DioWebClient;

/// `<appSupportDir>/cedict/…txt.gz`; overridden in tests.
final cedictPathProvider = FutureProvider<String>(
  (ref) async => p.join(
    await appSupportDir(),
    'cedict',
    'cedict_1_0_ts_utf-8_mdbg.txt.gz',
  ),
);

/// The client of the dictionary download: timeouts and User-Agent as the other services.
final cedictDioProvider = Provider<Dio>(
  (ref) => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'User-Agent': DioWebClient.userAgent},
    ),
  ),
);

enum ChineseDictionaryStatus { notDownloaded, downloading, ready, error }

class ChineseDictionaryState {
  const ChineseDictionaryState(
    this.status, {
    this.progress,
    this.sizeBytes = 0,
  });

  final ChineseDictionaryStatus status;

  /// 0..1 while downloading, null when the size is not known.
  final double? progress;

  /// Size of the file on disk when [status] is ready.
  final int sizeBytes;
}

/// How many times the app tried to download the dictionary by itself and
/// failed in this session; after [maxAutomatic] it waits for the user.
class CedictAutoGate {
  static const maxAutomatic = 2;
  var failures = 0;
}

final cedictAutoGateProvider = Provider<CedictAutoGate>(
  (ref) => CedictAutoGate(),
);

/// The CC-CEDICT dictionary of the Chinese transliteration (D-476): the file in
/// the data folder and, while something uses it, the parsed map in memory. The
/// provider is auto-dispose: nobody watching it frees the memory (the file stays).
class ChineseDictionaryNotifier extends Notifier<ChineseDictionaryState> {
  PinyinDictionary? _dict;
  Future<PinyinDictionary?>? _loading;
  CancelToken? _cancel;
  var _disposed = false;

  /// Bumped by [delete]: a run that started before it must not write anything.
  var _generation = 0;

  @override
  ChineseDictionaryState build() {
    ref.onDispose(() {
      _disposed = true;
      _cancel?.cancel();
    });
    unawaited(_probe());
    return const ChineseDictionaryState(ChineseDictionaryStatus.notDownloaded);
  }

  Future<String> get _path => ref.read(cedictPathProvider.future);

  Future<void> _probe() async {
    final size = await cedictInstalledSize(await _path);
    if (_disposed || state.status != ChineseDictionaryStatus.notDownloaded) {
      return;
    }
    if (size > 0) {
      state = ChineseDictionaryState(
        ChineseDictionaryStatus.ready,
        sizeBytes: size,
      );
    }
  }

  /// The file is there (or the map is loaded): no download needed.
  Future<bool> installed() async =>
      _dict != null || await cedictInstalledSize(await _path) > 0;

  /// The loaded dictionary: reads the file, downloading it first when missing
  /// and [download] allows (the lyrics enrichment's network rule). Null when it
  /// fails (state `error`). Concurrent calls share one run. A damaged file is
  /// deleted, so it is downloaded again. [automatic] (the lyrics view, not a
  /// button) stops trying after two failed downloads in a session.
  Future<PinyinDictionary?> ensure({
    required bool download,
    bool automatic = false,
  }) {
    if (_dict != null) return Future.value(_dict);
    final gate = ref.read(cedictAutoGateProvider);
    final allow =
        download && (!automatic || gate.failures < CedictAutoGate.maxAutomatic);
    final current = _loading;
    if (current != null) return current;
    late final Future<PinyinDictionary?> run;
    run = _run(allow).whenComplete(() {
      if (identical(_loading, run)) _loading = null;
    });
    return _loading = run;
  }

  Future<PinyinDictionary?> _run(bool download) async {
    final gen = _generation;
    final gate = ref.read(cedictAutoGateProvider);
    final path = await _path;
    var downloading = false;
    try {
      if (await cedictInstalledSize(path) == 0) {
        if (!download) return null;
        downloading = true;
        await _download(path);
        downloading = false;
        gate.failures = 0;
      }
      final PinyinDictionary d;
      try {
        d = await PinyinDictionary.load(path);
      } on Object {
        // Damaged file: out with it, the next run downloads it again.
        if (gen == _generation) await deleteCedict(path);
        rethrow;
      }
      if (_disposed || gen != _generation) return null;
      _dict = d;
      state = ChineseDictionaryState(
        ChineseDictionaryStatus.ready,
        sizeBytes: await cedictInstalledSize(path),
      );
      return d;
    } on Object catch (e, st) {
      if (!(e is DioException && CancelToken.isCancel(e))) {
        AppLog.w('Chinese dictionary not available', e, st);
        if (downloading) gate.failures++;
      }
      if (!_disposed && gen == _generation) {
        state = const ChineseDictionaryState(ChineseDictionaryStatus.error);
      }
      return null;
    }
  }

  Future<void> _download(String path) async {
    state = const ChineseDictionaryState(ChineseDictionaryStatus.downloading);
    final cancel = _cancel = CancelToken();
    await downloadCedict(
      dio: ref.read(cedictDioProvider),
      target: path,
      cancel: cancel,
      onProgress: (got, total) {
        if (_disposed || cancel.isCancelled) return;
        state = ChineseDictionaryState(
          ChineseDictionaryStatus.downloading,
          progress: total > 0 ? got / total : null,
        );
      },
    );
  }

  /// «Elimina»: deletes the file and frees the map; a download or a load that
  /// is running is dropped.
  Future<void> delete() async {
    _generation++;
    _cancel?.cancel();
    _dict = null;
    _loading = null;
    await deleteCedict(await _path);
    if (!_disposed) {
      state = const ChineseDictionaryState(
        ChineseDictionaryStatus.notDownloaded,
      );
    }
  }
}

final chineseDictionaryProvider =
    NotifierProvider.autoDispose<
      ChineseDictionaryNotifier,
      ChineseDictionaryState
    >(ChineseDictionaryNotifier.new);
