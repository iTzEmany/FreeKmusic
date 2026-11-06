import 'dart:math' show min;

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'light_tracks.dart';

enum AlbumSort { title, artist, year }

class AlbumSummary {
  const AlbumSummary({
    required this.albumKey,
    required this.title,
    required this.artist,
    required this.variousArtists,
    required this.trackCount,
    required this.durationMs,
    required this.year,
    required this.coverKey,
    this.lastPlayedAt,
    this.addedAt = 0,
    this.playCount = 0,
  });

  final String albumKey;
  final String? title; // null = unknown album
  final String? artist;
  final bool variousArtists;
  final int trackCount, durationMs;
  final int? year;
  final String? coverKey;

  /// Latest play of any of its tracks (epoch ms), null if never played.
  final int? lastPlayedAt;

  /// Latest `addedAt` of its tracks.
  final int addedAt;

  /// Sum of the plays of its tracks.
  final int playCount;
}

class GenreSummary {
  const GenreSummary(this.name, this.trackCount);

  final String name;
  final int trackCount;
}

class ArtistSummary {
  const ArtistSummary({
    required this.key,
    required this.name,
    required this.trackCount,
    required this.albumCount,
    this.coverKey,
    this.lastPlayedAt,
    this.addedAt = 0,
    this.playCount = 0,
    this.durationMs = 0,
  });

  final String key; // lowercase trimmed; '' = unknown artist
  final String? name;
  final int trackCount, albumCount;

  /// Cover most present among the artist's tracks.
  final String? coverKey;
  final int? lastPlayedAt;
  final int addedAt;

  /// Sum of the plays and of the durations of its tracks.
  final int playCount, durationMs;
}

/// The columns an [AlbumSummary] is built from (add `WHERE ... GROUP BY album_key`).
const albumSelectSql = '''
SELECT album_key,
  MIN(album) AS album,
  MAX(album_artist) AS album_artist,
  MIN(artist) AS artist,
  COUNT(DISTINCT lower(trim(COALESCE(artist, '')))) AS artist_count,
  COUNT(*) AS track_count,
  SUM(duration_ms) AS duration_ms,
  MAX(year) AS year,
  COALESCE(MIN(CASE WHEN cover_source = 1 THEN cover_key END), MIN(CASE WHEN cover_source = 0 THEN cover_key END), MIN(cover_key)) AS cover_key,
  MAX(last_played_at) AS last_played,
  MAX(added_at) AS added,
  SUM(play_count) AS plays,
  SUM(size_bytes) AS size_bytes
FROM tracks
''';

/// One row of [albumSelectSql] as an [AlbumSummary].
AlbumSummary albumSummaryFromRow(QueryRow r) {
  final albumArtist = r.read<String?>('album_artist');
  final count = r.read<int>('artist_count');
  return AlbumSummary(
    albumKey: r.read<String>('album_key'),
    title: r.read<String?>('album'),
    artist: albumArtist ?? r.read<String?>('artist'),
    variousArtists: albumArtist == null && count > 1,
    trackCount: r.read<int>('track_count'),
    durationMs: r.read<int?>('duration_ms') ?? 0,
    year: r.read<int?>('year'),
    coverKey: r.read<String?>('cover_key'),
    lastPlayedAt: r.read<int?>('last_played'),
    addedAt: r.read<int?>('added') ?? 0,
    playCount: r.read<int?>('plays') ?? 0,
  );
}

class LibraryQueries {
  LibraryQueries(this._db);

  final AppDatabase _db;

  AlbumSummary _album(QueryRow r) => albumSummaryFromRow(r);

  Stream<List<AlbumSummary>> watchAlbums({AlbumSort sort = AlbumSort.title}) {
    final order = switch (sort) {
      AlbumSort.title => 'album COLLATE NOCASE',
      AlbumSort.artist => 'COALESCE(album_artist, artist) COLLATE NOCASE, album COLLATE NOCASE',
      AlbumSort.year => 'year DESC, album COLLATE NOCASE',
    };
    return _db
        .customSelect(
          '$albumSelectSql WHERE missing = 0 AND ignored = 0 AND kind = 0 GROUP BY album_key ORDER BY $order',
          readsFrom: {_db.tracks},
        )
        .watch()
        .map((rows) => rows.map(_album).toList());
  }

