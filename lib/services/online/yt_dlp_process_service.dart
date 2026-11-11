import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../core/text_utils.dart';
import 'yt_dlp_args.dart';
import 'yt_dlp_version.dart';
import 'youtube_service.dart';

/// Parses `yt-dlp -J --flat-playlist` output (a playlist or a single video).
List<YtResult> parseYtDlpJson(String raw) {
  final data = jsonDecode(raw);
  if (data is! Map) return const [];
  return _results(data['entries'] is List ? data['entries'] as List : [data]);
}

const _unavailableTitles = {'[private video]', '[deleted video]'};
final _tabSuffix = RegExp(r'\s+-\s+(Videos|Video|Vídeos|Vidéos)$');

/// Parses `yt-dlp -J --flat-playlist` of a playlist page or a channel's Videos
/// tab. Private and deleted videos are counted, not listed; a video without a
/// channel of its own gets the playlist's, so its «Artist - Title» can be read.
PlaylistListing parsePlaylistListing(String raw, {int limit = 500}) {
  final data = jsonDecode(raw);
  if (data is! Map) return const PlaylistListing.empty();
  final owner = '${data['channel'] ?? data['uploader'] ?? ''}'.trim();
  final entries = data['entries'] is List ? data['entries'] as List : const [];
  var unavailable = 0;
  final playable = <Map>[];
  for (final entry in entries) {
    if (entry is! Map) continue;
    if (_unavailableTitles.contains('${entry['title']}'.toLowerCase())) {
      unavailable++;
      continue;
    }
    playable.add(owner.isNotEmpty && entry['channel'] == null && entry['uploader'] == null
        ? {...entry, 'channel': owner}
        : entry);
  }
  final title = htmlUnescape('${data['title'] ?? ''}').replaceFirst(_tabSuffix, '').trim();
  return PlaylistListing(
    title: title,
    owner: owner.isEmpty ? null : htmlUnescape(owner),
    entries: _results(playable),
    unavailable: unavailable,
    truncated: entries.length >= limit,
  );
}

List<YtResult> _results(List entries) {
  final out = <YtResult>[];
  for (final e in entries) {
    if (e is! Map) continue;
    final id = e['id'] as String?;
    final rawTitle = e['title'] as String?;
    if (id == null || rawTitle == null) continue;
    final title = htmlUnescape(rawTitle);
    final source = _sourceOf(e);
    final page = e['webpage_url'];
    // Without a page a SoundCloud track has no address to download from.
    if (source != MediaSource.youtube && (page is! String || page.isEmpty)) {
      continue;
    }
    // The smallest picture that fills a result row, not the biggest yt-dlp
    // lists first (1280×720 for a video, the original artwork on SoundCloud).
    String? thumb = source == MediaSource.youtube
        ? smallVideoThumbnail(id)
        : smallestThumbnail(e['thumbnails']) ?? e['thumbnail'] as String?;
    final thumbs = e['thumbnails'];
    if (thumb == null && thumbs is List && thumbs.isNotEmpty) {
      final last = thumbs.last;
      if (last is Map) thumb = last['url'] as String?;
    }
    final artists = [
      for (final a in (e['artists'] is List ? e['artists'] as List : const []))
        if (a is String && a.trim().isNotEmpty) a.trim(),
    ];
    final d = e['duration'];
    out.add(YtResult(
      id: id,
      title: title,
      channel: htmlUnescape((e['channel'] ??
          e['uploader'] ??
          (artists.isEmpty ? '' : artists.first)) as String),
      duration: d is num ? Duration(seconds: d.round()) : null,
      thumbnailUrl: thumb,
      artists: artists,
      album: e['album'] as String?,
      source: source,
      webpageUrl: source == MediaSource.youtube ? null : page as String,
    ));
  }
  return out;
}

/// `extractor_key` (full metadata) or `ie_key` (flat listing) says where an
/// entry comes from; anything that is not SoundCloud is treated as YouTube.
MediaSource _sourceOf(Map e) {
  final key = '${e['extractor_key'] ?? e['ie_key'] ?? ''}'.toLowerCase();
  return key.startsWith('soundcloud') ? MediaSource.soundcloud : MediaSource.youtube;
}

