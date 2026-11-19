import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/karaoke_video/karaoke_video.dart';
import 'package:codecore/services/online/youtube_service.dart' show YtException;
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
}
