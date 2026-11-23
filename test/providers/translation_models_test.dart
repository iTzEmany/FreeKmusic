import 'package:codecore/providers/translation_providers.dart';
import 'package:codecore/services/online/lyrics_translator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Translator implements LyricsTranslator {
  _Translator(this.ready, {this.stale = false, this.failDelete = false});

  final Set<String> ready;

  /// The platform keeps answering «downloaded» for a moment after a delete.
  final bool stale;
  final bool failDelete;

  @override
  Future<bool> isModelReady(String lang) async => ready.contains(lang);

  @override
  Future<void> deleteModel(String lang) async {
    if (failDelete) throw StateError('not deleted');
    if (!stale) ready.remove(lang);
  }

  @override
  Future<void> downloadModel(String lang) async => ready.add(lang);

  @override
  Future<List<String>> translateLines(List<String> lines, {required String from, required String to}) async => lines;

  @override
  Future<void> close() async {}
}

ProviderContainer _container(_Translator t) {
  final c = ProviderContainer(overrides: [lyricsTranslatorProvider.overrideWithValue(t)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('deleting a model removes it from the list, even if the platform still reports it', () async {
    final c = _container(_Translator({'en', 'it'}, stale: true));
    c.listen(translationModelsProvider, (_, _) {});
    expect(await c.read(translationModelsProvider.future), ['en', 'it']);
    await c.read(translationModelsProvider.notifier).delete('it');
    expect(c.read(translationModelsProvider).value, ['en']);
  });

  test('a delete that fails keeps the model in the list and rethrows', () async {
    final c = _container(_Translator({'en', 'it'}, failDelete: true));
    c.listen(translationModelsProvider, (_, _) {});
    await c.read(translationModelsProvider.future);
    await expectLater(c.read(translationModelsProvider.notifier).delete('it'), throwsStateError);
    expect(c.read(translationModelsProvider).value, ['en', 'it']);
  });

  test('a translation refreshes the models list', () async {
    final t = _Translator({'en'});
    final c = _container(t);
    c.listen(translationModelsProvider, (_, _) {});
    expect(await c.read(translationModelsProvider.future), ['en']);
    t.ready.add('it'); // the platform fetched a model while translating
    final ok = await c
        .read(lyricsTranslationProvider.notifier)
        .translate(trackId: 1, synced: false, lines: ['a'], from: 'en', to: 'it');
    expect(ok, isTrue);
    expect(await c.read(translationModelsProvider.future), ['en', 'it']);
  });
}