/// Album page links from a flat YouTube Music album search.
List<YtResult> parseYtAlbumLinks(String raw) {
  final data = jsonDecode(raw);
  if (data is! Map || data['entries'] is! List) return const [];
  return [
    for (final e in data['entries'] as List)
      if (e is Map &&
          '${e['url'] ?? ''}'.startsWith('https://music.youtube.com/browse/'))
        YtResult(
            id: '${e['url']}',
            title: '${e['url']}',
            channel: '',
            duration: null),
  ];
}

final _albumPagePrefix = RegExp(r'^(Album|EP|Single)\s+-\s+');
final _topicSuffix = RegExp(r'\s+-\s+Topic$');

/// The tracks of a YouTube Music album page read with `--flat-playlist`: one
/// request for the whole page instead of one per track (a 24-track album took
/// 64 s in full, 4.5 s flat). Flat entries carry no album nor artists: the
/// album is the page title («Album - Name», «EP - …», «Single - …») and the
/// artist the «Artist - Topic» channel.
List<YtResult> parseYtAlbumPage(String raw) {
  final data = jsonDecode(raw);
  if (data is! Map) return const [];
  final album = htmlUnescape('${data['title'] ?? ''}').replaceFirst(_albumPagePrefix, '').trim();
  final entries = data['entries'] is List ? data['entries'] as List : const [];
  return [
    for (final r in _results(entries))
      YtResult(
        id: r.id,
        title: r.title,
        channel: r.channel,
        duration: r.duration,
        thumbnailUrl: r.thumbnailUrl,
        artists: r.artists.isNotEmpty || !_topicSuffix.hasMatch(r.channel)
            ? r.artists
            : [r.channel.replaceFirst(_topicSuffix, '')],
        album: r.album ?? (album.isEmpty ? null : album),
        source: r.source,
        webpageUrl: r.webpageUrl,
      ),
  ];
}

/// Parses a line produced by our `--progress-template`:
/// `PROG <downloaded> <total> <estimate>` ("NA" when unknown).
DownloadProgress? parseProgressLine(String line) {
  if (!line.startsWith('PROG ')) return null;
  final parts = line.trim().split(RegExp(r'\s+'));
  if (parts.length < 4) return null;
  int? n(String s) => int.tryParse(s) ?? double.tryParse(s)?.round();
  final done = n(parts[1]) ?? 0;
  final total = n(parts[2]) ?? n(parts[3]) ?? 0;
  return DownloadProgress(received: done, total: total);
}

/// The yt-dlp channel's own failures (Kotlin appends `| root: <class>: <msg>`
/// to internal Throwables), as opposed to yt-dlp's stderr.
bool isInternalChannelError(String msg) =>
    msg.contains('| root:') ||
    RegExp(r'NoClassDefFoundError|ExceptionInInitializerError|UnsatisfiedLinkError')
        .hasMatch(msg);

/// Maps yt-dlp's stderr to a user-facing error kind.
YtException ytExceptionFromStderr(String err) {
  if (isInternalChannelError(err)) return YtException(YtErrorKind.internal, err);
  final t = err.toLowerCase();
  if (t.contains('http error 429') ||
      t.contains('too many requests') ||
      (t.contains('confirm') && t.contains('not a bot'))) {
    return YtException(YtErrorKind.rateLimited, err);
  }
  if (t.contains('name or service') ||
      t.contains('no address associated') ||
      t.contains('network is unreachable') ||
      t.contains('temporary failure in name resolution') ||
      t.contains('timed out')) {
    return YtException(YtErrorKind.network, err);
  }
  if (t.contains('private video') ||
      t.contains('playlist does not exist') ||
      t.contains('playlist is private') ||
      t.contains('video unavailable') ||
      t.contains('not available') ||
      t.contains('sign in') ||
      t.contains('drm protected') ||
      t.contains('age-restricted')) {
    return YtException(YtErrorKind.unavailable, err);
  }
  return YtException(YtErrorKind.changed, err);
}

class YtDlpProcessService implements YoutubeService {
  /// [locate] picks the binary to run (first call only); without it, and
  /// without [executable], `yt-dlp` is taken from the PATH.
  YtDlpProcessService({
    this.executable,
    this.locate,
    this.searchTimeout = const Duration(seconds: 45),
  });

  /// A search that takes longer is killed and reported as a network error.
  final Duration searchTimeout;

