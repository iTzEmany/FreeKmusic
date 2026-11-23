import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../services/karaoke/separation_service.dart'
    show kKaraokeModelMegabytes;
import '../services/lyrics/cedict_download.dart';
import '../services/online/lyrics_translator.dart';
import 'chinese_dictionary_providers.dart';
import 'karaoke_providers.dart';
import 'translation_providers.dart';

enum ModelKind { translation, dictionary, karaoke }

/// Rough sizes where no file tells the truth (D-673): the ML Kit models are not
/// readable from Dart, and nothing is on disk before the download.
const int kMb = 1024 * 1024;
const int kTranslationModelBytes = translationModelMegabytes * kMb;
// Estimate: the CC-CEDICT .txt.gz release asset is about 4 MB.
const int kDictionaryEstimateBytes = 4 * kMb;
// Two Spleeter ONNX files: the size the karaoke sheet already announces.
const int kKaraokeEstimateBytes = kKaraokeModelMegabytes * kMb;

String modelKey(ModelEntry e) => '${e.kind.name}:${e.id}';

class ModelEntry {
  const ModelEntry({
    required this.kind,
    required this.id,
    required this.name,
    required this.estimatedBytes,
    required this.installed,
    this.diskBytes,
  });

  final ModelKind kind;

  /// Language code for translations, otherwise `cedict` / `spleeter`.
  final String id;
  final String name;
  final int estimatedBytes;
  final bool installed;

  /// Real size on disk when known (dictionary, karaoke).
  final int? diskBytes;

  /// What it takes (installed) or would take (not yet).
  int get bytes => diskBytes ?? estimatedBytes;
}

/// Space taken by the installed models.
int installedModelsBytes(Iterable<ModelEntry> entries) =>
    entries.fold(0, (sum, e) => e.installed ? sum + e.bytes : sum);

/// The one list behind Settings → Modelli: translation languages (Android
/// only), the Chinese dictionary and the karaoke model (Android only).
class ModelCatalogNotifier extends AsyncNotifier<List<ModelEntry>> {
  var _ops = 0;
  ProviderSubscription<AsyncValue<List<ModelEntry>>>? _keep;

  /// A download or delete goes on when the page is left. A listener of its own
  /// (not a keepAlive link: the rebuilds of [build] drop those).
  void _hold() {
    _ops++;
    _keep ??= ref.container.listen(modelCatalogProvider, (_, _) {});
  }

  void _release() {
    if (--_ops == 0) {
      _keep?.close();
      _keep = null;
    }
  }

  @override
  Future<List<ModelEntry>> build() {
    // What changes the list from elsewhere (a model fetched by the lyrics view,
    // the dictionary downloaded by a lyrics page): the catalog is rebuilt.
    ref.watch(lyricsTranslatorProvider);
    ref.watch(translationModelsProvider);
    ref.watch(cedictPathProvider);
    final karaoke = ref.watch(separationServiceProvider);
    ref.watch(chineseDictionaryProvider.select((s) => s.status));
    if (karaoke != null) {
      // Models fetched or deleted elsewhere (the karaoke sheet, the expiry); the
      // progress ticks of a running job are skipped.
      void changed() {
        if (!karaoke.busy) ref.invalidateSelf();
      }

      karaoke.addListener(changed);
      ref.onDispose(() => karaoke.removeListener(changed));
    }
    return _load();
  }

  Future<List<ModelEntry>> _load() async {
    final entries = <ModelEntry>[];
    final translator = ref.read(lyricsTranslatorProvider);
    if (translator != null) {
      final ready = await ref.read(translationModelsProvider.future);
      for (final e in translationLanguages.entries) {
        entries.add(
          ModelEntry(
            kind: ModelKind.translation,
            id: e.key,
            name: e.value,
            estimatedBytes: kTranslationModelBytes,
            installed: ready.contains(e.key),
          ),
        );
      }
    }
    final dictSize = await cedictInstalledSize(
      await ref.read(cedictPathProvider.future),
    );
    entries.add(
      ModelEntry(
        kind: ModelKind.dictionary,
        id: 'cedict',
        name: 'CC-CEDICT',
        estimatedBytes: kDictionaryEstimateBytes,
        installed: dictSize > 0,
        diskBytes: dictSize > 0 ? dictSize : null,
      ),
    );
    final karaoke = ref.read(separationServiceProvider);
    if (karaoke != null) {
      final size = await karaoke.modelsSize();
      entries.add(
        ModelEntry(
          kind: ModelKind.karaoke,
          id: 'spleeter',
          name: 'Spleeter',
          estimatedBytes: kKaraokeEstimateBytes,
          installed: !await karaoke.modelsMissing(),
          diskBytes: size > 0 ? size : null,
        ),
      );
    }
    return entries;
  }

