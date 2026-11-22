import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/online/credits.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/musicbrainz_client.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';

class _Web implements WebClient {
  _Web(this.answer);
  final Object? answer;
  final asked = <(String, Map<String, String>?)>[];

  @override
  Future<Object?> getJson(String url, {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async {
    asked.add((url, query));
    if (strict && answer == null) throw WebUnavailableException(url, 503);
    return answer;
  }

  @override
  Future<List<int>?> getBytes(String url, {int maxBytes = 0, CancelToken? cancel}) async => null;
}

void main() {
  final fixture =
      jsonDecode(File('test/fixtures/musicbrainz/recording_credits_get_lucky.json').readAsStringSync());
  const mbid = 'abc';

  test('Get Lucky: the credits from one request', () async {
    final w = _Web(fixture);
    final credits = await MusicBrainzClient(w, pause: (_) async {}).recordingCredits(mbid);
    final want = parseMbCredits(Map<String, dynamic>.from(fixture as Map));
    String key(TrackCredit c) => '${c.name}|${c.role}|${c.source}';
    expect(credits.map(key), want.map(key));
    expect(credits, hasLength(14));
    expect(w.asked, hasLength(1));
    expect(w.asked.single.$1, endsWith('/recording/$mbid'));
    expect(w.asked.single.$2?['inc'], 'artist-rels+work-rels+work-level-rels');
  });

  test('two calls in a row are at least 1.1 s apart', () async {
    var t = DateTime(2026);
    final waits = <Duration>[];
    final mb = MusicBrainzClient(_Web(fixture), now: () => t, pause: (d) async {
      waits.add(d);
      t = t.add(d);
    });
    await mb.recordingCredits(mbid);
    await mb.recordingCredits('another-$mbid'); // the same request would come from the cache (D-683)
    expect(waits.fold(Duration.zero, (a, b) => a + b), greaterThanOrEqualTo(MusicBrainzClient.gap));
  });

  test('no answer (503): an error, not an empty list', () async {
    final w = _Web(null);
    await expectLater(MusicBrainzClient(w, pause: (_) async {}).recordingCredits(mbid),
        throwsA(isA<MusicBrainzUnavailable>()));
    expect(w.asked, hasLength(1), reason: 'D-683: no retry, the client rests instead');
  });
}
