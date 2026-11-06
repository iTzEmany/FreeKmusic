import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../core/text_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/podcast_repository.dart';
import '../../data/repositories/track_repository.dart';
import '../covers/cover_store.dart';
import '../online/http_client.dart';
import '../online/yt_dlp_args.dart' show podcastAudioSelector;
import '../online/youtube_service.dart';
import 'ytm_podcast_sync.dart' show kPodcastSourceYtm;
import '../tags/tag_reader.dart';
import 'podcast_models.dart';

/// The audio containers an episode may come in, by the extension we save it as.
const episodeExtensions = {'mp3', 'm4a', 'ogg', 'opus'};

/// `mp3`, `m4a`, `ogg` or `opus` from what the server says, else from the
/// address, else from what the feed said; null when none of them is known.
String? episodeExtension({String? contentType, String? url, String? mime}) {
  String? fromMime(String? m) {
    final t = (m ?? '').toLowerCase().split(';').first.trim();
    return switch (t) {
      'audio/mpeg' || 'audio/mp3' || 'audio/mpeg3' || 'audio/x-mpeg' => 'mp3',
      'audio/mp4' || 'audio/x-m4a' || 'audio/m4a' || 'audio/aac' || 'audio/x-aac' => 'm4a',
      'audio/ogg' || 'application/ogg' || 'audio/vorbis' => 'ogg',
      'audio/opus' => 'opus',
      _ => null,
    };
  }

  String? fromUrl(String? u) {
    final path = Uri.tryParse(u ?? '')?.path ?? '';
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (ext == 'mp4') return 'm4a';
    return episodeExtensions.contains(ext) ? ext : null;
  }

  return fromMime(contentType) ?? fromUrl(url) ?? fromMime(mime);
}

/// A file name that is safe on every system and unique per `guid`: the readable
/// part of the guid, cut short, and a few letters of its hash.
String episodeFileStem(String guid) {
  final readable = sanitizeFileName(guid.replaceAll(RegExp(r'^[a-z]+://'), ''));
  final cut = readable.length > 48 ? readable.substring(0, 48) : readable;
  final hash = sha1.convert(utf8.encode(guid)).toString().substring(0, 8);
  return '${cut.isEmpty || cut == 'track' ? 'episode' : cut}-$hash';
}

