import 'package:codecore/services/online/acoustid_client.dart';
import 'package:codecore/services/online/http_client.dart' show RateLimitedException;
import 'package:codecore/services/online/musicbrainz_client.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_song_parser.dart';
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
      expect(r.calls, ['mb.isrc']);
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

    test('reliable tags found by the text search: no AcoustID, and the meta comes back', () async {
      r.text = meta('Believer', 'Imagine Dragons');
      final out = await r.recognize(track('Believer', 'Imagine Dragons'));
      expect(r.calls, ['text']);
      expect([out.rec!.src, out.rec!.sure], [RecogSource.text, false]);
      expect(out.meta, same(r.text));
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

    test('a cancel is not swallowed', () async {
      final cancel = CancelToken();
      r.mbError = DioException.requestCancelled(requestOptions: RequestOptions(path: '/'), reason: 'x');
      await expectLater(r.recognize(track('Song', 'Artist', isrc: 'USUM71700626'), cancel: cancel),
          throwsA(isA<DioException>()));
    });
  });
}
