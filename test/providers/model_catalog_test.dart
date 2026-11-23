import 'dart:async';
import 'dart:io';

import 'package:codecore/core/platform.dart';
import 'package:codecore/providers/chinese_dictionary_providers.dart';
import 'package:codecore/providers/karaoke_providers.dart';
import 'package:codecore/providers/model_catalog_providers.dart';
import 'package:codecore/providers/translation_providers.dart';
import 'package:codecore/services/karaoke/separation_service.dart';
import 'package:codecore/services/online/lyrics_translator.dart';
import 'package:codecore/services/stream/stream_cache.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _Translator implements LyricsTranslator {
  final ready = <String>{};
  Object? downloadError;
  Completer<void>? hold;
  bool failDelete = false;

  /// Still declares a language ready after its delete (the platform lags).
  final sticky = <String>{};

  @override
  Future<bool> isModelReady(String lang) async =>
      ready.contains(lang) || sticky.contains(lang);

  @override
  Future<void> deleteModel(String lang) async {
    if (failDelete) throw StateError('not deleted');
    ready.remove(lang);
  }

  @override
  Future<void> downloadModel(String lang) async {
    await hold?.future;
    if (downloadError != null) throw downloadError!;
    ready.add(lang);
  }

  @override
  Future<List<String>> translateLines(
    List<String> lines, {
    required String from,
    required String to,
  }) async => lines;

  @override
  Future<void> close() async {}
}

class _Offline implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? body,
    Future<void>? cancel,
  ) async => throw DioException(requestOptions: options, message: 'offline');

  @override
  void close({bool force = false}) {}
}

