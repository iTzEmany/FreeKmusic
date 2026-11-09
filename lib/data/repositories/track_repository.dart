import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../core/import_row.dart';
import '../../core/text_utils.dart';
import '../../services/share/track_meta.dart';
import '../../services/stream/stream_key.dart';
import '../../services/library/rules/rule_ast.dart';
import '../../services/library/rules/rule_country.dart';
import '../../services/library/rules/rule_sql.dart';
import '../../services/online/youtube_service.dart' show YtResult;
import '../db/app_database.dart';
import 'duplicate_repository.dart';
import 'artist_info_repository.dart' show ArtistInfoRepository;
import 'light_tracks.dart';
import 'track_genre_repository.dart';
import 'track_kinds.dart';

enum SortOption { defaultOrder, title, artist, album, year, addedAt, duration }

/// The lyrics of a track and its enrichment marks, as [TrackRepository.clearLyrics] found them.
typedef LyricsSnapshot = ({String? plain, String? synced, bool byUser, int? noneAt, int? syncedNoneAt});

class TrackRepository {
  TrackRepository(this._db);

  final AppDatabase _db;

  /// Inserts new rows; for existing paths only file-derived fields change, so
  /// favourites, lyrics, counters and user edits survive a rescan. [genresByPath]
  /// are the genres read for a path; they replace its `track_genres` rows.
  Future<void> upsertBatch(List<TracksCompanion> rows, {Map<String, List<String>> genresByPath = const {}}) async {
    if (rows.isEmpty) return;
    final genres = TrackGenreRepository(_db);
    await _db.transaction(() async {
      final newGenres = <int, List<String>>{};
      for (var row in rows) {
        final path = row.path.value;
        // The album's hand-picked cover may have changed since the scan read it.
        if (row.coverSource.present && row.coverSource.value == 1) {
          row = await _freshAlbumCover(row);
        }
        final existing = await (_db.select(
          _db.tracks,
        )..where((t) => t.path.equals(path))).getSingleOrNull();
        if (existing == null) {
          final id = await _db.into(_db.tracks).insert(row);
          final g = genresByPath[path];
          if (g != null) newGenres[id] = g;
          continue;
        }
        final keepText = existing.userEdited;
        // A row moved to another album leaves the album's hand-picked cover behind.
        final moved = existing.coverSource == 1 &&
            !keepText &&
            row.albumKey.present &&
            row.albumKey.value != existing.albumKey;
        final handPicked = existing.coverSource > 0 && !moved;
        final keepCover =
            handPicked ||
            keepText && !(row.hasCover.present && row.hasCover.value);
        // A hash of the old bytes says nothing about the new ones.
        final changed =
            existing.sizeBytes != row.sizeBytes.value ||
            existing.mtimeMs != row.mtimeMs.value;
        await (_db.update(
          _db.tracks,
        )..where((t) => t.id.equals(existing.id))).write(
          TracksCompanion(
            folderId: row.folderId,
            title: keepText ? const Value.absent() : row.title,
            artist: keepText ? const Value.absent() : row.artist,
            albumArtist: keepText ? const Value.absent() : row.albumArtist,
            album: keepText ? const Value.absent() : row.album,
            albumKey: keepText ? const Value.absent() : row.albumKey,
            trackNumber: row.trackNumber,
            discNumber: row.discNumber,
            year: row.year,
            genre: row.genre,
            durationMs: row.durationMs,
            format: row.format,
            sampleRateHz: row.sampleRateHz,
            bitDepth: row.bitDepth,
            bitrateKbps: row.bitrateKbps,
            channels: row.channels,
            sizeBytes: row.sizeBytes,
            mtimeMs: row.mtimeMs,
            // An edited row keeps the cover it was given when the scan finds none.
            hasCover: keepCover ? const Value.absent() : row.hasCover,
            coverKey: keepCover ? const Value.absent() : row.coverKey,
            // A hand-picked cover stays; a row that joins a hand-picked album takes its source.
            coverSource: handPicked ? const Value.absent() : row.coverSource,
            replayGainDb: row.replayGainDb,
            isrc: (existing.isrc ?? '').isEmpty
                ? row.isrc
                : const Value.absent(),
            missing: const Value(false),
            sha256: changed ? const Value(null) : const Value.absent(),
          ),
        );
        final g = genresByPath[path];
        if (g != null) newGenres[existing.id] = g;
      }
      await genres.replaceMany(newGenres);
    });
  }

  /// The shadow rows (`kind = 2`) among [ids], as list rows; other ids are skipped.
  Future<List<Track>> streamRowsAmong(List<int> ids) => ids.isEmpty
      ? Future.value(const [])
      : lightSelect(
          _db,
          _db.select(_db.tracks)
            // A streamed YouTube Music episode (kind 1) has the same kind of path.
            ..where((t) => t.id.isIn(ids) & t.kind.isIn(const [kStreamKind, kEpisodeKind]) & t.path.like('stream:%')),
        ).get();

