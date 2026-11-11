import 'package:codecore/services/online/credits.dart';
import 'dart:convert';

import 'package:codecore/services/backup/user_data.dart';
import 'package:flutter_test/flutter_test.dart';

UserData sample() => const UserData(
      createdAt: 5,
      tracks: [
        TrackUserData(
          ref: TrackRef(
              folder: '/music',
              relPath: 'a/b.mp3',
              title: 'B',
              artist: 'A',
              durationMs: 1000,
              sha256: 'ff'),
          favorite: true,
          edit: TrackEditData(title: 'B2', artist: 'A2', year: 1999),
          lyricsPlain: 'la la',
          playCount: 3,
          lastPlayedAt: 9,
        ),
      ],
      playlists: [
        PlaylistData(name: 'Mix', createdAt: 1, items: [
          TrackRef(title: 'B', artist: 'A', durationMs: 1000),
          TrackRef(title: 'C'),
        ]),
      ],
      imports: [
        ImportData(
          playlistName: 'Mix',
          sourceName: 'mix.csv',
          createdAt: 2,
          status: 2,
          rows: [
            ImportRowData(
                rowIndex: 0, title: 'B', artists: 'A;Z', status: 2, isrc: 'X')
          ],
        ),
      ],
    );

void main() {
  test('JSON round trip keeps everything', () {
    final back = UserData.fromJson(
        jsonDecode(jsonEncode(sample().toJson())) as Map<String, dynamic>);
    expect(jsonEncode(back.toJson()), jsonEncode(sample().toJson()));
    final t = back.tracks.single;
    expect(t.favorite, isTrue);
    expect(t.edit!.year, 1999);
    expect(t.ref.relPath, 'a/b.mp3');
    expect(back.playlists.single.items.map((i) => i.title), ['B', 'C']);
    expect(back.imports.single.rows.single.artists, 'A;Z');
  });

  test('an unknown future format is refused', () {
    final j = sample().toJson()..['format'] = 2;
    expect(() => UserData.fromJson(j), throwsFormatException);
  });

  test('missing format is refused', () {
    expect(() => UserData.fromJson({'tracks': []}), throwsFormatException);
  });

  test('unknown extra fields are ignored', () {
    final j = jsonDecode(jsonEncode(sample().toJson())) as Map<String, dynamic>
      ..['future'] = {'x': 1};
    (j['tracks'] as List).first['whatever'] = 7;
    expect(UserData.fromJson(j).tracks, hasLength(1));
  });

  test('optional fields are omitted from the JSON', () {
    const t = TrackUserData(ref: TrackRef(title: 'x'));
    expect(t.toJson().keys, ['ref']);
  });

  test('credits and details travel; a track without them writes neither key', () {
    final t = TrackUserData(
      ref: const TrackRef(title: 'B'),
      credits: [TrackCredit('Ann', 'composer', 'deezer')],
      details: const TrackDetails(label: 'L', bpm: 120),
    );
    final back = TrackUserData.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
    expect(back.credits.single.toJson(), {'name': 'Ann', 'role': 'composer', 'source': 'deezer'});
    expect((back.details!.label, back.details!.bpm), ('L', 120));
    final old = const TrackUserData(ref: TrackRef(title: 'B')).toJson();
    expect(old.containsKey('credits') || old.containsKey('details'), isFalse);
    final read = TrackUserData.fromJson(old);
    expect(read.credits, isEmpty);
    expect(read.details, isNull);
  });

  test('wrong-typed details in a backup do not break the reading', () {
    final t = TrackUserData.fromJson({
      'ref': {'title': 'B'},
      'details': {'label': 5, 'bpm': '120', 'explicit': 1},
    });
    expect((t.details!.label, t.details!.bpm, t.details!.explicit), (null, null, null));
  });

  test('hand-set cover fields round trip; an old track without them reads as automatic', () {
    const t = TrackUserData(ref: TrackRef(title: 'a'), coverSource: 2, coverKey: 'manual_x');
    final back = TrackUserData.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
    expect((back.coverSource, back.coverKey), (2, 'manual_x'));
    for (final v in <Object>[99, '1', -1, 1.5]) {
      expect(TrackUserData.fromJson({'ref': {'title': 'a'}, 'coverSource': v}).coverSource, 0, reason: '$v');
    }
    final old = TrackUserData.fromJson({'ref': {'title': 'a'}, 'coverSource': 'x', 'coverKey': 5});
    expect((old.coverSource, old.coverKey), (0, null));
    expect(const TrackUserData(ref: TrackRef(title: 'a'), favorite: true).toJson().containsKey('coverSource'), isFalse);
  });

  test('an automatic cover key travels too (source 0), and an old file without it reads as no key', () {
    const t = TrackUserData(ref: TrackRef(title: 'a'), coverKey: 'auto_k');
    final back = TrackUserData.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
    expect((back.coverSource, back.coverKey), (0, 'auto_k'));
    expect(TrackUserData.fromJson({'ref': {'title': 'a'}}).coverKey, isNull);
  });
}
