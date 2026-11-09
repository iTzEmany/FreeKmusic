import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/lyrics_ovh_client.dart';
import 'package:codecore/services/online/netease_lyrics_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Object _fx(String name) =>
    jsonDecode(File('test/fixtures/lyrics/$name.json').readAsStringSync())
        as Object;

/// Answers by URL suffix; a value that is a Function is called (to throw or hang).
class _Web implements WebClient {
  _Web(this.byPath);
  final Map<String, Object? Function()> byPath;
  final asked = <(String, Map<String, String>?, bool)>[];

  @override
  Future<Object?> getJson(
    String url, {
    Map<String, String>? query,
    CancelToken? cancel,
    bool strict = false,
  }) async {
    asked.add((url, query, strict));
    final key = byPath.keys.firstWhere(url.endsWith);
    final r = byPath[key]!();
    return r is Future ? await r : r;
  }

  @override
  Future<List<int>?> getBytes(
    String url, {
    int maxBytes = 0,
    CancelToken? cancel,
  }) async => null;
}

Future<Object?> Function() _never = () => Completer<Object?>().future;

class _Adapter implements HttpClientAdapter {
  _Adapter(this.code, {this.body, this.type});
  final int code;
  final String? body, type;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<List<int>>? r,
    Future<void>? c,
  ) async => ResponseBody.fromString(
    body ?? (code == 200 ? '{"a":1}' : 'x'),
    code,
    headers: {
      Headers.contentTypeHeader: [
        type ?? (code == 200 ? 'application/json' : 'text/plain'),
      ],
    },
  );

  @override
  void close({bool force = false}) {}
}

DioWebClient _dio(int code, {String? body, String? type}) => DioWebClient(
  Dio(BaseOptions(validateStatus: (_) => true))
    ..httpClientAdapter = _Adapter(code, body: body, type: type),
);

