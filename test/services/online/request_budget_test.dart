import 'package:codecore/core/app_info.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/request_budget.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// A clock that only moves when something waits.
class _Clock {
  var t = DateTime(2026, 1, 1);
  final waits = <Duration>[];
  DateTime now() => t;
  Future<void> pause(Duration d) async {
    waits.add(d);
    t = t.add(d);
  }
}

class _Ok implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? r, Future<void>? c) async {
    calls++;
    return ResponseBody.fromString('{"ok":true}', 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('the documented tiers', () {
    test('with a contact the app is identified, sends it in the User-Agent '
        'and uses the identified Wikimedia limit', () {
      expect(apiIdentified, isTrue);
      expect(
        apiUserAgent,
        'Codecore/$kAppVersion (https://github.com/iTzEmany/codecore-music-player)',
      );
      expect(wikimediaLimiter().perMinute, kWikimediaIdentifiedPerMinute);
      expect(kWikimediaAnonymousPerMinute, lessThan(10));
      expect(kWikimediaIdentifiedPerMinute, lessThan(200));
    });

    test('the Wikimedia hosts share one limit; others are not counted', () {
      for (final h in ['it.wikipedia.org', 'en.wikipedia.org', 'www.wikidata.org', 'api.wikimedia.org', 'upload.wikimedia.org']) {
        expect(isWikimediaHost(h), isTrue, reason: h);
      }
      for (final h in ['musicbrainz.org', 'itunes.apple.com', 'lrclib.net', 'notwikipedia.org', 'wikipedia.org.evil.example']) {
        expect(isWikimediaHost(h), isFalse, reason: h);
      }
    });
  });

  group('WindowLimiter', () {
    test('tryAcquire says no instead of waiting once the minute is full, and yes again after it', () {
      final c = _Clock();
      final l = WindowLimiter(perMinute: 2, now: c.now, pause: c.pause);
      expect([l.tryAcquire(), l.tryAcquire(), l.tryAcquire()], [true, true, false]);
      expect(c.waits, isEmpty);
      c.t = c.t.add(const Duration(seconds: 61));
      expect(l.tryAcquire(), isTrue);
    });

    test('tryAcquire(2) takes both slots or none', () {
      final c = _Clock();
      final l = WindowLimiter(perMinute: 3, now: c.now, pause: c.pause);
      expect([l.tryAcquire(2), l.tryAcquire(2), l.recent], [true, false, 2]);
      expect(l.tryAcquire(), isTrue);
    });

    test('lets perMinute requests straight through, then waits for the oldest to leave the minute', () async {
      final c = _Clock();
      final l = WindowLimiter(perMinute: 3, now: c.now, pause: c.pause);
      for (var i = 0; i < 3; i++) {
        await l.acquire();
      }
      expect(c.waits, isEmpty);
      await l.acquire();
      expect(c.waits, [const Duration(seconds: 60)]);
      expect(c.t, DateTime(2026, 1, 1, 0, 1));
    });

    test('never more than perMinute in any 60 seconds, however many ask', () async {
      final c = _Clock();
      const n = 8;
      final l = WindowLimiter(perMinute: n, now: c.now, pause: c.pause);
      for (var i = 0; i < 100; i++) {
        await l.acquire();
      }
      final stamps = l.granted;
      for (var i = 0; i < stamps.length; i++) {
        final inWindow = stamps.where((s) => !s.isBefore(stamps[i]) && s.difference(stamps[i]) < const Duration(seconds: 60));
        expect(inWindow.length, lessThanOrEqualTo(n), reason: 'from request $i');
      }
      // 100 requests at 8 a minute: 12 full minutes after the first batch.
      expect(c.t.difference(DateTime(2026, 1, 1)), const Duration(minutes: 12));
    });

    test('callers at the same time share the budget: still never more than perMinute a minute', () async {
      final c = _Clock();
      final l = WindowLimiter(perMinute: 2, now: c.now, pause: c.pause);
      await Future.wait([for (var i = 0; i < 5; i++) l.acquire()]);
      final at = l.granted;
      expect(at, hasLength(5));
      for (final s in at) {
        expect(at.where((x) => !x.isBefore(s) && x.difference(s) < const Duration(seconds: 60)).length, lessThanOrEqualTo(2));
      }
      expect(c.t.difference(DateTime(2026, 1, 1)), const Duration(minutes: 2), reason: '5 requests at 2 a minute: 3 batches');
    });

    test('time passing frees slots without any wait', () async {
      final c = _Clock();
      final l = WindowLimiter(perMinute: 2, now: c.now, pause: c.pause);
      await l.acquire();
      await l.acquire();
      c.t = c.t.add(const Duration(seconds: 61));
      await l.acquire();
      expect(c.waits, isEmpty);
      expect(l.recent, 1);
    });
  });

  group('the web client uses it', () {
    test('every Wikimedia request takes a slot, other services do not', () async {
      final c = _Clock();
      final adapter = _Ok();
      final dio = Dio(BaseOptions(validateStatus: (_) => true))..httpClientAdapter = adapter;
      final web = DioWebClient(dio, (d) async {}, WindowLimiter(perMinute: 2, now: c.now, pause: c.pause));
      await web.getJson('https://musicbrainz.org/ws/2/x');
      await web.getJson('https://itunes.apple.com/search');
      expect(c.waits, isEmpty);
      await web.getJson('https://it.wikipedia.org/w/api.php');
      await web.getJson('https://www.wikidata.org/w/api.php');
      expect(c.waits, isEmpty, reason: 'two slots, both free');
      await web.getJson('https://en.wikipedia.org/w/api.php');
      expect(c.waits, [const Duration(seconds: 60)], reason: 'the third waits: the limit is shared by every Wikimedia site');
      expect(adapter.calls, 5);
    });

    test('a retry after a 429 takes a slot too', () async {
      final c = _Clock();
      final adapter = _Throttled();
      final dio = Dio(BaseOptions(validateStatus: (_) => true))..httpClientAdapter = adapter;
      final web = DioWebClient(dio, (d) async {}, WindowLimiter(perMinute: 1, now: c.now, pause: c.pause));
      expect(await web.getJson('https://it.wikipedia.org/w/api.php'), {'ok': true});
      expect(adapter.calls, 2);
      expect(c.waits, hasLength(1), reason: 'the retry waited for its slot');
    });
  });
}

class _Throttled implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? r, Future<void>? c) async {
    calls++;
    final limited = calls == 1;
    return ResponseBody.fromString(limited ? 'slow down' : '{"ok":true}', limited ? 429 : 200, headers: {
      Headers.contentTypeHeader: [limited ? 'text/plain' : 'application/json'],
      if (limited) 'retry-after': ['1'],
    });
  }

  @override
  void close({bool force = false}) {}
}
