import 'package:codecore/core/clock.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/musicbrainz_client.dart';
import 'package:dio/dio.dart' show CancelToken, DioException;
import 'package:flutter_test/flutter_test.dart';

class _Web implements WebClient {
  final asked = <String>[];
  var inFlight = 0, maxInFlight = 0;
  bool down = false;
  Object? answer = {'artists': []};
  Object? fail; // thrown instead of an answer
  final failOn = <String, Object>{}; // thrown for a url holding the key

  @override
  Future<Object?> getJson(String url, {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async {
    asked.add(url);
    maxInFlight = ++inFlight > maxInFlight ? inFlight : maxInFlight;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    inFlight--;
    if (down) throw WebUnavailableException(url, 503);
    if (fail != null) throw fail!;
    for (final e in failOn.entries) {
      if (url.contains(e.key)) throw e.value;
    }
    return answer;
  }

  @override
  Future<List<int>?> getBytes(String url, {int maxBytes = 0, CancelToken? cancel}) async => null;
}

void main() {
  late _Web web;
  late MusicBrainzClient mb;
  var t = DateTime(2026);

  setUp(() {
    web = _Web();
    t = DateTime(2026);
    mb = MusicBrainzClient(web, now: () => t, pause: (_) async {});
  });

  void minutes(int m) => t = t.add(Duration(minutes: m));

  test('two calls at once run one after the other', () async {
    await Future.wait([mb.artistWikidata('a1'), mb.artistWikidata('a2')]);
    expect(web.asked, hasLength(2));
    expect(web.maxInFlight, 1);
  });

  test('rests 1, 5, 15, 15 minutes after each 503 in a row', () async {
    web.down = true;
    final seen = <Duration>[];
    for (var i = 0; i < 4; i++) {
      await expectLater(mb.artistWikidata('a$i'), throwsA(isA<MusicBrainzUnavailable>()));
      seen.add(mb.restUntil!.difference(t));
      t = mb.restUntil!;
    }
    expect(seen, [1, 5, 15, 15].map((m) => Duration(minutes: m)));
  });

  test('while resting nothing goes to the network', () async {
    web.down = true;
    await expectLater(mb.artistWikidata('a1'), throwsA(isA<MusicBrainzUnavailable>()));
    expect(mb.resting, isTrue);
    web.down = false;
    t = t.add(const Duration(seconds: 59));
    await expectLater(mb.artistWikidata('a2'), throwsA(isA<MusicBrainzUnavailable>()));
    expect(web.asked, hasLength(1));
    t = t.add(const Duration(seconds: 2));
    expect(mb.resting, isFalse);
    await mb.artistWikidata('a2');
    expect(web.asked, hasLength(2));
  });

  test('a success resets the ladder', () async {
    web.down = true;
    await expectLater(mb.artistWikidata('a1'), throwsA(isA<MusicBrainzUnavailable>()));
    minutes(2);
    await expectLater(mb.artistWikidata('a2'), throwsA(isA<MusicBrainzUnavailable>()));
    expect(mb.restUntil!.difference(t), const Duration(minutes: 5));
    minutes(6);
    web.down = false;
    await mb.artistWikidata('a3');
    web.down = true;
    await expectLater(mb.artistWikidata('a4'), throwsA(isA<MusicBrainzUnavailable>()));
    expect(mb.restUntil!.difference(t), const Duration(minutes: 1));
  });

  test('identical requests make one call; «not found» is remembered too', () async {
    web.answer = null; // 404
    await Future.wait([mb.artistWikidata('a1'), mb.artistWikidata('a1')]);
    expect(await mb.artistWikidata('a1'), isNull);
    expect(web.asked, hasLength(1));
    minutes(7 * 60); // past the expiry
    await mb.artistWikidata('a1');
    expect(web.asked, hasLength(2));
  });

  test('an error is not cached', () async {
    web.down = true;
    await expectLater(mb.artistWikidata('a1'), throwsA(isA<MusicBrainzUnavailable>()));
    web.down = false;
    minutes(2);
    await mb.artistWikidata('a1');
    expect(web.asked, hasLength(2));
  });

  test('the default clock follows nowMsOverride', () async {
    nowMsOverride = () => 1000;
    addTearDown(() => nowMsOverride = null);
    final c = MusicBrainzClient(web..down = true, pause: (_) async {});
    await expectLater(c.artistWikidata('a1'), throwsA(isA<MusicBrainzUnavailable>()));
    expect(c.restUntil, DateTime.fromMillisecondsSinceEpoch(1000 + 60000));
    expect(c.resting, isTrue);
  });

  test('a 400 is «not found» (cached), no rest', () async {
    web.fail = const WebUnavailableException('u', 400);
    expect(await mb.artistWikidata('a1'), isNull);
    expect(mb.resting, isFalse);
    web.fail = null;
    await mb.artistWikidata('a1');
    expect(web.asked, hasLength(1));
  });

  test('a 429 or 403 rests like a 503', () async {
    web.fail = const RateLimitedException(429);
    await expectLater(mb.artistWikidata('a1'), throwsA(isA<MusicBrainzUnavailable>()));
    expect(mb.restUntil!.difference(t), const Duration(minutes: 1));
  });

  test('a 500 or a timeout reaches the caller with no rest and no cache', () async {
    web.fail = const WebUnavailableException('u', 500);
    await expectLater(mb.artistWikidata('a1'), throwsA(isA<WebUnavailableException>()));
    expect(mb.resting, isFalse);
    web.fail = null;
    await mb.artistWikidata('a1');
    expect(web.asked, hasLength(2));
  });

  test('calls are served in call order', () async {
    await Future.wait([for (final a in ['a1', 'a2', 'a3']) mb.artistWikidata(a)]);
    expect(web.asked.map((u) => u.split('/').last), ['a1', 'a2', 'a3']);
  });

  test('an error in the middle of the queue does not block the next calls', () async {
    web.failOn['a2'] = const WebUnavailableException('u', 500);
    final r = await Future.wait([
      for (final a in ['a1', 'a2', 'a3']) mb.artistWikidata(a).then<Object?>((v) => v, onError: (Object e) => e),
    ]);
    expect(r[1], isA<WebUnavailableException>());
    expect(web.asked, hasLength(3));
  });

  test('fresh asks again what the cache would have served', () async {
    await mb.artistWikidata('a1');
    await MusicBrainzClient.fresh(() => mb.artistWikidata('a1'));
    expect(web.asked, hasLength(2));
  });

  test('between two requests the pause is at least 1.1 s', () async {
    final pauses = <Duration>[];
    final c = MusicBrainzClient(web, now: () => t, pause: (d) async => pauses.add(d));
    await c.artistWikidata('a1');
    await c.artistWikidata('a2');
    expect(pauses.single, greaterThanOrEqualTo(const Duration(milliseconds: 1100)));
  });

  test('the cache holds up to 6 hours, not a moment more', () async {
    await mb.artistWikidata('a1');
    t = t.add(MusicBrainzClient.cacheTtl - const Duration(milliseconds: 1));
    await mb.artistWikidata('a1');
    expect(web.asked, hasLength(1));
    t = t.add(const Duration(milliseconds: 1));
    await mb.artistWikidata('a1');
    expect(web.asked, hasLength(2));
  });

  test('beyond the cap the oldest answer goes', () async {
    for (var i = 0; i <= MusicBrainzClient.cacheMax; i++) {
      await mb.artistWikidata('a$i');
    }
    final n = web.asked.length;
    await mb.artistWikidata('a${MusicBrainzClient.cacheMax}');
    expect(web.asked, hasLength(n), reason: 'the newest is kept');
    await mb.artistWikidata('a0');
    expect(web.asked, hasLength(n + 1), reason: 'the oldest is gone');
  });

  test('a request cancelled while queued never reaches the network', () async {
    final token = CancelToken();
    final first = mb.artistWikidata('a1');
    final second = mb.artistWikidata('a2', cancel: token);
    token.cancel();
    await first;
    await expectLater(second, throwsA(predicate((e) => e is DioException && CancelToken.isCancel(e))));
    expect(web.asked, hasLength(1));
  });
}