  Stream<List<AlbumSummary>> watchArtistAlbums(String artistKey) {
    return _db
        .customSelect(
          '$albumSelectSql WHERE missing = 0 AND ignored = 0 AND kind = 0 AND album_key IN ('
          "SELECT album_key FROM tracks WHERE missing = 0 AND ignored = 0 AND kind = 0 AND lower(trim(COALESCE(artist, ''))) = ?) "
          'GROUP BY album_key ORDER BY year DESC, album COLLATE NOCASE',
          variables: [Variable<String>(artistKey)],
          readsFrom: {_db.tracks},
        )
        .watch()
        .map((rows) => rows.map(_album).toList());
  }

  /// Artists grouped by lower-cased name. The cover is the one most present
  /// among the artist's tracks, found in a single pass (a per-artist subquery
  /// scanned the whole table once per artist: 5 s at 50 000 tracks).
  Stream<List<ArtistSummary>> watchArtists() {
    return _db
        .customSelect(
          '''
WITH cov AS (
  SELECT lower(trim(COALESCE(artist, ''))) AS k, cover_key, SUM(cover_source < 2) AS n
  FROM tracks WHERE missing = 0 AND ignored = 0 AND kind = 0 AND cover_key IS NOT NULL GROUP BY k, cover_key
),
best AS (
  SELECT k, cover_key FROM (
    SELECT k, cover_key,
      ROW_NUMBER() OVER (PARTITION BY k ORDER BY n DESC, cover_key) AS rn
    FROM cov
  ) WHERE rn = 1
)
SELECT g.k AS k, g.name AS name, g.track_count AS track_count,
  g.album_count AS album_count, g.last_played AS last_played,
  g.added AS added, g.plays AS plays, g.duration AS duration,
  best.cover_key AS cover_key
FROM (
  SELECT lower(trim(COALESCE(artist, ''))) AS k, MIN(artist) AS name,
    COUNT(*) AS track_count, COUNT(DISTINCT album_key) AS album_count,
    MAX(last_played_at) AS last_played, MAX(added_at) AS added,
    SUM(play_count) AS plays, SUM(duration_ms) AS duration
  FROM tracks WHERE missing = 0 AND ignored = 0 AND kind = 0 GROUP BY k
) g
LEFT JOIN best ON best.k = g.k
ORDER BY g.k COLLATE NOCASE
''',
          readsFrom: {_db.tracks},
        )
        .watch()
        .map((rows) => [
              for (final r in rows)
                ArtistSummary(
                  key: r.read<String>('k'),
                  name: r.read<String?>('name'),
                  trackCount: r.read<int>('track_count'),
                  albumCount: r.read<int>('album_count'),
                  coverKey: r.read<String?>('cover_key'),
                  lastPlayedAt: r.read<int?>('last_played'),
                  addedAt: r.read<int?>('added') ?? 0,
                  playCount: r.read<int?>('plays') ?? 0,
                  durationMs: r.read<int?>('duration') ?? 0,
                ),
            ]);
  }

  /// The library artist called [name] (SQL `lower` on both sides, so the key
  /// is the one of [watchArtists]); null when no visible library track has it. No cover.
  Future<ArtistSummary?> artistNamed(String name) async {
    final r = await _db
        .customSelect(
          "SELECT MIN(lower(trim(COALESCE(artist, '')))) AS k, MIN(artist) AS name, "
          'COUNT(*) AS n, COUNT(DISTINCT album_key) AS albums '
          'FROM tracks WHERE missing = 0 AND ignored = 0 AND kind = 0 '
          "AND lower(trim(COALESCE(artist, ''))) = lower(trim(?))",
          variables: [Variable<String>(name)],
          readsFrom: {_db.tracks},
        )
        .getSingle();
    final n = r.read<int>('n');
    if (n == 0) return null;
    return ArtistSummary(
      key: r.read<String>('k'),
      name: r.read<String?>('name'),
      trackCount: n,
      albumCount: r.read<int>('albums'),
    );
  }

  /// Every track of an artist (same grouping key as [watchArtists]), by
  /// album, then disc and track number.
  Stream<List<Track>> watchArtistTracks(String artistKey) {
    return _db
        .customSelect(
          'SELECT ${lightTrackColumns(_db)} FROM tracks WHERE missing = 0 AND ignored = 0 AND kind = 0 '
          "AND lower(trim(COALESCE(artist, ''))) = ? "
          'ORDER BY album COLLATE NOCASE, disc_number, track_number, '
          'title COLLATE NOCASE',
          variables: [Variable<String>(artistKey)],
          readsFrom: {_db.tracks},
        )
        .watch()
        .map((rows) => [for (final r in rows) _db.tracks.map(r.data)]);
  }

