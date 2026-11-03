import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_kinds.dart';
import 'package:codecore/providers/stream_providers.dart';
import 'package:codecore/services/online/enrich_parts.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../support/enrich_fakes.dart';

void main() {
  late EnrichRig rig;
  setUp(() => rig = EnrichRig());
  tearDown(() => rig.dispose());

  Future<int> shadow() => rig.add(kind: kStreamKind, path: 'youtube:v1');

  test('a bare shadow row gets its text and tags, and its credits are saved', () async {
    final id = await shadow();
    await enrichStreamRow(rig.svc, rig.repo, id);
    final row = (await rig.repo.getById(id))!;
    expect(row.lyricsPlain, 'la la');
    expect(row.genre, isNotNull); // tags from the faked iTunes
    expect(await rig.enrichOf(id), isNotNull);
  });

  test('a row already found does not ask anything', () async {
    final id = await shadow();
    await (rig.db.update(rig.db.tracks)..where((t) => t.id.equals(id)))
        .write(TracksCompanion(enrichStatus: Value(EnrichStatus.found.code)));
    await enrichStreamRow(rig.svc, rig.repo, id);
    expect(rig.chain.calls, 0);
    expect(rig.finder.calls, 0);
    expect(rig.web.urls, isEmpty);
  });

  test('a refused proposal writes nothing', () async {
    final id = await shadow();
    rig.chain.limited = true;
    await enrichStreamRow(rig.svc, rig.repo, id);
    final row = (await rig.repo.getById(id))!;
    expect(row.lyricsPlain, isNull);
    expect(row.curiosities, isNull);
    expect(await rig.enrichOf(id), isNull);
  });
}
