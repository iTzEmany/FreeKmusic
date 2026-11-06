import 'dart:convert';

import 'youtube_service.dart';

/// Containers a download can end up in (without ffmpeg the audio stays as
/// served: m4a when there is one, else opus in webm).
const downloadExtensions = ['mp3', 'm4a', 'opus', 'ogg', 'webm'];

/// Audio-only format of a YouTube Music podcast episode: the best m4a, else the
/// best audio. Never `best`: that would take the video.
const podcastAudioSelector = 'bestaudio[ext=m4a]/bestaudio';

const _preferM4a = 'bestaudio[ext=m4a]/bestaudio/best';

/// How yt-dlp is asked for [format]: the stream to pick and what ffmpeg turns
/// it into (`audioFormat` null = the codec as served). Without ffmpeg nothing
/// is converted and YouTube's m4a is preferred, since every player reads it.
({String selector, String? audioFormat, String? quality}) downloadChoice(
    DownloadFormat format,
    {required bool hasFfmpeg,
    String? selector}) {
  // A chosen selector (a podcast episode) is taken as it is: never converted.
  if (selector != null) return (selector: selector, audioFormat: null, quality: null);
  if (!hasFfmpeg) return (selector: _preferM4a, audioFormat: null, quality: null);
  return switch (format) {
    DownloadFormat.original =>
      (selector: 'bestaudio/best', audioFormat: null, quality: null),
    // An AAC stream is only moved into the m4a container (no re-encoding);
    // the quality applies to sources that have to be converted.
    DownloadFormat.m4a => (selector: _preferM4a, audioFormat: 'm4a', quality: '192K'),
    DownloadFormat.mp3High =>
      (selector: 'bestaudio/best', audioFormat: 'mp3', quality: '320K'),
    DownloadFormat.mp3Low =>
      (selector: 'bestaudio/best', audioFormat: 'mp3', quality: '192K'),
  };
}

/// Command-line for downloading one video or track ([url]) with the desktop `yt-dlp`.
/// [jsArgs] are the `--js-runtimes` flags found on this machine.
List<String> buildDownloadArgs({
  required String url,
  required String stem,
  required bool hasFfmpeg,
  required DownloadOptions options,
  List<String> jsArgs = const [],
}) {
  final rate = options.rateLimitKBps;
  final choice = downloadChoice(options.format, hasFfmpeg: hasFfmpeg, selector: options.selector);
  final audioFormat = choice.audioFormat;
  return [
    '--no-playlist',
    '--no-warnings',
    '--newline',
    '--no-part',
    '--progress-template',
    'download:PROG %(progress.downloaded_bytes)s '
        '%(progress.total_bytes)s %(progress.total_bytes_estimate)s',
    // --print implies --quiet; --progress keeps the PROG lines.
    if (options.emitStreamUrl) ...[
      '--progress',
      '--print',
      'before_dl:$streamUrlPrefix%(urls)s',
      '--print',
      'before_dl:$streamHeadersPrefix%(http_headers)j',
    ],
    ...jsArgs,
    if (rate != null && rate > 0) ...['--limit-rate', '${rate}K'],
    '-f',
    choice.selector,
    if (hasFfmpeg) '-x',
    if (audioFormat != null) ...[
      '--audio-format',
      audioFormat,
      '--audio-quality',
      choice.quality ?? '192K',
    ],
    '-o',
    '$stem.%(ext)s',
    url,
  ];
}

/// Extension to reserve in [uniquePath]: the converted format, else what the
/// audio usually is as served (Opus once extracted, m4a without ffmpeg). Pair
/// it with [anyDownloadExtensionExists] for the uniqueness check.
String reservedExtension({required bool hasFfmpeg, required DownloadOptions options}) =>
    downloadChoice(options.format, hasFfmpeg: hasFfmpeg, selector: options.selector).audioFormat ??
    (hasFfmpeg ? 'opus' : 'm4a');

/// True when `<stem>.<ext>` exists for any container a download can produce,
/// so the original format cannot overwrite a file saved with another extension.
bool anyDownloadExtensionExists(String path, bool Function(String) exists) {
  final dot = path.lastIndexOf('.');
  final stem = dot < 0 ? path : path.substring(0, dot);
  return downloadExtensions.any((e) => exists('$stem.$e'));
}

const streamUrlPrefix = 'CODECORE_URL ';
const streamHeadersPrefix = 'CODECORE_HDR ';

/// Reads the marked lines of one download and reports the stream address
/// once, when both the URL and the headers have arrived. Anything broken
/// gives no event: the download goes on as without it.
class StreamUrlLines {
  Uri? _url;
  bool _done = false;

  /// True for lines this parser owns (they are not download progress).
  static bool isMarked(String line) =>
      line.startsWith(streamUrlPrefix) || line.startsWith(streamHeadersPrefix);

  DownloadProgress? add(String line) {
    if (_done) return null;
    if (line.startsWith(streamUrlPrefix)) {
      // Several addresses come on following lines (ignored): the first wins.
      final u = Uri.tryParse(line.substring(streamUrlPrefix.length).trim());
      if (_url == null && u != null && u.isAbsolute && u.scheme == 'https') {
        _url = u;
      }
      return null;
    }
    if (!line.startsWith(streamHeadersPrefix) || _url == null) return null;
    _done = true;
    try {
      final j = jsonDecode(line.substring(streamHeadersPrefix.length));
      if (j is! Map || j.values.any((v) => v is! String)) return null;
      return DownloadProgress(
        streamUrl: _url,
        headers: j.cast<String, String>(),
      );
    } on FormatException {
      return null;
    }
  }
}
