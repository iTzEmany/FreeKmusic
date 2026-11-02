import 'package:drift/drift.dart';

import '../../services/online/enrich_parts.dart';
import '../../services/online/enrich_engine.dart' show needsRecognition;
import '../../services/recognition/track_identity.dart' show kRecogVersion;
import '../db/app_database.dart';
import 'credits_repository.dart' show decodeRec;

/// Ids for the recognition re-pass (R-176): enriched tracks, not hand-edited,
/// whose `rec` is missing or older than [kRecogVersion], by id above [after].
Future<List<int>> Function(int after, int limit) recogPassQuery(AppDatabase db) => (after, limit) async {
  final rows = await db
      .customSelect(
        'SELECT t.id FROM $eligibleSql AND t.id > ?1 AND t.enrich_status <> 0 AND t.user_edited = 0 '
        "AND COALESCE(CASE WHEN json_valid(e.details) THEN json_extract(e.details, '\$.rec.v') END, 0) < ?2 "
        'ORDER BY t.id LIMIT ?3',
        variables: [Variable<int>(after), Variable<int>(kRecogVersion), Variable<int>(limit)],
        readsFrom: {db.tracks, db.trackEnrich},
      )
      .get();
  return [for (final r in rows) r.read<int>('id')];
};

/// `needsRecognition` for one track, read fresh from the database.
Future<bool> Function(int id) recogPassNeeds(AppDatabase db) => (id) async {
  final t = await (db.select(db.tracks)..where((t) => t.id.equals(id))).getSingleOrNull();
  if (t == null) return false;
  final e = await (db.select(db.trackEnrich)..where((e) => e.trackId.equals(id))).getSingleOrNull();
  return needsRecognition(t, e, decodeRec(e?.details, id));
};