class _Separator implements Separator {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  late Directory dir;
  late File cedict;
  late _Translator translator;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('catalog');
    cedict = File(p.join(dir.path, 'cedict.gz'));
    translator = _Translator();
  });
  tearDown(() {
    debugIsAndroidOverride = null;
    dir.deleteSync(recursive: true);
  });

  Future<ProviderContainer> container({required bool android}) async {
    debugIsAndroidOverride = android;
    final cache = StreamCache(
      Directory(p.join(dir.path, 'cache')),
      freeSpace: () async => null,
    );
    await cache.open();
    final karaoke = SeparationService(
      cache: cache,
      separator: _Separator(),
      modelsRoot: () async => dir,
      models: {
        'a.onnx': sha256.convert('model:a.onnx'.codeUnits).toString(),
        'b.onnx': sha256.convert('model:b.onnx'.codeUnits).toString(),
      },
      download: (url, dest, _, _) async =>
          File(dest).writeAsStringSync('model:${url.split('/').last}'),
    );
    final c = ProviderContainer(
      overrides: [
        lyricsTranslatorProvider.overrideWithValue(android ? translator : null),
        separationServiceProvider.overrideWithValue(android ? karaoke : null),
        cedictPathProvider.overrideWith((_) => cedict.path),
        cedictDioProvider.overrideWithValue(
          Dio()..httpClientAdapter = _Offline(),
        ),
      ],
    );
    addTearDown(() {
      c.dispose();
      karaoke.dispose();
    });
    c.listen(modelCatalogProvider, (_, _) {});
    c.listen(chineseDictionaryProvider, (_, _) {});
    return c;
  }

  test('Android lists 20 languages, the dictionary and karaoke; elsewhere only the dictionary', () async {
    var c = await container(android: true);
    var list = await c.read(modelCatalogProvider.future);
    expect(
      list.where((e) => e.kind == ModelKind.translation),
      hasLength(translationLanguages.length),
    );
    expect(list.where((e) => e.kind == ModelKind.dictionary), hasLength(1));
    expect(list.where((e) => e.kind == ModelKind.karaoke), hasLength(1));

    c = await container(android: false);
    list = await c.read(modelCatalogProvider.future);
    expect(list.map((e) => e.kind), [ModelKind.dictionary]);
  });

  test('download and delete update the entries and the total', () async {
    final c = await container(android: true);
    final n = c.read(modelCatalogProvider.notifier);
    var list = await c.read(modelCatalogProvider.future);
    expect(installedModelsBytes(list), 0);

    await n.download(list.firstWhere((e) => e.id == 'it'));
    await n.download(list.firstWhere((e) => e.kind == ModelKind.karaoke));
    list = c.read(modelCatalogProvider).value!;
    expect(list.firstWhere((e) => e.id == 'it').installed, isTrue);
    final karaoke = list.firstWhere((e) => e.kind == ModelKind.karaoke);
    expect(karaoke.installed, isTrue);
    expect(karaoke.diskBytes, 'model:a.onnx'.length + 'model:b.onnx'.length);
    final total = installedModelsBytes(list);
    expect(total, kTranslationModelBytes + karaoke.diskBytes!);

    await n.delete(list.firstWhere((e) => e.id == 'it'));
    list = c.read(modelCatalogProvider).value!;
    expect(list.firstWhere((e) => e.id == 'it').installed, isFalse);
    expect(installedModelsBytes(list), total - kTranslationModelBytes);

    await n.delete(karaoke);
    list = c.read(modelCatalogProvider).value!;
    expect(installedModelsBytes(list), 0);
  });

  test(
    'an installed dictionary counts with its size on disk and can be deleted',
    () async {
      cedict.writeAsBytesSync(List.filled(1234, 1));
      final c = await container(android: false);
      var list = await c.read(modelCatalogProvider.future);
      expect(installedModelsBytes(list), 1234);
      await c.read(modelCatalogProvider.notifier).delete(list.single);
      list = c.read(modelCatalogProvider).value!;
      expect(installedModelsBytes(list), 0);
      expect(cedict.existsSync(), isFalse);
    },
  );

  test('a failed download leaves the entry not installed, rethrows, and the list is re-read', () async {
    final c = await container(android: true);
    final n = c.read(modelCatalogProvider.notifier);
    final list = await c.read(modelCatalogProvider.future);
    translator.downloadError = StateError('offline');
    await expectLater(
      n.download(list.firstWhere((e) => e.id == 'it')),
      throwsStateError,
    );
    expect(
      c
          .read(modelCatalogProvider)
          .value!
          .firstWhere((e) => e.id == 'it')
          .installed,
      isFalse,
    );
    translator.downloadError = null;
    translator.ready.add(
      'fr',
    ); // appeared meanwhile: the refresh after the failure sees it
    translator.downloadError = StateError('offline');
    await expectLater(
      n.download(list.firstWhere((e) => e.id == 'it')),
      throwsStateError,
    );
    expect(
      c
          .read(modelCatalogProvider)
          .value!
          .firstWhere((e) => e.id == 'fr')
          .installed,
      isTrue,
    );
  });

  test(
    'a translation deleted stays deleted even if the platform still says ready',
    () async {
      final c = await container(android: true);
      final n = c.read(modelCatalogProvider.notifier);
      translator.ready.add('it');
      translator.sticky.add('it');
      c.invalidate(translationModelsProvider);
      var list = await c.read(modelCatalogProvider.future);
      expect(list.firstWhere((e) => e.id == 'it').installed, isTrue);
      await n.delete(list.firstWhere((e) => e.id == 'it'));
      list = c.read(modelCatalogProvider).value!;
      expect(list.firstWhere((e) => e.id == 'it').installed, isFalse);
    },
  );

  test('karaoke with only one of the two files is not installed but counts its bytes', () async {
    final c = await container(android: true);
    final models = Directory(
      p.join(dir.path, 'models', 'spleeter-2stems-7001ba31'),
    )..createSync(recursive: true);
    File(p.join(models.path, 'a.onnx')).writeAsStringSync('model:a.onnx');
    c.invalidate(modelCatalogProvider);
    final k = (await c.read(modelCatalogProvider.future))
        .firstWhere((e) => e.kind == ModelKind.karaoke);
    expect(k.installed, isFalse);
    expect(k.diskBytes, greaterThan(0));
  });

  test(
    'a model fetched elsewhere (the lyrics view) shows up in the open catalog',
    () async {
      final c = await container(android: true);
      await c.read(modelCatalogProvider.future);
      await translator.downloadModel('de');
      c.invalidate(translationModelsProvider);
      await c.read(modelCatalogProvider.future);
      expect(
        c
            .read(modelCatalogProvider)
            .value!
            .firstWhere((e) => e.id == 'de')
            .installed,
        isTrue,
      );
    },
  );

  test(
    'karaoke models fetched or deleted elsewhere show up in the open catalog',
    () async {
      final c = await container(android: true);
      ModelEntry k() => c
          .read(modelCatalogProvider)
          .value!
          .firstWhere((e) => e.kind == ModelKind.karaoke);
      expect(
        (await c.read(modelCatalogProvider.future))
            .firstWhere((e) => e.kind == ModelKind.karaoke)
            .installed,
        isFalse,
      );
      final svc = c.read(separationServiceProvider)!;
      await svc.downloadModels();
      await c.read(modelCatalogProvider.future);
      expect(k().installed, isTrue);
      await svc.deleteModels();
      await c.read(modelCatalogProvider.future);
      expect(k().installed, isFalse);
    },
  );

  test('a translation delete that fails reaches the caller', () async {
    final c = await container(android: true);
    final n = c.read(modelCatalogProvider.notifier);
    translator.ready.add('it');
    c.invalidate(translationModelsProvider);
    final list = await c.read(modelCatalogProvider.future);
    translator.failDelete = true;
    await expectLater(
      n.delete(list.firstWhere((e) => e.id == 'it')),
      throwsStateError,
    );
    expect(
      c
          .read(modelCatalogProvider)
          .value!
          .firstWhere((e) => e.id == 'it')
          .installed,
      isTrue,
    );
  });

  test('a dictionary download that fails reaches the catalog (error state, not installed)', () async {
    final c = await container(android: false);
    final list = await c.read(modelCatalogProvider.future);
    await expectLater(
      c.read(modelCatalogProvider.notifier).download(list.single),
      throwsA(anything),
    );
    expect(
      c.read(chineseDictionaryProvider).status,
      ChineseDictionaryStatus.error,
    );
    expect(c.read(modelCatalogProvider).value!.single.installed, isFalse);
  });

  test('the page closed during a download: it ends without error and the list is still right', () async {
    debugIsAndroidOverride = true;
    translator.hold = Completer<void>();
    final c = ProviderContainer(
      overrides: [
        lyricsTranslatorProvider.overrideWithValue(translator),
        separationServiceProvider.overrideWithValue(null),
        cedictPathProvider.overrideWith((_) => cedict.path),
        cedictDioProvider.overrideWithValue(Dio()),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(modelCatalogProvider, (_, _) {});
    final list = await c.read(modelCatalogProvider.future);
    final done = c
        .read(modelCatalogProvider.notifier)
        .download(list.firstWhere((e) => e.id == 'it'));
    sub.close(); // nobody watches any more
    await Future<void>.delayed(Duration.zero);
    translator.hold!.complete();
    await done;
    expect(
      c
          .read(modelCatalogProvider)
          .value!
          .firstWhere((e) => e.id == 'it')
          .installed,
      isTrue,
    );
  });
}
