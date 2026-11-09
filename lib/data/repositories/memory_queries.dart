import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../db/app_database.dart';
import 'hidden_playlists.dart';
import 'library_queries.dart';
import 'light_tracks.dart';

/// Music that counts as disk use: files that exist. Hidden (merged-away)
/// duplicates still take space, so they are counted.
const _music = 'kind = 0 AND missing = 0';

/// Music the user can see and act on: what the «never played» list shows.
const _neverPlayedWhere =
    '$_music AND ignored = 0 AND play_count = 0 AND last_played_at IS NULL '
    'AND NOT EXISTS (SELECT 1 FROM plays WHERE plays.track_id = tracks.id)';

class SizeTotals {
  const SizeTotals({this.sizeBytes = 0, this.trackCount = 0, this.durationMs = 0});

  final int sizeBytes, trackCount, durationMs;
}

/// A slice of the library: a playlist, a format, a folder.
class SizeGroup {
  const SizeGroup({
    required this.name,
    required this.totals,
    this.playlist,
    this.path,
    this.isFavorites = false,
    this.autoCoverKey,
  });

  /// The playlist name, the format (`mp3`) or the folder label; empty for
  /// Preferiti (the screen supplies the translated name).
  final String name;
  final SizeTotals totals;

  /// Set for a playlist; null for Preferiti and for non-playlist groups.
  final Playlist? playlist;

  /// Set for a folder: its full path (null = tracks outside any folder).
  final String? path;

  /// The Preferiti row of the playlist list.
  final bool isFavorites;

  /// A playlist's first track with a cover (the mosaic fallback), like the
  /// playlist sheet; null when none has one.
  final String? autoCoverKey;
}

class AlbumWeight {
  const AlbumWeight(this.album, this.sizeBytes);

  final AlbumSummary album;
  final int sizeBytes;
}

/// Everything under the totals of «Memoria» that needs one pass per section.
class MemoryBreakdown {
  const MemoryBreakdown({
    required this.playlists,
    required this.formats,
    required this.folders,
    required this.heaviestTracks,
    required this.heaviestAlbums,
    required this.neverPlayed,
    required this.podcastBytes,
  });

  /// Playlists and Preferiti, the biggest first.
  final List<SizeGroup> playlists;
  final List<SizeGroup> formats, folders;
  final List<Track> heaviestTracks;
  final List<AlbumWeight> heaviestAlbums;
  final SizeTotals neverPlayed;

  /// Downloaded podcast episodes (kind 1).
  final int podcastBytes;
}

/// Bytes of the text kept by the enrichment, per part.
class EnrichmentBytes {
  const EnrichmentBytes({this.lyrics = 0, this.curiosities = 0, this.credits = 0});

  /// Plain and synced lyrics.
  final int lyrics;
  /// Track curiosities and artist bios.
  final int curiosities;

  /// Credits and the per-track details.
  final int credits;

  int get total => lyrics + curiosities + credits;
}

/// The sums behind the «Memoria» tab. Everything is a GROUP BY: no track is
/// loaded just to be added up.
class MemoryQueries {
  MemoryQueries(this._db);

  final AppDatabase _db;

  SizeTotals _totals(QueryRow r) => SizeTotals(
    sizeBytes: r.read<int?>('bytes') ?? 0,
    trackCount: r.read<int?>('n') ?? 0,
    durationMs: r.read<int?>('ms') ?? 0,
  );

  static const _sums =
      'COALESCE(SUM(size_bytes), 0) AS bytes, COUNT(*) AS n, '
      'COALESCE(SUM(duration_ms), 0) AS ms';

  Stream<SizeTotals> watchTotals() => _db
      .customSelect(
        'SELECT $_sums FROM tracks WHERE $_music',
        readsFrom: {_db.tracks},
      )
      .watchSingle()
      .map(_totals);

  Future<SizeTotals> neverPlayed() async => _totals(
    await _db
        .customSelect(
          'SELECT $_sums FROM tracks WHERE $_neverPlayedWhere',
          readsFrom: {_db.tracks, _db.plays},
        )
        .getSingle(),
  );

  /// Never-played music, the biggest first (the list behind the summary).
  Stream<List<Track>> watchNeverPlayed() => _db
      .customSelect(
        'SELECT ${lightTrackColumns(_db)} FROM tracks '
        'WHERE $_neverPlayedWhere ORDER BY size_bytes DESC, id',
        readsFrom: {_db.tracks, _db.plays},
      )
      .watch()
      .map((rows) => [for (final r in rows) _db.tracks.map(r.data)]);

  Future<List<SizeGroup>> byFormat() async {
    final rows = await _db
        .customSelect(
          'SELECT lower(format) AS k, $_sums FROM tracks WHERE $_music '
          'GROUP BY lower(format) ORDER BY bytes DESC, k',
          readsFrom: {_db.tracks},
        )
        .get();
    return [
      for (final r in rows)
        SizeGroup(name: r.read<String>('k'), totals: _totals(r)),
    ];
  }

  Future<List<SizeGroup>> byFolder() async {
    final rows = await _db
        .customSelect(
          'SELECT f.path AS path, f.label AS label, $_sums FROM tracks '
          'LEFT JOIN folders f ON f.id = tracks.folder_id '
          'WHERE $_music GROUP BY tracks.folder_id ORDER BY bytes DESC, path',
          readsFrom: {_db.tracks, _db.folders},
        )
        .get();
    return [
      for (final r in rows)
        SizeGroup(
          name: r.read<String?>('label') ?? _leaf(r.read<String?>('path')),
          path: r.read<String?>('path'),
          totals: _totals(r),
        ),
    ];
  }

