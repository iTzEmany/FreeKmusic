import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_kinds.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/stream_providers.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/radio/radio_station.dart';
import 'package:codecore/services/online/synthetic_track.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/enrich_fakes.dart';

void main() {
  late EnrichRig rig;
  late OnlineEntries online;
  late StreamController<Track?> cur;
  late ProviderContainer container;

  setUp(() {
    rig = EnrichRig();
    online = OnlineEntries();
    cur = StreamController<Track?>.broadcast();
    container = ProviderContainer(overrides: [
      currentTrackProvider.overrideWith((ref) => cur.stream),
      onlineEntriesProvider.overrideWithValue(online),
      enrichmentServiceProvider.overrideWithValue(rig.svc),
      trackRepositoryProvider.overrideWithValue(rig.repo),
    ]);
    container.listen(streamEnrichTriggerProvider, (_, _) {});
  });
  tearDown(() async {
    container.dispose();
    await cur.close();
    await rig.dispose();
  });

  /// Makes [t] the current track and waits for what it triggers.
  Future<void> play(Track t) async {
    cur.add(t);
    for (var n = 0; n < 100 && rig.chain.calls == 0; n++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Track track(int id, {int kind = 0}) => syntheticTrack(title: 'Song', kind: kind).copyWith(id: id);

  YtResult result() => const YtResult(id: 'v1', title: 'Song', channel: 'Chan', duration: Duration(minutes: 3));

  test('a row that arrives while paused (no position tick) enriches it', () async {
    final row = await rig.add(kind: kStreamKind, path: 'youtube:v1');
    final id = online.register(result());
    cur.add(track(id));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(rig.chain.calls, 0);
    online.bindRow(id, row);
    for (var n = 0; n < 100 && rig.chain.calls == 0; n++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(rig.chain.calls, 1);
  });

  test('an entry without a row and a radio enrich nothing', () async {
    final id = online.register(result());
    await play(track(id));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final radio = online.registerRadio(const RadioStation(id: 'r', name: 'R', streamUrl: 'http://x'));
    cur.add(track(radio));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(rig.chain.calls, 0);
  });

  test('a positive stream row uses its own id', () async {
    final row = await rig.add(kind: kStreamKind, path: 'youtube:v1');
    await play(track(row, kind: kStreamKind));
    expect(rig.chain.calls, 1);
  });
}
