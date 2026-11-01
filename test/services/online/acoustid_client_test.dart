import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/online/acoustid_client.dart';
import 'package:codecore/services/online/http_client.dart' show RateLimiter, RateLimitedException;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real answers (2026-11-01), trimmed to the fields the parser reads.
String fixture(String name) => File('test/fixtures/acoustid/$name.json').readAsStringSync();

class _Adapter implements HttpClientAdapter {
  _Adapter(this.code, this.body);

  final int code;
  final String body;
  final sent = <RequestOptions>[];
  final bodies = <List<int>>[];
  final at = <DateTime>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream,
      Future<void>? cancelFuture) async {
    sent.add(options);
    at.add(DateTime.now());
    bodies.add([await for (final c in requestStream!) ...c]);
    return ResponseBody.fromString(body, code, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

(AcoustIdClient, _Adapter) _client(int code, String body, {bool paced = false}) {
  final a = _Adapter(code, body);
  final dio = Dio(BaseOptions(validateStatus: (_) => true))..httpClientAdapter = a;
  return (paced ? AcoustIdClient(dio) : AcoustIdClient(dio, RateLimiter(minGap: Duration.zero)), a);
}

void main() {
  test('parses the whole recordings list, in order, with artists, seconds and first year', () async {
    final (c, _) = _client(200, fixture('happier'));
    final hits = await c.lookup('fp', 214);
    expect(hits, hasLength(1));
    expect(hits[0].score, closeTo(0.96, 0.01));
    // The untitled recording is skipped; the right one (Marshmello) is second.
    expect(hits[0].recordings.map((r) => r.title), ['Happier', 'Happier', 'Happier', 'Happier']);
    final right = hits[0].recordings[1];
    expect(right.artists, ['Marshmello', 'Bastille']);
    expect(right.durationS, 214);
    expect(right.year, 2018);
    expect(hits[0].recordings[2].year, isNull);
  });

  test('empty answer gives no hits, a low score is kept as it is', () async {
    expect(await _client(200, fixture('empty')).$1.lookup('fp', 1), isEmpty);
    final hits = await _client(200, fixture('low_score')).$1.lookup('fp', 1);
    expect(hits.map((h) => h.score < 0.7), [false, true]);
  });

  test('wrong types are skipped, not thrown', () {
    final hits = parseAcoustId({
      'results': [
        {'id': 'a', 'score': 'x'},
        {
          'id': 'b',
          'score': 1,
          'recordings': [
            {'id': 'r', 'title': 5},
            {'id': 'r2', 'title': 't', 'artists': [1, {'name': 'A'}], 'releases': 3, 'duration': 'long'},
            {'id': 'r3', 'title': 't', 'duration': double.nan},
          ],
        },
        'junk',
      ],
    });
    expect(hits.single.recordings.first.artists, ['A']);
    expect(hits.single.recordings.first.year, isNull);
    expect(hits.single.recordings.map((r) => r.durationS), [null, null]);
  });

  test('sends a gzip form body with the key, duration and fingerprint, never audio', () async {
    final (c, a) = _client(200, fixture('empty'));
    await c.lookup('AQAA-fp_x', 183);
    final o = a.sent.single;
    expect(o.uri.toString(), 'https://api.acoustid.org/v2/lookup');
    expect(o.method, 'POST');
    expect(o.headers['Content-Encoding'], 'gzip');
    final form = Uri.splitQueryString(utf8.decode(gzip.decode(a.bodies.single)));
    expect(form, {
      'client': 'Hsn5w6Tjwv',
      'duration': '183',
      'fingerprint': 'AQAA-fp_x',
      'meta': 'recordings releases compress',
    });
  });

  test('10 lookups in a row never put more than 3 requests in one second', () async {
    final (c, a) = _client(200, fixture('empty'), paced: true);
    await Future.wait([for (var i = 0; i < 10; i++) c.lookup('fp', 1)]);
    final t = a.at;
    expect(t, hasLength(10));
    // Real clock: 4 requests would need 3 gaps under 1 s, i.e. a gap under 333 ms.
    for (var i = 3; i < t.length; i++) {
      expect(t[i].difference(t[i - 3]), greaterThanOrEqualTo(const Duration(seconds: 1)));
    }
  }, timeout: const Timeout(Duration(seconds: 20)));

  for (final code in [429, 503]) {
    test('HTTP $code rests the source: later lookups do not start', () async {
      final (c, a) = _client(code, '{}');
      await expectLater(c.lookup('fp', 1), throwsA(isA<RateLimitedException>()));
      expect(c.isResting, isTrue);
      await expectLater(c.lookup('fp', 1), throwsA(isA<RateLimitedException>()));
      expect(a.sent, hasLength(1));
    });
  }

  test('queued lookups do not start after a 429', () async {
    final (c, a) = _client(429, '{}', paced: true);
    final r = await Future.wait([
      for (var i = 0; i < 3; i++) c.lookup('fp', 1).then<Object?>((_) => null, onError: (e) => e),
    ]);
    expect(r, everyElement(isA<RateLimitedException>()));
    expect(a.sent, hasLength(1));
  });
}
