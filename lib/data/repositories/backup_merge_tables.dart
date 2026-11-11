import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../services/backup/backup_db_reader.dart';
import '../../services/backup/track_resolver.dart';
import '../db/app_database.dart';
import 'track_repository.dart';

class TablesMergeReport {
  int playsAdded = 0;

  /// Plays whose track is not on this device: skipped (D-546).
  int playsUnlinked = 0;
  int tagsAdded = 0;
  int trackTagsAdded = 0;
  int smartPlaylistsAdded = 0;
  int podcastsAdded = 0;
  int episodesAdded = 0;
  int coversLinked = 0;

  /// The backup's database could not be read: none of the above was merged.
  bool backupDbUnreadable = false;
}

/// Adds the listening history, tags, smart playlists and podcasts of the
/// backup's database to [db]. Safe to run twice: nothing already there is added.
Future<TablesMergeReport> mergeBackupTables(
  AppDatabase db,
  File backupDb,
  TrackResolver resolver, {
  Directory? coversDir,
}) async {
  // Synchronous sqlite I/O: off the UI isolate. The data is plain maps and TrackRefs.
  final data = await readBackupDbOffThread(backupDb);
  final report = TablesMergeReport()..backupDbUnreadable = data.unreadable;
  final repo = TrackRepository(db);
  return db.transaction(() async {
    // Backup track id -> local id; unresolved ones are left out. A streamed track
    // maps to its existing shadow row only: none is created here (D-546).
    final tracks = <int, int>{};
    for (final e in data.refs.entries) {
      final key = e.value.streamKey;
      final local = key == null ? resolver.resolve(e.value) : (await repo.streamRow(key))?.id;
      if (local != null) tracks[e.key] = local;
    }
    await _plays(db, data, tracks, report);
    await _tags(db, data, tracks, report);
    await _smartPlaylists(db, data, report);
    await _podcasts(db, data, tracks, report);
    await _covers(db, data, tracks, coversDir, report);
    return report;
  });
}

Future<void> _plays(AppDatabase db, BackupDbData data, Map<int, int> tracks, TablesMergeReport report) async {
  final seen = {
    for (final r in await db.select(db.plays).get()) (r.trackId, r.playedAt),
  };
  for (final r in data.plays) {
    final local = tracks[r['track_id']];
    final at = r['played_at'] as int?;
    if (local == null) {
      report.playsUnlinked++;
      continue;
    }
    if (at == null || !seen.add((local, at))) continue;
    await db.into(db.plays).insert(PlaysCompanion.insert(
          trackId: local,
          playedAt: at,
          msPlayed: Value((r['ms_played'] as int?) ?? 0),
          context: Value(r['context'] as int?),
          contextName: Value(r['context_name'] as String?),
        ));
    report.playsAdded++;
  }
}

Future<void> _tags(AppDatabase db, BackupDbData data, Map<int, int> tracks, TablesMergeReport report) async {
  final byName = {for (final t in await db.select(db.userTags).get()) t.name.toLowerCase(): t.id};
  final tagIds = <int, int>{}; // backup tag id -> local tag id
  for (final r in data.userTags) {
    final name = (r['name'] as String?)?.trim();
    if (name == null || name.isEmpty) continue;
    var id = byName[name.toLowerCase()];
    if (id == null) {
      id = await db.into(db.userTags).insert(UserTagsCompanion.insert(name: name, color: Value(r['color'] as int?)));
      byName[name.toLowerCase()] = id;
      report.tagsAdded++;
    }
    tagIds[r['id'] as int] = id;
  }
  final have = {
    for (final r in await db.select(db.trackTags).get()) (r.trackId, r.tagId),
  };
  for (final r in data.trackTags) {
    final track = tracks[r['track_id']], tag = tagIds[r['tag_id']];
    if (track == null || tag == null || !have.add((track, tag))) continue;
    await db.into(db.trackTags).insert(TrackTagsCompanion.insert(trackId: track, tagId: tag));
    report.trackTagsAdded++;
  }
}

