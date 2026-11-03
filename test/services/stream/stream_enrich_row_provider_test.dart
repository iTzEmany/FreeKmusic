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
}
