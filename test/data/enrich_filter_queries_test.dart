import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/enrich_filter_queries.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    Future<void> add(int id, String? details) async {
      await db.into(db.tracks).insert(TracksCompanion.insert(
          id: Value(id), path: '/$id.mp3', title: 't$id', albumKey: 'k',
          format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1));
      if (details != null) {
        await db.into(db.trackEnrich).insert(
            TrackEnrichCompanion.insert(trackId: Value(id), details: Value(details)));
      }
    }
    await add(1, '{"bpm":120.0,"label":"Édition  Spéciale"}');
    await add(2, '{"bpm":90,"label":"Other"}');
    await add(3, null); // not enriched
    await add(4, '{"rank":5}'); // fields missing
    await add(5, '{not json'); // malformed
    await add(6, '{"bpm":"fast","label":7}'); // wrong types
  });
  tearDown(() => db.close());

  test('BPM range returns only enriched tracks in range', () async {
    expect(await trackIdsByBpm(db, min: 100, max: 130), {1});
    expect(await trackIdsByBpm(db, max: 100), {2});
    expect(await trackIdsByBpm(db), {1, 2});
  });

  test('label match ignores case, accents and spaces', () async {
    expect(await trackIdsByLabel(db, ['edition speciale']), {1});
    expect(await trackIdsByLabel(db, ['OTHER', 'nope']), {2});
    expect(await trackIdsByLabel(db, ['']), isEmpty);
  });

  test('missing, malformed and mistyped details never break the query', () async {
    expect(await trackIdsByLabel(db, ['7', 'fast']), isEmpty);
    expect(await trackIdsByBpm(db, min: 0), {1, 2});
  });
}
