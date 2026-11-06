import 'package:codecore/services/online/yt_dlp_args.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> args({
  DownloadOptions options = const DownloadOptions(),
  bool hasFfmpeg = true,
}) =>
    buildDownloadArgs(
        url: 'https://www.youtube.com/watch?v=abc',
        stem: '/d/Song',
        hasFfmpeg: hasFfmpeg,
        options: options,
        jsArgs: ['--js-runtimes', 'node']);

void main() {
  test('default: M4A, YouTube\'s AAC stream first, no rate limit', () {
    final a = args();
    expect(
        a,
        containsAllInOrder([
          '-f', 'bestaudio[ext=m4a]/bestaudio/best', '-x', '--audio-format', 'm4a',
          '--audio-quality', '192K',
        ]));
    expect(a, isNot(contains('--limit-rate')));
    expect(a, containsAllInOrder(['--js-runtimes', 'node']));
    expect(a.last, 'https://www.youtube.com/watch?v=abc');
    expect(a, containsAllInOrder(['-o', '/d/Song.%(ext)s']));
  });

  test('rate limit becomes --limit-rate <n>K; 0 and null mean unlimited', () {
    expect(args(options: const DownloadOptions(rateLimitKBps: 500)),
        containsAllInOrder(['--limit-rate', '500K']));
    expect(args(options: const DownloadOptions(rateLimitKBps: 0)),
        isNot(contains('--limit-rate')));
    expect(args(), isNot(contains('--limit-rate')));
  });

  test('MP3 320 and 192: the best audio converted at that rate', () {
    for (final (f, q) in [(DownloadFormat.mp3High, '320K'), (DownloadFormat.mp3Low, '192K')]) {
      expect(
          args(options: DownloadOptions(format: f)),
          containsAllInOrder([
            '-f', 'bestaudio/best', '-x', '--audio-format', 'mp3', '--audio-quality', q,
          ]));
    }
  });

  test('original: the best audio taken out of the video, never re-encoded', () {
    final a = args(options: const DownloadOptions(format: DownloadFormat.original));
    expect(a, containsAllInOrder(['-f', 'bestaudio/best', '-x']));
    expect(a, isNot(contains('--audio-format')));
    expect(a, isNot(contains('--audio-quality')));
  });

  test('without ffmpeg the audio is kept as downloaded, whatever the format', () {
    for (final f in DownloadFormat.values) {
      final a = args(hasFfmpeg: false, options: DownloadOptions(format: f));
      expect(a, containsAllInOrder(['-f', 'bestaudio[ext=m4a]/bestaudio/best']));
    }
  });

  test('reserved extension follows what will be produced', () {
    expect(reservedExtension(hasFfmpeg: true, options: const DownloadOptions()), 'm4a');
    expect(
        reservedExtension(
            hasFfmpeg: true,
            options: const DownloadOptions(format: DownloadFormat.mp3Low)),
        'mp3');
    expect(
        reservedExtension(
            hasFfmpeg: true,
            options: const DownloadOptions(format: DownloadFormat.original)),
        'opus');
    expect(
        reservedExtension(
            hasFfmpeg: false,
            options: const DownloadOptions(format: DownloadFormat.mp3High)),
        'm4a');
  });

  test('a name taken by any container is not reused', () {
    final taken = {'/d/Song.opus'};
    expect(anyDownloadExtensionExists('/d/Song.m4a', taken.contains), isTrue);
    expect(anyDownloadExtensionExists('/d/Other.m4a', taken.contains), isFalse);
  });

  test('podcast audio: the literal selector, audio only, no conversion', () {
    expect(podcastAudioSelector, 'bestaudio[ext=m4a]/bestaudio');
    final a = args(options: const DownloadOptions(selector: podcastAudioSelector));
    expect(a, containsAllInOrder(['-f', 'bestaudio[ext=m4a]/bestaudio']));
    expect(a, isNot(contains('--extract-audio')));
    expect(a, isNot(contains('--audio-format')));
  });

  test('a SoundCloud page is passed to yt-dlp as it is', () {
    final a = buildDownloadArgs(
      url: 'https://soundcloud.com/artist/track',
      stem: '/d/Song',
      hasFfmpeg: true,
      options: const DownloadOptions(),
    );
    expect(a.last, 'https://soundcloud.com/artist/track');
    expect(a, contains('--no-playlist'));
  });

  test('stream URL options only with emitStreamUrl, together with --progress', () {
    final a = args(options: const DownloadOptions(emitStreamUrl: true));
    expect(a, containsAllInOrder(['--progress', '--print', 'before_dl:CODECORE_URL %(urls)s']));
    expect(a, containsAllInOrder(['--print', 'before_dl:CODECORE_HDR %(http_headers)j']));
    expect(args(), isNot(contains('--print')));
    expect(args(), isNot(contains('--progress')));
  });

  group('StreamUrlLines', () {
    const hdr = 'CODECORE_HDR {"User-Agent":"UA","Accept":"*/*"}';

    test('url + headers give exactly one event', () {
      final p = StreamUrlLines();
      expect(p.add('CODECORE_URL https://v.example/a?x=1'), isNull);
      final e = p.add(hdr)!;
      expect(e.streamUrl, Uri.parse('https://v.example/a?x=1'));
      expect(e.headers, {'User-Agent': 'UA', 'Accept': '*/*'});
      expect(p.add(hdr), isNull);
    });

    test('two addresses: the first one', () {
      final p = StreamUrlLines();
      p.add('CODECORE_URL https://v.example/video');
      p.add('https://v.example/audio');
      expect(p.add(hdr)!.streamUrl, Uri.parse('https://v.example/video'));
    });

    test('broken or missing lines never give an event', () {
      expect(StreamUrlLines().add(hdr), isNull);
      for (final bad in ['CODECORE_HDR not json', 'CODECORE_HDR {"a":1}', 'CODECORE_HDR [1]']) {
        final p = StreamUrlLines()..add('CODECORE_URL https://v.example/a');
        expect(p.add(bad), isNull);
      }
      final p = StreamUrlLines()..add('CODECORE_URL http://v.example/a');
      expect(p.add(hdr), isNull);
    });
  });
}
