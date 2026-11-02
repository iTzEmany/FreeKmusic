import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/app_log.dart';
import '../../services/online/credits.dart';
import '../../services/online/enrich_parts.dart';
import '../../services/recognition/track_identity.dart';
import '../db/app_database.dart';
import 'light_tracks.dart';

/// Credits and enrichment state of tracks. Writes only `track_credits` and
/// `track_enrich`, never `tracks` (so the library list does not re-emit).
class CreditsRepository {
  CreditsRepository(this._db);

  final AppDatabase _db;

  Future<List<TrackCreditRow>> creditsOf(int trackId) => (_db.select(
    _db.trackCredits,
  )..where((c) => c.trackId.equals(trackId))).get();

  Future<TrackEnrichData?> enrichOf(int trackId) => (_db.select(
    _db.trackEnrich,
  )..where((e) => e.trackId.equals(trackId))).getSingleOrNull();

  /// Ids of tracks with a part of [parts] due at [now], by id, at most
  /// [limit]. The same rule as `isDue` (an empty part
  /// not marked «nothing» in the last 30 days), in SQL and on light columns.
  /// [after]: only ids above it; [upTo]: and up to this one; [among]: only
  /// these ids.
  /// [mode]: see [AskMode]. Tracks of kind music or stream, not missing or hidden.
  Future<List<int>> dueTrackIds(
    Set<EnrichPart> parts,
    DateTime now, {
    int limit = 20,
    AskMode mode = AskMode.due,
    int after = 0,
    int? upTo,
    Iterable<int>? among,
  }) async {
    if (parts.isEmpty || (among != null && among.isEmpty)) return const [];
    final rows = await _db
        .customSelect(
          'SELECT t.id FROM $eligibleSql AND t.id > ?3 AND t.id <= ?4 '
          '${among == null ? '' : 'AND t.id IN (${among.join(',')}) '}' // ints only
          'AND (${dueSql(parts, mode)}) ORDER BY t.id LIMIT ?2',
          variables: [
            _retryBefore(now),
            Variable<int>(limit),
            Variable<int>(after),
            Variable<int>(upTo ?? 0x7fffffffffffffff),
          ],
          readsFrom: {_db.tracks, _db.trackEnrich, _db.trackCredits},
        )
        .get();
    return [for (final r in rows) r.read<int>('id')];
  }

  /// How many eligible tracks have nothing due among [parts] (`complete`) out
  /// of all of them (`total`); due as in [mode].
  Future<({int complete, int total})> enrichCounts(
    Set<EnrichPart> parts,
    DateTime now, {
    AskMode mode = AskMode.due,
  }) => _counts(parts, now, mode).getSingle().then(_toCounts);

  /// [enrichCounts] again at each change of the tracks.
  Stream<({int complete, int total})> watchEnrichCounts(
    Set<EnrichPart> parts,
    DateTime now, {
    AskMode mode = AskMode.due,
  }) => _counts(parts, now, mode).watchSingle().map(_toCounts);

  Selectable<QueryRow> _counts(Set<EnrichPart> parts, DateTime now, AskMode mode) =>
      _db.customSelect(
        'SELECT COUNT(*) AS total, '
        '${parts.isEmpty ? '0' : 'COALESCE(SUM(${dueSql(parts, mode)}), 0)'} AS due '
        'FROM $eligibleSql',
        // ?1 is in the SQL only for a plain run.
        variables: [if (parts.isNotEmpty && mode == AskMode.due) _retryBefore(now)],
        readsFrom: {_db.tracks, _db.trackEnrich, _db.trackCredits},
      );

  static ({int complete, int total}) _toCounts(QueryRow r) {
    final total = r.read<int>('total');
    return (complete: total - r.read<int>('due'), total: total);
  }

  /// A «nothing» mark older than this (?1) no longer holds.
  static Variable<int> _retryBefore(DateTime now) =>
      Variable<int>(now.millisecondsSinceEpoch - retryNoneAfter.inMilliseconds);

