import 'package:codecore/data/db/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Old databases are fabricated in memory by the setup callback, before drift
// reads their version: the migration is the same as on a file, without a disk
// sync per schema statement (seconds per test on a busy disk).

void main() {
  test('v1 database gets the playlists.cover_key column', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE playlists (id INTEGER PRIMARY KEY '
            'AUTOINCREMENT, name TEXT NOT NULL, created_at INTEGER NOT NULL)',
          );
          raw.execute(
            "INSERT INTO playlists (name, created_at) VALUES ('Old', 1)",
          );
          // v1 also had a tracks table (without replay_gain_db).
          raw.execute(
            'CREATE TABLE tracks (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'path TEXT NOT NULL)',
          );
          raw.userVersion = 1;
        },
      ),
    );
    final rows = await db.select(db.playlists).get();
    expect(rows.single.name, 'Old');
    expect(rows.single.coverKey, isNull);
    final cols = await db.customSelect('PRAGMA table_info(tracks)').get();
    expect(cols.map((c) => c.read<String>('name')), contains('replay_gain_db'));
    await db.close();
  });

  test('v3 database gets the import tables and keeps its data', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE playlists (id INTEGER PRIMARY KEY '
            'AUTOINCREMENT, name TEXT NOT NULL, created_at INTEGER NOT NULL, '
            'cover_key TEXT)',
          );
          raw.execute(
            "INSERT INTO playlists (name, created_at) VALUES ('Mine', 1)",
          );
          raw.execute(
            'CREATE TABLE tracks (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'path TEXT NOT NULL, replay_gain_db REAL)',
          );
          raw.userVersion = 3;
        },
      ),
    );
    final rows = await db.select(db.playlists).get();
    expect(rows.single.name, 'Mine');
    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final names = tables.map((t) => t.read<String>('name'));
    expect(names, containsAll(['playlist_imports', 'playlist_import_items']));
    expect(await db.select(db.playlistImports).get(), isEmpty);
    final cols = await db
        .customSelect('PRAGMA table_info(playlist_imports)')
        .get();
    expect(
      cols.map((c) => c.read<String>('name')),
      containsAll([
        'source_kind',
        'folder_path',
        'number_files',
        'link_only',
        'plan_first',
        'fetch_covers',
      ]),
      reason: 'created from the current definition, v5 columns included',
    );
    await db.close();
  });

  test('v4 database gets the v5 import columns and keeps its import intact', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE playlists (id INTEGER PRIMARY KEY '
            'AUTOINCREMENT, name TEXT NOT NULL, created_at INTEGER NOT NULL, '
            'cover_key TEXT)',
          );
          raw.execute(
            "INSERT INTO playlists (name, created_at) VALUES ('Mood', 1)",
          );
          raw.execute(
            'CREATE TABLE tracks (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'path TEXT NOT NULL, replay_gain_db REAL)',
          );
          raw.execute(
            'CREATE TABLE playlist_imports (id INTEGER PRIMARY KEY '
            'AUTOINCREMENT, playlist_id INTEGER NOT NULL, source_name TEXT NOT '
            'NULL, created_at INTEGER NOT NULL, status INTEGER NOT NULL DEFAULT 0)',
          );
          raw.execute(
            'CREATE TABLE playlist_import_items (import_id INTEGER NOT '
            'NULL, row_index INTEGER NOT NULL, title TEXT NOT NULL, artists TEXT '
            'NOT NULL, album TEXT, duration_ms INTEGER, isrc TEXT, status INTEGER '
            'NOT NULL DEFAULT 0, video_id TEXT, candidates TEXT, track_id '
            'INTEGER, score REAL, PRIMARY KEY (import_id, row_index))',
          );
          raw.execute(
            "INSERT INTO playlist_imports (playlist_id, source_name, "
            "created_at, status) VALUES (1, 'Mood', 5, 2)",
          );
          raw.execute(
            "INSERT INTO playlist_import_items (import_id, row_index, "
            "title, artists, status) VALUES (1, 0, 'Song', 'Band', 2)",
          );
          raw.userVersion = 4;
        },
      ),
    );
    final imp = (await db.select(db.playlistImports).get()).single;
    expect(imp.sourceName, 'Mood');
    expect(imp.status, 2);
    expect(imp.sourceKind, 'exportify', reason: 'default for old imports');
    expect(imp.folderPath, isNull);
    expect(imp.numberFiles, isFalse);
    expect(imp.linkOnly, isFalse);
    expect(imp.planFirst, isFalse);
    expect(imp.fetchCovers, isFalse);
    final item = (await db.select(db.playlistImportItems).get()).single;
    expect(item.title, 'Song');
    expect(item.status, 2);
    expect(item.note, isNull);
    expect(item.location, isNull);
    await db.close();
  });

  test('v5 database gets tracks.resume_position_ms and keeps its tracks', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE playlists (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, created_at INTEGER NOT NULL, cover_key TEXT)',
          );
          raw.execute(
            'CREATE TABLE tracks (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'path TEXT NOT NULL, title TEXT NOT NULL, album_key TEXT NOT NULL, '
            'format TEXT NOT NULL, size_bytes INTEGER NOT NULL, mtime_ms INTEGER '
            'NOT NULL, added_at INTEGER NOT NULL, replay_gain_db REAL)',
          );
          raw.execute(
            "INSERT INTO tracks (path, title, album_key, format, size_bytes, "
            "mtime_ms, added_at) VALUES ('/a.mp3', 'Old', 'k', 'mp3', 1, 1, 1)",
          );
          raw.userVersion = 5;
        },
      ),
    );
    final t =
        (await db
                .customSelect('SELECT title, resume_position_ms FROM tracks')
                .get())
            .single;
    expect(t.read<String>('title'), 'Old');
    expect(t.read<int?>('resume_position_ms'), isNull);
    final cols = await db.customSelect('PRAGMA table_info(tracks)').get();
    expect(
      cols.map((c) => c.read<String>('name')),
      contains('resume_position_ms'),
    );
    await db.close();
  });

  test('v6 database gets the history, smart playlist and tag tables and keeps its data', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE playlists (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, created_at INTEGER NOT NULL, cover_key TEXT)',
          );
          raw.execute(
            'CREATE TABLE tracks (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'path TEXT NOT NULL, title TEXT NOT NULL, album_key TEXT NOT NULL, '
            'format TEXT NOT NULL, size_bytes INTEGER NOT NULL, mtime_ms INTEGER '
            'NOT NULL, added_at INTEGER NOT NULL, play_count INTEGER NOT NULL '
            'DEFAULT 0, replay_gain_db REAL, resume_position_ms INTEGER)',
          );
          raw.execute(
            "INSERT INTO tracks (path, title, album_key, format, size_bytes, "
            "mtime_ms, added_at, play_count) VALUES ('/a.mp3', 'Old', 'k', 'mp3', 1, 1, 1, 7)",
          );
          raw.userVersion = 6;
        },
      ),
    );
    final t =
        (await db.customSelect('SELECT title, play_count FROM tracks').get())
            .single;
    expect(t.read<String>('title'), 'Old');
    expect(
      t.read<int>('play_count'),
      7,
      reason: 'the old counter is untouched',
    );
    final tables =
        (await db
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type = 'table'",
                )
                .get())
            .map((r) => r.read<String>('name'));
    expect(
      tables,
      containsAll(['plays', 'smart_playlists', 'user_tags', 'track_tags']),
    );
    expect(
      await db.select(db.plays).get(),
      isEmpty,
      reason: 'new tables start empty',
    );
    expect(await db.select(db.smartPlaylists).get(), isEmpty);
    expect(await db.select(db.userTags).get(), isEmpty);
    expect(await db.select(db.trackTags).get(), isEmpty);
    final indexes =
        (await db
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type = 'index'",
                )
                .get())
            .map((r) => r.read<String>('name'));
    expect(indexes, containsAll(['plays_track', 'plays_at']));
    await db.close();
  });

  test('v7 database gets tracks.ignored, false for every existing track', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE playlists (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, created_at INTEGER NOT NULL, cover_key TEXT)',
          );
          raw.execute(
            'CREATE TABLE tracks (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'path TEXT NOT NULL, title TEXT NOT NULL, album_key TEXT NOT NULL, '
            'format TEXT NOT NULL, size_bytes INTEGER NOT NULL, mtime_ms INTEGER '
            'NOT NULL, added_at INTEGER NOT NULL, play_count INTEGER NOT NULL '
            'DEFAULT 0, missing INTEGER NOT NULL DEFAULT 0)',
          );
          raw.execute(
            "INSERT INTO tracks (path, title, album_key, format, size_bytes, "
            "mtime_ms, added_at, play_count) VALUES ('/a.mp3', 'Old', 'k', 'mp3', 1, 1, 1, 7)",
          );
          raw.userVersion = 7;
        },
      ),
    );
    final t =
        (await db
                .customSelect('SELECT title, play_count, ignored FROM tracks')
                .get())
            .single;
    expect(t.read<String>('title'), 'Old');
    expect(
      t.read<int>('play_count'),
      7,
      reason: 'the old counter is untouched',
    );
    expect(
      t.read<int>('ignored'),
      0,
      reason: 'nothing is hidden by the upgrade',
    );
    await db.close();
  });

  test('v8 database gets tracks.kind (0 for every track) and the podcast tables, and keeps its data', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE playlists (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT NOT NULL, created_at INTEGER NOT NULL, cover_key TEXT)',
          );
          raw.execute(
            'CREATE TABLE tracks (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'path TEXT NOT NULL, title TEXT NOT NULL, album_key TEXT NOT NULL, '
            'format TEXT NOT NULL, size_bytes INTEGER NOT NULL, mtime_ms INTEGER '
            'NOT NULL, added_at INTEGER NOT NULL, play_count INTEGER NOT NULL '
            'DEFAULT 0, missing INTEGER NOT NULL DEFAULT 0, ignored INTEGER NOT NULL DEFAULT 0)',
          );
          raw.execute(
            "INSERT INTO tracks (path, title, album_key, format, size_bytes, "
            "mtime_ms, added_at, play_count) VALUES ('/a.mp3', 'Old', 'k', 'mp3', 1, 1, 1, 7)",
          );
          raw.execute(
            "INSERT INTO tracks (path, title, album_key, format, size_bytes, "
            "mtime_ms, added_at, ignored) VALUES ('/b.mp3', 'Hidden', 'k', 'mp3', 1, 1, 1, 1)",
          );
          raw.userVersion = 8;
        },
      ),
    );
    final rows = await db
        .customSelect(
          'SELECT title, play_count, ignored, kind FROM tracks ORDER BY id',
        )
        .get();
    expect(rows.map((r) => r.read<int>('kind')), [
      0,
      0,
    ], reason: 'every old track is music');
    expect(
      rows.first.read<int>('play_count'),
      7,
      reason: 'the old counter is untouched',
    );
    expect(
      rows.last.read<int>('ignored'),
      1,
      reason: 'a hidden track stays hidden',
    );
    expect(await db.select(db.podcasts).get(), isEmpty);
    expect(await db.select(db.podcastEpisodes).get(), isEmpty);
    final names =
        (await db
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type IN ('table', 'index')",
                )
                .get())
            .map((r) => r.read<String>('name'));
    expect(
      names,
      containsAll([
        'podcasts',
        'podcast_episodes',
        'tracks_kind',
        'podcast_episodes_podcast',
      ]),
    );
    await db.close();
  });

  test('podcast rows: a feed address is unique, an episode is unique per podcast, deleting a podcast takes its episodes and a track link goes null', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final pid = await db
        .into(db.podcasts)
        .insert(
          PodcastsCompanion.insert(
            feedUrl: 'https://x/feed',
            title: 'P',
            addedAt: 1,
          ),
        );
    await expectLater(
      db
          .into(db.podcasts)
          .insert(
            PodcastsCompanion.insert(
              feedUrl: 'https://x/feed',
              title: 'Other',
              addedAt: 2,
            ),
          ),
      throwsA(anything),
    );
    final trackId = await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            path: '/p/e1.mp3',
            title: 'E1',
            albumKey: 'k',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 1,
            kind: const Value(1),
          ),
        );
    await db
        .into(db.podcastEpisodes)
        .insert(
          PodcastEpisodesCompanion.insert(
            podcastId: pid,
            guid: 'g1',
            title: 'E1',
            audioUrl: 'https://x/e1.mp3',
            trackId: Value(trackId),
          ),
        );
    await expectLater(
      db
          .into(db.podcastEpisodes)
          .insert(
            PodcastEpisodesCompanion.insert(
              podcastId: pid,
              guid: 'g1',
              title: 'dup',
              audioUrl: 'https://x/e1b.mp3',
            ),
          ),
      throwsA(anything),
    );
    // The same guid in another podcast is fine.
    final other = await db
        .into(db.podcasts)
        .insert(
          PodcastsCompanion.insert(
            feedUrl: 'https://y/feed',
            title: 'Q',
            addedAt: 1,
          ),
        );
    await db
        .into(db.podcastEpisodes)
        .insert(
          PodcastEpisodesCompanion.insert(
            podcastId: other,
            guid: 'g1',
            title: 'E1',
            audioUrl: 'https://y/e1.mp3',
          ),
        );

    await (db.delete(db.tracks)..where((t) => t.id.equals(trackId))).go();
    final ep = await (db.select(
      db.podcastEpisodes,
    )..where((e) => e.podcastId.equals(pid))).getSingle();
    expect(
      ep.trackId,
      isNull,
      reason: 'the episode stays listed as not downloaded',
    );

    await (db.delete(db.podcasts)..where((p) => p.id.equals(pid))).go();
    expect(
      (await db.select(db.podcastEpisodes).get()).map((e) => e.podcastId),
      [other],
    );
    await db.close();
  });

  test('deleting a track takes its listens and its tag links with it, and a tag name is unique ignoring case', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            path: '/a.mp3',
            title: 'A',
            albumKey: 'k',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 1,
          ),
        );
    final trackId = (await db.select(db.tracks).getSingle()).id;
    final tagId = await db
        .into(db.userTags)
        .insert(UserTagsCompanion.insert(name: 'Live'));
    await db
        .into(db.trackTags)
        .insert(TrackTagsCompanion.insert(trackId: trackId, tagId: tagId));
    await db
        .into(db.plays)
        .insert(PlaysCompanion.insert(trackId: trackId, playedAt: 5));
    await expectLater(
      db.into(db.userTags).insert(UserTagsCompanion.insert(name: 'LIVE')),
      throwsA(anything),
    );
    await (db.delete(db.tracks)..where((t) => t.id.equals(trackId))).go();
    expect(await db.select(db.plays).get(), isEmpty);
    expect(await db.select(db.trackTags).get(), isEmpty);
    expect(
      await db.select(db.userTags).get(),
      hasLength(1),
      reason: 'the label stays',
    );
    await db.close();
  });

  test(
    'a v10 database gets the artist_infos table and keeps its tracks',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              'CREATE TABLE tracks (id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'path TEXT NOT NULL, title TEXT NOT NULL)',
            );
            raw.execute(
              "INSERT INTO tracks (path, title) VALUES ('/a.mp3', 'Old')",
            );
            raw.userVersion = 10;
          },
        ),
      );
      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      expect(
        tables.map((r) => r.read<String>('name')),
        contains('artist_infos'),
      );
      expect(await db.select(db.artistInfos).get(), isEmpty);
      expect(
        (await db.customSelect('SELECT title FROM tracks').getSingle())
            .read<String>('title'),
        'Old',
      );
      await db.close();
    },
  );

  test(
    'a v11 database gets radio_stations and keeps its tracks and playlists',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              'CREATE TABLE tracks (id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'path TEXT NOT NULL, title TEXT NOT NULL)',
            );
            raw.execute(
              "INSERT INTO tracks (path, title) VALUES ('/a.mp3', 'Old')",
            );
            raw.execute(
              'CREATE TABLE playlists (id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'name TEXT NOT NULL, created_at INTEGER NOT NULL, cover_key TEXT, uuid TEXT, updated_at INTEGER)',
            );
            raw.execute(
              "INSERT INTO playlists (name, created_at, updated_at) VALUES ('Mine', 1, 1)",
            );
            raw.userVersion = 11;
          },
        ),
      );
      expect(await db.select(db.radioStations).get(), isEmpty);
      await db
          .into(db.radioStations)
          .insert(
            RadioStationsCompanion.insert(
              stationId: 'x',
              name: 'X',
              streamUrl: 'http://x',
              position: 0,
            ),
          );
      final row = await db.select(db.radioStations).getSingle();
      expect(
        (row.homepage, row.hls, row.unreachable, row.lastPlayedAt),
        ('', false, false, null),
      );
      expect(
        (await db.customSelect('SELECT title FROM tracks').getSingle())
            .read<String>('title'),
        'Old',
      );
      expect((await db.select(db.playlists).getSingle()).name, 'Mine');
      await db.close();
    },
  );

  test(
    'a v12 database gets the follow tables and keeps its radios and tracks',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              'CREATE TABLE tracks (id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'path TEXT NOT NULL, title TEXT NOT NULL)',
            );
            raw.execute(
              "INSERT INTO tracks (path, title) VALUES ('/a.mp3', 'Old')",
            );
            raw.execute(
              'CREATE TABLE radio_stations (station_id TEXT NOT NULL PRIMARY KEY, '
              'name TEXT NOT NULL, stream_url TEXT NOT NULL, homepage TEXT NOT NULL DEFAULT \'\', '
              'favicon_url TEXT NOT NULL DEFAULT \'\', country_code TEXT NOT NULL DEFAULT \'\', '
              'state TEXT NOT NULL DEFAULT \'\', tags TEXT NOT NULL DEFAULT \'\', '
              'codec TEXT NOT NULL DEFAULT \'\', bitrate INTEGER NOT NULL DEFAULT 0, '
              'hls INTEGER NOT NULL DEFAULT 0, position INTEGER NOT NULL, added_at INTEGER NOT NULL, '
              'last_played_at INTEGER, last_ok_at INTEGER, unreachable INTEGER NOT NULL DEFAULT 0)',
            );
            raw.execute(
              "INSERT INTO radio_stations (station_id, name, stream_url, position, added_at) "
              "VALUES ('r', 'Radio', 'http://r', 0, 1)",
            );
            raw.userVersion = 12;
          },
        ),
      );
      expect(await db.select(db.followedArtists).get(), isEmpty);
      expect(await db.select(db.artistReleases).get(), isEmpty);
      expect(await db.select(db.artistLookups).get(), isEmpty);
      await db
          .into(db.followedArtists)
          .insert(FollowedArtistsCompanion.insert(ytmId: 'UC1', name: 'A'));
      final a = await db.select(db.followedArtists).getSingle();
      expect(
        (a.origin, a.excluded, a.muted, a.lastCheckedAt, a.checksFailed),
        (0, false, false, null, 0),
      );
      expect((await db.select(db.radioStations).getSingle()).name, 'Radio');
      expect(
        (await db.customSelect('SELECT title FROM tracks').getSingle())
            .read<String>('title'),
        'Old',
      );
      await db.close();
    },
  );

  test('a v13 database gets tracks.isrc from the latest linked import row', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE tracks (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'path TEXT NOT NULL, title TEXT NOT NULL)',
          );
          raw.execute(
            "INSERT INTO tracks (path, title) VALUES ('/a.mp3', 'A'), ('/b.mp3', 'B')",
          );
          raw.execute(
            'CREATE TABLE playlist_imports (id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'playlist_id INTEGER NOT NULL, source_name TEXT NOT NULL, created_at INTEGER NOT NULL)',
          );
          raw.execute(
            "INSERT INTO playlist_imports (playlist_id, source_name, created_at) "
            "VALUES (1, 'old', 1), (1, 'new', 2)",
          );
          raw.execute(
            'CREATE TABLE playlist_import_items (import_id INTEGER NOT NULL, '
            'row_index INTEGER NOT NULL, title TEXT NOT NULL, artists TEXT NOT NULL, '
            'isrc TEXT, track_id INTEGER, PRIMARY KEY (import_id, row_index))',
          );
          raw.execute(
            "INSERT INTO playlist_import_items VALUES "
            "(1, 0, 't', 'a', 'OLD', 1), (2, 0, 't', 'a', 'NEW', 1)",
          );
          raw.userVersion = 13;
        },
      ),
    );
    final rows = await db.customSelect('SELECT title, isrc FROM tracks').get();
    String? isrcOf(String title) => rows
        .firstWhere((r) => r.read<String>('title') == title)
        .read<String?>('isrc');
    expect(isrcOf('A'), 'NEW');
    expect(isrcOf('B'), isNull);
    final cols = await db
        .customSelect('PRAGMA table_info(playlist_import_items)')
        .get();
    expect(cols.map((c) => c.read<String>('name')), contains('year'));
    final idx = await db.customSelect('PRAGMA index_list(tracks)').get();
    expect(idx.map((c) => c.read<String>('name')), contains('tracks_isrc'));
    final tmp = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE name = 'tmp_items_track'",
        )
        .get();
    expect(tmp, isEmpty);
    await db.close();
  });

  test('a v14 database gets the enrichment tables and a dated mark for not-found parts', () async {
    final before = DateTime.now().millisecondsSinceEpoch;
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE tracks (id INTEGER PRIMARY KEY AUTOINCREMENT, path TEXT NOT NULL, '
            'title TEXT NOT NULL, lyrics_plain TEXT, lyrics_synced TEXT, '
            'enrich_status INTEGER NOT NULL DEFAULT 0, user_edited INTEGER NOT NULL DEFAULT 0)',
          );
          raw.execute(
            'INSERT INTO tracks (id, path, title, lyrics_plain, lyrics_synced, enrich_status, user_edited) VALUES '
            "(1, '/1', 'none-nolyrics', NULL, '', 2, 0), "
            "(2, '/2', 'none-lyrics', 'words', NULL, 2, 0), "
            "(3, '/3', 'edited-lyrics', NULL, '[00:01]x', 0, 1), "
            "(4, '/4', 'edited-nolyrics', '', NULL, 0, 1), "
            "(5, '/5', 'edited-none-lyrics', 'w', NULL, 2, 1), "
            "(6, '/6', 'plain', NULL, NULL, 0, 0)",
          );
          raw.userVersion = 14;
        },
      ),
    );
    final names =
        (await db.customSelect("SELECT name FROM sqlite_master").get())
            .map((r) => r.read<String>('name'))
            .toSet();
    expect(
      names,
      containsAll([
        'track_credits',
        'track_enrich',
        'activity_log',
        'track_credits_name_key',
        'activity_log_at',
      ]),
    );
    final cols = await db.customSelect('PRAGMA table_info(tracks)').get();
    expect(cols.map((c) => c.read<String>('name')), contains('cover_source'));

    final rows = await db
        .customSelect('SELECT * FROM track_enrich ORDER BY track_id')
        .get();
    Map<int, Map<String, Object?>> byId = {
      for (final r in rows) r.read<int>('track_id'): r.data,
    };
    expect(byId.keys, [1, 2, 3, 5]);
    expect(byId[1]!['meta_none_at'] as int, greaterThanOrEqualTo(before));
    expect(
      byId[1]!['lyrics_none_at'],
      byId[1]!['meta_none_at'],
      reason: 'no lyrics: also marked',
    );
    expect(byId[1]!['lyrics_by_user'], 0);
    expect(byId[2]!['meta_none_at'], isNotNull);
    expect(byId[2]!['lyrics_none_at'], isNull);
    expect(byId[3]!['meta_none_at'], isNull);
    expect(byId[3]!['lyrics_by_user'], 1);
    expect(byId[5]!['meta_none_at'], isNotNull);
    expect(byId[5]!['lyrics_by_user'], 1, reason: 'upsert into the same row');

    final t = await db
        .customSelect(
          'SELECT id, path, title, lyrics_plain, lyrics_synced, enrich_status, user_edited, cover_source FROM tracks ORDER BY id',
        )
        .get();
    expect(t.map((r) => r.read<int>('enrich_status')), [2, 2, 0, 0, 2, 0]);
    expect(t.map((r) => r.read<int>('cover_source')), everyElement(0));
    expect(t.map((r) => r.read<String?>('lyrics_plain')), [
      null,
      'words',
      null,
      '',
      'w',
      null,
    ]);
    await db.close();
  });
  test('a v15 database gets the genre and artist-country tables, empty, and keeps its tracks', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE tracks (id INTEGER PRIMARY KEY AUTOINCREMENT, path TEXT NOT NULL, '
            'title TEXT NOT NULL, genre TEXT)',
          );
          raw.execute(
            "INSERT INTO tracks (id, path, title, genre) VALUES (1, '/1', 'one', 'Rock'), (2, '/2', 'two', NULL)",
          );
          raw.userVersion = 15;
        },
      ),
    );
    final names =
        (await db.customSelect('SELECT name FROM sqlite_master').get())
            .map((r) => r.read<String>('name'))
            .toSet();
    expect(
      names,
      containsAll(['track_genres', 'artist_countries', 'track_genres_genre']),
    );
    expect(await db.select(db.trackGenres).get(), isEmpty);
    expect(await db.select(db.artistCountries).get(), isEmpty);
    final t = await db
        .customSelect('SELECT id, title, genre FROM tracks ORDER BY id')
        .get();
    expect(t.map((r) => r.read<String?>('genre')), ['Rock', null]);

    // The genre matches ignoring case, and deleting a track takes its genres.
    await db
        .into(db.trackGenres)
        .insert(
          TrackGenresCompanion.insert(trackId: 1, genre: 'Rock', position: 0),
        );
    final hit = await db
        .customSelect("SELECT track_id FROM track_genres WHERE genre = 'rock'")
        .get();
    expect(hit, hasLength(1));
    await db.customStatement('PRAGMA foreign_keys = ON');
    await db.customStatement('DELETE FROM tracks WHERE id = 1');
    expect(await db.select(db.trackGenres).get(), isEmpty);
    await db.close();
  });
  test('a v16 database gets the alias and not-same tables, empty, and keeps its tracks and followed artists', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE tracks (id INTEGER PRIMARY KEY AUTOINCREMENT, path TEXT NOT NULL, title TEXT NOT NULL)',
          );
          raw.execute(
            "INSERT INTO tracks (id, path, title) VALUES (1, '/1', 'one')",
          );
          raw.execute(
            'CREATE TABLE followed_artists (yt_m_id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL)',
          );
          raw.execute(
            "INSERT INTO followed_artists (yt_m_id, name) VALUES ('UC1', 'One')",
          );
          raw.userVersion = 16;
        },
      ),
    );
    expect(await db.select(db.artistAliases).get(), isEmpty);
    expect(await db.select(db.artistNotSame).get(), isEmpty);
    expect(
      (await db.customSelect('SELECT title FROM tracks').getSingle())
          .read<String>('title'),
      'one',
    );
    await db
        .into(db.artistAliases)
        .insert(ArtistAliasesCompanion.insert(aliasId: 'UC2', mainId: 'UC1'));
    await db
        .into(db.artistNotSame)
        .insert(ArtistNotSameCompanion.insert(a: 'UC1', b: 'UC3'));
    expect(await db.select(db.artistAliases).get(), hasLength(1));
    expect(await db.select(db.artistNotSame).get(), hasLength(1));
    await db.close();
  });
  test('a v17 database gets the podcast source: existing podcasts are RSS, with their episodes', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE podcasts (id INTEGER PRIMARY KEY AUTOINCREMENT, feed_url TEXT NOT NULL UNIQUE, '
            'title TEXT NOT NULL, added_at INTEGER NOT NULL)',
          );
          raw.execute(
            "INSERT INTO podcasts (id, feed_url, title, added_at) VALUES (1, 'https://x/feed', 'Old', 5)",
          );
          raw.userVersion = 17;
        },
      ),
    );
    final old = await db.select(db.podcasts).getSingle();
    expect((old.title, old.source, old.sourceId), ('Old', 0, null));
    await db
        .into(db.podcasts)
        .insert(
          PodcastsCompanion.insert(
            feedUrl: 'ytm:1',
            title: 'New',
            addedAt: 6,
            source: const Value(1),
            sourceId: const Value('MPSPPx'),
          ),
        );
    expect((await db.select(db.podcasts).get()).map((p) => p.source), [0, 1]);
    await db.close();
  });

  test('a v18 database gets followed=true on its podcasts, episodes intact', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE podcasts (id INTEGER PRIMARY KEY AUTOINCREMENT, feed_url TEXT NOT NULL UNIQUE, '
            'title TEXT NOT NULL, added_at INTEGER NOT NULL, source INTEGER NOT NULL DEFAULT 0, source_id TEXT)',
          );
          raw.execute(
            'CREATE TABLE podcast_episodes (id INTEGER PRIMARY KEY AUTOINCREMENT, podcast_id INTEGER NOT NULL, '
            'guid TEXT NOT NULL, title TEXT NOT NULL, audio_url TEXT NOT NULL)',
          );
          raw.execute(
            "INSERT INTO podcasts (id, feed_url, title, added_at) VALUES (1, 'https://x/feed', 'Old', 5)",
          );
          raw.execute(
            "INSERT INTO podcast_episodes (podcast_id, guid, title, audio_url) VALUES (1, 'g', 'E', 'u')",
          );
          raw.userVersion = 18;
        },
      ),
    );
    expect((await db.select(db.podcasts).getSingle()).followed, isTrue);
    expect(
      (await db.customSelect('SELECT title FROM podcast_episodes').getSingle())
          .read<String>('title'),
      'E',
    );
    await db.close();
  });

  test('the v19 step does not fail when the column already exists', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE podcasts (id INTEGER PRIMARY KEY AUTOINCREMENT, feed_url TEXT NOT NULL UNIQUE, '
            'title TEXT NOT NULL, added_at INTEGER NOT NULL, source INTEGER NOT NULL DEFAULT 0, source_id TEXT, '
            'followed INTEGER NOT NULL DEFAULT 1)',
          );
          raw.execute(
            "INSERT INTO podcasts (id, feed_url, title, added_at, followed) VALUES (1, 'https://x/f', 'Off', 5, 0)",
          );
          raw.userVersion = 18;
        },
      ),
    );
    expect((await db.select(db.podcasts).getSingle()).followed, isFalse);
    await db.close();
  });

  test('the v16 step can run again over an index that already exists (downgrade and back)', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            'CREATE TABLE tracks (id INTEGER PRIMARY KEY AUTOINCREMENT, path TEXT NOT NULL, title TEXT NOT NULL)',
          );
          raw.execute(
            'CREATE TABLE track_genres (track_id INTEGER NOT NULL, genre TEXT NOT NULL, position INTEGER NOT NULL)',
          );
          raw.execute(
            'CREATE INDEX track_genres_genre ON track_genres (genre)',
          );
          raw.userVersion = 15;
        },
      ),
    );
    final idx = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE name = 'track_genres_genre'",
        )
        .get();
    expect(idx, hasLength(1));
    await db.close();
  });
}