  /// The shadow row (`kind = 2`) of the streamed track [key], if it has one. A podcast episode
  /// (kind 1) on the same path is not one: promote and merge never touch it.
  Future<Track?> streamRow(String key) async {
    final row = await byPath(streamPathOf(key));
    return row != null && row.kind == kStreamKind ? row : null;
  }

  /// Deletes the shadow rows with no plays, except the [keepKeys] ones (still
  /// in the cache). Rows with plays stay (D-81). Returns how many went.
  Future<int> deleteUnplayedStreamRows({Set<String> keepKeys = const {}}) =>
      (_db.delete(_db.tracks)..where((t) =>
              t.kind.equals(kStreamKind) &
              t.path.isNotIn([for (final k in keepKeys) streamPathOf(k)]) &
              notExistsQuery(_db.select(_db.plays)..where((pl) => pl.trackId.equalsExp(t.id)))))
          .go();

  /// Turns the shadow row of [key] into a library track at [path] (R-10): `kind = 0`,
  /// real path and [folderId] (so the scan finds it by path and skips it), and the
  /// `albumKey` a scanned file there would get. Plays, text and cover stay.
  /// Returns the updated row, or null when there is no shadow row.
  Future<Track?> promoteStreamRow(String key, String path, int folderId, File file) async {
    final row = await streamRow(key);
    if (row == null) return null;
    final stat = await file.stat();
    await (_db.update(_db.tracks)..where((t) => t.id.equals(row.id))).write(TracksCompanion(
      path: Value(path),
      kind: const Value(kMusicKind),
      folderId: Value(folderId),
      format: Value(p.extension(path).replaceFirst('.', '').toLowerCase()),
      sizeBytes: Value(stat.size),
      mtimeMs: Value(stat.modified.millisecondsSinceEpoch),
      albumKey: Value(computeAlbumKey(
          albumArtist: row.albumArtist, artist: row.artist, album: row.album, directory: p.dirname(path))),
      missing: const Value(false),
    ));
    return getById(row.id);
  }

  /// A fresh download [keepId] of the track [key] was streamed before: its listens,
  /// counts, lyrics and curiosities move to [keepId] (as in `DuplicateRepository.merge`)
  /// and the shadow row goes. Returns the id of the deleted shadow row (a queue may still
  /// hold it), or null when there was nothing to merge.
  Future<int?> mergeStreamRow(String key, int keepId) async {
    final shadow = await streamRow(key);
    if (shadow == null || shadow.id == keepId) return null;
    await DuplicateRepository(_db).merge(keepId, [shadow.id]);
    await (_db.delete(_db.tracks)..where((t) => t.id.equals(shadow.id))).go();
    return shadow.id;
  }

  /// Creates or refreshes the shadow row (`kind = 2`) of the streamed track
  /// [key] whose cached [file] is ready; one row per key. Returns its id.
  Future<int> upsertStreamRow(String key, YtResult r, File file) async {
    final stat = await file.stat();
    final artist = displayArtist(r);
    final path = streamPathOf(key);
    final row = TracksCompanion.insert(
      path: path,
      title: r.title,
      // Own key per stream: never shares (or overwrites) a library album's cover.
      albumKey: 'stream|$key',
      format: p.extension(file.path).replaceFirst('.', '').toLowerCase(),
      sizeBytes: stat.size,
      mtimeMs: stat.modified.millisecondsSinceEpoch,
      addedAt: DateTime.now().millisecondsSinceEpoch,
      artist: Value(artist),
      album: Value(r.album),
      durationMs: Value(r.duration?.inMilliseconds ?? 0),
      kind: const Value(kStreamKind),
    );
    return _db.transaction(() async {
      final existing = await byPath(path);
      if (existing == null) return _db.into(_db.tracks).insert(row);
      // A podcast episode streamed from the same address: its size and format are its own.
      if (existing.kind != kStreamKind) return existing.id;
      await (_db.update(_db.tracks)..where((t) => t.id.equals(existing.id)))
          .write(TracksCompanion(
        sizeBytes: row.sizeBytes,
        mtimeMs: row.mtimeMs,
        format: row.format,
        missing: const Value(false),
      ));
      return existing.id;
    });
  }

  Future<Track?> byPath(String path) =>
      (_db.select(_db.tracks)..where((t) => t.path.equals(path))).getSingleOrNull();

