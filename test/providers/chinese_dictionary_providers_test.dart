import 'dart:convert';
import 'dart:io';

import 'package:codecore/providers/chinese_dictionary_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _Down implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? body,
    Future<void>? cancel,
  ) async => throw DioException(requestOptions: options, message: 'offline');

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory dir;
  late File file;
  late ProviderContainer c;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cedict');
    file = File(p.join(dir.path, 'sub', 'cedict.gz'));
    c = ProviderContainer(
      overrides: [
        cedictPathProvider.overrideWith((_) => file.path),
        cedictDioProvider.overrideWithValue(Dio()..httpClientAdapter = _Down()),
      ],
    );
    c.listen(chineseDictionaryProvider, (_, _) {});
  });
  tearDown(() {
    c.dispose();
    dir.deleteSync(recursive: true);
  });

  test(
    'not on disk and no download allowed: nothing, state untouched',
    () async {
      final n = c.read(chineseDictionaryProvider.notifier);
      expect(await n.installed(), isFalse);
      expect(await n.ensure(download: false), isNull);
      expect(
        c.read(chineseDictionaryProvider).status,
        ChineseDictionaryStatus.notDownloaded,
      );
    },
  );

  test(
    'a failed download is an error state, and the next call tries again',
    () async {
      final n = c.read(chineseDictionaryProvider.notifier);
      expect(await n.ensure(download: true), isNull);
      expect(
        c.read(chineseDictionaryProvider).status,
        ChineseDictionaryStatus.error,
      );
      expect(File('${file.path}.tmp').existsSync(), isFalse);
      expect(await n.ensure(download: true), isNull);
    },
  );

  test(
    'loads the file once, shows its size, and «Elimina» removes file and map',
    () async {
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(
        gzip.encode(utf8.encode('銀行 银行 [yin2 hang2] /bank/\n')),
      );
      final n = c.read(chineseDictionaryProvider.notifier);
      expect(await n.installed(), isTrue);
      final d = await n.ensure(download: false);
      expect(d!.romanize('银行'), 'yínháng');
      expect(identical(await n.ensure(download: false), d), isTrue);
      expect(c.read(chineseDictionaryProvider).sizeBytes, file.lengthSync());

      await n.delete();
      expect(file.existsSync(), isFalse);
      expect(await n.installed(), isFalse);
      expect(
        c.read(chineseDictionaryProvider).status,
        ChineseDictionaryStatus.notDownloaded,
      );
    },
  );
}