  /// Library tracks (`kind = 0`) credited to [nameKey] (a `creditNameKey`).
  /// Exact key: one entry per role (a track with two roles appears twice).
  /// [prefix]: names starting with the key, one entry per track, by title,
  /// without the [exclude] ids and at most [limit]. The key is compared as
  /// stored (made in Dart, not lower()'d by SQLite); the prefix range uses the
  /// `name_key` index.
  Future<List<({String role, Track track})>> creditedTracks(
    String nameKey, {
    bool prefix = false,
    Set<int> exclude = const {},
    int? limit,
  }) async {
    if (nameKey.isEmpty) return const [];
    final rows = await _db
        .customSelect(
          'SELECT ${prefix ? '' : 'DISTINCT '}c.role AS credit_role, '
          '${lightTrackColumns(_db, alias: 't')} '
          'FROM track_credits c JOIN tracks t ON t.id = c.track_id '
          'WHERE ${prefix ? 'c.name_key >= ? AND c.name_key < ? || char(1114111)' : 'c.name_key = ?'} '
          'AND t.kind = 0 AND t.missing = 0 AND t.ignored = 0 '
          '${prefix ? 'GROUP BY t.id ORDER BY t.title COLLATE NOCASE' : 'ORDER BY c.role, t.title COLLATE NOCASE'}'
          '${limit == null ? '' : ' LIMIT ?'}',
          variables: [
            Variable<String>(nameKey),
            if (prefix) Variable<String>(nameKey),
            if (limit != null) Variable<int>(limit + exclude.length),
          ],
          readsFrom: {_db.tracks, _db.trackCredits},
        )
        .get();
    final all = [
      for (final r in rows)
        (role: r.read<String>('credit_role'), track: _db.tracks.map(r.data)),
    ].where((e) => !exclude.contains(e.track.id));
    return (limit == null ? all : all.take(limit)).toList();
  }

  /// Replaces every credit of [trackId] with [credits] (their `trackId` is
  /// the one given here).
  Future<void> saveCredits(int trackId, List<TrackCreditsCompanion> credits) =>
      _db.transaction(() => _replace(trackId, credits));

  /// Runs [body] in one transaction (read-merge-write of the shared `details`).
  Future<T> atomic<T>(Future<T> Function() body) => _db.transaction(body);

  /// Upserts the enrichment row; columns absent from [row] keep their value.
  Future<void> saveEnrich(TrackEnrichCompanion row) => _upsert(row);

  /// [saveCredits] and [saveEnrich] in one transaction.
  Future<void> save(
    int trackId,
    List<TrackCreditsCompanion> credits,
    TrackEnrichCompanion row,
  ) => _db.transaction(() async {
    await _replace(trackId, credits);
    await _upsert(row);
  });

  /// For the duplicate merge, inside its transaction. Credits move only when [keepId] has none (first drop with credits wins);
  /// `track_enrich` merges column by column, the keeper's value first.
  Future<void> moveInto(int keepId, Set<int> drops) async {
    final c = _db.trackCredits;
    final keepHas = await (_db.select(
      c,
    )..where((t) => t.trackId.equals(keepId))).get();
    if (keepHas.isEmpty) {
      for (final id in drops) {
        final n = await _db.customUpdate(
          'INSERT OR IGNORE INTO track_credits '
          '(track_id, name, name_key, role, source) '
          'SELECT ?, name, name_key, role, source FROM track_credits '
          'WHERE track_id = ?',
          variables: [Variable<int>(keepId), Variable<int>(id)],
          updates: {c},
        );
        if (n > 0) break;
      }
    }
    await (_db.delete(c)..where((t) => t.trackId.isIn(drops))).go();

    // Credits and the «searched, nothing» mark never coexist.
    final hasCredits =
        (await (_db.select(c)
                  ..where((t) => t.trackId.equals(keepId))
                  ..limit(1))
                .get())
            .isNotEmpty;
    final e = _db.trackEnrich;
    final rows = <TrackEnrichData>[
      for (final id in [keepId, ...drops])
        ...await (_db.select(e)..where((t) => t.trackId.equals(id))).get(),
    ];
    final keeperMark = rows
        .where((r) => r.trackId == keepId)
        .firstOrNull
        ?.creditsNoneAt;
    if (rows.length > (rows.any((r) => r.trackId == keepId) ? 1 : 0) ||
        (hasCredits && keeperMark != null)) {
      T? first<T extends Object>(T? Function(TrackEnrichData) pick) =>
          rows.map(pick).whereType<T>().firstOrNull;
      await _db
          .into(e)
          .insertOnConflictUpdate(
            TrackEnrichCompanion.insert(
              trackId: Value(keepId),
              details: Value(_mergedRaw(rows)),
              deezerId: Value(first((r) => r.deezerId)),
              mbid: Value(first((r) => r.mbid)),
              metaNoneAt: Value(first((r) => r.metaNoneAt)),
              lyricsNoneAt: Value(first((r) => r.lyricsNoneAt)),
              syncedNoneAt: Value(first((r) => r.syncedNoneAt)),
              curioNoneAt: Value(first((r) => r.curioNoneAt)),
              creditsNoneAt: Value(
                hasCredits ? null : first((r) => r.creditsNoneAt),
              ),
              lyricsByUser: Value(rows.any((r) => r.lyricsByUser)),
            ),
          );
    }
    await (_db.delete(e)..where((t) => t.trackId.isIn(drops))).go();
  }