/// Downloads episodes into `<baseDir>/<podcastId>/`, a folder the music scan
/// never looks at, and makes each one a track (kind 1) the player can queue.
class EpisodeDownloader {
  EpisodeDownloader({
    required this.repo,
    required this.tracks,
    required this.tags,
    required this.baseDir,
    Dio? dio,
    this.readTagsInIsolate = true,
    this.youtube,
  }) : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
              headers: {'User-Agent': DioWebClient.userAgent},
              validateStatus: (_) => true,
            ));

  final PodcastRepository repo;
  final TrackRepository tracks;
  final TagReader tags;

  /// `<appSupportDir>/podcasts`. Nothing outside it is ever written or deleted.
  final String baseDir;
  final Dio _dio;
  final bool readTagsInIsolate;

  /// yt-dlp, for the episodes of YouTube Music shows (audio only).
  final YoutubeService? youtube;

  bool _inside(String path) => p.isWithin(baseDir, path);

  /// Downloads the episode and returns the id of its track, or null when it was
  /// cancelled (no file is left). [onProgress] gets (received, total); total is
  /// -1 when nobody knows it. Already downloaded: returns the existing track.
  Future<int?> download(
    int episodeId, {
    CancelToken? cancel,
    void Function(int received, int total)? onProgress,
  }) async {
    final episode = await repo.episodeById(episodeId);
    if (episode == null) return null;
    final existing = episode.trackId == null ? null : await tracks.getById(episode.trackId!);
    if (existing != null && File(existing.path).existsSync()) return existing.id;
    final podcast = await repo.byId(episode.podcastId);
    if (podcast == null) return null;
    if (podcast.source == kPodcastSourceYtm) {
      return _downloadYtm(episode, podcast, cancel: cancel, onProgress: onProgress);
    }

    final Response<ResponseBody> res;
    try {
      res = await _dio.get<ResponseBody>(
        episode.audioUrl,
        cancelToken: cancel,
        options: Options(responseType: ResponseType.stream, followRedirects: true),
      );
    } on DioException catch (e, st) {
      if (CancelToken.isCancel(e)) return null;
      AppLog.w('episode request failed: ${episode.audioUrl}', e, st);
      throw PodcastException(PodcastErrorKind.network, e.message);
    }
    final code = res.statusCode ?? 0;
    final body = res.data;
    if (code != 200 || body == null) {
      throw PodcastException(PodcastErrorKind.network, 'HTTP $code');
    }
    final type = res.headers.value('content-type');
    final ext = episodeExtension(contentType: type, url: episode.audioUrl, mime: episode.mimeType);
    if (ext == null) {
      throw PodcastException(PodcastErrorKind.unsupportedFormat, type ?? episode.audioUrl);
    }

    final dir = Directory(p.join(baseDir, '${podcast.id}'));
    await dir.create(recursive: true);
    final target = p.join(dir.path, '${episodeFileStem(episode.guid)}.$ext');
    final part = File('$target.part');
    final total = int.tryParse(res.headers.value('content-length') ?? '') ?? episode.sizeBytes ?? -1;
    var received = 0;
    final sink = part.openWrite();
    try {
      await for (final chunk in body.stream) {
        if (cancel?.isCancelled ?? false) break;
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
    } on DioException catch (e, st) {
      await sink.close();
      await _deleteQuietly(part);
      if (CancelToken.isCancel(e)) return null;
      AppLog.w('episode download failed: ${episode.audioUrl}', e, st);
      throw PodcastException(PodcastErrorKind.network, e.message);
    } on Object catch (e, st) {
      await sink.close();
      await _deleteQuietly(part);
      AppLog.w('episode write failed: $target', e, st);
      throw PodcastException(PodcastErrorKind.network, '$e');
    }
    await sink.close();
    if (cancel?.isCancelled ?? false) {
      await _deleteQuietly(part);
      return null;
    }
    if (received == 0) {
      await _deleteQuietly(part);
      throw const PodcastException(PodcastErrorKind.network, 'empty answer');
    }
    await part.rename(target);
    return _register(episode, podcast, target, ext);
  }

  /// Only the audio of the episode, with yt-dlp (the WEB_REMIX player says
  /// UNPLAYABLE, so nothing else is tried). The file stays as served (m4a or opus).
  Future<int?> _downloadYtm(PodcastEpisode episode, Podcast podcast,
      {CancelToken? cancel, void Function(int received, int total)? onProgress}) async {
    final yt = youtube;
    if (yt == null) {
      throw const PodcastException(PodcastErrorKind.unsupportedFormat, 'no yt-dlp');
    }
    final dir = Directory(p.join(baseDir, '${podcast.id}'));
    String? path;
    try {
      await for (final prog in yt.download(
        YtResult(
          id: episode.guid,
          title: episode.title,
          channel: podcast.title,
          duration: null,
          downloadName: episodeFileStem(episode.guid),
          webpageUrl: episode.audioUrl,
        ),
        dir,
        cancel: cancel,
        options: const DownloadOptions(selector: podcastAudioSelector),
      )) {
        if (prog.path != null) path = prog.path;
        onProgress?.call(prog.received, prog.total);
      }
    } on YtException catch (e, st) {
      AppLog.w('YouTube Music episode failed: ${episode.guid}', e, st);
      throw PodcastException(PodcastErrorKind.network, '$e');
    }
    if (path == null || (cancel?.isCancelled ?? false)) return null;
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    return _register(episode, podcast, path, ext);
  }

  /// Makes the saved file [target] a library track and links the episode to it.
  Future<int?> _register(PodcastEpisode episode, Podcast podcast, String target, String ext) async {
    final info = await _readTags(target);
    final st = await File(target).stat();
    final albumKey = podcastAlbumKeyOf(podcast.id);
    await tracks.upsertBatch([
      TracksCompanion.insert(
        path: target,
        title: episode.title,
        albumKey: albumKey,
        format: ext,
        sizeBytes: st.size,
        mtimeMs: st.modified.millisecondsSinceEpoch,
        addedAt: DateTime.now().millisecondsSinceEpoch,
        artist: Value(podcast.title),
        albumArtist: Value(podcast.title),
        album: Value(podcast.title),
        genre: const Value('Podcast'),
        durationMs: Value(info.durationMs ?? episode.durationMs ?? 0),
        bitrateKbps: Value(info.bitrateKbps),
        sampleRateHz: Value(info.sampleRateHz),
        hasCover: Value(podcast.coverKey != null),
        coverKey: Value(podcast.coverKey ?? CoverStore.coverKeyFor(albumKey)),
        kind: const Value(1),
      ),
    ]);
    final trackId = await tracks.idForPath(target);
    if (trackId == null) {
      throw const PodcastException(PodcastErrorKind.network, 'library row missing');
    }
    await repo.setTrackId(episode.id, trackId);
    return trackId;
  }

  Future<TagInfo> _readTags(String path) async {
    try {
      return readTagsInIsolate
          ? await Isolate.run(() => tags.read(path, withCover: false))
          : await tags.read(path, withCover: false);
    } on Object catch (e, st) {
      // A file without readable tags still plays: the feed's length stands in.
      AppLog.w('episode tags unreadable: $path', e, st);
      return const TagInfo();
    }
  }

  /// Deletes the episode's file and its library row; the episode stays listed,
  /// as «not downloaded». Only a file inside the podcast folder is ever deleted.
  Future<void> deleteFile(int episodeId) async {
    final episode = await repo.episodeById(episodeId);
    final trackId = episode?.trackId;
    if (episode == null || trackId == null) return;
    final track = await tracks.getById(trackId);
    if (track != null && track.kind == 1) {
      if (_inside(track.path)) {
        await _deleteQuietly(File(track.path));
      } else {
        AppLog.w('episode file outside the podcast folder, not deleted: ${track.path}');
      }
      await tracks.deleteTrack(trackId);
    }
    await repo.setTrackId(episodeId, null);
  }

  /// Leftovers of interrupted downloads (`*.part`) under [baseDir].
  Future<int> removeOrphanParts() async {
    final root = Directory(baseDir);
    if (!await root.exists()) return 0;
    var n = 0;
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is File && e.path.endsWith('.part') && _inside(e.path)) {
        await _deleteQuietly(e);
        n++;
      }
    }
    return n;
  }

  Future<void> _deleteQuietly(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } on FileSystemException catch (e, st) {
      AppLog.w('could not delete ${f.path}', e, st);
    }
  }
}

/// The albumKey every episode of a podcast shares (its cover hangs on it).
String podcastAlbumKeyOf(int podcastId) => 'podcast|$podcastId';
