import 'package:codecore/data/db/app_database.dart' show Track;
import 'package:codecore/services/online/credits.dart';
import 'package:codecore/services/share/track_meta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const full = TrackMeta(
    title: 'T',
    artist: 'A',
    albumArtist: 'AA',
    album: 'Al',
    year: 2001,
    genre: 'Rock',
    trackNumber: 3,
    discNumber: 1,
    isrc: 'USRC17607839',
    lyricsPlain: 'la la',
    lyricsSynced: '[00:01.00]la la',
    enrichStatus: 1,
    youtubeId: 'dQw4w9WgXcQ',
  );

  test('round trip keeps every field', () {
    final back = TrackMeta.tryParse(full.toJson())!;
    expect(back.toJson(), full.toJson());
    expect(back.toJson().length, 13);
  });

  test('a bad field becomes null and the others stay', () {
    final json = full.toJson()
      ..['year'] = 99999
      ..['isrc'] =
          'USRC1760783' // 11 chars
      ..['trackNumber'] = -1
      ..['title'] = 'x' * 5000
      ..['enrichStatus'] = 7
      ..['lyricsSynced'] = 'no timestamps'
      ..['youtubeId'] = 'short';
    final m = TrackMeta.tryParse(json)!;
    expect(m.year, isNull);
    expect(m.isrc, isNull);
    expect(m.trackNumber, isNull);
    expect(m.enrichStatus, isNull);
    expect(m.lyricsSynced, isNull);
    expect(m.youtubeId, isNull);
    expect(m.title!.length, 200);
    expect(m.artist, 'A');
    expect(m.discNumber, 1);
    expect(m.lyricsPlain, 'la la');
  });

  test('a huge LRC offset does not throw', () {
    final m = TrackMeta.tryParse({
      'lyricsSynced': '[offset:99999999999999999999]\n[00:01.00]a',
    });
    expect(m!.lyricsSynced, isNotNull);
  });

  test('isrc is upper-cased', () {
    expect(TrackMeta.tryParse({'isrc': 'usrc17607839'})!.isrc, 'USRC17607839');
  });

  test('non-map gives null, empty map gives all-null fields', () {
    expect(TrackMeta.tryParse('x'), isNull);
    expect(TrackMeta.tryParse(null), isNull);
    expect(TrackMeta.tryParse(<String, Object?>{})!.toJson(), isEmpty);
  });

  test('curiosities travel when present and an old payload reads null', () {
    expect(
      TrackMeta.tryParse(const TrackMeta(curiosities: 'x').toJson())!
          .curiosities,
      'x',
    );
    expect(TrackMeta.tryParse({'title': 't'})!.curiosities, isNull);
    expect(
      const TrackMeta(title: 't').toJson().containsKey('curiosities'),
      false,
    );
  });

  test('credits and details round trip; an old meta has none', () {
    final m = TrackMeta(
      title: 'T',
      credits: [TrackCredit('Ann', 'composer', 'deezer')],
      details: const TrackDetails(label: 'L'),
    );
    final back = TrackMeta.tryParse(m.toJson())!;
    expect(back.credits.single.name, 'Ann');
    expect(back.details!.label, 'L');
    final old = TrackMeta.tryParse(full.toJson())!;
    expect(old.credits, isEmpty);
    expect(old.details, isNull);
  });

  test('more than 200 credits are cut to 200, on both sides', () {
    final many = [
      for (var i = 0; i < 250; i++) TrackCredit('P$i', 'guitar', 'deezer'),
    ];
    final json = {
      'credits': [for (final c in many) c.toJson()],
    };
    expect(TrackMeta.tryParse(json)!.credits, hasLength(200));
  });

  test('wrong-typed details and unknown credit sources do not throw', () {
    final m = TrackMeta.tryParse({
      'details': {
        'label': 5,
        'bpm': '120',
        'explicit': 1,
        'copyright': 'c' * 900,
        'rank': 7,
      },
      'credits': [
        {'name': 'A', 'role': 'guitar', 'source': 'evil'},
        {'name': 'B', 'role': 'guitar', 'source': 'deezer'},
      ],
    })!;
    expect(
      (m.details!.label, m.details!.bpm, m.details!.explicit, m.details!.rank),
      (null, null, null, 7),
    );
    expect(m.details!.copyright!.length, 500);
    expect(m.credits.map((c) => c.name), ['B']);
  });

  test('fromTrack with 250 credits sends 200', () {
    final t = Track(saved: false, 
      coverSource: 0,
      id: 1,
      path: '/1',
      title: 'T',
      albumKey: 'k',
      format: 'mp3',
      sizeBytes: 1,
      mtimeMs: 1,
      addedAt: 1,
      durationMs: 1000,
      playCount: 0,
      isFavorite: false,
      missing: false,
      ignored: false,
      kind: 0,
      enrichStatus: 0,
      hasCover: false,
      userEdited: false,
    );
    final many = [
      for (var i = 0; i < 250; i++) TrackCredit('P$i', 'guitar', 'deezer'),
    ];
    expect(
      TrackMeta.fromTrack(t, credits: many).toJson()['credits'],
      hasLength(200),
    );
  });
}