  /// The column of the first row with details (else the first with any), plus
  /// the recognition of another row if that one has none.
  static String? _mergedRaw(List<TrackEnrichData> rows) {
    // Each row's JSON is decoded once.
    final ds = [
      for (final r in rows) (raw: r.details, j: _decodeMap(r.details, r.trackId)),
    ];
    final chosen =
        ds.where((d) => _hasDetails(d.j)).firstOrNull ?? ds.where((d) => d.raw != null).firstOrNull;
    if (chosen == null || _recOf(chosen.j) != null) return chosen?.raw;
    final rec = ds.map((d) => _recOf(d.j)).nonNulls.firstOrNull;
    return rec == null ? chosen.raw : mergeDetails(chosen.raw, rec: rec);
  }

  /// Credits and details as they travel (backup, share, Jam).
  Future<({List<TrackCredit> credits, TrackDetails? details})> portableOf(
    int trackId,
  ) async => (await portableOfMany([trackId]))[trackId]!;

  /// [portableOf] again whenever this track's credits or details change.
  /// Watches only a per-track query (not `tracks`): drift drops equal results.
  Stream<({List<TrackCredit> credits, TrackDetails? details})> watchPortableOf(
    int trackId,
  ) => _db
      .customSelect(
        'SELECT name, role, source, NULL AS d FROM track_credits '
        'WHERE track_id = ?1 UNION ALL '
        'SELECT NULL, NULL, NULL, details FROM track_enrich WHERE track_id = ?1',
        variables: [Variable<int>(trackId)],
        readsFrom: {_db.trackCredits, _db.trackEnrich},
      )
      .watch()
      .asyncMap((_) => portableOf(trackId));

  /// The recognition stored for [trackId] (null when none), again whenever it changes.
  Stream<Recognition?> watchRec(int trackId) => _db
      .customSelect(
        'SELECT details FROM track_enrich WHERE track_id = ?1',
        variables: [Variable<int>(trackId)],
        readsFrom: {_db.trackEnrich},
      )
      .watch()
      .map((rows) => rows.isEmpty ? null : decodeRec(rows.first.read<String?>('details'), trackId));

  /// The open proposals (a sure-enough identity that differs, not yet decided) of
  /// the tracks the user has not edited. A row whose JSON is broken is left out (K-RB-08).
  Stream<List<({Track track, Recognition rec})>> watchProposals() => _db
      .customSelect(
        'SELECT e.track_id AS id, e.details AS d FROM track_enrich e '
        'JOIN tracks t ON t.id = e.track_id '
        "WHERE json_valid(e.details) AND json_extract(e.details, '\$.rec.prop') = 'open' "
        'AND t.user_edited = 0',
        readsFrom: {_db.trackEnrich, _db.tracks},
      )
      .watch()
      .asyncMap((rows) async {
        final recs = <int, Recognition>{};
        for (final r in rows) {
          final id = r.read<int>('id');
          final rec = decodeRec(r.read<String>('d'), id);
          if (rec?.identity != null) recs[id] = rec!;
        }
        final tracks = await (_db.select(_db.tracks)..where((t) => t.id.isIn(recs.keys))).get();
        return [for (final t in tracks) (track: t, rec: recs[t.id]!)];
      });

  /// [creditedTracks] again whenever credits with this key change.
  Stream<List<({String role, Track track})>> watchCreditedTracks(
    String nameKey,
  ) => _db
      .customSelect(
        'SELECT track_id, role FROM track_credits WHERE name_key = ?',
        variables: [Variable<String>(nameKey)],
        readsFrom: {_db.trackCredits},
      )
      .watch()
      .asyncMap((_) => creditedTracks(nameKey));

