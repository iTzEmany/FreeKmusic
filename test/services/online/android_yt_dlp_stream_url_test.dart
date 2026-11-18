import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/karaoke_video/karaoke_video_source.dart';
import 'package:codecore/services/online/android_yt_dlp_service.dart';
import 'package:codecore/services/online/yt_dlp_args.dart' show videoOnlyFormat;
import 'package:codecore/services/online/youtube_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _ch = MethodChannel('codecore/ytdlp');
final _ytdlpUrl = Uri.parse('https://ytdlp.example/a');
final _pipeUrl = Uri.parse('https://newpipe.example/a');

/// Sends the two marked lines yt-dlp prints before the download.
Future<void> _ytdlpLines() async {
  for (final line in [
    'CODECORE_URL $_ytdlpUrl',
    'CODECORE_HDR ${jsonEncode({'User-Agent': 'x'})}',
  ]) {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          _ch.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('progress', {'processId': 'dl-0', 'line': line}),
          ),
          (_) {},
        );
  }
}

/// Runs one download with the given fake `streamUrl` and `download` and
/// returns the stream URLs that came out.
Future<List<Uri>> _run(
  Future<Object?> Function() streamUrl,
  Future<void> Function() download,
) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_ch, (call) async {
        if (call.method == 'streamUrl') return streamUrl();
        if (call.method == 'download') {
          await download();
          return '/tmp/x.m4a';
        }
        return null;
      });
  final dir = Directory.systemTemp.createTempSync('ytdl');
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ch, null);
    dir.deleteSync(recursive: true);
  });
  final events = AndroidYtDlpService().download(
    const YtResult(
      id: 'abc',
      title: 't',
      channel: 'c',
      duration: Duration(seconds: 1),
    ),
    dir,
    options: const DownloadOptions(emitStreamUrl: true),
  );
  return [
    await for (final e in events)
      if (e.streamUrl != null) e.streamUrl!,
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, Object?> pipe() => {
    'url': '$_pipeUrl',
    'headers': {'User-Agent': 'x'},
  };

  test('NewPipe first: one stream url event, the NewPipe one', () async {
    final urls = await _run(
      () async => pipe(),
      () async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await _ytdlpLines();
      },
    );
    expect(urls, [_pipeUrl]);
  });

  test('NewPipe fails: the yt-dlp url is used', () async {
    final urls = await _run(
      () async => throw PlatformException(code: 'YTDLP'),
      () async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await _ytdlpLines();
      },
    );
    expect(urls, [_ytdlpUrl]);
  });

  test('NewPipe answers without a url: the yt-dlp url is used', () async {
    final urls = await _run(
      () async => {'headers': {'User-Agent': 'x'}},
      () async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await _ytdlpLines();
      },
    );
    expect(urls, [_ytdlpUrl]);
  });

  test('NewPipe after yt-dlp: ignored', () async {
    final urls = await _run(
      () async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return pipe();
      },
      () async {
        await _ytdlpLines();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      },
    );
    expect(urls, [_ytdlpUrl]);
  });

  group('videoUrl', () {
    Future<KaraokeVideoStream> ask(Future<Object?> Function(MethodCall) h) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_ch, h);
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_ch, null));
      return AndroidYtDlpService().videoUrl('abc');
    }

    test('NewPipe answers: its url and headers, asked at 480p at most', () async {
      MethodCall? seen;
      final s = await ask((c) async {
        seen = c;
        return {'url': '$_pipeUrl?expire=1700000000', 'headers': {'User-Agent': 'x'}};
      });
      expect(seen!.method, 'videoUrl');
      expect(seen!.arguments, {'id': 'abc', 'maxHeight': 480});
      expect(s.url.host, _pipeUrl.host);
      expect(s.headers, {'User-Agent': 'x'});
      expect(s.expires, isNotNull);
    });

    test('NewPipe fails: yt-dlp is asked with the video-only selector', () async {
      MethodCall? fallback;
      final s = await ask((c) async {
        if (c.method == 'videoUrl') throw PlatformException(code: 'X');
        fallback = c;
        return '$_ytdlpUrl\n';
      });
      expect(fallback!.method, 'ytdlpVideoUrl');
      expect((fallback!.arguments as Map)['selector'], videoOnlyFormat);
      expect(s.url, _ytdlpUrl);
    });
  });
}