  /// Writes the non-null fields of a received [TrackMeta] over the row (the
  /// sender's package wins over the local tags), recomputes `albumKey` and
  /// sets `userEdited` so a rescan keeps title, artist and album.
  /// `enrichStatus` is not applied: the receiver judges its own enrichment.
  /// shortcut: year/genre/numbers come back from the file on a rescan if it
  /// changes outside Codecore; fixed by writing tags (37.4).
  /// Returns the new `albumKey`, or null when the row does not exist.
  Future<String?> applyReceivedMeta(int trackId, TrackMeta m) async {
    final t = await (_db.select(_db.tracks)..where((r) => r.id.equals(trackId))).getSingleOrNull();
    if (t == null) return null;
    final albumArtist = m.albumArtist ?? t.albumArtist;
    final artist = m.artist ?? t.artist;
    final album = m.album ?? t.album;
    final key = computeAlbumKey(
      albumArtist: albumArtist,
      artist: artist,
      album: album,
      directory: p.dirname(t.path),
    );
    await (_db.update(_db.tracks)..where((r) => r.id.equals(trackId))).write(
      TracksCompanion(
        title: Value(m.title ?? t.title),
        artist: Value(artist),
        albumArtist: Value(albumArtist),
        album: Value(album),
        albumKey: Value(key),
        year: Value(m.year ?? t.year),
        genre: Value(m.genre ?? t.genre),
        trackNumber: Value(m.trackNumber ?? t.trackNumber),
        discNumber: Value(m.discNumber ?? t.discNumber),
        isrc: Value(m.isrc ?? t.isrc),
        lyricsPlain: Value(m.lyricsPlain ?? t.lyricsPlain),
        lyricsSynced: Value(m.lyricsSynced ?? t.lyricsSynced),
        userEdited: const Value(true),
      ),
    );
    await settleMovedCover(t, key);
    return key;
  }

  Future<Map<String, ({int size, int mtime})>> fileIndexForFolder(
    int folderId,
  ) async {
    final rows = await (_db.select(
      _db.tracks,
    )..where((t) => t.folderId.equals(folderId))).get();
    return {
      for (final r in rows) r.path: (size: r.sizeBytes, mtime: r.mtimeMs),
    };
  }

  Future<Set<String>> missingPathsForFolder(int folderId) async {
    final rows =
        await (_db.select(_db.tracks)..where(
              (t) => t.folderId.equals(folderId) & t.missing.equals(true),
            ))
            .get();
    return rows.map((r) => r.path).toSet();
  }

  Future<void> markMissing(Set<String> paths, bool missing) async {
    if (paths.isEmpty) return;
    await _db.transaction(() async {
      for (final chunk in _chunks(paths.toList(), 500)) {
        await (_db.update(_db.tracks)..where((t) => t.path.isIn(chunk))).write(
          TracksCompanion(missing: Value(missing)),
        );
      }
    });
  }

  /// Automatic cover for the album; rows with a hand-picked cover keep theirs.
  Future<void> setCoverForAlbum(
    String albumKey,
    bool hasCover,
    String? coverKey,
  ) async {
    await (_db.update(
      _db.tracks,
    )..where((t) => t.albumKey.equals(albumKey) & t.coverSource.equals(0))).write(
      TracksCompanion(hasCover: Value(hasCover), coverKey: Value(coverKey)),
    );
  }

  /// A hand-picked cover for one track (`cover_source = 2`).
  Future<void> setManualCover(int trackId, String coverKey) =>
      (_db.update(_db.tracks)..where((t) => t.id.equals(trackId))).write(
        TracksCompanion(
          hasCover: const Value(true),
          coverKey: Value(coverKey),
          coverSource: const Value(2),
        ),
      );

  /// A hand-picked cover for an album (`cover_source = 1`); tracks with their own stay.
  Future<void> setManualAlbumCover(String albumKey, String coverKey) =>
      (_db.update(_db.tracks)
            ..where((t) => t.albumKey.equals(albumKey) & t.coverSource.isNotValue(2)))
          .write(
        TracksCompanion(
          hasCover: const Value(true),
          coverKey: Value(coverKey),
          coverSource: const Value(1),
        ),
      );

  /// Back to the automatic cover [coverKey] (null = none) for track [trackId], or,
  /// with [albumKey], for the rows of that album whose cover was picked for the album.
  Future<void> restoreCover({int? trackId, String? albumKey, required String? coverKey}) {
    assert((trackId == null) != (albumKey == null));
    final q = _db.update(_db.tracks)
      ..where((t) => trackId != null
          ? t.id.equals(trackId) & t.coverSource.isBiggerThanValue(0)
          : t.albumKey.equals(albumKey!) & t.coverSource.equals(1));
    return q.write(TracksCompanion(
      hasCover: Value(coverKey != null),
      coverKey: Value(coverKey),
      coverSource: const Value(0),
    ));
  }

  /// [row] with the hand-picked cover its album has now (automatic when it has none).
  Future<TracksCompanion> _freshAlbumCover(TracksCompanion row) async {
    final album = row.albumKey.value;
    final manual = await albumManualRow(album);
    if (manual?.coverKey != null) return row.copyWith(coverKey: Value(manual!.coverKey));
    final auto = await _autoCoverOf(album);
    return row.copyWith(hasCover: Value(auto != null), coverKey: Value(auto), coverSource: const Value(0));
  }

  Future<String?> _autoCoverOf(String albumKey) async =>
      (await (_db.select(_db.tracks)
                ..where((t) => t.albumKey.equals(albumKey) & t.coverSource.equals(0) & t.coverKey.isNotNull())
                ..limit(1))
              .getSingleOrNull())
          ?.coverKey;

