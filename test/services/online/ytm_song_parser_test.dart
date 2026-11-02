import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/online/innertube_client.dart';
import 'package:codecore/services/online/ytm_song_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Map _json(String name) =>
    jsonDecode(File('test/fixtures/innertube/$name.json').readAsStringSync()) as Map;

void main() {
  test('Topic upload (ATV): artist, album, length, official', () {
    final s = parseYtmSong(_json('ytm_next_song_atv'));
    expect([s.title, s.album, s.durationMs], ['Mother', 'The Wall', 335000]);
    expect(s.artists, ['Pink Floyd']);
    expect(s.videoType, 'MUSIC_VIDEO_TYPE_ATV');
    expect(s.official, isTrue);
  });

  test('official clip (OMV): official, no album', () {
    final s = parseYtmSong(_json('ytm_next_song_omv'));
    expect(s.artists, ['Queen']);
    expect([s.album, s.durationMs], [null, 360000]);
    expect(s.official, isTrue);
  });

  test('anyone\'s upload (UGC): not official, the channel is no artist', () {
    final s = parseYtmSong(_json('ytm_next_song_ugc'));
    expect(s.videoType, 'MUSIC_VIDEO_TYPE_UGC');
    expect(s.artists, isEmpty);
    expect(s.durationMs, 236000);
    expect(s.official, isFalse);
  });

  test('clockMs reads m:ss and h:mm:ss, nothing else', () {
    expect(clockMs('3:45'), 225000);
    expect(clockMs('1:02:03'), 3723000);
    expect(clockMs('abc'), isNull);
    expect(clockMs('1:75'), isNull);
    expect(clockMs('-1:20'), isNull);
    expect(clockMs(''), isNull);
    expect(clockMs('3:5'), isNull);
    expect(clockMs('3:005'), isNull);
    expect(clockMs('3: 45'), isNull);
    expect(clockMs('+3:45'), isNull);
    expect(clockMs('1:02:3'), isNull);
    expect(clockMs('1:2:03:04'), isNull);
    expect(clockMs('3:+45'), isNull);
    expect(clockMs(' 3:45'), 225000);
    expect(clockMs('3:45\u00A0'), 225000);
    expect(clockMs('99999999999999999999:00'), isNull);
    expect(clockMs('1234:00'), isNull);
  });

  test('ytmMatches: length within the slack and the title check', () {
    const s = Duration(seconds: 1);
    bool m(Duration? d, {int slack = 10000, bool ok = true}) =>
        ytmMatches(d, 200000, slackMs: slack, titleOk: ok);
    expect(m(const Duration(seconds: 209)), isTrue);
    expect(m(const Duration(seconds: 211)), isFalse);
    expect(m(const Duration(seconds: 203), slack: 3000), isTrue);
    expect(m(const Duration(seconds: 204), slack: 3000), isFalse);
    expect(m(null), isFalse);
    expect(m(s * 200, ok: false), isFalse);
  });

  test('an answer without the song is InnerTubeChanged', () {
    expect(() => parseYtmSong(_json('ytm_empty')), throwsA(isA<InnerTubeChanged>()));
  });
}