  /// The most played tracks (never-played ones excluded).
  Stream<List<Track>> watchTopTracks({int limit = 10}) {
    return _db
        .customSelect(
          'SELECT ${lightTrackColumns(_db)} FROM tracks WHERE missing = 0 AND ignored = 0 AND kind = 0 AND play_count > 0 '
          'ORDER BY play_count DESC, last_played_at DESC, title COLLATE NOCASE '
          'LIMIT ?',
          variables: [Variable<int>(limit)],
          readsFrom: {_db.tracks},
        )
        .watch()
        .map((rows) => [for (final r in rows) _db.tracks.map(r.data)]);
  }

  /// Genres present in the library with their track counts, biggest first.
  Stream<List<GenreSummary>> watchGenres() {
    return _db
        .customSelect(
          'SELECT trim(genre) AS g, COUNT(*) AS n FROM tracks '
          "WHERE missing = 0 AND ignored = 0 AND kind = 0 AND genre IS NOT NULL AND trim(genre) <> '' "
          'GROUP BY lower(trim(genre)) ORDER BY n DESC, g COLLATE NOCASE',
          readsFrom: {_db.tracks},
        )
        .watch()
        .map((rows) => [
              for (final r in rows)
                GenreSummary(r.read<String>('g'), r.read<int>('n')),
            ]);
  }

  Stream<List<Track>> watchGenreTracks(String genre) {
    return _db
        .customSelect(
          'SELECT ${lightTrackColumns(_db)} FROM tracks WHERE missing = 0 AND ignored = 0 AND kind = 0 '
          'AND lower(trim(genre)) = lower(trim(?)) '
          'ORDER BY artist COLLATE NOCASE, album COLLATE NOCASE, '
          'disc_number, track_number, title COLLATE NOCASE',
          variables: [Variable<String>(genre)],
          readsFrom: {_db.tracks},
        )
        .watch()
        .map((rows) => [for (final r in rows) _db.tracks.map(r.data)]);
  }

  Stream<List<Track>> watchAlbumTracks(String albumKey) {
    return lightSelect(_db, _db.select(_db.tracks)
          ..where((t) => t.albumKey.equals(albumKey) &
              t.missing.equals(false) &
              t.ignored.equals(false) &
              t.kind.equals(0))
          ..orderBy([
            (t) => OrderingTerm.asc(t.discNumber),
            (t) => OrderingTerm.asc(t.trackNumber),
            (t) => OrderingTerm(
                expression: t.title.collate(Collate.noCase)),
          ]))
        .watch();
  }

  /// How many of the library tracks [ids] have each genre (key `lower(trim(genre))`):
  /// the weights of the Jam suggestions (R-102).
  Future<Map<String, int>> genreCounts(List<int> ids) async {
    final out = <String, int>{};
    for (var i = 0; i < ids.length; i += 500) {
      final chunk = ids.sublist(i, min(i + 500, ids.length));
      final rows = await _db
          .customSelect(
            'SELECT lower(trim(genre)) AS g, COUNT(*) AS n FROM tracks '
            "WHERE id IN (${List.filled(chunk.length, '?').join(',')}) AND missing = 0 AND ignored = 0 AND kind = 0 "
            "AND genre IS NOT NULL AND trim(genre) <> '' GROUP BY g",
            variables: [for (final id in chunk) Variable<int>(id)],
            readsFrom: {_db.tracks},
          )
          .get();
      for (final r in rows) {
        out.update(r.read<String>('g'), (n) => n + r.read<int>('n'),
            ifAbsent: () => r.read<int>('n'));
      }
    }
    return out;
  }

  /// Up to [limit] random visible library tracks, of genre [genre] when given
  /// (compared as `lower(trim(?))` on both sides).
  Future<List<Track>> randomTracks({String? genre, int limit = 200}) async {
    final rows = await _db
        .customSelect(
          'SELECT ${lightTrackColumns(_db)} FROM tracks WHERE missing = 0 AND ignored = 0 AND kind = 0 '
          '${genre == null ? '' : 'AND lower(trim(genre)) = lower(trim(?)) '}'
          'ORDER BY random() LIMIT ?',
          variables: [if (genre != null) Variable<String>(genre), Variable<int>(limit)],
          readsFrom: {_db.tracks},
        )
        .get();
    return [for (final r in rows) _db.tracks.map(r.data)];
  }
}
