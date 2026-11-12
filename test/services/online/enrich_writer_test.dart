import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/covers/cover_store.dart';
import 'package:codecore/services/online/enrich_parts.dart';
import 'package:codecore/services/online/enrich_writer.dart';
import 'package:codecore/services/online/enrichment_proposal.dart';
import 'package:codecore/services/online/itunes_client.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('moving off the unknown|dir key drops the shared cover', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tracks = TrackRepository(db);
    const old = 'unknown|/m';
    await tracks.upsertBatch([
      TracksCompanion.insert(
        path: '/m/a.mp3',
        title: 'a',
        albumKey: old,
        format: 'mp3',
        sizeBytes: 1,
        mtimeMs: 1,
        addedAt: 1,
        hasCover: const Value(true),
        coverKey: Value(CoverStore.coverKeyFor(old)),
      ),
    ]);
    final t = (await tracks.byPath('/m/a.mp3'))!;
    await EnrichWriter(db, tracks).writeFields(
      t,
      EnrichmentProposal(
        track: t,
        meta: const ItunesMatch(title: 'a', artist: 'Art', album: 'Alb'),
      ),
      {EnrichField.artist, EnrichField.album},
    );
    final after = (await tracks.byPath('/m/a.mp3'))!;
    expect(after.albumKey, 'art|alb');
    expect(after.hasCover, false);
    expect(after.coverKey, isNull);
  });
}
