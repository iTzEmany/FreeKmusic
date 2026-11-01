import 'dart:convert';

import 'package:codecore/services/recognition/track_identity.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  const full = Recognition(
    at: 1767225600000,
    src: RecogSource.acoustid,
    score: 0.97,
    sure: true,
    identity: TrackIdentity(
        title: 'Believer', artist: 'Imagine Dragons', ms: 204000, isrc: 'USUM71700626', mbid: 'm', vid: 'xxxxxxxxxxx'),
    prop: 'auto',
    was: {'title': 'Believer (Romy Wave Cover)', 'artist': '7clouds Rock'},
    original: {'title': 'Believer', 'artist': 'Imagine Dragons'},
  );

  test('JSON goes there and back, through text', () {
    final back = Recognition.fromJson(jsonDecode(jsonEncode(full.toJson())))!;
    expect(back.toJson(), full.toJson());
    expect(back.src, RecogSource.acoustid);
    expect(back.identity!.ms, 204000);
    expect(back.was!['artist'], '7clouds Rock');
  });

  test('«nothing found» keeps only version, time and a null source', () {
    final json = const Recognition(at: 5).toJson();
    expect(json, {'v': kRecogVersion, 'at': 5, 'src': null});
    final back = Recognition.fromJson(json)!;
    expect(back.src, isNull);
    expect(back.identity, isNull);
  });

  test('wrong types become absent fields and never throw', () {
    final rec = Recognition.fromJson({
      'v': 'one', 'at': null, 'src': 'napster', 'score': 'high', 'sure': 'yes',
      'title': 7, 'artist': ['x'], 'ms': '204000', 'isrc': {}, 'prop': 'maybe',
      'was': [1, 2], 'original': {'title': 3, 'artist': 'A'},
    })!;
    expect(rec.v, 0);
    expect(rec.at, 0);
    expect(rec.src, isNull);
    expect(rec.score, isNull);
    expect(rec.sure, isFalse);
    expect(rec.identity, isNull);
    expect(rec.prop, isNull);
    expect(rec.was, isNull);
    expect(rec.original, {'artist': 'A'});
  });

  test('something that is not a map is no recognition', () {
    for (final x in [null, 'rec', 3, <Object?>[], true]) {
      expect(Recognition.fromJson(x), isNull);
    }
  });

  test('applyTo puts the identity on a copy of the track', () {
    final t = track('Believer (Romy Wave Cover)', '7clouds Rock', isrc: 'OLD');
    final q = full.identity!.applyTo(t);
    expect([q.title, q.artist, q.durationMs, q.isrc], ['Believer', 'Imagine Dragons', 204000, 'USUM71700626']);
    final bare = const TrackIdentity(title: 'T', artist: '').applyTo(t);
    expect([bare.artist, bare.durationMs, bare.isrc], ['7clouds Rock', 200000, 'OLD']);
    expect(t.title, 'Believer (Romy Wave Cover)');
  });
}
