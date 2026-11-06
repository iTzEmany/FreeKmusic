import 'package:drift/drift.dart';

import '../../core/text_utils.dart';
import '../db/app_database.dart';

/// Filters on BPM and label (F-96, D-390), read from `track_enrich.details`
/// with `json_extract`: no derived columns, only enriched tracks have a value.
/// `json_valid` guards the extract, so malformed JSON gives NULL (excluded).
/// [e] is the alias of `track_enrich` in the caller's query.
String bpmSql([String e = 'e']) =>
    "(CASE WHEN json_valid($e.details) THEN json_extract($e.details, '\$.bpm') END)";

/// Same as [bpmSql], for the label. Not folded: SQLite has no accent folding.
String labelSql([String e = 'e']) =>
    "(CASE WHEN json_valid($e.details) THEN json_extract($e.details, '\$.label') END)";

/// Ids of enriched tracks with BPM in [min]..[max] (either bound optional).
Future<Set<int>> trackIdsByBpm(AppDatabase db, {double? min, double? max}) async {
  final rows = await db.customSelect(
    'SELECT e.track_id AS id FROM track_enrich e WHERE ${bpmSql()} IS NOT NULL '
    'AND ${bpmSql()} >= ?1 AND ${bpmSql()} <= ?2',
    variables: [Variable<double>(min ?? 0), Variable<double>(max ?? 1e9)],
    readsFrom: {db.trackEnrich},
  ).get();
  return {for (final r in rows) r.read<int>('id')};
}

/// Ids of enriched tracks whose label is any of [labels], compared with
/// [normalize] (case, accents, spaces). shortcut: folded in Dart over the
/// enriched rows only, upgrade to a derived column if that set grows large.
Future<Set<int>> trackIdsByLabel(AppDatabase db, Iterable<String> labels) async {
  final wanted = {for (final l in labels) normalize(l)}..remove('');
  if (wanted.isEmpty) return {};
  final rows = await db.customSelect(
    'SELECT e.track_id AS id, ${labelSql()} AS label FROM track_enrich e '
    'WHERE ${labelSql()} IS NOT NULL',
    readsFrom: {db.trackEnrich},
  ).get();
  return {
    for (final r in rows)
      if (r.data['label'] case final String l when wanted.contains(normalize(l)))
        r.read<int>('id'),
  };
}
