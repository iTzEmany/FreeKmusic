import '../../data/db/app_database.dart' show Track;
import '../online/youtube_service.dart';

const _prefix = 'stream:';

/// Library path of a streamed track's shadow row.
String streamPathOf(String key) => '$_prefix$key';

/// The cache key of a `stream:<key>` path, or null for any other path. The `#cc-ep=<id>` fragment
/// (the row of a second episode on the same video) is no part of the key.
String? keyOfStreamPath(String path) {
  if (!path.startsWith(_prefix)) return null;
  final key = path.substring(_prefix.length);
  final hash = key.indexOf('#');
  return hash < 0 ? key : key.substring(0, hash);
}

/// File name of [key] inside the cache folder.
String streamFileName(String key) => key.replaceAll(':', '_');

/// The artist shown for [r]: its credited artists, else the channel.
String displayArtist(YtResult r) =>
    r.artists.isEmpty ? r.channel : r.artists.join(', ');

/// The download request of a shadow row, rebuilt from its [key] and the row;
/// the inverse of [YtResult.indexKey].
/// shortcut: the row keeps no artist ids, thumbnail or page address (a SoundCloud row can't be re-downloaded), fix with the first SoundCloud stream.
YtResult streamResultOfRow(String key, Track row) => streamResultOf(
  key,
  title: row.title,
  artist: row.artist,
  album: row.album,
  durationMs: row.durationMs,
);

/// [streamResultOfRow] from the plain fields a row (or a backup reference) keeps.
YtResult streamResultOf(
  String key, {
  required String title,
  String? artist,
  String? album,
  int durationMs = 0,
}) {
  final sep = key.indexOf(':');
  final source = MediaSource.values.firstWhere(
    (m) => m.name == key.substring(0, sep),
    orElse: () => MediaSource.youtube,
  );
  return YtResult(
    id: key.substring(sep + 1),
    title: title,
    channel: artist ?? '',
    artists: artist == null ? const [] : [artist],
    album: album,
    duration: durationMs > 0 ? Duration(milliseconds: durationMs) : null,
    source: source,
  );
}

/// True for a well-formed `<source>:<id>` stream key (what [streamResultOf] needs).
bool isStreamKey(String key) {
  final sep = key.indexOf(':');
  return sep > 0 && sep < key.length - 1 && MediaSource.values.any((m) => m.name == key.substring(0, sep));
}
