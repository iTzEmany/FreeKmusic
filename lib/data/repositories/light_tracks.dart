import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// The long texts of a track: lyrics, synced lyrics and curiosities (about
/// 6 KB on an enriched track). Lists never show them, so list rows do not
/// carry them: in their place a list row has `''` when the text exists and
/// null when it does not, so `== null` keeps meaning «none». The screens that
/// show the texts read the whole row ([TrackRepository.watchById]).
const heavyTrackColumns = {'lyrics_plain', 'lyrics_synced', 'curiosities'};

String? _columns;
final _aliased = <String, String>{};

/// The SELECT list of a list row; [alias] qualifies the columns in a join.
String lightTrackColumns(AppDatabase db, {String? alias}) {
  String build(String pre) => [
        for (final c in db.tracks.$columns)
          heavyTrackColumns.contains(c.$name)
              ? "CASE WHEN $pre${c.$name} IS NULL THEN NULL ELSE '' END AS ${c.$name}"
              : '$pre${c.$name}',
      ].join(', ');
  if (alias == null) return _columns ??= build('');
  return _aliased[alias] ??= build('$alias.');
}

/// [query], a plain `select(tracks)` with its filter, order and limit, read as
/// list rows.
Selectable<Track> lightSelect(
    AppDatabase db, SimpleSelectStatement<$TracksTable, Track> query) {
  final ctx = query.constructQuery();
  const star = 'SELECT * FROM ';
  final sql = ctx.sql;
  if (!sql.startsWith(star)) throw StateError('not a plain select: $sql');
  final rest = sql.substring(star.length).replaceFirst(RegExp(r';\s*$'), '');
  return db
      .customSelect('SELECT ${lightTrackColumns(db)} FROM $rest',
          variables: ctx.introducedVariables, readsFrom: {db.tracks, ...ctx.watchedTables})
      .map((r) => db.tracks.map(r.data));
}
