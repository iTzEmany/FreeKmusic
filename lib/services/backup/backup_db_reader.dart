import 'dart:io';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import '../../core/app_log.dart';
import '../../data/repositories/track_kinds.dart';
import '../stream/stream_key.dart';
import 'package:path/path.dart' as p;
import 'user_data.dart';

typedef BackupRow = Map<String, Object?>;

/// Plain rows of the tables a backup's `codecore.sqlite` carries, read once.
/// The file may come from an older schema: a missing table is an empty list
/// and a missing column is simply absent from the row (reads as null).
class BackupDbData {
  BackupDbData({
    this.tracks = const [],
    this.plays = const [],
    this.userTags = const [],
    this.trackTags = const [],
    this.smartPlaylists = const [],
    this.podcasts = const [],
    this.podcastEpisodes = const [],
    this.refs = const {},
    this.unreadable = false,
  });

  /// Rows with `id`, `cover_key`, `cover_source`, `has_cover`.
  final List<BackupRow> tracks;
  final List<BackupRow> plays;
  final List<BackupRow> userTags;
  final List<BackupRow> trackTags;
  final List<BackupRow> smartPlaylists;
  final List<BackupRow> podcasts;
  final List<BackupRow> podcastEpisodes;

  /// Portable reference of every backup track, by the backup's track id.
  final Map<int, TrackRef> refs;

  /// The file could not be opened or read: the lists are empty.
  final bool unreadable;
}

const _columns = <String, List<String>>{
  'plays': ['track_id', 'played_at', 'ms_played', 'context', 'context_name'],
  'user_tags': ['id', 'name', 'color'],
  'track_tags': ['track_id', 'tag_id'],
  'smart_playlists': ['name', 'rules', 'sort', 'limit_count', 'created_at'],
  'podcasts': [
    'id', 'feed_url', 'title', 'author', 'image_url', 'cover_key', 'language',
    'last_checked_at', 'auto_delete_days', 'added_at', 'source', 'source_id', 'followed',
  ],
  'podcast_episodes': [
    'podcast_id', 'guid', 'title', 'published_at', 'duration_ms', 'audio_url', 'mime_type',
    'size_bytes', 'description', 'track_id', 'played', 'played_at',
  ],
  'tracks': [
    'id', 'path', 'folder_id', 'title', 'artist', 'duration_ms', 'sha256', 'kind',
    'cover_key', 'cover_source', 'has_cover',
  ],
  'folders': ['id', 'path'],
};

/// [readBackupDb] off the UI isolate (here, so the closure captures only [file]).
Future<BackupDbData> readBackupDbOffThread(File file) => Isolate.run(() => readBackupDb(file));

BackupDbData readBackupDb(File file) {
  Database? db;
  try {
    db = sqlite3.open(file.path, mode: OpenMode.readOnly);
    List<BackupRow> rows(String table) => _rows(db!, table, _columns[table]!);
    final folders = {for (final f in rows('folders')) f['id'] as int: f['path'] as String};
    final tracks = rows('tracks');
    return BackupDbData(
      tracks: tracks,
      plays: rows('plays'),
      userTags: rows('user_tags'),
      trackTags: rows('track_tags'),
      smartPlaylists: rows('smart_playlists'),
      podcasts: rows('podcasts'),
      podcastEpisodes: rows('podcast_episodes'),
      refs: {for (final t in tracks) t['id'] as int: _refOf(t, folders)},
    );
  } catch (e, st) {
    AppLog.e('backup db unreadable', e, st);
    return BackupDbData(unreadable: true);
  } finally {
    db?.close();
  }
}

List<BackupRow> _rows(Database db, String table, List<String> wanted) {
  final have = {for (final c in db.select('PRAGMA table_info($table)')) c['name'] as String};
  final cols = [for (final c in wanted) if (have.contains(c)) c];
  if (cols.isEmpty) return const [];
  return [for (final r in db.select('SELECT ${cols.join(', ')} FROM $table')) {...r}];
}

// Same shape as trackRefFor (backup_queries.dart), but from raw rows.
TrackRef _refOf(BackupRow t, Map<int, String> folders) {
  final path = (t['path'] as String?) ?? '';
  final title = (t['title'] as String?) ?? '';
  final artist = t['artist'] as String?;
  final duration = (t['duration_ms'] as int?) ?? 0;
  final streamKey = t['kind'] == kStreamKind ? keyOfStreamPath(path) : null;
  if (streamKey != null) {
    return TrackRef(streamKey: streamKey, title: title, artist: artist, durationMs: duration);
  }
  final root = folders[t['folder_id']];
  final inside = root != null && p.isWithin(root, path);
  return TrackRef(
    folder: inside ? root : path,
    relPath: inside ? p.relative(path, from: root).replaceAll(r'\', '/') : null,
    title: title,
    artist: artist,
    durationMs: duration,
    sha256: t['sha256'] as String?,
  );
}