  /// [before] (a row with a hand-picked album cover) now has album key [newKey]: it
  /// leaves that cover behind and takes the one of the new album.
  Future<void> settleMovedCover(Track before, String newKey) async {
    if (before.coverSource != 1 || before.albumKey == newKey) return;
    final manual = await albumManualRow(newKey, exceptId: before.id);
    final key = manual?.coverKey ?? await _autoCoverOf(newKey);
    await (_db.update(_db.tracks)..where((t) => t.id.equals(before.id))).write(TracksCompanion(
      hasCover: Value(key != null),
      coverKey: Value(key),
      coverSource: Value(manual?.coverKey != null ? 1 : 0),
    ));
  }

  /// Every cover key a hand-picked cover (track or album) points at.
  Future<Set<String>> handPickedCoverKeys() async {
    final rows = await (_db.select(_db.tracks)
          ..where((t) => t.coverSource.isBiggerThanValue(0) & t.coverKey.isNotNull()))
        .get();
    return {for (final r in rows) r.coverKey!};
  }

  /// The distinct keys of the hand-picked covers of the album's rows.
  Future<Set<String>> albumManualKeys(String albumKey) async {
    final rows = await (_db.select(_db.tracks)
          ..where((t) => t.albumKey.equals(albumKey) & t.coverSource.equals(1) & t.coverKey.isNotNull()))
        .get();
    return {for (final r in rows) r.coverKey!};
  }

  /// How many rows show the cover [key].
  Future<int> countWithCoverKey(String key) async {
    final n = _db.tracks.id.count();
    final q = _db.selectOnly(_db.tracks)
      ..addColumns([n])
      ..where(_db.tracks.coverKey.equals(key));
    return (await q.map((r) => r.read(n)).getSingle()) ?? 0;
  }

  /// A row of the album whose cover was picked for the album, if any.
  Future<Track?> albumManualRow(String albumKey, {int? exceptId}) =>
      (_db.select(_db.tracks)
            ..where((t) =>
                t.albumKey.equals(albumKey) & t.coverSource.equals(1) & t.id.equals(exceptId ?? -1).not())
            ..limit(1))
          .getSingleOrNull();

  /// Every library music track as a list row, in no particular order (the
  /// daylist sorts them itself): no `ORDER BY`, no long texts.
  Future<List<Track>> musicLight() => lightSelect(
    _db,
    _db.select(_db.tracks)
      ..where((t) => t.missing.equals(false) & t.ignored.equals(false) & t.kind.equals(kMusicKind)),
  ).get();

