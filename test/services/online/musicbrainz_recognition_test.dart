import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/musicbrainz_client.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';

Object _fixture(String name) =>
    jsonDecode(File('test/fixtures/musicbrainz/$name.json').readAsStringSync()) as Object;

/// Answers from [answers] in turn: a name is a fixture, null a 404, an
/// exception is thrown (strict 503).
class _Web implements WebClient {
  _Web(this.answers);
  final List<Object?> answers;
  final asked = <String>[];

  @override
  Future<Object?> getJson(String url, {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async {
    asked.add('$url ${query?['inc']}');
    final a = answers.removeAt(0);
    if (a is Exception) throw a;
    return a == null ? null : _fixture(a as String);
  }

  @override
  Future<List<int>?> getBytes(String url, {int maxBytes = 0, CancelToken? cancel}) async => null;
}

MusicBrainzClient _mb(_Web w) => MusicBrainzClient(w, pause: (_) async {});

void main() {
  test('recordingById: title, artist, length, ISRCs, first year and the work', () async {
    final w = _Web(['recording_imagine_work']);
    final r = (await _mb(w).recordingById('ec04e3c5-0548-4e73-bfc3-19a26108f302'))!;
    expect(w.asked.single, contains('isrcs+artist-credits+releases+work-rels'));
    expect(r.title, 'Imagine');
    expect(r.artist, 'John Lennon');
    expect(r.length, 184000);
    expect(r.isrcs, contains('GBAYE1000769'));
    expect(r.year, 1971);
    expect(r.works.single.id, '517ff96c-5970-3eac-9ae5-bcafc15f5bc7');
    expect(r.works.single.cover, isFalse);
  });

  test('recordingById: 404 is null', () async {
    final w = _Web([null]);
    expect(await _mb(w).recordingById('x'), isNull);
    expect(w.asked, hasLength(1));
  });

  test('recordingById: 503 once, then the answer', () async {
    final w = _Web([const WebUnavailableException('503'), 'recording_imagine_work']);
    expect((await _mb(w).recordingById('x'))?.title, 'Imagine');
    expect(w.asked, hasLength(2));
  });

  test('recordingById: 503 twice is MusicBrainzUnavailable', () async {
    final w = _Web([const WebUnavailableException('503'), const WebUnavailableException('503')]);
    expect(_mb(w).recordingById('x'), throwsA(isA<MusicBrainzUnavailable>()));
  });

  test('recordingById: the cover attribute of the performance is kept on the work link', () async {
    final r = (await _mb(_Web(['recording_cover_work'])).recordingById('x'))!;
    expect([r.works.single.id, r.works.single.cover], ['w-believer', true]);
  });

  test('workOriginal: the oldest recording that is not a cover, one browse request', () async {
    final w = _Web(['work_imagine_recordings']);
    final o = (await _mb(w).workOriginal('w'))!;
    expect(w.asked.single, contains('artist-credits'));
    expect([o.id, o.artistName], ['ec04e3c5-0548-4e73-bfc3-19a26108f302', 'John Lennon']);
  });

  test('workOriginal: unknown work is null', () async {
    expect(await _mb(_Web([null])).workOriginal('w'), isNull);
  });

  test('recordingsByIsrc without title and artist: nothing is filtered out', () async {
    final w = _Web(['isrc_two_recordings']);
    expect(await _mb(w).recordingsByIsrc('GBAYE1000769', 184000), hasLength(2));
  });
}