  /// [portableOf] for many tracks in two queries; every id has an entry.
  Future<Map<int, ({List<TrackCredit> credits, TrackDetails? details})>>
  portableOfMany(Iterable<int> ids) async {
    final credits = <int, List<TrackCredit>>{};
    final details = <int, TrackDetails?>{};
    final all = ids.toSet().toList();
    // Chunks keep the IN list under SQLite's variable limit.
    for (var i = 0; i < all.length; i += 500) {
      final chunk = all.sublist(i, i + 500 > all.length ? all.length : i + 500);
      for (final c in await (_db.select(
        _db.trackCredits,
      )..where((c) => c.trackId.isIn(chunk))).get()) {
        (credits[c.trackId] ??= []).add(TrackCredit(c.name, c.role, c.source));
      }
      for (final e in await (_db.select(
        _db.trackEnrich,
      )..where((e) => e.trackId.isIn(chunk))).get()) {
        details[e.trackId] = decodeDetails(e.trackId, e.details);
      }
    }
    return {
      for (final id in ids)
        id: (credits: credits[id] ?? const [], details: details[id]),
    };
  }

  /// For backup and received tracks: credits are written only when the track
  /// has none, details only when it has none. Saving credits clears
  /// `credits_none_at` (credits and the «searched, nothing» mark never coexist).
  Future<void> saveIfNone(
    int trackId,
    List<TrackCredit> credits,
    TrackDetails? details,
  ) => _db.transaction(() async {
    final hasCredits = (await creditsOf(trackId)).isNotEmpty;
    final saveCredits = credits.isNotEmpty && !hasCredits;
    final raw = details == null ? null : (await enrichOf(trackId))?.details;
    final saveDetails = details != null && decodeDetails(trackId, raw) == null;
    if (saveCredits) {
      await _replace(trackId, [
        for (final c in credits)
          TrackCreditsCompanion.insert(
            trackId: trackId,
            name: c.name,
            nameKey: c.nameKey,
            role: c.role,
            source: c.source,
          ),
      ]);
    }
    if (saveCredits || saveDetails) {
      await _upsert(
        TrackEnrichCompanion(
          trackId: Value(trackId),
          details: saveDetails
              ? Value(mergeDetails(raw, details: details))
              : const Value.absent(),
          creditsNoneAt: saveCredits ? const Value(null) : const Value.absent(),
        ),
      );
    }
  });

  Future<void> _replace(
    int trackId,
    List<TrackCreditsCompanion> credits,
  ) async {
    await (_db.delete(
      _db.trackCredits,
    )..where((c) => c.trackId.equals(trackId))).go();
    await _db.batch(
      (b) => b.insertAll(_db.trackCredits, [
        for (final c in credits) c.copyWith(trackId: Value(trackId)),
      ], mode: InsertMode.insertOrReplace),
    );
  }

  Future<void> _upsert(TrackEnrichCompanion row) =>
      _db.into(_db.trackEnrich).insert(row, onConflict: DoUpdate((_) => row));
}

/// The keys of [TrackDetails] in the shared `details` column; `rec` is the other.
final _detailKeys = const TrackDetails().toJson().keys.toSet();

Map<Object?, Object?>? _decodeMap(String? raw, [int? trackId]) {
  if (raw == null) return null;
  try {
    return jsonDecode(raw) as Map;
  } on Object catch (e, st) {
    AppLog.w('track $trackId: details not readable', e, st);
    return null;
  }
}

/// The stored details JSON; a corrupt row logs and gives null, and so does a
/// row with no key of [TrackDetails] (e.g. only `rec`).
TrackDetails? decodeDetails(int trackId, String? raw) {
  final j = _decodeMap(raw, trackId);
  return _hasDetails(j) ? TrackDetails.fromJson(j!) : null;
}

bool _hasDetails(Map<Object?, Object?>? j) => j != null && _detailKeys.any(j.containsKey);

Recognition? _recOf(Map<Object?, Object?>? j) => Recognition.fromJson(j?['rec']);

/// The recognition stored under `rec`, or null. [trackId] is for the log.
Recognition? decodeRec(String? raw, [int? trackId]) => _recOf(_decodeMap(raw, trackId));

/// The only way to write `details`: [raw] (what is stored) with [details] and
/// [rec] put in, whatever the other one owns kept.
String mergeDetails(String? raw, {TrackDetails? details, Recognition? rec}) {
  final j = <Object?, Object?>{...?_decodeMap(raw)};
  if (details != null) j.addAll(details.toJson()); // all its keys, null or not
  if (rec != null) j['rec'] = rec.toJson();
  return jsonEncode(j);
}