  Stream<List<Track>> watchTracks({
    String query = '',
    SortOption sort = SortOption.defaultOrder,
    bool favoritesOnly = false,
  }) {
    final q = _db.select(_db.tracks)
      ..where((t) {
        Expression<bool> cond =
            t.missing.equals(false) &
            t.ignored.equals(false) &
            t.kind.equals(0);
        if (favoritesOnly) cond = cond & t.isFavorite.equals(true);
        final text = query.trim();
        if (text.isNotEmpty) {
          final pattern = '%${_escapeLike(text)}%';
          cond =
              cond &
              (t.title.like(pattern, escapeChar: r'\') |
                  t.artist.like(pattern, escapeChar: r'\') |
                  t.album.like(pattern, escapeChar: r'\'));
        }
        return cond;
      })
      ..orderBy(_orderFor(sort));
    return lightSelect(_db, q).watch();
  }

  List<OrderingTerm Function($TracksTable)> _orderFor(SortOption sort) {
    OrderingTerm nocase(Expression<String> e) =>
        OrderingTerm(expression: e.collate(Collate.noCase));
    return switch (sort) {
      SortOption.title => [(t) => nocase(t.title)],
      SortOption.artist => [(t) => nocase(t.artist), (t) => nocase(t.title)],
      SortOption.album => [
        (t) => nocase(t.album),
        (t) => OrderingTerm.asc(t.discNumber),
        (t) => OrderingTerm.asc(t.trackNumber),
      ],
      SortOption.year => [
        (t) => OrderingTerm.desc(t.year),
        (t) => nocase(t.title),
      ],
      SortOption.addedAt => [(t) => OrderingTerm.desc(t.addedAt)],
      SortOption.duration => [(t) => OrderingTerm.desc(t.durationMs)],
      SortOption.defaultOrder => [
        (t) => OrderingTerm.asc(t.albumKey),
        (t) => OrderingTerm.asc(t.discNumber),
        (t) => OrderingTerm.asc(t.trackNumber),
        (t) => nocase(t.title),
      ],
    };
  }

  /// The `ORDER BY` of [sort] in SQL (the same orders as [watchTracks]), or a
  /// shuffle that stays the same for a given [randomSeed].
  static String _orderSql(
    SortOption sort,
    int? randomSeed, {
    bool mostPlayed = false,
  }) {
    if (mostPlayed) {
      return 'play_count DESC, COALESCE(last_played_at, 0) DESC, title COLLATE NOCASE';
    }
    if (randomSeed != null) {
      // Not linear in the id (a seed would only rotate the order).
      final s = randomSeed.abs() % 1000003;
      return '(((((id + $s) * (id + $s)) % 1000003) * 104729) + id * 7919) % 1000003, id';
    }
    return switch (sort) {
      SortOption.title => 'title COLLATE NOCASE',
      SortOption.artist => 'artist COLLATE NOCASE, title COLLATE NOCASE',
      SortOption.album => 'album COLLATE NOCASE, disc_number, track_number',
      SortOption.year => 'year DESC, title COLLATE NOCASE',
      SortOption.addedAt => 'added_at DESC',
      SortOption.duration => 'duration_ms DESC',
      SortOption.defaultOrder =>
        'album_key, disc_number, track_number, title COLLATE NOCASE',
    };
  }

  ({String sql, List<Variable> vars}) _byRules(
    RuleExpr rules,
    SortOption sort,
    int? limit,
    int? randomSeed,
    int nowMs,
    Map<String, List<String>> countryArtists, {
    bool mostPlayed = false,
  }) {
    final q = toSql(rules, nowMs: nowMs, countryArtists: countryArtists);
    final vars = [...q.vars];
    final lim = limit == null ? '' : ' LIMIT ?';
    if (limit != null) vars.add(Variable<int>(limit));
    return (
      sql:
          'SELECT ${lightTrackColumns(_db)} FROM tracks WHERE ${q.where} '
          'ORDER BY ${_orderSql(sort, randomSeed, mostPlayed: mostPlayed)}$lim',
      vars: vars,
    );
  }

  /// The library songs whose main artist is [name], whatever the spelling in
  /// the tags (same artist key), by title.
  Future<List<Track>> tracksOfArtist(String name) async {
    final key = ArtistInfoRepository.keyOf(name);
    // A name of only symbols has an empty key: match the exact spelling.
    final spellings = key.isEmpty ? [name] : await spellingsOf(_db, key);
    if (spellings.isEmpty) return const [];
    return _db
        .customSelect(
          'SELECT ${lightTrackColumns(_db)} FROM tracks WHERE missing = 0 '
          'AND ignored = 0 AND kind = 0 AND artist IN '
          '(${List.filled(spellings.length, '?').join(',')}) '
          'ORDER BY title COLLATE NOCASE',
          variables: [for (final s in spellings) Variable<String>(s)],
          readsFrom: {_db.tracks},
        )
        .map((r) => _db.tracks.map(r.data))
        .get();
  }

  /// The tables a rule reads: a write to any other must not redo its query.
  Set<TableInfo> _ruleTables(RuleExpr rules) {
    final f = fieldsOf(rules);
    return {
      _db.tracks,
      if (f.contains(RuleField.tag)) ...[_db.trackTags, _db.userTags],
      if (f.contains(RuleField.genre)) _db.trackGenres,
      if (f.contains(RuleField.bpm) || f.contains(RuleField.recordLabel)) _db.trackEnrich,
      if (f.contains(RuleField.country)) _db.artistCountries,
    };
  }

  /// Tracks matching [rules] (the rule language of the search and of the smart
  /// playlists), kept up to date. «Added» terms count back from [now] at the
  /// time of the call.
  Stream<List<Track>> watchByRules(
    RuleExpr rules, {
    SortOption sort = SortOption.defaultOrder,
    int? limit,
    int? randomSeed,
    bool mostPlayed = false,
    DateTime? now,
  }) {
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    Stream<List<Track>> query(Map<String, List<String>> ca) {
      final q = _byRules(rules, sort, limit, randomSeed, nowMs, ca, mostPlayed: mostPlayed);
      return _db
          .customSelect(q.sql, variables: q.vars, readsFrom: _ruleTables(rules))
          .watch()
          .map((rows) => [for (final r in rows) _db.tracks.map(r.data)]);
    }

    if (countriesOf(rules).isEmpty) return query(const {});
    // The country -> artists map depends on tracks and countries: the query is redone
    // at most every 300 ms after a change of either (only rules that use «nazionalita»).
    // The map is reused while artist_countries is untouched (`version`) and no new
    // artist arrived (a smaller set is covered): the key resolution is the costly part.
    ({int version, Set<String> artists, Map<String, List<String>> map})? cache;
    return _watchWithCountries(rules, (version) async {
      final artists = await distinctArtists(_db);
      final c = cache;
      if (c == null || c.version != version || !c.artists.containsAll(artists)) {
        final map = await countryArtistsOf(_db, rules, artists: artists);
        cache = (version: version, artists: artists, map: map);
      }
      final ca = cache!.map;
      final q = _byRules(rules, sort, limit, randomSeed, nowMs, ca, mostPlayed: mostPlayed);
      final rows = await _db.customSelect(q.sql, variables: q.vars).get();
      return [for (final r in rows) _db.tracks.map(r.data)];
    });
  }

  Stream<List<Track>> _watchWithCountries(RuleExpr rules, Future<List<Track>> Function(int countriesVersion) run) {
    late final StreamController<List<Track>> c;
    StreamSubscription<Set<TableUpdate>>? sub;
    Timer? debounce;
    var gen = 0;
    var countriesVersion = 0; // bumped by every write on artist_countries
    Future<void> refresh() async {
      final mine = ++gen;
      try {
        final r = await run(countriesVersion);
        if (mine == gen && !c.isClosed) c.add(r); // only the latest answer counts
      } catch (e, st) {
        if (!c.isClosed) c.addError(e, st);
      }
    }

    c = StreamController<List<Track>>(
      onListen: () {
        refresh();
        sub = _db.tableUpdates(TableUpdateQuery.onAllTables(_ruleTables(rules))).listen((u) {
          if (u.any((t) => t.table == _db.artistCountries.actualTableName)) countriesVersion++;
          // not restarted by later events: a steady stream of writes still re-runs every 300 ms
          debounce ??= Timer(const Duration(milliseconds: 300), () {
            debounce = null;
            refresh();
          });
        });
      },
      onCancel: () async {
        gen++;
        debounce?.cancel();
        await sub?.cancel();
      },
    );
    return c.stream;
  }

  /// How many tracks match (for the «37 brani» of the editor).
  Future<int> countByRules(RuleExpr rules, {DateTime? now}) async {
    final q = toSql(
      rules,
      nowMs: (now ?? DateTime.now()).millisecondsSinceEpoch,
      countryArtists: await countryArtistsOf(_db, rules),
    );
    final rows = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM tracks WHERE ${q.where}',
          variables: q.vars,
          readsFrom: _ruleTables(rules),
        )
        .get();
    return rows.single.read<int>('n');
  }

  Future<Track?> getById(int id) =>
      (_db.select(_db.tracks)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// The visible tracks of the albums [keys], album by album, in album order.
  Future<List<Track>> tracksOfAlbums(Iterable<String> keys) =>
      _db.transaction(() async {
        final out = <Track>[];
        for (final key in keys) {
          out.addAll(
            await (_db.select(_db.tracks)
                  ..where(
                    (t) =>
                        t.albumKey.equals(key) &
                        t.missing.equals(false) &
                        t.ignored.equals(false) &
                        t.kind.equals(0),
                  )
                  ..orderBy([
                    (t) => OrderingTerm.asc(t.discNumber),
                    (t) => OrderingTerm.asc(t.trackNumber),
                  ]))
                .get(),
          );
        }
        return out;
      });

  /// [getByIds] as list rows (without the long texts): for the play queue.
  Future<List<Track>> getByIdsLight(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await lightSelect(
      _db,
      _db.select(_db.tracks)..where((t) => t.id.isIn(ids)),
    ).get();
    final byId = {for (final r in rows) r.id: r};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<List<Track>> getByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await (_db.select(
      _db.tracks,
    )..where((t) => t.id.isIn(ids))).get();
    final byId = {for (final r in rows) r.id: r};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<void> registerPlay(int id) async {
    await _db.customUpdate(
      'UPDATE tracks SET play_count = play_count + 1, last_played_at = ? WHERE id = ?',
      variables: [
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        Variable.withInt(id),
      ],
      updates: {_db.tracks},
    );
  }

  /// Where a long track was left (see `resumePointFor`); null clears it.
  Future<void> setResumePosition(int id, int? ms) =>
      (_db.update(_db.tracks)..where((t) => t.id.equals(id))).write(
        TracksCompanion(resumePositionMs: Value(ms)),
      );

  /// The length the player measured (an episode's tags or feed can be wrong).
  Future<void> setDurationMs(int id, int ms) =>
      (_db.update(_db.tracks)..where((t) => t.id.equals(id))).write(
        TracksCompanion(durationMs: Value(ms)),
      );

  /// Local mp3 music files that are there (no episodes: the player corrects their length; no
  /// stream shadow rows), for the one-off length fix.
  Future<List<({int id, String path, int durationMs, int? bitrateKbps})>> mp3LengthRows() async {
    final rows = await (_db.select(_db.tracks)
          ..where((t) => t.format.equals('mp3') & t.kind.equals(kMusicKind) & t.missing.equals(false)))
        .get();
    return [
      for (final r in rows)
        if (!r.path.startsWith('stream:'))
          (id: r.id, path: r.path, durationMs: r.durationMs, bitrateKbps: r.bitrateKbps),
    ];
  }

  /// Only the length and the bitrate: titles, artists and the rest stay as they are.
  Future<void> setLengths(List<({int id, int durationMs, int bitrateKbps})> rows) =>
      _db.transaction(() async {
        for (final r in rows) {
          await (_db.update(_db.tracks)..where((t) => t.id.equals(r.id))).write(
            TracksCompanion(durationMs: Value(r.durationMs), bitrateKbps: Value(r.bitrateKbps)),
          );
        }
      });

  /// Hides or shows tracks (the duplicates a merge leaves behind). The
  /// scanner never touches the flag, so a hidden file stays hidden.
  Future<void> setIgnored(Set<int> ids, bool value) async {
    if (ids.isEmpty) return;
    await _db.transaction(() async {
      for (final chunk in _chunks(ids.toList(), 500)) {
        await (_db.update(_db.tracks)..where((t) => t.id.isIn(chunk))).write(
          TracksCompanion(ignored: Value(value)),
        );
      }
    });
  }

  Stream<List<Track>> watchIgnored() =>
      (_db.select(_db.tracks)
            ..where((t) => t.ignored.equals(true) & t.kind.isNotValue(kStreamKind))
            ..orderBy([
              (t) => OrderingTerm(expression: t.title.collate(Collate.noCase)),
            ]))
          .watch();

  /// The music added last, newest first (the empty player offers them).
  Stream<List<Track>> watchRecentlyAdded({int limit = 24}) => lightSelect(
    _db,
    _db.select(_db.tracks)
      ..where((t) => t.missing.equals(false) & t.ignored.equals(false) & t.kind.equals(0))
      ..orderBy([(t) => OrderingTerm.desc(t.addedAt), (t) => OrderingTerm.desc(t.id)])
      ..limit(limit),
  ).watch();

  /// Tracks and podcast episodes left in the middle, newest first (the Home
  /// «Riprendi» rows). Kind 2 (stream shadow rows) stays out.
  Stream<List<Track>> watchResumable({int limit = 3}) =>
      (_db.select(_db.tracks)
            ..where(
              (t) =>
                  t.resumePositionMs.isNotNull() &
                  t.missing.equals(false) &
                  t.ignored.equals(false) &
                  t.kind.isIn(const [0, kEpisodeKind]) &
                  // Marked as heard by hand: nothing left to resume.
                  notExistsQuery(_db.select(_db.podcastEpisodes)
                    ..where((e) => e.trackId.equalsExp(t.id) & e.played.equals(true))),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.lastPlayedAt)])
            ..limit(limit))
          .watch();

  Stream<List<Track>> watchMissing() =>
      (_db.select(_db.tracks)
            ..where((t) =>
                t.missing.equals(true) &
                t.ignored.equals(false) &
                t.kind.isNotValue(kStreamKind))
            ..orderBy([(t) => OrderingTerm.asc(t.path)]))
          .watch();

  Future<void> deleteTrack(int id) =>
      (_db.delete(_db.tracks)..where((t) => t.id.equals(id))).go();

  /// Forgets cover info (not the hand-picked ones) and forces the next scan to re-read every file.
  Future<void> resetCovers() async {
    await (_db.update(_db.tracks)..where((t) => t.coverSource.equals(0)))
        .write(const TracksCompanion(hasCover: Value(false), coverKey: Value(null)));
    await _db.update(_db.tracks).write(const TracksCompanion(mtimeMs: Value(0)));
  }

  /// Id, title, artist and length of every available track, for matching an
  /// imported playlist against the library without loading whole rows.
  Future<List<LibraryEntryLite>> liteEntries() async {
    // Plain SQL: the typed query API costs ~15 µs per row, which is most of
    // the time at 50 000 tracks.
    final rows = await _db
        .customSelect(
          'SELECT id, title, artist, duration_ms, path FROM tracks '
          'WHERE missing = 0 AND ignored = 0 AND kind = 0',
          readsFrom: {_db.tracks},
        )
        .get();
    return [
      for (final r in rows)
        LibraryEntryLite(
          id: r.data['id']! as int,
          title: (r.data['title'] as String?) ?? '',
          artist: r.data['artist'] as String?,
          durationMs: (r.data['duration_ms'] as int?) ?? 0,
          path: r.data['path'] as String?,
        ),
    ];
  }

  Future<int?> idForPath(String path) async {
    final rows = await lightSelect(
      _db,
      _db.select(_db.tracks)..where((r) => r.path.equals(path)),
    ).get();
    return rows.firstOrNull?.id;
  }

  /// Marks a track as edited by hand (its tags then survive a rescan) or not.
  Future<void> setUserEdited(int id, bool value) =>
      (_db.update(_db.tracks)..where((t) => t.id.equals(id))).write(
        TracksCompanion(userEdited: Value(value)),
      );

  Future<void> setFavorite(int id, bool value) =>
      (_db.update(_db.tracks)..where((t) => t.id.equals(id))).write(
        TracksCompanion(isFavorite: Value(value)),
      );

  /// Stores the lyrics of one track; a missing synced version clears the column.
  /// [byUser]: the user chose or wrote them, so the enrichment never replaces them.
  Future<void> setLyrics(int id, {String? plain, String? synced, bool byUser = false}) =>
      _db.transaction(() async {
        await (_db.update(_db.tracks)..where((t) => t.id.equals(id))).write(
          TracksCompanion(lyricsPlain: Value(plain), lyricsSynced: Value(synced)),
        );
        if (byUser) {
          await _db.into(_db.trackEnrich).insertOnConflictUpdate(
              TrackEnrichCompanion(trackId: Value(id), lyricsByUser: const Value(true)));
        }
      });

  /// Removes the lyrics of one track and lets the automatic search try again:
  /// the «by user» flag and the «nothing found» marks go too (D-471). Returns
  /// what was there, for [restoreLyrics].
  Future<LyricsSnapshot> clearLyrics(int id) => _db.transaction(() async {
        final t = await (_db.select(_db.tracks)..where((t) => t.id.equals(id))).getSingle();
        final e = await (_db.select(_db.trackEnrich)..where((e) => e.trackId.equals(id))).getSingleOrNull();
        await (_db.update(_db.tracks)..where((t) => t.id.equals(id)))
            .write(const TracksCompanion(lyricsPlain: Value(null), lyricsSynced: Value(null)));
        await (_db.update(_db.trackEnrich)..where((e) => e.trackId.equals(id))).write(const TrackEnrichCompanion(
            lyricsByUser: Value(false), lyricsNoneAt: Value(null), syncedNoneAt: Value(null)));
        return (
          plain: t.lyricsPlain,
          synced: t.lyricsSynced,
          byUser: e?.lyricsByUser ?? false,
          noneAt: e?.lyricsNoneAt,
          syncedNoneAt: e?.syncedNoneAt,
        );
      });

  /// Puts back exactly what [clearLyrics] took away.
  Future<void> restoreLyrics(int id, LyricsSnapshot s) => _db.transaction(() async {
        await (_db.update(_db.tracks)..where((t) => t.id.equals(id)))
            .write(TracksCompanion(lyricsPlain: Value(s.plain), lyricsSynced: Value(s.synced)));
        await (_db.update(_db.trackEnrich)..where((e) => e.trackId.equals(id))).write(TrackEnrichCompanion(
            lyricsByUser: Value(s.byUser), lyricsNoneAt: Value(s.noneAt), syncedNoneAt: Value(s.syncedNoneAt)));
      });

  /// Stores the «curiosities» text of one track (null clears it).
  Future<void> setCuriosities(int id, String? text) =>
      (_db.update(_db.tracks)..where((t) => t.id.equals(id))).write(
        TracksCompanion(curiosities: Value(text)),
      );

  /// Sets the favourite flag of many tracks in one transaction.
  Future<void> setFavoriteMany(List<int> ids, bool value) async {
    if (ids.isEmpty) return;
    await _db.transaction(() async {
      for (final chunk in _chunks(ids, 500)) {
        await (_db.update(_db.tracks)..where((t) => t.id.isIn(chunk))).write(
          TracksCompanion(isFavorite: Value(value)),
        );
      }
    });
  }

  /// Forgets library rows, but only those whose file is gone (`missing`): a
  /// track that is still there is never touched. Returns how many went.
  Future<int> deleteMissingTracks(List<int> ids) async {
    if (ids.isEmpty) return 0;
    return _db.transaction(() async {
      var removed = 0;
      for (final chunk in _chunks(ids, 500)) {
        removed += await (_db.delete(
          _db.tracks,
        )..where((t) => t.id.isIn(chunk) & t.missing.equals(true))).go();
      }
      return removed;
    });
  }

  /// Deletes library rows whatever their state (the caller has already made
  /// sure the files are gone). Playlist entries, history and tags go with them
  /// (cascade). Returns how many rows went.
  Future<int> deleteTracks(List<int> ids) async {
    if (ids.isEmpty) return 0;
    return _db.transaction(() async {
      var removed = 0;
      for (final chunk in _chunks(ids, 500)) {
        removed += await (_db.delete(
          _db.tracks,
        )..where((t) => t.id.isIn(chunk))).go();
      }
      return removed;
    });
  }

  Stream<Track?> watchById(int id) => (_db.select(
    _db.tracks,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// How many music tracks there are (podcast episodes are not counted).
  Future<int> countAll() async {
    final c = _db.tracks.id.count();
    final row =
        await (_db.selectOnly(_db.tracks)
              ..addColumns([c])
              ..where(_db.tracks.kind.equals(0)))
            .getSingle();
    return row.read(c) ?? 0;
  }

  /// Live [countAll].
  Stream<int> watchCount({bool favoritesOnly = false}) {
    final c = _db.tracks.id.count();
    return (_db.selectOnly(_db.tracks)
          ..addColumns([c])
          ..where(
            _db.tracks.kind.equals(0) &
                _db.tracks.missing.equals(false) &
                _db.tracks.ignored.equals(false) &
                (favoritesOnly
                    ? _db.tracks.isFavorite.equals(true)
                    : const Constant(true)),
          ))
        .watchSingle()
        .map((r) => r.read(c) ?? 0);
  }

  static String _escapeLike(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

  static Iterable<List<T>> _chunks<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, i + size > list.length ? list.length : i + size);
    }
  }
}