  static String _leaf(String? path) =>
      path == null ? '' : (p.basename(path).isEmpty ? path : p.basename(path));

  /// Every playlist (empty ones too) plus Preferiti, the biggest first. A
  /// track in two playlists counts in both.
  Future<List<SizeGroup>> byPlaylist() async {
    final lists = {for (final pl in await _db.visiblePlaylists()) pl.id: pl};
    final rows = await _db
        .customSelect(
          'SELECT pt.playlist_id AS pid, '
          'COALESCE(SUM(t.size_bytes), 0) AS bytes, COUNT(t.id) AS n, '
          'COALESCE(SUM(t.duration_ms), 0) AS ms '
          'FROM playlist_tracks pt JOIN tracks t ON t.id = pt.track_id '
          'AND t.kind = 0 AND t.missing = 0 GROUP BY pt.playlist_id',
          readsFrom: {_db.playlistTracks, _db.tracks},
        )
        .get();
    final sums = {for (final r in rows) r.read<int>('pid'): _totals(r)};
    final coverRows = await _db
        .customSelect(
          'SELECT p.id AS pid, (SELECT t.cover_key FROM playlist_tracks x '
          'JOIN tracks t ON t.id = x.track_id WHERE x.playlist_id = p.id '
          'AND t.cover_key IS NOT NULL ORDER BY x.position LIMIT 1) AS auto_cover '
          'FROM playlists p',
          readsFrom: {_db.playlists, _db.playlistTracks, _db.tracks},
        )
        .get();
    final covers = {for (final r in coverRows) r.read<int>('pid'): r.read<String?>('auto_cover')};
    final favorites = _totals(
      await _db
          .customSelect(
            'SELECT $_sums FROM tracks WHERE $_music AND is_favorite = 1',
            readsFrom: {_db.tracks},
          )
          .getSingle(),
    );
    final out = [
      SizeGroup(name: '', totals: favorites, isFavorites: true),
      for (final pl in lists.values)
        SizeGroup(
          name: pl.name,
          playlist: pl,
          totals: sums[pl.id] ?? const SizeTotals(),
          autoCoverKey: covers[pl.id],
        ),
    ];
    out.sort((a, b) => b.totals.sizeBytes.compareTo(a.totals.sizeBytes));
    return out;
  }

  Future<List<Track>> heaviestTracks({int limit = 10}) async {
    final rows = await _db
        .customSelect(
          'SELECT ${lightTrackColumns(_db)} FROM tracks WHERE $_music '
          'ORDER BY size_bytes DESC, id LIMIT ?',
          variables: [Variable<int>(limit)],
          readsFrom: {_db.tracks},
        )
        .get();
    return [for (final r in rows) _db.tracks.map(r.data)];
  }

  Future<List<AlbumWeight>> heaviestAlbums({int limit = 10}) async {
    final rows = await _db
        .customSelect(
          '$albumSelectSql WHERE $_music AND ignored = 0 '
          'GROUP BY album_key ORDER BY size_bytes DESC, album_key LIMIT ?',
          variables: [Variable<int>(limit)],
          readsFrom: {_db.tracks},
        )
        .get();
    return [
      for (final r in rows)
        AlbumWeight(albumSummaryFromRow(r), r.read<int?>('size_bytes') ?? 0),
    ];
  }

  Future<int> podcastBytes() async =>
      (await _db
              .customSelect(
                'SELECT COALESCE(SUM(size_bytes), 0) AS bytes FROM tracks '
                'WHERE kind = 1 AND missing = 0',
                readsFrom: {_db.tracks},
              )
              .getSingle())
          .read<int>('bytes');

  /// UTF-8 bytes of a text column (length() alone counts characters).
  static String _bytesOf(String table, String col) =>
      'COALESCE((SELECT SUM(length(CAST($col AS BLOB))) FROM $table), 0)';

  Future<EnrichmentBytes> enrichmentBytes() async {
    final r = await _db
        .customSelect(
          'SELECT '
          '(SELECT ${_bytesOf('tracks', 'lyrics_plain')} + '
          '${_bytesOf('tracks', 'lyrics_synced')}) AS lyrics, '
          '(SELECT ${_bytesOf('tracks', 'curiosities')} + '
          '${_bytesOf('artist_infos', 'body')}) AS curio, '
          '(SELECT ${_bytesOf('track_credits', 'name')} + '
          '${_bytesOf('track_credits', 'role')} + '
          '${_bytesOf('track_credits', 'source')}) AS credits, '
          '(SELECT ${_bytesOf('track_enrich', 'details')}) AS details',
          readsFrom: {
            _db.tracks,
            _db.artistInfos,
            _db.trackCredits,
            _db.trackEnrich,
          },
        )
        .getSingle();
    return EnrichmentBytes(
      lyrics: r.read<int>('lyrics'),
      curiosities: r.read<int>('curio'),
      credits: r.read<int>('credits') + r.read<int>('details'),
    );
  }

  Future<MemoryBreakdown> breakdown() async {
    return MemoryBreakdown(
      playlists: await byPlaylist(),
      formats: await byFormat(),
      folders: await byFolder(),
      heaviestTracks: await heaviestTracks(),
      heaviestAlbums: await heaviestAlbums(),
      neverPlayed: await neverPlayed(),
      podcastBytes: await podcastBytes(),
    );
  }
}
