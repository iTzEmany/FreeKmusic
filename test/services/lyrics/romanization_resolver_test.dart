import 'dart:io';

import 'package:codecore/services/lyrics/pinyin_dictionary.dart';
import 'package:codecore/services/lyrics/romanization_cache.dart';
import 'package:codecore/services/lyrics/romanization_resolver.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _key = 'T\u0000A';
const _jaSynced = '[00:01.00]こんにちは\n[00:05.00]さようなら';
const _jaRoman = '[00:01.00]konnichiwa\n[00:05.00]sayounara';

void main() {
  late Directory dir;
  late RomanizationCache cache;
  var fetched = 0;
  var now = DateTime(2026, 11, 8);
  Future<String?> Function() online = () async => null;
  var installed = false;
  PinyinDictionary? dict;
  var downloads = 0;

  RomanizationResolver resolver() => RomanizationResolver(
    cache: cache,
    fetch: (_, CancelToken? _) async {
      fetched++;
      return online();
    },
    dictionaryInstalled: () async => installed,
    dictionary: ({required download}) async {
      if (download && !installed) downloads++;
      return dict;
    },
  );

  RomanizationInput input({
    String? plain,
    String? synced,
    String? manual,
    bool handWritten = false,
    bool enabled = true,
    bool net = true,
    String artist = 'A',
    int? durationSec = 200,
  }) => RomanizationInput(
    trackId: 1,
    title: 'T',
    artist: artist,
    durationSec: durationSec,
    plain: plain,
    synced: synced,
    manual: manual,
    handWritten: handWritten,
    enabled: enabled,
    online: net,
  );

  Future<List<RomanizationState>> run(RomanizationInput i) =>
      resolver().resolve(i).toList();

  setUp(() {
    dir = Directory.systemTemp.createTempSync('romres');
    cache = RomanizationCache(
      file: () async => File(p.join(dir.path, 'c.json')),
      now: () => now,
    );
    now = DateTime(2026, 11, 8);
    fetched = 0;
    downloads = 0;
    online = () async => null;
    installed = false;
    dict = null;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('off when the setting is off or the text has no CJK', () async {
    expect(
      (await run(input(plain: 'こんにちは', enabled: false))).single.status,
      RomanizationStatus.off,
    );
    expect(
      (await run(input(plain: 'hello world'))).single.status,
      RomanizationStatus.off,
    );
  });

  test('Korean is computed with no network and no lookup', () async {
    final r = (await run(input(plain: '안녕하세요\nhello', net: false))).last;
    expect(r.status, RomanizationStatus.ready);
    expect(r.source, RomanizationSource.computed);
    expect(r.lines, ['annyeonghaseyo', null]);
    expect(fetched, 0);
  });

  test('Japanese from the cache, no lookup', () async {
    await cache.put(1, _jaRoman, key: _key);
    final r = (await run(input(synced: _jaSynced))).last;
    expect(r.status, RomanizationStatus.ready);
    expect(r.source, RomanizationSource.found);
    expect(r.lines, ['konnichiwa', 'sayounara']);
    expect(fetched, 0);
  });

  test(
    'a found romalrc is saved in the cache; plain text matches by index',
    () async {
      online = () async => _jaRoman;
      final r = (await run(input(plain: 'こんにちは\nさようなら'))).last;
      expect(r.lines, ['konnichiwa', 'sayounara']);
      expect((await cache.get(1, key: _key))!.lrc, _jaRoman);
    },
  );

  test('«none» is saved too, and believed while fresh', () async {
    expect(
      (await run(input(synced: _jaSynced))).last.status,
      RomanizationStatus.unavailable,
    );
    expect((await cache.get(1, key: _key))!.lrc, isNull);
    expect(fetched, 1);
    await run(input(synced: _jaSynced));
    expect(fetched, 1, reason: 'the fresh «none» is not asked again');
  });

  test('without the network rule nothing is searched or saved', () async {
    online = () async => _jaRoman;
    expect(
      (await run(input(synced: _jaSynced, net: false))).last.status,
      RomanizationStatus.unavailable,
    );
    expect(fetched, 0);
    expect(await cache.get(1, key: _key), isNull);
  });

  test('synced lines are matched by time, not by their index', () async {
    // The transliteration has an extra line at 3 s: by index it would shift.
    await cache.put(
      1,
      '[00:01.00]a\n[00:03.00]interlude\n[00:05.00]b\n[00:09.00]c',
      key: _key,
    );
    final r = (await run(
      input(synced: '[00:01.00]あ\n[00:05.00]い\n[00:09.00]う'),
    )).last;
    expect(r.lines, ['a', 'b', 'c']);
  });

  test('Japanese never goes to the Chinese dictionary', () async {
    installed = true;
    dict = PinyinDictionary({'銀行': 'yínháng', '银行': 'yínháng'});
    final r = (await run(input(plain: '銀行です', net: false))).last;
    expect(r.status, RomanizationStatus.unavailable);
    expect(downloads, 0);
  });

  test('a failing service is not saved and counts as unavailable', () async {
    online = () async => throw StateError('down');
    expect(
      (await run(input(synced: _jaSynced))).last.status,
      RomanizationStatus.unavailable,
    );
    expect(await cache.get(1, key: _key), isNull);
  });

  test('under half of the lines matched is unavailable', () async {
    online = () async => '[00:01.00]konnichiwa\n[00:50.00]x';
    const four =
        '[00:01.00]こんにちは\n[00:05.00]さようなら\n[00:09.00]ありがとう\n[00:13.00]おはよう';
    expect(
      (await run(input(synced: four))).last.status,
      RomanizationStatus.unavailable,
    );
  });

  test('the manual transliteration wins over a found one', () async {
    await cache.put(1, _jaRoman, key: _key);
    final r = (await run(input(synced: _jaSynced, manual: 'mine 1\nmine 2')))
        .last;
    expect(r.source, RomanizationSource.manual);
    expect(r.lines, ['mine 1', 'mine 2']);
  });

  test('a manual one that does not fit gives way to the others', () async {
    await cache.put(1, _jaRoman, key: _key);
    final r = (await run(input(synced: _jaSynced, manual: 'only one'))).last;
    expect(r.source, RomanizationSource.found);
  });

  test('a hand-written text: nothing is searched, cache or lookup, but Korean and the manual one count', () async {
    online = () async => _jaRoman;
    await cache.put(1, _jaRoman, key: _key);
    expect(
      (await run(input(synced: _jaSynced, handWritten: true))).last.status,
      RomanizationStatus.unavailable,
    );
    expect(fetched, 0);
    final ko = (await run(input(plain: '좋아', handWritten: true))).last;
    expect(ko.lines, ['joa']);
    final withManual = (await run(
      input(plain: 'こんにちは', handWritten: true, manual: 'konnichiwa'),
    )).last;
    expect(withManual.source, RomanizationSource.manual);
  });

  test('no artist or no length: no request and nothing saved', () async {
    online = () async => _jaRoman;
    expect(
      (await run(input(synced: _jaSynced, artist: ' '))).last.status,
      RomanizationStatus.unavailable,
    );
    expect(
      (await run(input(synced: _jaSynced, durationSec: null))).last.status,
      RomanizationStatus.unavailable,
    );
    expect(fetched, 0);
    expect(await cache.get(1, key: _key), isNull);
  });

  test('a saved text that does not fit is asked again only when old', () async {
    online = () async => _jaRoman;
    await cache.put(
      1,
      '[00:50.00]other\n[01:00.00]more\n[01:10.00]third',
      key: _key,
    );
    expect(
      (await run(input(synced: _jaSynced))).last.status,
      RomanizationStatus.unavailable,
    );
    expect(fetched, 0, reason: 'still fresh');
    now = now.add(kRomanizationRetryAfter + const Duration(days: 1));
    final r = (await run(input(synced: _jaSynced))).last;
    expect(fetched, 1);
    expect(r.lines, ['konnichiwa', 'sayounara']);
  });

  test(
    'a cache entry made for another title or artist is not believed',
    () async {
      online = () async => _jaRoman;
      await cache.put(1, null, key: 'Other\u0000A');
      final r = (await run(input(synced: _jaSynced))).last;
      expect(fetched, 1);
      expect(r.status, RomanizationStatus.ready);
    },
  );

  group('Chinese without a romalrc', () {
    final d = PinyinDictionary({'银行': 'yínháng'});

    test('installed dictionary: pinyin, no download', () async {
      installed = true;
      dict = d;
      final r = (await run(input(plain: '银行', net: false))).last;
      expect(r.source, RomanizationSource.dictionary);
      expect(r.lines, ['yínháng']);
    });

    test('missing and the network allowed: downloading, then pinyin', () async {
      dict = d;
      final states = await run(input(plain: '银行'));
      expect(states.map((s) => s.status), [
        RomanizationStatus.loading,
        RomanizationStatus.downloading,
        RomanizationStatus.ready,
      ]);
      expect(downloads, 1);
    });

    test(
      'a hand-written text uses the installed dictionary, no lookup',
      () async {
        installed = true;
        dict = d;
        online = () async => 'x';
        final r = (await run(input(plain: '银行', handWritten: true))).last;
        expect(r.source, RomanizationSource.dictionary);
        expect(r.lines, ['yínháng']);
        expect(fetched, 0);
      },
    );

    test(
      'a hand-written text may download the dictionary, same rule',
      () async {
        dict = d;
        final states = await run(input(plain: '银行', handWritten: true));
        expect(states.map((s) => s.status), [
          RomanizationStatus.loading,
          RomanizationStatus.downloading,
          RomanizationStatus.ready,
        ]);
        expect(downloads, 1);
        await run(input(plain: '银行', handWritten: true, net: false));
        expect(downloads, 1, reason: 'no network, no download');
      },
    );

    test('only characters the dictionary does not know: unavailable', () async {
      installed = true;
      dict = d;
      final r = (await run(input(plain: '龘龘', net: false))).last;
      expect(r.status, RomanizationStatus.unavailable);
    });

    test(
      'missing and no network, or the download fails: unavailable',
      () async {
        expect(
          (await run(input(plain: '银行', net: false))).last.status,
          RomanizationStatus.unavailable,
        );
        expect(downloads, 0);
        expect(
          (await run(input(plain: '银行'))).last.status,
          RomanizationStatus.unavailable,
        );
      },
    );
  });
}
