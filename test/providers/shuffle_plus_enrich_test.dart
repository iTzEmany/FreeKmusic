import 'dart:async';
import 'dart:io';

import 'package:codecore/data/repositories/track_kinds.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart';
import 'package:codecore/providers/stream_providers.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/stream/stream_preparer.dart' show StreamPhase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/enrich_fakes.dart';
import '../support/fake_stream_preparer.dart';

void main() {
  late EnrichRig rig;
  late OnlineEntries online;
  late FakeStreamPreparer preparer;
  late ProviderContainer c;
  late Directory dir;
  const r = YtResult(id: 'v1', title: 'Song', channel: 'Chan', duration: Duration(minutes: 3));

  setUp(() {
    rig = EnrichRig();
    online = OnlineEntries();
    dir = Directory.systemTemp.createTempSync('sp_enrich');
    preparer = FakeStreamPreparer(rig.repo, dir);
    c = ProviderContainer(overrides: [
      enrichmentServiceProvider.overrideWithValue(rig.svc),
      trackRepositoryProvider.overrideWithValue(rig.repo),
      onlineEntriesProvider.overrideWithValue(online),
      streamPreparerProvider.overrideWithValue(preparer),
    ]);
  });
  tearDown(() async {
    c.dispose();
    await rig.dispose();
    dir.deleteSync(recursive: true);
  });

  test('a suggestion is enriched once its file has made the row', () async {
    final id = online.register(r, suggested: true);
    var done = false;
    unawaited(c.read(shufflePlusEnrichProvider)([id], const Duration(seconds: 5)).then((_) => done = true));
    await pumpEventQueue();
    expect(done, isFalse, reason: 'no row yet');
    await rig.add(kind: kStreamKind, path: 'stream:${r.indexKey}');
    preparer.phases.value = {r.indexKey: StreamPhase.ready};
    await pumpEventQueue();
    for (var n = 0; n < 500 && !done; n++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(done, isTrue);
    expect(rig.chain.calls, 1);
  });

  test('a forgotten entry ends the wait without any phase change', () async {
    final id = online.register(r, suggested: true);
    final run = c.read(shufflePlusEnrichProvider)([id], const Duration(seconds: 5));
    await pumpEventQueue();
    online.forget(id);
    await run.timeout(const Duration(milliseconds: 1500)); // no phase change wakes it
    expect(rig.chain.calls, 0);
  });

  test('a download that failed ends the wait', () async {
    final id = online.register(r, suggested: true);
    final run = c.read(shufflePlusEnrichProvider)([id], const Duration(seconds: 5));
    await pumpEventQueue();
    preparer.phases.value = {r.indexKey: StreamPhase.failed};
    await run.timeout(const Duration(seconds: 2));
    expect(rig.chain.calls, 0);
  });
}
