import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_kinds.dart';
import 'package:codecore/services/recognition/track_recognizer.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/stream_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/enrich_fakes.dart';

void main() {
  test('two calls for the same row while one runs enrich it once', () async {
    final rig = EnrichRig();
    addTearDown(rig.dispose);
    final c = ProviderContainer(overrides: [
      enrichEngineProvider.overrideWithValue(rig.engine),
      settingsProvider.overrideWith(_On.new),
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
      enrichEngineProvider.overrideWithValue(rig.engine),
      settingsProvider.overrideWith(_On.new),
      trackRepositoryProvider.overrideWithValue(rig.repo),
    ]);
    addTearDown(c.dispose);
    final row = await rig.add(kind: kStreamKind, path: 'youtube:v1');
    final enrich = c.read(streamEnrichRowProvider);
    final first = enrich(row);
    await first;
    await pumpEventQueue();
    final second = enrich(row);
    expect(identical(second, first), isFalse);
    await second;
  });

  Future<(EnrichRig, ProviderContainer)> open({bool on = true}) async {
    final rig = EnrichRig();
    addTearDown(rig.dispose);
    final c = ProviderContainer(overrides: [
      enrichEngineProvider.overrideWithValue(rig.engine),
      settingsProvider.overrideWith(on ? _On.new : _Off.new),
      trackRepositoryProvider.overrideWithValue(rig.repo),
    ]);
    addTearDown(c.dispose);
    return (rig, c);
  }

  test('D-683: a stream row keeps its title and artist, only empty fields are filled', () async {
    final (rig, c) = await open();
    final row = await rig.add(kind: kStreamKind, path: 'youtube:v1', title: 'song', artist: 'band');
    await c.read(streamEnrichRowProvider)(row);
    final t = (await rig.repo.getById(row))!;
    expect([t.title, t.artist], ['song', 'band']);
    expect(t.enrichStatus, 1);
  });

  test('D-683: nothing found marks the row, a second listen asks nothing', () async {
    final (rig, c) = await open();
    rig.web.itunes = ItunesMode.empty;
    rig.chain.result = null;
    final row = await rig.add(kind: kStreamKind, path: 'youtube:v1');
    final enrich = c.read(streamEnrichRowProvider);
    await enrich(row);
    await pumpEventQueue();
    final first = (rig.web.urls.length, rig.chain.calls);
    expect(first.$1, greaterThan(0));
    await enrich(row);
    expect((rig.web.urls.length, rig.chain.calls), first);
  });

  test('D-683: with the automatic switches off a stream row asks nothing', () async {
    final (rig, c) = await open(on: false);
    final row = await rig.add(kind: kStreamKind, path: 'youtube:v1');
    await c.read(streamEnrichRowProvider)(row);
    expect(rig.chain.calls, 0);
    expect(rig.web.urls, isEmpty);
  });

  test('with the switches off the recognition is not asked either', () async {
    final rec = _Counting();
    final rig = EnrichRig(recognizer: rec);
    addTearDown(rig.dispose);
    final c = ProviderContainer(overrides: [
      enrichEngineProvider.overrideWithValue(rig.engine),
      settingsProvider.overrideWith(_Off.new),
      trackRepositoryProvider.overrideWithValue(rig.repo),
    ]);
    addTearDown(c.dispose);
    final row = await rig.add(kind: kStreamKind, path: 'youtube:v1');
    await c.read(streamEnrichRowProvider)(row);
    expect(rec.calls, 0);
  });
}

class _Counting implements TrackRecognizer {
  int calls = 0;

  @override
  Future<RecogOutcome> recognize(Track t, {required TextProbe? textProbe, CancelToken? cancel}) async {
    calls++;
    return const RecogOutcome();
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

class _On extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings(autoEnrich: true, autoLyrics: true, autoCuriosities: true);
}

class _Off extends SettingsNotifier {
  @override
  AppSettings build() => helpersOff();
}
