import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/clock.dart';
import '../../core/paths.dart';
import '../../core/uuid.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Bump with every migration step below.
const kSchemaVersion = 19;

@DriftDatabase(
  tables: [
    Tracks,
    Folders,
    Playlists,
    PlaylistTracks,
    PlaylistImports,
    PlaylistImportItems,
    Plays,
    SmartPlaylists,
    UserTags,
    TrackTags,
    Podcasts,
    PodcastEpisodes,
    ArtistInfos,
    RadioStations,
    FollowedArtists,
    ArtistReleases,
    ArtistLookups,
    TrackCredits,
    TrackEnrich,
    ActivityLogRows,
    TrackGenres,
    ArtistCountries,
    ArtistAliases,
    ArtistNotSame,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.production() : super(driftDatabase(
      name: 'codecore',
      native: DriftNativeOptions(databaseDirectory: databaseDir),
    ));

  @override
  int get schemaVersion => kSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.addColumn(playlists, playlists.coverKey);
      if (from < 3) await m.addColumn(tracks, tracks.replayGainDb);
      if (from < 4) {
        // Created from the current definition, v5 columns included.
        await m.createTable(playlistImports);
        await m.createTable(playlistImportItems);
      } else if (from < 5) {
        await m.addColumn(playlistImports, playlistImports.sourceKind);
        await m.addColumn(playlistImports, playlistImports.folderPath);
        await m.addColumn(playlistImports, playlistImports.numberFiles);
        await m.addColumn(playlistImports, playlistImports.linkOnly);
        await m.addColumn(playlistImports, playlistImports.planFirst);
        await m.addColumn(playlistImports, playlistImports.fetchCovers);
        await m.addColumn(playlistImportItems, playlistImportItems.note);
        await m.addColumn(playlistImportItems, playlistImportItems.location);
      }
      if (from < 6) await m.addColumn(tracks, tracks.resumePositionMs);
      if (from < 7) {
        // History, smart playlists and user tags: new tables, nothing
        // existing is touched.
        await m.createTable(plays);
        await m.createIndex(playsTrack);
        await m.createIndex(playsAt);
        await m.createTable(smartPlaylists);
        await m.createTable(userTags);
        await m.createTable(trackTags);
      }
      if (from < 8) await m.addColumn(tracks, tracks.ignored);
      if (from < 9) {
        // Podcasts: one column on tracks, two new tables; nothing existing
        // is touched and every existing track stays music (kind 0).
        await m.addColumn(tracks, tracks.kind);
        await m.createIndex(tracksKind);
        await m.createTable(podcasts);
        await m.createTable(podcastEpisodes);
        await m.createIndex(podcastEpisodesPodcast);
      }
      if (from < 10) {
        // Playlists get an identity that survives a sync, and a change
        // time (the creation time until the first change).
        await m.addColumn(playlists, playlists.uuid);
        await m.addColumn(playlists, playlists.updatedAt);
        await customStatement('UPDATE playlists SET updated_at = created_at');
        for (final row in await customSelect(
          'SELECT id FROM playlists',
        ).get()) {
          await customStatement('UPDATE playlists SET uuid = ? WHERE id = ?', [
            newUuid(),
            row.read<int>('id'),
          ]);
        }
        await m.createIndex(playlistsUuid);
      }
      if (from < 11) await m.createTable(artistInfos);
      if (from < 12) await m.createTable(radioStations);
      if (from < 13) {
        await m.createTable(followedArtists);
        await m.createTable(artistReleases);
        await m.createTable(artistLookups);
      }
      if (from < 14) {
        await m.addColumn(tracks, tracks.isrc);
        await m.createIndex(tracksIsrc);
        // Absent in a table just created from the current definition (from < 4).
        final itemCols = await customSelect(
          'PRAGMA table_info(playlist_import_items)',
        ).get();
        final names = itemCols.map((c) => c.read<String>('name')).toSet();
        if (names.isNotEmpty) {
          if (!names.contains('year')) {
            await m.addColumn(playlistImportItems, playlistImportItems.year);
          }
          // Temporary index: the correlated lookup below is by track_id.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS tmp_items_track ON playlist_import_items (track_id)',
          );
          // The latest import row linked to a track wins.
          await customStatement(
            'UPDATE tracks SET isrc = (SELECT i.isrc FROM playlist_import_items i '
            'JOIN playlist_imports m ON m.id = i.import_id '
            "WHERE i.track_id = tracks.id AND i.isrc IS NOT NULL AND i.isrc <> '' "
            'ORDER BY m.created_at DESC, m.id DESC, i.row_index DESC LIMIT 1) '
            "WHERE (isrc IS NULL OR isrc = '') AND id IN (SELECT track_id "
            "FROM playlist_import_items WHERE isrc IS NOT NULL AND isrc <> '')",
          );
          await customStatement('DROP INDEX IF EXISTS tmp_items_track');
        }
      }
      if (from < 15) {
        await m.addColumn(tracks, tracks.coverSource);
        await m.createTable(trackCredits);
        await m.createIndex(trackCreditsNameKey);
        await m.createTable(trackEnrich);
        await m.createTable(activityLogRows);
        await m.createIndex(activityLogAt);
        // Old test fixtures have a bare tracks table.
        final cols = await customSelect('PRAGMA table_info(tracks)').get();
        final names = cols.map((c) => c.read<String>('name')).toSet();
        if (names.containsAll([
          'enrich_status',
          'user_edited',
          'lyrics_plain',
          'lyrics_synced',
        ])) {
          // "Not found" (status 2) becomes a dated mark (D-103).
          const noLyrics =
              "COALESCE(lyrics_plain, '') = '' AND COALESCE(lyrics_synced, '') = ''";
          final now = nowMs();
          await customStatement(
            'INSERT INTO track_enrich (track_id, meta_none_at, lyrics_none_at) '
            'SELECT id, ?, CASE WHEN $noLyrics THEN ? END '
            'FROM tracks WHERE enrich_status = 2',
            [now, now],
          );
          // Hand-edited lyrics are never overwritten by enrichment (D-121).
          await customStatement(
            'INSERT INTO track_enrich (track_id, lyrics_by_user) '
            'SELECT id, 1 FROM tracks WHERE user_edited = 1 AND NOT ($noLyrics) '
            'ON CONFLICT(track_id) DO UPDATE SET lyrics_by_user = 1',
          );
        }
      }
      if (from < 16) {
        await m.createTable(trackGenres);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS track_genres_genre ON track_genres (genre)',
        );
        await m.createTable(artistCountries);
      }
      if (from < 17) {
        await m.createTable(artistAliases);
        await m.createTable(artistNotSame);
      }
      if (from < 18) {
        // Existing podcasts keep source 0 (RSS) through the column default.
        // A table made by the step for < 9 above already has them (created from today's definition).
        final cols = {
          for (final c in await customSelect(
            "PRAGMA table_info('podcasts')",
          ).get())
            c.read<String>('name'),
        };
        if (cols.isNotEmpty && !cols.contains('source')) {
          await m.addColumn(podcasts, podcasts.source);
          await m.addColumn(podcasts, podcasts.sourceId);
        }
      }
      if (from < 19) {
        // Existing podcasts stay followed (column default); a table just created above already has it.
        final cols = {
          for (final c in await customSelect(
            "PRAGMA table_info('podcasts')",
          ).get())
            c.read<String>('name'),
        };
        if (cols.isNotEmpty && !cols.contains('followed')) {
          await m.addColumn(podcasts, podcasts.followed);
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