  /// Downloads [e]; throws when it fails (logged). The list is re-read either way.
  Future<void> download(ModelEntry e) async {
    _hold();
    try {
      switch (e.kind) {
        case ModelKind.translation:
          await ref.read(lyricsTranslatorProvider)?.downloadModel(e.id);
        case ModelKind.dictionary:
          await ref.read(chineseDictionaryProvider.notifier).downloadOnly();
        case ModelKind.karaoke:
          await ref.read(separationServiceProvider)?.downloadModels();
      }
    } on Object catch (err, st) {
      AppLog.w('model ${e.id} download failed', err, st);
      rethrow;
    } finally {
      if (e.kind == ModelKind.translation) {
        ref.invalidate(translationModelsProvider);
      }
      await _refresh(e);
      _release();
    }
  }

  Future<void> delete(ModelEntry e) async {
    _hold();
    try {
      switch (e.kind) {
        case ModelKind.translation:
          // Not invalidated: its notifier trusts the delete over the platform.
          await ref.read(translationModelsProvider.notifier).delete(e.id);
        case ModelKind.dictionary:
          await ref.read(chineseDictionaryProvider.notifier).delete();
        case ModelKind.karaoke:
          await ref.read(separationServiceProvider)?.deleteModels();
      }
    } on Object catch (err, st) {
      AppLog.w('model ${e.id} delete failed', err, st);
      rethrow;
    } finally {
      await _refresh(e);
      _release();
    }
  }

  Future<void> _refresh(ModelEntry e) async {
    try {
      if (e.kind == ModelKind.translation) {
        // Its provider changing rebuilds this one (see [build]): wait for that
        // rebuild, a second load in parallel would be cut by it.
        await future;
        return;
      }
      final list = await _load();
      if (ref.mounted) state = AsyncData(list);
    } on Object catch (err, st) {
      AppLog.w('model catalog refresh failed', err, st);
    }
  }
}

final modelCatalogProvider =
    AsyncNotifierProvider.autoDispose<ModelCatalogNotifier, List<ModelEntry>>(
      ModelCatalogNotifier.new,
    );

/// The «Scarica selezionati» queue: lives here, not in the page, so it goes on
/// when the page is left and shows again when it is reopened.
class ModelQueueState {
  const ModelQueueState({this.running, this.queued = const {}});

  /// [modelKey] of the download running now.
  final String? running;

  /// [modelKey]s waiting for their turn.
  final Set<String> queued;

  bool get active => running != null || queued.isNotEmpty;
}

class ModelQueueNotifier extends Notifier<ModelQueueState> {
  @override
  ModelQueueState build() => const ModelQueueState();

  /// Downloads [targets] one at a time (large files, one network); does nothing
  /// while a queue is running. A failure goes to [onFailed] and the rest goes on.
  Future<void> downloadAll(
    List<ModelEntry> targets, {
    void Function(ModelEntry)? onFailed,
    void Function(ModelEntry)? onDone,
  }) async {
    if (state.active || targets.isEmpty) return;
    // The catalog is autoDispose: keep it for the whole queue.
    final keep = ref.listen(modelCatalogProvider, (_, _) {});
    state = ModelQueueState(queued: {for (final e in targets) modelKey(e)});
    try {
      final catalog = ref.read(modelCatalogProvider.notifier);
      for (final e in targets) {
        final k = modelKey(e);
        if (!state.queued.contains(k)) continue; // cancelled
        state = ModelQueueState(
          running: k,
          queued: {...state.queued}..remove(k),
        );
        try {
          await catalog.download(e);
          onDone?.call(e);
        } on Object {
          // Already logged by the catalog.
          onFailed?.call(e);
        }
        state = ModelQueueState(queued: state.queued);
      }
    } finally {
      keep.close();
      state = const ModelQueueState();
    }
  }

  /// Drops what has not started. The running one goes on (a language model of
  /// ML Kit cannot be stopped).
  void cancelQueued() => state = ModelQueueState(running: state.running);
}

final modelQueueProvider =
    NotifierProvider<ModelQueueNotifier, ModelQueueState>(
      ModelQueueNotifier.new,
    );