  final String? executable;
  final Future<String?> Function()? locate;
  Future<String>? _resolved;

  Future<String> get _exe => _resolved ??=
      Future(() async => executable ?? await locate?.call() ?? 'yt-dlp');
  List<String>? _jsRuntimeArgs;
  bool? _hasFfmpeg;

  Future<bool> _exists(String exe) async {
    try {
      // ffmpeg only understands the single-dash form.
      final r = await Process.run(
          exe, [exe == 'ffmpeg' ? '-version' : '--version']);
      return r.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  Future<List<String>> _jsArgs() async {
    final cached = _jsRuntimeArgs;
    if (cached != null) return cached;
    // yt-dlp enables only Deno by default; enable any other runtime we find.
    final args = <String>[];
    for (final rt in const ['deno', 'node', 'bun', 'qjs']) {
      if (await _exists(rt)) {
        args.addAll(['--js-runtimes', rt == 'qjs' ? 'quickjs' : rt]);
      }
    }
    return _jsRuntimeArgs = args;
  }

  Future<String?>? _version;

  /// Forget the located binary and its version (after an in-app update).
  void refresh() {
    _resolved = null;
    _version = null;
  }

  @override
  Future<String?> toolVersion() => _version ??= () async {
        try {
          final r = await Process.run(await _exe, ['--version']);
          if (r.exitCode != 0) return null;
          return '${r.stdout}'.trim().split('\n').first.trim();
        } on ProcessException {
          return null;
        }
      }();

  /// A failure on an outdated yt-dlp is most likely YouTube having moved on.
  Future<YtException> _explain(Object stderr) async {
    final e = ytExceptionFromStderr('$stderr');
    final stale = e.kind == YtErrorKind.changed ||
        e.kind == YtErrorKind.unavailable;
    if (stale && isYtDlpOutdated(await toolVersion())) {
      return YtException(YtErrorKind.toolOutdated, e.detail);
    }
    return e;
  }

  /// Runs a search to the end or kills it after [searchTimeout].
  Future<({int code, String out, String err})> _runSearch(
      List<String> args, {Duration? timeout}) async {
    final proc = await Process.start(await _exe, args);
    final out = proc.stdout.transform(utf8.decoder).join();
    final err = proc.stderr.transform(utf8.decoder).join();
    try {
      final code = await proc.exitCode.timeout(timeout ?? searchTimeout);
      return (code: code, out: await out, err: await err);
    } on TimeoutException {
      proc.kill(ProcessSignal.sigkill);
      throw const YtException(YtErrorKind.network, 'search timed out');
    }
  }

  Future<void> _ensureTool() async {
    if (!await _exists(await _exe)) {
      throw const YtException(YtErrorKind.toolMissing, 'yt-dlp');
    }
  }

  @override
  Future<List<YtResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    await _ensureTool();
    final isUrl = isYoutubeUrl(q);
    final args = [
      '-J',
      '--no-warnings',
      if (isUrl) '--no-playlist' else '--flat-playlist',
      isUrl ? q : 'ytsearch10:$q',
    ];
    final r = await _runSearch(args);
    if (r.code != 0) throw await _explain(r.err);
    try {
      return parseYtDlpJson(r.out);
    } on FormatException catch (e, st) {
      AppLog.w('yt-dlp search output not JSON', e, st);
      throw const YtException(YtErrorKind.changed, 'bad output');
    }
  }

  @override
  Future<PlaylistListing> listPlaylist(String url, {int limit = 500}) async {
    await _ensureTool();
    // Listing 500 videos takes about 25 s, more than a search: a longer timeout.
    final r = await _runSearch([
      '-J',
      '--no-warnings',
      '--flat-playlist',
      '--playlist-items',
      '1-$limit',
      url,
    ], timeout: const Duration(seconds: 120));
    if (r.code != 0) throw await _explain(r.err);
    try {
      return parsePlaylistListing(r.out, limit: limit);
    } on FormatException catch (e, st) {
      AppLog.w('yt-dlp playlist output not JSON', e, st);
      throw const YtException(YtErrorKind.changed, 'bad output');
    }
  }

  @override
  Future<List<YtResult>> searchSongs(String query, {int limit = 5}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    await _ensureTool();
    final r = await _runSearch([
      '-J',
      '--no-warnings',
      '--playlist-items',
      '1-$limit',
      ...await _jsArgs(),
      youtubeMusicSearchUri(q).toString(),
    ]);
    if (r.code != 0) throw await _explain(r.err);
    try {
      return parseYtDlpJson(r.out);
    } on FormatException catch (e, st) {
      AppLog.w('yt-dlp music search output not JSON', e, st);
      throw const YtException(YtErrorKind.changed, 'bad output');
    }
  }

  @override
  Future<List<YtResult>> searchAlbums(String query, {int limit = 3}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    await _ensureTool();
    final r = await _runSearch([
      '-J',
      '--no-warnings',
      '--flat-playlist',
      '--playlist-items',
      '1-$limit',
      ...await _jsArgs(),
      youtubeMusicAlbumsUri(q).toString(),
    ]);
    if (r.code != 0) throw await _explain(r.err);
    try {
      return parseYtAlbumLinks(r.out);
    } on FormatException catch (e, st) {
      AppLog.w('yt-dlp album search output not JSON', e, st);
      throw const YtException(YtErrorKind.changed, 'bad output');
    }
  }

  @override
  Future<List<YtResult>> albumTracks(String albumLink) async {
    await _ensureTool();
    final r = await _runSearch([
      '-J',
      '--no-warnings',
      '--flat-playlist',
      '--playlist-items',
      '1-80',
      ...await _jsArgs(),
      albumLink,
    ]);
    if (r.code != 0) throw await _explain(r.err);
    try {
      return parseYtAlbumPage(r.out);
    } on FormatException catch (e, st) {
      AppLog.w('yt-dlp album page output not JSON', e, st);
      throw const YtException(YtErrorKind.changed, 'bad output');
    }
  }

  @override
  Stream<DownloadProgress> download(YtResult r, Directory outDir,
      {CancelToken? cancel,
      DownloadOptions options = const DownloadOptions()}) async* {
    await _ensureTool();
    await outDir.create(recursive: true);
    _hasFfmpeg ??= await _exists('ffmpeg');
    final hasFfmpeg = _hasFfmpeg!;
    final target = uniquePath(
        outDir.path,
        downloadBaseName(r),
        reservedExtension(hasFfmpeg: hasFfmpeg, options: options),
        (f) => anyDownloadExtensionExists(f, (x) => File(x).existsSync()));
    final stem = p.withoutExtension(target);
    final args = buildDownloadArgs(
      url: r.downloadUrl,
      stem: stem,
      hasFfmpeg: hasFfmpeg,
      options: options,
      jsArgs: await _jsArgs(),
    );
    final proc = await Process.start(await _exe, args);
    final err = StringBuffer();
    proc.stderr.transform(utf8.decoder).listen(err.write);
    final lines =
        proc.stdout.transform(utf8.decoder).transform(const LineSplitter());
    final cancelTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (cancel?.isCancelled ?? false) proc.kill();
    });
    final streamLines = StreamUrlLines();
    try {
      await for (final line in lines) {
        final prog = parseProgressLine(line) ?? streamLines.add(line);
        if (prog != null) yield prog;
      }
      final code = await proc.exitCode;
      if (cancel?.isCancelled ?? false) {
        await _cleanup(stem);
        return;
      }
      if (code != 0) {
        await _cleanup(stem);
        throw await _explain(err);
      }
      final out = await _findOutput(stem);
      if (out == null) throw const YtException(YtErrorKind.changed, 'no output');
      yield DownloadProgress(received: 1, total: 1, path: out);
    } finally {
      cancelTimer.cancel();
      proc.kill();
    }
  }

  Future<String?> _findOutput(String stem) async {
    final dir = Directory(p.dirname(stem));
    final base = p.basename(stem);
    await for (final e in dir.list()) {
      final name = p.basename(e.path);
      if (e is File && name.startsWith('$base.') && !name.endsWith('.part')) {
        return e.path;
      }
    }
    return null;
  }

  Future<void> _cleanup(String stem) async {
    final dir = Directory(p.dirname(stem));
    final base = p.basename(stem);
    await for (final e in dir.list()) {
      if (e is File && p.basename(e.path).startsWith('$base.')) {
        try {
          await e.delete();
        } on FileSystemException catch (err, st) {
          AppLog.w('cleanup failed: ${e.path}', err, st);
        }
      }
    }
  }

  @override
  void close() {}
}