Future<void> _smartPlaylists(AppDatabase db, BackupDbData data, TablesMergeReport report) async {
  final local = [for (final s in await db.select(db.smartPlaylists).get()) (s.name, s.rules)];
  final names = {for (final s in local) s.$1};
  for (final r in data.smartPlaylists) {
    final name = r['name'] as String?, rules = r['rules'] as String?;
    if (name == null || rules == null) continue;
    // A renamed copy («name (ripristinata N)») of the same rules counts as the same one.
    final same = local.any(
      (s) => s.$2 == rules && (s.$1 == name || s.$1.startsWith('$name (ripristinata')),
    );
    if (same) continue;
    var unique = name;
    if (names.contains(unique)) {
      unique = '$name (ripristinata)';
      for (var n = 2; names.contains(unique); n++) {
        unique = '$name (ripristinata $n)';
      }
    }
    names.add(unique);
    await db.into(db.smartPlaylists).insert(SmartPlaylistsCompanion.insert(
          name: unique,
          rules: rules,
          sort: Value(r['sort'] as String?),
          limitCount: Value(r['limit_count'] as int?),
          createdAt: (r['created_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
        ));
    local.add((unique, rules));
    report.smartPlaylistsAdded++;
  }
}

Future<void> _podcasts(AppDatabase db, BackupDbData data, Map<int, int> tracks, TablesMergeReport report) async {
  final byFeed = {for (final r in await db.select(db.podcasts).get()) r.feedUrl: r.id};
  final ids = <int, int>{}; // backup podcast id -> local id
  for (final r in data.podcasts) {
    final feed = r['feed_url'] as String?;
    if (feed == null) continue;
    var id = byFeed[feed];
    if (id == null) {
      id = await db.into(db.podcasts).insert(PodcastsCompanion.insert(
            feedUrl: feed,
            title: (r['title'] as String?) ?? feed,
            author: Value(r['author'] as String?),
            imageUrl: Value(r['image_url'] as String?),
            coverKey: Value(r['cover_key'] as String?),
            language: Value(r['language'] as String?),
            lastCheckedAt: Value(r['last_checked_at'] as int?),
            autoDeleteDays: Value(r['auto_delete_days'] as int?),
            addedAt: (r['added_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
            source: Value((r['source'] as int?) ?? 0),
            sourceId: Value(r['source_id'] as String?),
            followed: Value((r['followed'] as int?) != 0),
          ));
      byFeed[feed] = id;
      report.podcastsAdded++;
    }
    ids[r['id'] as int] = id;
  }

  final local = {
    for (final e in await db.select(db.podcastEpisodes).get()) (e.podcastId, e.guid): e,
  };
  for (final r in data.podcastEpisodes) {
    final podcast = ids[r['podcast_id']], guid = r['guid'] as String?, audio = r['audio_url'] as String?;
    if (podcast == null || guid == null || audio == null) continue;
    final played = (r['played'] as int?) == 1, playedAt = r['played_at'] as int?;
    final track = tracks[r['track_id']];
    final here = local[(podcast, guid)];
    if (here != null) {
      // The furthest progress wins: played stays played, the latest date is kept.
      final nowPlayed = here.played || played;
      final nowAt = [here.playedAt, playedAt].whereType<int>().fold<int?>(null, (m, v) => m == null || v > m ? v : m);
      final nowTrack = here.trackId ?? track;
      if (nowPlayed != here.played || nowAt != here.playedAt || nowTrack != here.trackId) {
        await (db.update(db.podcastEpisodes)..where((e) => e.id.equals(here.id))).write(PodcastEpisodesCompanion(
          played: Value(nowPlayed),
          playedAt: Value(nowAt),
          trackId: Value(nowTrack),
        ));
      }
      continue;
    }
    await db.into(db.podcastEpisodes).insert(PodcastEpisodesCompanion.insert(
          podcastId: podcast,
          guid: guid,
          title: (r['title'] as String?) ?? guid,
          audioUrl: audio,
          publishedAt: Value(r['published_at'] as int?),
          durationMs: Value(r['duration_ms'] as int?),
          mimeType: Value(r['mime_type'] as String?),
          sizeBytes: Value(r['size_bytes'] as int?),
          description: Value(r['description'] as String?),
          trackId: Value(track),
          played: Value(played),
          playedAt: Value(playedAt),
        ));
    report.episodesAdded++;
  }
}

/// Old backups carry no portable cover list: the automatic cover is found by
/// the key the backup's row had, when its file came along.
Future<void> _covers(
  AppDatabase db,
  BackupDbData data,
  Map<int, int> tracks,
  Directory? coversDir,
  TablesMergeReport report,
) async {
  if (coversDir == null) return;
  for (final r in data.tracks) {
    final key = r['cover_key'] as String?;
    final local = tracks[r['id']];
    if (key == null || local == null || key != p.basename(key)) continue;
    if (!['jpg', 'png', 'webp'].any((e) => File(p.join(coversDir.path, '$key.$e')).existsSync())) continue;
    final t = await (db.select(db.tracks)..where((x) => x.id.equals(local))).getSingleOrNull();
    if (t == null || t.hasCover || t.coverKey != null) continue;
    await (db.update(db.tracks)..where((x) => x.id.equals(local))).write(TracksCompanion(
      coverKey: Value(key),
      hasCover: const Value(true),
      coverSource: Value((r['cover_source'] as int?) ?? 0),
    ));
    report.coversLinked++;
  }
}
