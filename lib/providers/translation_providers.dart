import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../core/platform.dart';
import '../services/online/lyrics_translator.dart';
import '../services/online/lyrics_translator_mlkit.dart';

/// The on-device translator, or null where there is none (everything but
/// Android): the UI hides every translation entry then.
final lyricsTranslatorProvider = Provider<LyricsTranslator?>((ref) {
  if (!isAndroid) return null;
  final t = MlKitLyricsTranslator();
  ref.onDispose(t.close);
  return t;
});

/// Translated lyrics of one track, line by line (same order as the original).
class LyricsTranslation {
  const LyricsTranslation({
    required this.trackId,
    required this.synced,
    required this.lines,
  });

  final int trackId;

  /// True when [lines] line up with the timed (LRC) lines.
  final bool synced;
  final List<String> lines;
}

class LyricsTranslationNotifier extends Notifier<LyricsTranslation?> {
  @override
  LyricsTranslation? build() => null;

  /// Translates [lines] and shows the result for [trackId]. Returns false on
  /// failure (logged), leaving any previous translation in place.
  Future<bool> translate({
    required int trackId,
    required bool synced,
    required List<String> lines,
    required String from,
    required String to,
  }) async {
    final translator = ref.read(lyricsTranslatorProvider);
    if (translator == null) return false;
    try {
      final out = await translateKeepingLayout(
        translator,
        lines,
        from: from,
        to: to,
      );
      state = LyricsTranslation(trackId: trackId, synced: synced, lines: out);
      // A translation can have fetched a model: the settings list re-reads.
      ref.invalidate(translationModelsProvider);
      return true;
    } on Object catch (e, st) {
      AppLog.e('lyrics translation failed', e, st);
      return false;
    }
  }

  void clear() => state = null;

  /// Drops the translation when it belongs to [trackId] (its text just changed).
  void clearFor(int trackId) {
    if (state?.trackId == trackId) state = null;
  }
}

final lyricsTranslationProvider =
    NotifierProvider<LyricsTranslationNotifier, LyricsTranslation?>(
      LyricsTranslationNotifier.new,
    );

/// The languages whose model is on the phone, for Settings → translation
/// models. Re-read each time the page opens.
class TranslationModelsNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() => _ready();

  Future<List<String>> _ready() async {
    final translator = ref.read(lyricsTranslatorProvider);
    if (translator == null) return const [];
    final found = <String>[];
    try {
      for (final lang in translationLanguages.keys) {
        if (await translator.isModelReady(lang)) found.add(lang);
      }
    } on Object catch (e, st) {
      AppLog.e('translation models listing failed', e, st);
    }
    return found;
  }

  /// Deletes [lang]'s model and refreshes the list. The platform can still
  /// report a just-deleted model as present for a moment, so a delete that
  /// succeeded is trusted over that answer.
  Future<void> delete(String lang) async {
    try {
      await ref.read(lyricsTranslatorProvider)?.deleteModel(lang);
    } on Object catch (e, st) {
      AppLog.e('translation model delete failed', e, st);
      state = AsyncData(await _ready());
      return;
    }
    state = AsyncData([
      for (final l in state.value ?? const <String>[])
        if (l != lang) l,
    ]);
    state = AsyncData([
      for (final l in await _ready())
        if (l != lang) l,
    ]);
  }
}

final translationModelsProvider =
    AsyncNotifierProvider.autoDispose<TranslationModelsNotifier, List<String>>(
      TranslationModelsNotifier.new,
    );
