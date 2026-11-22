import 'package:codecore/data/repositories/track_kinds.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/providers/stream_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/enrich_fakes.dart';

void main() {
  test('two calls for the same row while one runs enrich it once', () async {
    final rig = EnrichRig();
    addTearDown(rig.dispose);
    final c = ProviderContainer(overrides: [
      enrichmentServiceProvider.overrideWithValue(rig.svc),
      trackRepositoryProvider.overrideWithValue(rig.repo),
    ]);
    addTearDown(c.dispose);
    final row = await rig.add(kind: kStreamKind, path: 'youtube:v1');
    final enrich = c.read(streamEnrichRowProvider);
    final a = enrich(row), b = enrich(row);
    expect(identical(a, b), isTrue, reason: 'the same run for the same row');
    await Future.wait([a, b]);
    expect(rig.chain.calls, 1);
  });

  test('once a run is over, a new call for the row starts a new one', () async {
    final rig = EnrichRig();
    addTearDown(rig.dispose);
    final c = ProviderContainer(overrides: [
      enrichmentServiceProvider.overrideWithValue(rig.svc),
      trackRepositoryProvider.overrideWithValue(rig.repo),
    ]);
    addTearDown(c.dispose);
    final row = await rig.add(kind: kStreamKind, path: 'youtube:v1');
    final enrich = c.read(streamEnrichRowProvider);
    final first = enrich(row);
    await first;
    await pumpEventQueue();
    expect(identical(enrich(row), first), isFalse);
  });

  Future<(EnrichRig, ProviderContainer)> open() async {
    final rig = EnrichRig();
    addTearDown(rig.dispose);
    final c = ProviderContainer(overrides: [
      enrichmentServiceProvider.overrideWithValue(rig.svc),
      trackRepositoryProvider.overrideWithValue(rig.repo),
    ]);
    addTearDown(c.dispose);
    return (rig, c);
  }

  test('characterization: D-683 will change this: the stream row also rewrites title and artist', () async {
    final (rig, c) = await open();
    final row = await rig.add(kind: kStreamKind, path: 'youtube:v1', title: 'song', artist: 'band');
    await c.read(streamEnrichRowProvider)(row);
    final t = (await rig.repo.getById(row))!;
    expect([t.title, t.artist, t.album], ['Song', 'Band', 'New Album']);
    expect(t.enrichStatus, 1);
  });

  test('characterization: D-683 will change this: nothing found keeps status untried, a second listen asks again', () async {
    final (rig, c) = await open();
    rig.web.itunes = ItunesMode.empty;
    rig.chain.result = null;
    final row = await rig.add(kind: kStreamKind, path: 'youtube:v1');
    final enrich = c.read(streamEnrichRowProvider);
    await enrich(row);
    await pumpEventQueue();
    final first = (rig.web.count('itunes'), rig.chain.calls);
    expect((await rig.repo.getById(row))!.enrichStatus, 0);
    await enrich(row);
    expect((rig.web.count('itunes'), rig.chain.calls), (first.$1 * 2, first.$2 * 2));
    expect(first.$1, greaterThan(0));
  });
}
