import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
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
// Size of the CC-CEDICT .txt.gz release asset (about 4 MB).
const int kDictionaryEstimateBytes = 4 * kMb;
// Two Spleeter ONNX files: the «78 MB» the karaoke screen already announces.
const int kKaraokeEstimateBytes = 78 * kMb;

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
int installedModelsBytes(Iterable<ModelEntry> entries) => entries.fold(
  0,
  (sum, e) => e.installed ? sum + e.bytes : sum,
);

/// The one list behind Settings → Modelli: translation languages (Android
/// only), the Chinese dictionary and the karaoke model (Android only).
class ModelCatalogNotifier extends AsyncNotifier<List<ModelEntry>> {
  @override
  Future<List<ModelEntry>> build() => _load();

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
    final dict = ref.read(chineseDictionaryProvider.notifier);
    final dictSize = await cedictInstalledSize(
      await ref.read(cedictPathProvider.future),
    );
    entries.add(
      ModelEntry(
        kind: ModelKind.dictionary,
        id: 'cedict',
        name: 'CC-CEDICT',
        estimatedBytes: kDictionaryEstimateBytes,
        installed: dictSize > 0 || await dict.installed(),
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
    try {
      switch (e.kind) {
        case ModelKind.translation:
          await ref.read(lyricsTranslatorProvider)?.downloadModel(e.id);
        case ModelKind.dictionary:
          final d = await ref
              .read(chineseDictionaryProvider.notifier)
              .ensure(download: true);
          if (d == null) throw StateError('dictionary not downloaded');
        case ModelKind.karaoke:
          await ref.read(separationServiceProvider)?.downloadModels();
      }
    } on Object catch (err, st) {
      AppLog.w('model ${e.id} download failed', err, st);
      rethrow;
    } finally {
      await _refresh();
    }
  }

  Future<void> delete(ModelEntry e) async {
    try {
      switch (e.kind) {
        case ModelKind.translation:
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
      await _refresh();
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(translationModelsProvider);
    state = AsyncData(await _load());
  }
}

final modelCatalogProvider =
    AsyncNotifierProvider.autoDispose<ModelCatalogNotifier, List<ModelEntry>>(
      ModelCatalogNotifier.new,
    );
