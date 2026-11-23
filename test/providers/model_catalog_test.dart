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

  @override
  Future<bool> isModelReady(String lang) async => ready.contains(lang);

  @override
  Future<void> deleteModel(String lang) async => ready.remove(lang);

  @override
  Future<void> downloadModel(String lang) async => ready.add(lang);

  @override
  Future<List<String>> translateLines(List<String> lines, {required String from, required String to}) async => lines;

  @override
  Future<void> close() async {}
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
    final cache = StreamCache(Directory(p.join(dir.path, 'cache')), freeSpace: () async => null);
    await cache.open();
    final karaoke = SeparationService(
      cache: cache,
      separator: _Separator(),
      modelsRoot: () async => dir,
      models: {
        'a.onnx': sha256.convert('model:a.onnx'.codeUnits).toString(),
        'b.onnx': sha256.convert('model:b.onnx'.codeUnits).toString(),
      },
      download: (url, dest, _, _) async => File(dest).writeAsStringSync('model:${url.split('/').last}'),
    );
    final c = ProviderContainer(
      overrides: [
        lyricsTranslatorProvider.overrideWithValue(android ? translator : null),
        separationServiceProvider.overrideWithValue(android ? karaoke : null),
        cedictPathProvider.overrideWith((_) => cedict.path),
        cedictDioProvider.overrideWithValue(Dio()),
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
    expect(list.where((e) => e.kind == ModelKind.translation), hasLength(20));
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

  test('an installed dictionary counts with its size on disk and can be deleted', () async {
    cedict.writeAsBytesSync(List.filled(1234, 1));
    final c = await container(android: false);
    var list = await c.read(modelCatalogProvider.future);
    expect(installedModelsBytes(list), 1234);
    await c.read(modelCatalogProvider.notifier).delete(list.single);
    list = c.read(modelCatalogProvider).value!;
    expect(installedModelsBytes(list), 0);
    expect(cedict.existsSync(), isFalse);
  });
}
