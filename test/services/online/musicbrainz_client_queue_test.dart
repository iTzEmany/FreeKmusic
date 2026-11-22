import 'package:codecore/core/clock.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/musicbrainz_client.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';

class _Web implements WebClient {
  final asked = <String>[];
  var inFlight = 0, maxInFlight = 0;
  bool down = false;
  Object? answer = {'artists': []};

  @override
  Future<Object?> getJson(String url, {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async {
    asked.add(url);
    maxInFlight = ++inFlight > maxInFlight ? inFlight : maxInFlight;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    inFlight--;
    if (down) throw WebUnavailableException(url, 503);
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
}
