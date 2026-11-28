import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/karaoke_video/karaoke_video.dart';
import 'package:codecore/services/online/karaoke_filter.dart';
import 'package:codecore/services/online/merge_results.dart';
import 'package:codecore/services/online/query_match.dart' show MediaKind;
import 'package:codecore/services/online/youtube_service.dart' show YtException, YtResult;
import 'package:flutter_test/flutter_test.dart';

Track track(String path, String title) => Track(
  saved: false,
  coverSource: 0,
  id: 1,
  path: path,
  title: title,
  artist: 'a',
  albumKey: 'k',
  durationMs: 1000,
  format: 'mp3',
  sizeBytes: 1,
  mtimeMs: 1,
  hasCover: false,
  isFavorite: false,
  enrichStatus: 0,
  userEdited: false,
  missing: false,
  ignored: false,
  kind: 0,
  addedAt: 1,
  playCount: 0,
);

JamItem item(String title, {String? ref, String? videoId = 'abc'}) => JamItem(
  id: 1, ownerDeviceId: 'd', title: title, ext: 'm4a', ref: ref, videoId: videoId,
);

void main() {
  test('streamed YouTube track with «karaoke» in the title, any case', () {
    expect(isKaraokeVideo(track('online:youtube:abc', 'Song (Karaoke Version)')), isTrue);
    expect(isKaraokeVideo(track('stream:youtube:abc', 'SONG KARAOKE')), isTrue);
  });

  test('never for a local file, a title without the word or another source', () {
    expect(isKaraokeVideo(track('/m/song.mp3', 'Song karaoke')), isFalse);
    expect(isKaraokeVideo(track('online:youtube:abc', 'Song')), isFalse);
    expect(isKaraokeVideo(track('online:soundcloud:abc', 'Song karaoke')), isFalse);
    expect(isKaraokeVideo(track('online:radio:abc', 'Song karaoke')), isFalse);
  });

  test('the video id comes from the key, without the episode fragment', () {
    expect(karaokeVideoId(track('online:youtube:abc', 'x')), 'abc');
    expect(karaokeVideoId(track('stream:youtube:abc#cc-ep=2', 'x')), 'abc');
    expect(karaokeVideoId(track('/m/a.mp3', 'x')), isNull);
    expect(karaokeVideoId(track('online:youtube:', 'x')), isNull);
    expect(karaokeVideoId(track('stream:youtube:', 'x')), isNull);
  });

  test('the expiry comes from the expire parameter of the URL', () {
    final s = karaokeVideoStreamOf(Uri.parse('https://v.example/a?expire=1700000000'));
    expect(s.expires, DateTime.utc(2023, 11, 14, 22, 13, 20));
    expect(karaokeVideoStreamOf(Uri.parse('https://v.example/a')).expires, isNull);
  });

  test('a huge or invalid expire gives no expiry instead of throwing', () {
    expect(karaokeVideoStreamOf(Uri.parse('https://v.example/a?expire=99999999999999999')).expires, isNull);
    expect(karaokeVideoStreamOf(Uri.parse('https://v.example/a?expire=abc')).expires, isNull);
  });

  test('the output of -g: first line only (also with CRLF); http, relative or hostless is a changed output', () {
    expect(karaokeVideoStreamOfOutput('https://v.example/a?x=1\r\nhttps://v.example/b\r\n').url.path, '/a');
    for (final bad in ['http://v.example/a', '/relative/a', 'https:///a', '', null]) {
      expect(() => karaokeVideoStreamOfOutput(bad), throwsA(isA<YtException>()), reason: '$bad');
    }
  });

  group('jamKaraokeVideoId', () {
    test('a streamed YouTube karaoke item gives its id', () {
      expect(jamKaraokeVideoId(item('Hello Karaoke', ref: 'yt:youtube:abc')), 'abc');
    });
    test('another title gives none', () {
      expect(jamKaraokeVideoId(item('Hello', ref: 'yt:youtube:abc')), isNull);
    });
    test('a library item never has a video (D-636)', () {
      expect(jamKaraokeVideoId(item('Hello Karaoke', ref: '42')), isNull);
    });
  });

  // The three karaoke rules of today side by side: the player (isKaraokeVideo), the Jam
  // (jamKaraokeVideoId) and the search filter (karaokeResults). The filter alone also
  // drops reactions, covers and lives; the other two only look for the word.
  group('the three rules on the same titles', () {
    for (final (title, player, jam, filter) in [
      ('Hello (Karaoke Version)', true, true, true),
      ('HELLO KARAOKE', true, true, true),
      ('hello karaoke', true, true, true),
      ('Hello Karaokes', true, true, true),
      ('Hello - Karaoke Version - Instrumental', true, true, true),
      ('Hello (Instrumental)', false, false, false),
      ('Hello', false, false, false),
      ('Hello (Karaoké)', false, false, false), // an accent is not the word
      ('KARAOKÉ Hello', false, false, false),
      ('Hello KARAOKE reaction', true, true, false),
      ('Hello karaoke reactions', true, true, false),
      ('Hello - karaoke cover', true, true, false),
      ('Hello (Live) karaoke', true, true, false),
      ('Hello [Cover] karaoke', true, true, false),
      ('Hello - live karaoke', true, true, false),
      ('Live Forever (Karaoke Version)', true, true, true),
    ]) {
      test('«$title»: player $player, Jam $jam, filter $filter', () {
        expect(isKaraokeVideo(track('online:youtube:abc', title)), player);
        expect(jamKaraokeVideoId(item(title, ref: 'yt:youtube:abc')), jam ? 'abc' : isNull);
        final r = SmartResult(
          primary: YtResult(id: 'abc', title: title, channel: 'Someone', duration: null),
          sources: {MediaKind.ytVideo},
          alternatives: const [],
          confidence: 0.5,
          hasVideo: false,
        );
        expect(karaokeResults([r]).length, filter ? 1 : 0);
      });
    }
  });
}
