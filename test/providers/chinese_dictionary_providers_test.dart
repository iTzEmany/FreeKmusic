import 'dart:convert';
import 'dart:io';

import 'package:codecore/providers/chinese_dictionary_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _Down implements HttpClientAdapter {
  var calls = 0;

  /// When true the request hangs until it is cancelled.
  var hang = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? body,
    Future<void>? cancel,
  ) async {
    calls++;
    if (hang) {
      await cancel;
      throw DioException.requestCancelled(
        requestOptions: options,
        reason: 'cancelled',
      );
    }
    throw DioException(requestOptions: options, message: 'offline');
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory dir;
  late File file;
  late ProviderContainer c;
  late _Down down;
  var clock = DateTime(2026, 11, 9, 12);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cedict');
    file = File(p.join(dir.path, 'sub', 'cedict.gz'));
    down = _Down();
    clock = DateTime(2026, 11, 9, 12);
    c = ProviderContainer(
      overrides: [
        cedictPathProvider.overrideWith((_) => file.path),
        cedictAutoGateProvider.overrideWithValue(
          CedictAutoGate(now: () => clock),
        ),
        cedictDioProvider.overrideWithValue(Dio()..httpClientAdapter = down),
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

  test('«Elimina» during a download: no error state, nothing loaded', () async {
    down.hang = true;
    final n = c.read(chineseDictionaryProvider.notifier);
    final run = n.ensure(download: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      c.read(chineseDictionaryProvider).status,
      ChineseDictionaryStatus.downloading,
    );
    await n.delete();
    expect(await run, isNull);
    expect(
      c.read(chineseDictionaryProvider).status,
      ChineseDictionaryStatus.notDownloaded,
    );
    expect(await n.installed(), isFalse);
  });

  test('«Elimina» during a load: the map is not kept', () async {
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(
      gzip.encode(utf8.encode('銀行 银行 [yin2 hang2] /bank/\n')),
    );
    final n = c.read(chineseDictionaryProvider.notifier);
    final run = n.ensure(download: false);
    await n.delete();
    expect(await run, isNull);
    expect(await n.installed(), isFalse);
    expect(
      c.read(chineseDictionaryProvider).status,
      ChineseDictionaryStatus.notDownloaded,
    );
  });

  test('a damaged file is deleted and gives the error state', () async {
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(utf8.encode('this is not gzip'));
    final n = c.read(chineseDictionaryProvider.notifier);
    expect(await n.ensure(download: false), isNull);
    expect(file.existsSync(), isFalse);
    expect(
      c.read(chineseDictionaryProvider).status,
      ChineseDictionaryStatus.error,
    );
  });

  test('after a failed automatic download the next one waits, doubling; the button always tries', () async {
    final n = c.read(chineseDictionaryProvider.notifier);
    Future<void> auto() => n.ensure(download: true, automatic: true);
    await auto();
    await auto();
    expect(down.calls, 1, reason: 'no new try right after a failure');
    clock = clock.add(CedictAutoGate.firstPause + const Duration(seconds: 1));
    await auto();
    expect(down.calls, 2);
    clock = clock.add(CedictAutoGate.firstPause);
    await auto();
    expect(down.calls, 2, reason: 'the second pause is twice as long');
    clock = clock.add(CedictAutoGate.firstPause);
    await auto();
    expect(down.calls, 3);
    await n.ensure(download: true);
    expect(down.calls, 4, reason: 'the button ignores the pause');
  });

  test('the pause is capped at an hour and a success clears it', () {
    var t = DateTime(2026, 11, 9);
    final gate = CedictAutoGate(now: () => t);
    expect(gate.allowed, isTrue);
    for (var i = 0; i < 10; i++) {
      gate.failed();
    }
    t = t.add(CedictAutoGate.maxPause - const Duration(seconds: 1));
    expect(gate.allowed, isFalse);
    t = t.add(const Duration(seconds: 2));
    expect(gate.allowed, isTrue);
    gate.failed();
    expect(gate.allowed, isFalse);
    gate.succeeded();
    expect((gate.allowed, gate.failures), (true, 0));
  });

  test(
    'a valid but empty file is a broken one: deleted, error state',
    () async {
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(gzip.encode(utf8.encode('# only a comment\n')));
      final n = c.read(chineseDictionaryProvider.notifier);
      expect(await n.ensure(download: false), isNull);
      expect(file.existsSync(), isFalse);
      expect(
        c.read(chineseDictionaryProvider).status,
        ChineseDictionaryStatus.error,
      );
    },
  );

  test(
    'a run that may not download, then one that may: the download follows',
    () async {
      final n = c.read(chineseDictionaryProvider.notifier);
      final first = n.ensure(download: false);
      final second = n.ensure(download: true);
      expect(await first, isNull);
      expect(await second, isNull);
      expect(down.calls, 1, reason: 'the second call asked for the download');
    },
  );

  test('...unless «Elimina» came in between', () async {
    final n = c.read(chineseDictionaryProvider.notifier);
    final first = n.ensure(download: false);
    final second = n.ensure(download: true);
    await n.delete();
    expect(await first, isNull);
    expect(await second, isNull);
    expect(down.calls, 0);
  });

  test('a download goes on when nobody watches any more, and the provider goes after it', () async {
    down.hang = true;
    final other = ProviderContainer(
      overrides: [
        cedictPathProvider.overrideWith((_) => file.path),
        cedictDioProvider.overrideWithValue(Dio()..httpClientAdapter = down),
      ],
    );
    addTearDown(other.dispose);
    final sub = other.listen(chineseDictionaryProvider, (_, _) {});
    final n = other.read(chineseDictionaryProvider.notifier);
    final run = n.ensure(download: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    sub.close(); // the Settings page is left
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(other.exists(chineseDictionaryProvider), isTrue);
    expect(
      other.read(chineseDictionaryProvider).status,
      ChineseDictionaryStatus.downloading,
    );
    await n.delete(); // cancels the hanging request
    await run;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(other.exists(chineseDictionaryProvider), isFalse);
  });
}
