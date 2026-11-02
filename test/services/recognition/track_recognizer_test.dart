import 'package:codecore/services/online/acoustid_client.dart';
import 'package:codecore/services/online/http_client.dart' show RateLimitedException;
import 'package:codecore/services/online/musicbrainz_client.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_song_parser.dart';
import 'package:codecore/services/recognition/channel_detector.dart' show tagsDubious;
import 'package:codecore/services/recognition/track_identity.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

YtResult ytResult(String title, String artist, int secs) => YtResult(
    id: 'vid', title: title, channel: 'chan', duration: Duration(seconds: secs), artists: [artist]);

void main() {
  late Rig r;
  setUp(() => r = Rig());

  group('R-161, one test per branch', () {
    test('an ISRC with reliable tags goes to MusicBrainz filtered by title and artist, and is sure', () async {
      r.mbByIsrc = [const MbRecording(id: 'm1', title: 'Believer', artistId: 'a', artistName: 'Imagine Dragons', length: 204000)];
      final out = await r.recognize(track('Believer', 'Imagine Dragons', isrc: 'USUM71700626'));
      expect(r.calls, ['mb.isrc']);
      expect(r.isrcArgs, ['Believer|Imagine Dragons']);
      final rec = out.rec!;
      expect([rec.src, rec.sure, rec.identity!.title, rec.identity!.artist], [RecogSource.tags, true, 'Believer', 'Imagine Dragons']);
      expect(rec.identity!.mbid, 'm1');
      expect(rec.identity!.isrc, 'USUM71700626');
      expect(out.lost, isFalse);
    });

    test('an ISRC with dubious tags is not filtered and only a proposal, still without text or AcoustID', () async {
      r.mbByIsrc = [const MbRecording(id: 'm1', title: 'Believer', artistId: 'a', artistName: 'Imagine Dragons', length: 204000)];
      final out = await r.recognize(track('Believer (Romy Wave Cover)', '7clouds Rock', isrc: 'USUM71700626'));
      expect(r.calls, ['mb.isrc', 'mb.search']); // the title says cover: the original is looked for
      expect(r.isrcArgs, ['null|null']);
      expect([out.rec!.src, out.rec!.sure], [RecogSource.tags, false]);
    });

    test('a MusicBrainz id in the file goes to recordingById; a length 20 s off is no match', () async {
      r.ids = (isrc: null, mbid: '6190f4cf-2396-4827-a9cc-c05a0ff3a5b4');
      r.mbById = const MbRecordingDetail(id: 'x', title: 'Fairytale', artist: 'Alexander Rybak', length: 183000, isrcs: ['NOA']);
      final out = await r.recognize(track('Fairytale', 'Alexander Rybak', durationMs: 183000));
      expect(r.calls, ['mb.id']);
      expect([out.rec!.src, out.rec!.sure, out.rec!.identity!.isrc], [RecogSource.tags, true, 'NOA']);

      r.calls.clear();
      final off = await r.recognize(track('Fairytale', 'Alexander Rybak', durationMs: 203000));
      expect(off.rec!.src, isNot(RecogSource.tags));
    });

    test('an id that is not a UUID never reaches a URL', () async {
      r.ids = (isrc: null, mbid: '../../artist/x?inc=1');
      await r.recognize(track('Song', 'Artist'));
      expect(r.calls, isNot(contains('mb.id')));
    });

    test('a video id asks YouTube Music, not AcoustID; official is sure', () async {
      r.song = const YtmSong(title: 'Skyfall', artists: ['Adele'], videoType: 'MUSIC_VIDEO_TYPE_ATV', durationMs: 286000);
      final out = await r.recognize(
          track('Adele - Skyfall (Lyrics)', '7clouds Rock', path: '/m/Adele - Skyfall (Lyrics) [sZrTJesvJeo].mp3', durationMs: 286000));
      expect(r.calls, ['songOf:sZrTJesvJeo']);
      expect([out.rec!.src, out.rec!.sure, out.rec!.identity!.vid], [RecogSource.ytid, true, 'sZrTJesvJeo']);
    });

    test('a deleted or private video is «nothing», not a lost source', () async {
      final out = await r.recognize(track('Song', 'Artist', path: '/m/Song [sZrTJesvJeo].mp3'));
      expect(r.calls, ['songOf:sZrTJesvJeo', 'text', 'fp', 'acoustid', 'ytm']);
      expect([out.rec!.src, out.lost], [null, false]);
    });

    test('a video of a lyrics channel is a proposal, not sure', () async {
      r.song = const YtmSong(title: 'Skyfall', artists: ['Adele'], videoType: 'MUSIC_VIDEO_TYPE_UGC', durationMs: 286000);
      final out = await r.recognize(track('Skyfall', null, path: '/m/Skyfall [sZrTJesvJeo].mp3', durationMs: 286000));
      expect([out.rec!.src, out.rec!.sure], [RecogSource.ytid, false]);
    });

    test('a video id known from outside wins over the file name', () async {
      r.videoIdFor = (_) async => 'AAAAAAAAAAA';
      r.song = const YtmSong(title: 'S', artists: ['A'], videoType: 'MUSIC_VIDEO_TYPE_OMV');
      await r.recognize(track('S', 'A', path: '/m/S [sZrTJesvJeo].mp3'));
      expect(r.calls, ['songOf:AAAAAAAAAAA']);
    });

    test('reliable tags found by the text search: no AcoustID', () async {
      r.text = meta('Believer', 'Imagine Dragons');
      final out = await r.recognize(track('Believer', 'Imagine Dragons'));
      expect(r.calls, ['text']);
      expect([out.rec!.src, out.rec!.sure], [RecogSource.text, false]);
    });

    test('dubious tags go to AcoustID and skip the text search', () async {
      r.hits = acoustIdFixture('heathens');
      final out = await r.recognize(track('Heathens', '7clouds Rock', durationMs: 218000));
      expect(r.calls, ['fp', 'acoustid']);
      expect(out.rec!.src, RecogSource.acoustid);
    });

    test('reliable tags the text does not find go on to AcoustID', () async {
      r.hits = acoustIdFixture('heathens');
      final out = await r.recognize(track('Heathens', 'twenty one pilots', durationMs: 218000));
      expect(r.calls, ['text', 'fp', 'acoustid']);
      expect(out.rec!.src, RecogSource.acoustid);
    });

    test('everything empty ends at YouTube Music, never sure', () async {
      r.ytm = [ytResult('Song', 'Artist', 201)];
      final out = await r.recognize(track('Song', 'Artist'));
      expect(r.calls, ['text', 'fp', 'acoustid', 'ytm']);
      expect([out.rec!.src, out.rec!.sure, out.rec!.identity!.vid], [RecogSource.ytm, false, 'vid']);
    });

    test('YouTube Music results 15 s off or with another title are no match', () async {
      r.ytm = [ytResult('Song', 'Artist', 215), ytResult('Other Thing', 'Artist', 200)];
      final out = await r.recognize(track('Song', 'Artist'));
      expect(out.rec!.src, isNull);
    });
  });

  group('R-165, the AcoustID pick', () {
    Future<void> picks(String fixture, String file, int ms, String artist, int secs, {bool dubious = true}) async {
      r.hits = acoustIdFixture(fixture);
      final out = await r.recognize(track(file, dubious ? null : artist, path: '/m/$file.mp3', durationMs: ms));
      final id = out.rec!.identity!;
      expect([out.rec!.src, out.rec!.sure, id.artist, id.ms], [RecogSource.acoustid, true, artist, secs * 1000]);
      expect(id.mbid, isNotNull);
      expect(out.rec!.score, greaterThanOrEqualTo(0.9));
    }

    test('Fairytale: Rybak at 183 s, not the Pointer Sisters, the karaoke or the remix', () =>
        picks('fairytale', 'Alexander Rybak  Fairytale (LYRICS)', 183000, 'Alexander Rybak', 183));

    test('Heathens: twenty one pilots at 218 s, not the 196 s version', () =>
        picks('heathens', 'twenty one pilots_ Heathens (from Suicide Squad_ The Album) [OFFICIAL VIDEO]', 218000,
            'twenty one pilots', 218));

    test('Happier: Marshmello and Bastille, not Guster', () =>
        picks('happier', 'Marshmello ft. Bastille - Happier (Official Music Video)', 214000,
            'Marshmello, Bastille', 214));

    test('the karaoke is never picked when the file does not say karaoke', () async {
      // same length as the plain song: only the title tells them apart
      r.hits = acoustIdFixture('fairytale').take(1).toList();
      final out = await r.recognize(track('Fairytale', null, durationMs: 183000));
      expect(out.rec!.identity!.title, 'Fairytale');
    });

    test('a score of 0.85 is dropped', () async {
      final h = acoustIdFixture('heathens').single;
      r.hits = [AcoustIdHit(id: h.id, score: 0.85, recordings: h.recordings)];
      final out = await r.recognize(track('Heathens', null, durationMs: 218000));
      expect(out.rec!.src, isNull);
    });

    test('a recording 15 s longer than the file is dropped', () async {
      r.hits = acoustIdFixture('heathens');
      final out = await r.recognize(track('Heathens', null, durationMs: 218000 + 15000));
      expect(out.rec!.src, isNull);
    });

    test('a title in another script than the file is a proposal (K-RB-04)', () async {
      r.hits = [
        AcoustIdHit(id: 'h', score: 0.97, recordings: [
          const AcoustIdRecording(id: 'r', title: 'ミリオンダラー', artists: ['X'], durationS: 200),
        ]),
      ];
      final out = await r.recognize(track('Million Dollar', null, path: '/m/Million Dollar.mp3'));
      expect([out.rec!.src, out.rec!.sure], [RecogSource.acoustid, false]);
    });
  });

  group('R-165, sure only for the same song', () {
    Future<Recognition> pick(String file, String title, {int secs = 200, double score = 0.97, int ms = 200000}) async {
      r.hits = [
        AcoustIdHit(id: 'h', score: score, recordings: [
          AcoustIdRecording(id: 'r', title: title, artists: const ['X'], durationS: secs),
        ]),
      ];
      return (await r.recognize(track(file, null, path: '/m/$file.mp3', durationMs: ms))).rec!;
    }

    test('another version or another song is a proposal, the same song is sure', () async {
      for (final other in ['Believer (Live)', 'Believer (Instrumental)', 'Believer (Karaoke)', 'Believer Remix', 'Believer (Cover)']) {
        expect((await pick('Believer', other)).sure, isFalse, reason: other);
      }
      expect((await pick('Love Story', 'Love Me')).sure, isFalse); // overlap exactly 0.5
      expect((await pick('Believer', 'Believer')).sure, isTrue);
      expect((await pick('Believer (Live)', 'Believer (Live)')).sure, isTrue); // the file names the version
      expect((await pick('Love Story Baby Tonight', 'Story Love Zebra')).sure, isTrue); // 2 of 3 words
    });

    test('a title with extra words in the same script as the file is sure; in another script it is not', () async {
      expect((await pick('Million Dollar', 'Million Dollar ミリオン')).sure, isFalse);
      expect((await pick('Million Dollar', 'Million Dollar Baby')).sure, isTrue);
    });

    test('a different artist in the tags makes it a proposal; a channel or the same artists do not', () async {
      Future<Recognition> withArtist(String? artist, List<String> recArtists) async {
        r.hits = [
          AcoustIdHit(id: 'h', score: 0.96, recordings: [
            AcoustIdRecording(id: 'r', title: 'Happier', artists: recArtists, durationS: 200),
          ]),
        ];
        return (await r.recognize(track('Happier', artist, path: '/m/Happier.mp3', durationMs: 200000))).rec!;
      }

      final wrong = await withArtist('Marshmello ft. Bastille', ['Guster']);
      expect(wrong.src, RecogSource.acoustid);
      expect(wrong.sure, isFalse);
      expect((await withArtist('Marshmello ft. Bastille', ['Marshmello', 'Bastille'])).sure, isTrue);
      expect((await withArtist('7clouds Rock', ['Guster'])).sure, isTrue);
      // dubious tags («Artist - Title» in the title): the artist is not compared
      r.hits = [
        AcoustIdHit(id: 'h', score: 0.96, recordings: [
          AcoustIdRecording(id: 'r', title: 'Super Mario World OST - Star Road', artists: const ['Other'], durationS: 200),
        ]),
      ];
      final t = track('Super Mario World OST - Star Road', 'retrovgnamusic', path: '/m/x.mp3', durationMs: 200000);
      expect(tagsDubious(t), isTrue);
      expect((await r.recognize(t)).rec!.sure, isTrue);
    });

    test('limits: score 0.9 is in; 10 s off is in, 10.001 s is out', () async {
      expect((await pick('Song', 'Song', score: 0.9)).src, RecogSource.acoustid);
      expect((await pick('Song', 'Song', secs: 210)).src, RecogSource.acoustid);
      expect((await pick('Song', 'Song', secs: 210, ms: 199999)).src, isNull);
      expect((await pick('Song', 'Song', secs: 190)).src, RecogSource.acoustid);
      expect((await pick('Song', 'Song', secs: 190, ms: 200001)).src, isNull);
    });
  });

  group('R-165, whole words and channels', () {
    AcoustIdHit hit(List<AcoustIdRecording> rs) => AcoustIdHit(id: 'h', score: 0.97, recordings: rs);
    AcoustIdRecording rec(String id, String title, String artist) =>
        AcoustIdRecording(id: id, title: title, artists: [artist], durationS: 200);

    test('«Low» is not found inside «Flower»', () async {
      r.hits = [hit([rec('a', 'Song', 'Low'), rec('b', 'Song', 'Flower')])];
      final out = await r.recognize(track('Flower Song', null));
      expect(out.rec!.identity!.artist, 'Flower');
      r.hits = [hit([rec('c', 'Low', 'X')])];
      final low = await r.recognize(track('Flower', null));
      expect(low.rec!.sure, isFalse);
    });

    test('the channel in the artist tag does not attract its own namesake', () async {
      r.hits = [hit([rec('a', 'Song', 'Real Artist'), rec('b', 'Song', 'Trap City')])];
      final out = await r.recognize(track('Song', 'Trap City'));
      expect(out.rec!.identity!.artist, 'Real Artist');
    });

    test('a generic artist is left out of the YouTube Music query', () async {
      await r.recognize(track('Song', 'Unknown Artist'));
      expect(r.ytmQueries, ['Song']);
    });
  });

  group('the 10 s slack of the other sources', () {
    test('a MusicBrainz id: 10 s off is a match, 10.001 s is not', () async {
      r.ids = (isrc: null, mbid: '6190f4cf-2396-4827-a9cc-c05a0ff3a5b4');
      r.mbById = const MbRecordingDetail(id: 'x', title: 'Song', artist: 'Artist', length: 210000, isrcs: []);
      expect((await r.recognize(track('Song', 'Artist'))).rec!.src, RecogSource.tags);
      r.mbById = const MbRecordingDetail(id: 'x', title: 'Song', artist: 'Artist', length: 210001, isrcs: []);
      expect((await r.recognize(track('Song', 'Artist'))).rec!.src, isNot(RecogSource.tags));
    });

    test('a video id: 10 s off is a match, 10.001 s is not', () async {
      YtmSong song(int ms) => YtmSong(title: 'S', artists: const ['A'], videoType: 'MUSIC_VIDEO_TYPE_ATV', durationMs: ms);
      r.song = song(210000);
      expect((await r.recognize(track('S', 'A', path: '/m/S [sZrTJesvJeo].mp3'))).rec!.src, RecogSource.ytid);
      r.song = song(210001);
      expect((await r.recognize(track('S', 'A', path: '/m/S [sZrTJesvJeo].mp3'))).rec!.src, isNot(RecogSource.ytid));
    });

    test('YouTube Music: 10 s off is a match, 10.001 s is not', () async {
      r.ytm = [ytResult('Song', 'Artist', 210)];
      expect((await r.recognize(track('Song', 'Artist'))).rec!.src, RecogSource.ytm);
      expect((await r.recognize(track('Song', 'Artist', durationMs: 199999))).rec!.src, isNull);
    });

    test('YouTube Music: a title with half of the words is a candidate, a third is not', () async {
      r.ytm = [ytResult('Love Me', 'Artist', 200)];
      expect((await r.recognize(track('Love Story', 'Artist'))).rec!.src, RecogSource.ytm);
      r.ytm = [ytResult('Love Me Tender', 'Artist', 200)];
      expect((await r.recognize(track('Love Story', 'Artist'))).rec!.src, isNull);
    });
  });

  group('failures and switches', () {
    test('a streamed track is never fingerprinted, and that is a definite «no»', () async {
      final out = await r.recognize(track('Song', null, path: 'stream:soundcloud:123'));
      expect(r.calls, ['ytm']);
      expect([out.rec!.src, out.lost], [null, false]);
    });

    test('a fingerprint that cannot be made is a definite «no», not a lost source', () async {
      r.fingerprintable = false;
      final out = await r.recognize(track('Song', null));
      expect(r.calls, ['fp', 'ytm']);
      expect([out.rec!.src, out.lost], [null, false]);
    });

    test('R-184: an .opus file with dubious tags asks YouTube Music, with no fingerprint', () async {
      r.ytm = [ytResult('Song', 'Artist', 200)];
      final out = await r.recognize(track('Song', null, path: '/m/Song.opus'));
      expect(r.calls, ['ytm']);
      expect(out.rec!.src, RecogSource.ytm);
    });

    test('R-164: with the switch off AcoustID is not asked, YouTube Music is', () async {
      r.acoustIdOn = false;
      r.ytm = [ytResult('Song', 'Artist', 200)];
      final out = await r.recognize(track('Song', null));
      expect(r.calls, ['ytm']);
      expect(out.rec!.src, RecogSource.ytm);
    });

    test('with the switch off and nothing found, the track is left to ask again', () async {
      r.acoustIdOn = false;
      final out = await r.recognize(track('Song', null));
      expect([out.rec, out.lost], [null, true]);
    });

    test('R-168: AcoustID that throws is skipped for YouTube Music', () async {
      r.acoustIdError = const RateLimitedException(429);
      r.ytm = [ytResult('Song', 'Artist', 200)];
      final out = await r.recognize(track('Song', null));
      expect(r.calls, ['fp', 'acoustid', 'ytm']);
      expect([out.rec!.src, out.lost], [RecogSource.ytm, false]);
    });

    test('MusicBrainz down and the InnerTube format changed: the next source answers', () async {
      r.mbError = const MusicBrainzUnavailable('isrc');
      r.song = null;
      r.text = meta('Song', 'Artist');
      final out = await r.recognize(track('Song', 'Artist', isrc: 'USUM71700626', path: '/m/Song [sZrTJesvJeo].mp3'));
      expect(out.rec!.src, RecogSource.text);
    });

    test('every source says «nothing»: a recognition with no source, not lost', () async {
      final out = await r.recognize(track('Song', 'Artist'));
      expect(out.lost, isFalse);
      expect(out.rec!.src, isNull);
      expect(out.rec!.toJson(), {'v': kRecogVersion, 'at': DateTime.utc(2026, 11, 1).millisecondsSinceEpoch, 'src': null});
    });

    test('a source lost and nothing found: no recognition, lost', () async {
      r.acoustIdError = Exception('offline');
      final out = await r.recognize(track('Song', null));
      expect([out.rec, out.lost], [null, true]);
    });

    test('AcoustID resting: the file is not decoded, the source is limited, the next one answers', () async {
      r.acoustIdResting = true;
      r.ytm = [ytResult('Song', 'Artist', 200)];
      final out = await r.recognize(track('Song', null));
      expect(r.calls, ['ytm']);
      expect([out.rec!.src, out.lost], [RecogSource.ytm, false]);
      r.ytm = [];
      final none = await r.recognize(track('Song', null));
      expect([none.rec, none.lost, none.limited], [null, true, true]);
    });

    test('a refusal (429) of a source is limited; a plain error is not', () async {
      r.acoustIdError = const RateLimitedException(429);
      expect((await r.recognize(track('Song', null))).limited, isTrue);
      r.acoustIdError = Exception('offline');
      expect((await r.recognize(track('Song', null))).limited, isFalse);
    });

    test('asked: true when a source answered, false when none was asked, false when all failed', () async {
      expect((await r.recognize(track('Song', 'Artist'))).asked, isTrue); // «nothing», but really answered
      r.calls.clear();
      final mute = await r.recognize(track('Song', 'Foo - Topic', path: '/m/x.opus', durationMs: 0));
      expect([r.calls, mute.rec!.src, mute.asked], [<String>[], null, false]);
      r.acoustIdError = Exception('offline');
      r.ytmError = Exception('offline');
      final down = await r.recognize(track('Song', null));
      expect([down.rec, down.lost, down.asked], [null, true, false]);
    });

    test('a file that cannot be read now is a lost source, not a saved «nothing»', () async {
      r.fingerprintError = Exception('io');
      final out = await r.recognize(track('Song', null));
      expect(r.calls, ['fp', 'ytm']);
      expect([out.rec, out.lost], [null, true]);
      r.ytm = [ytResult('Song', 'Artist', 200)];
      expect((await r.recognize(track('Song', null))).rec!.src, RecogSource.ytm);
    });

    test('an ISRC that is not an ISRC never reaches MusicBrainz', () async {
      await r.recognize(track('Song', 'Artist', isrc: '../../artist/x?x=1#'));
      r.ids = (isrc: 'US/UM?71700626', mbid: null);
      await r.recognize(track('Song', 'Artist'));
      expect(r.calls, isNot(contains('mb.isrc')));
      r.ids = (isrc: 'us-um7 1700626', mbid: null); // normalised, then valid
      await r.recognize(track('Song', 'Artist'));
      expect(r.calls, contains('mb.isrc'));
    });

    test('Opus with dubious tags where YouTube Music answers «nothing»: asked', () async {
      final out = await r.recognize(track('Song', null, path: '/m/Song.opus'));
      expect([r.calls, out.rec!.src, out.asked], [['ytm'], null, true]);
    });

    test('a cancel is not swallowed', () async {
      final cancel = CancelToken();
      r.mbError = DioException.requestCancelled(requestOptions: RequestOptions(path: '/'), reason: 'x');
      await expectLater(r.recognize(track('Song', 'Artist', isrc: 'USUM71700626'), cancel: cancel),
          throwsA(isA<DioException>()));
    });
  });

  group('R-172 / R-173, covers', () {
    const mbid = '6190f4cf-2396-4827-a9cc-c05a0ff3a5b4';
    const orig = MbRecording(id: 'o1', title: 'Believer', artistId: 'a', artistName: 'Imagine Dragons');

    test('a cover work in MusicBrainz: the original comes from the work, the identity stays the cover', () async {
      r.ids = (isrc: null, mbid: mbid);
      r.mbById = const MbRecordingDetail(
          id: 'c1', title: 'Believer (cover)', artist: 'Romy Wave', length: 200000, works: [MbWorkLink('w1', cover: true)]);
      r.mbOriginal = orig;
      final rec = (await r.recognize(track('Believer', 'Romy Wave'))).rec!;
      expect(r.calls, ['mb.id', 'mb.work:w1']);
      expect([rec.cover, rec.sure, rec.identity!.title], [true, true, 'Believer (cover)']);
      expect(rec.original, {'title': 'Believer', 'artist': 'Imagine Dragons', 'mbid': 'o1'});
    });

    test('a cover only the title hints at: original from the search of the cleaned title, never sure if the identity is the original', () async {
      r.mbByIsrc = [const MbRecording(id: 'x1', title: 'Believer', artistId: 'a', artistName: 'Imagine Dragons', length: 200000)];
      r.mbSearch = [orig];
      final rec = (await r.recognize(track('Believer (Romy Wave Cover)', 'Romy Wave', isrc: 'USUM71700626'))).rec!;
      expect(r.searches, ['Believer|Imagine Dragons']);
      expect([rec.cover, rec.sure, rec.identity!.mbid], [true, false, 'x1']);
      expect(rec.original!['mbid'], 'o1');
    });

    test('no original found: cover true and no original; the JSON keeps both', () async {
      r.text = meta('Believer', 'Imagine Dragons');
      final rec = (await r.recognize(track('Believer (Romy Wave Cover)', 'Romy Wave'))).rec!;
      expect(r.searches, ['Believer|Imagine Dragons']);
      expect([rec.cover, rec.original], [true, null]);
      final back = Recognition.fromJson(rec.toJson())!;
      expect([back.cover, back.original], [true, null]);
    });

    test('the original is saved in the JSON and read back; a normal song has no cover key', () async {
      r.text = meta('Believer', 'Imagine Dragons');
      r.mbSearch = [orig];
      final rec = (await r.recognize(track('Believer (Romy Wave Cover)', 'Romy Wave'))).rec!;
      final json = rec.toJson();
      expect(json['original'], {'title': 'Believer', 'artist': 'Imagine Dragons', 'mbid': 'o1'});
      expect(Recognition.fromJson(json)!.original, rec.original);
      final plain = (await r.recognize(track('Believer', 'Imagine Dragons'))).rec!;
      expect(plain.toJson().containsKey('cover'), isFalse);
    });

    test('the cover artist\'s own recording is never the original', () async {
      r.text = meta('Believer', 'Imagine Dragons');
      r.mbSearch = [const MbRecording(id: 'c1', title: 'Believer', artistId: 'b', artistName: 'Romy Wave'), orig];
      final rec = (await r.recognize(track('Believer (Piano Cover)', 'Romy Wave'))).rec!;
      expect(rec.original!['mbid'], 'o1');
    });

    test('a remix by the song\'s own artist is no cover, and stays sure', () async {
      r.ids = (isrc: null, mbid: mbid);
      r.mbById = const MbRecordingDetail(id: 'k1', title: 'Believer (Kaskade Remix)', artist: 'Imagine Dragons', length: 200000);
      final rec = (await r.recognize(track('Believer (Kaskade Remix)', 'Imagine Dragons'))).rec!;
      expect([rec.cover, rec.sure, rec.original], [false, true, null]);
      expect(r.calls, ['mb.id']);
    });

    test('a cover by the artist of its own recording stays a cover, the original is searched by title only', () async {
      r.text = meta('Believer', 'Romy Wave');
      r.mbSearch = [const MbRecording(id: 'c1', title: 'Believer', artistId: 'b', artistName: 'Romy Wave'), orig];
      final rec = (await r.recognize(track('Believer (Romy Wave Cover)', 'Romy Wave'))).rec!;
      expect(r.searches, ['Believer|']);
      expect([rec.cover, rec.original!['mbid']], [true, 'o1']);
    });

    test('a failing cover lookup is a lost source: no rec is saved', () async {
      r.ids = (isrc: null, mbid: mbid);
      r.mbById = const MbRecordingDetail(
          id: 'c1', title: 'Believer', artist: 'Romy Wave', length: 200000, works: [MbWorkLink('w1', cover: true)]);
      r.workError = const MusicBrainzUnavailable('work');
      final out = await r.recognize(track('Believer', 'Romy Wave'));
      expect([out.rec, out.lost], [null, true]);
    });
  });
}