void main() {
  Map<String, Object? Function()> ne() => {
    'search/get': () => _fx('netease_search_get_lucky'),
    'song/lyric': () => _fx('netease_lyric_get_lucky'),
  };

  group('NetEase', () {
    test('asks rv=-1 and gives romalrc only when present', () async {
      Map<String, Object?> lyric(Object? rom) => {
        'code': 200,
        'lrc': {'lyric': '[00:01.00]a'},
        'romalrc': rom,
      };
      for (final (rom, want) in [
        ({'lyric': '[00:01.00]ei'}, '[00:01.00]ei'),
        ({'lyric': ''}, null),
        (null, null),
      ]) {
        final w = _Web({...ne(), 'song/lyric': () => lyric(rom)});
        final c = NeteaseLyricsClient(w);
        expect(
          await c.romanized(
              title: 'Get Lucky', artist: 'Daft Punk', durationSec: 370),
          want,
        );
        expect(w.asked.last.$2?['rv'], '-1');
        final r = await c.find(
            title: 'Get Lucky', artist: 'Daft Punk', durationSec: 370);
        expect(r!.synced, '[00:01.00]a');
      }
    });

    test(
      'Get Lucky: the right song, its synced lyric, strict requests',
      () async {
        final w = _Web(ne());
        final r = await NeteaseLyricsClient(w)
            .find(title: 'Get Lucky', artist: 'Daft Punk', durationSec: 370);
        expect(r!.synced, startsWith('[00:00.000]'));
        expect(r.plain, isNull);
        expect(w.asked.map((a) => a.$3), everyElement(isTrue));
        expect(w.asked.last.$2?['id'], '26349642');
      },
    );

    test('another title, another artist or a length off by more than 3 s: no match', () async {
      final c = NeteaseLyricsClient(_Web(ne()));
      expect(
        await c.find(
          title: 'Lose Yourself to Dance',
          artist: 'Daft Punk',
          durationSec: 370,
        ),
        isNull,
      );
      expect(
        await c.find(
          title: 'Get Lucky',
          artist: 'Someone Else',
          durationSec: 370,
        ),
        isNull,
      );
      expect(
        await c.find(title: 'Get Lucky', artist: 'Daft Punk', durationSec: 365),
        isNull,
      );
      expect(
        await c.find(
          title: 'Get Lucky',
          artist: 'Daft Punk',
          durationSec: null,
        ),
        isNull,
      );
    });

    test('a 200 body with another code is WebUnavailableException, in search and in lyric', () async {
      for (final bad in ['search/get', 'song/lyric']) {
        final w = _Web({
          ...ne(),
          bad: () => {'code': -460},
        });
        await expectLater(
          NeteaseLyricsClient(w)
              .find(title: 'Get Lucky', artist: 'Daft Punk', durationSec: 370),
          throwsA(isA<WebUnavailableException>()),
        );
      }
    });

    test('a live/remix variant of the title is refused, a radio edit is not; any shared artist counts', () async {
      final songs =
          (_fx('netease_search_get_lucky') as Map)['result']['songs'] as List;
      Map song(int id, String name, int ms) => {
        'id': id,
        'name': name,
        'duration': ms,
        'artists': [
          {'name': 'Daft Punk'},
        ],
      };
      Future<Object?> find(
        List extra, {
        String title = 'Get Lucky',
        String artist = 'Daft Punk',
      }) => NeteaseLyricsClient(
        _Web({
          ...ne(),
          'search/get': () => {
            'code': 200,
            'result': {'songs': extra},
          },
        }),
      ).find(title: title, artist: artist, durationSec: 370);
      expect(await find([song(1, 'Get Lucky (Live)', 370000)]), isNull);
      expect(await find([song(1, 'Get Lucky (Live Video)', 370000)]), isNull);
      expect(
        await find([
          song(1, 'Get Lucky (Radio Edit)', 370000),
        ], title: 'Get Lucky (Radio Edit)'),
        isNotNull,
      );
      expect(
        await find(
          songs,
          title: 'Get Lucky',
          artist: 'Daft Punk feat. Pharrell Williams',
        ),
        isNotNull,
      );
      expect(
        await find(
          songs,
          title: 'Get Lucky',
          artist: 'Pharrell Williams & Someone',
        ),
        isNotNull,
      );
    });

    test('length gap: 3.3 s refused, exactly 3 s accepted', () async {
      Future<Object?> at(int ms) => NeteaseLyricsClient(
        _Web({
          ...ne(),
          'search/get': () => {
            'code': 200,
            'result': {
              'songs': [
                {
                  'id': 1,
                  'name': 'Get Lucky',
                  'duration': ms,
                  'artists': [
                    {'name': 'Daft Punk'},
                  ],
                },
              ],
            },
          },
        }),
      ).find(title: 'Get Lucky', artist: 'Daft Punk', durationSec: 370);
      expect(await at(373316), isNull);
      expect(await at(373000), isNotNull);
    });

    test('valid but empty lyric: null', () async {
      final w = _Web({
        ...ne(),
        'song/lyric': () => {
          'lrc': {'lyric': ''},
        },
      });
      expect(
        await NeteaseLyricsClient(w)
            .find(title: 'Get Lucky', artist: 'Daft Punk', durationSec: 370),
        isNull,
      );
    });

    testWidgets('no answer within 8 s is an error', (tester) async {
      Object? error;
      NeteaseLyricsClient(_Web({...ne(), 'search/get': _never}))
          .find(title: 'Get Lucky', artist: 'Daft Punk', durationSec: 370)
          .catchError((Object e) {
            error = e;
            return null;
          });
      await tester.pump(const Duration(seconds: 7));
      expect(error, isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(error, isA<TimeoutException>());
    });
  });

  group('lyrics.ovh', () {
    test('Get Lucky: plain text, URL encoded, strict', () async {
      final w = _Web({'Get%20Lucky': () => _fx('lyricsovh_get_lucky')});
      final r = await LyricsOvhClient(w)
          .find(title: 'Get Lucky', artist: 'Daft Punk');
      expect(r!.plain, startsWith('Like the legend of the phoenix'));
      expect(
        w.asked.single.$1,
        'https://api.lyrics.ovh/v1/Daft%20Punk/Get%20Lucky',
      );
      expect(w.asked.single.$3, isTrue);
    });

    test('surrounding spaces are trimmed', () async {
      final r = await LyricsOvhClient(
        _Web({
          'Lucky': () => {'lyrics': '  la la\n '},
        }),
      ).find(title: 'Lucky', artist: 'A');
      expect(r!.plain, 'la la');
    });

    test('empty lyrics: null; a 429 reaches the caller', () async {
      expect(
        await LyricsOvhClient(
          _Web({
            'Lucky': () => {'lyrics': ' '},
          }),
        ).find(title: 'Lucky', artist: 'A'),
        isNull,
      );
      final limited = _Web({
        'Lucky': () => throw const RateLimitedException(429),
      });
      await expectLater(
        LyricsOvhClient(limited).find(title: 'Lucky', artist: 'A'),
        throwsA(isA<RateLimitedException>()),
      );
    });
  });

  group('getJson strict', () {
    test('a 200 that is not JSON is WebUnavailableException; not strict stays null', () async {
      for (final c in [
        _dio(200, body: '<html>portal</html>', type: 'text/html'),
        _dio(200, body: '', type: 'text/html'),
      ]) {
        await expectLater(
          c.getJson('https://x/a', strict: true),
          throwsA(isA<WebUnavailableException>()),
        );
        expect(await c.getJson('https://x/a'), isNull);
      }
    });

    test('an already cancelled token stays a cancellation', () async {
      final tok = CancelToken()..cancel();
      await expectLater(
        _dio(200).getJson('https://x/a', strict: true, cancel: tok),
        throwsA(
          isA<DioException>().having(
            (e) => CancelToken.isCancel(e),
            'isCancel',
            true,
          ),
        ),
      );
    });

    test('404 is null, 503 is WebUnavailableException', () async {
      expect(await _dio(404).getJson('https://x/a', strict: true), isNull);
      await expectLater(
        _dio(503).getJson('https://x/a', strict: true),
        throwsA(isA<WebUnavailableException>()),
      );
      expect(await _dio(503).getJson('https://x/a'), isNull);
    });
  });
}
