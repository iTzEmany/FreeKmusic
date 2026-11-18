import 'package:codecore/data/repositories/track_kinds.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/karaoke_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/stream_providers.dart'
    show streamCacheProvider;
import 'package:codecore/services/karaoke/separation_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:codecore/data/db/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:codecore/services/stream/stream_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';

import '../support/app_harness.dart';

class _ActiveJam extends JamController {
  @override
  JamUiState build() =>
      const JamUiState(phase: JamPhase.active, role: JamRole.host);
}

class _NoSeparator implements Separator {
  @override
  Future<void> separate({
    required String input,
    required String output,
    required String voiceOutput,
    required String vocals,
    required String accompaniment,
    void Function(double fraction)? onProgress,
  }) async {}

  @override
  Future<void> mix({
    required String base,
    required String voice,
    required double level,
    required String output,
  }) async {}

  @override
  Future<void> cancel() async {}
}

Track _track(String path, String title) => Track(
  saved: false, coverSource: 0, id: 1, path: path, title: title, artist: 'a', albumKey: 'k',
  durationMs: 1000, format: 'mp3', sizeBytes: 1, mtimeMs: 1, hasCover: false, isFavorite: false,
  enrichStatus: 0, userEdited: false, missing: false, ignored: false, kind: 0, addedAt: 1, playCount: 0,
);

void main() {
  test('level is saved and read back; default 20 %, off', () async {
    SharedPreferences.setMockInitialValues({});
    var store = await SettingsStore.open();
    expect(store.readSettings().karaokeOn, isFalse);
    expect(store.readSettings().karaokeLevel, 0.2);
    expect(store.readSettings().showKaraoke, isTrue);
    await store.writeSettings(
      store.readSettings().copyWith(
        karaokeOn: true,
        karaokeLevel: 0.65,
        showKaraoke: false,
      ),
    );
    store = await SettingsStore.open();
    expect(store.readSettings().karaokeOn, isTrue);
    expect(store.readSettings().karaokeLevel, 0.65);
    expect(store.readSettings().showKaraoke, isFalse);
  });

  group('microphone visibility', () {
    Future<ProviderContainer> make({bool jam = false, bool show = true, Track? current}) async {
      SharedPreferences.setMockInitialValues({});
      final store = await SettingsStore.open();
      await store.writeSettings(
        store.readSettings().copyWith(showKaraoke: show),
      );
      final c = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          separationServiceProvider.overrideWithValue(
            SeparationService(
              cache: _cache(),
              separator: _NoSeparator(),
              modelsRoot: () async => Directory.systemTemp,
            ),
          ),
          if (jam) jamProvider.overrideWith(_ActiveJam.new),
          if (current != null) currentTrackProvider.overrideWith((_) => Stream.value(current)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('no Jam: visible', () async {
      expect((await make()).read(karaokeButtonVisibleProvider), isTrue);
    });

    test('a karaoke video playing: hidden', () async {
      final c = await make(current: _track('online:youtube:abc', 'Song karaoke'));
      c.listen(currentTrackProvider, (_, _) {});
      await c.read(currentTrackProvider.future);
      expect(c.read(karaokeButtonVisibleProvider), isFalse);
    });

    test('a karaoke video playing: bypass on, no separation target', () async {
      final c = await make(current: _track('online:youtube:abc', 'Song karaoke'));
      c.listen(currentTrackProvider, (_, _) {});
      c.listen(karaokeBypassProvider, (_, _) {});
      await c.read(currentTrackProvider.future);
      expect(c.read(karaokeBypassProvider), isTrue);
      expect(await c.read(karaokeTargetProvider.future), isNull);
    });

    test('Jam active: hidden', () async {
      expect(
        (await make(jam: true)).read(karaokeButtonVisibleProvider),
        isFalse,
      );
    });

    test('«Mostra il karaoke» off: hidden, and karaoke reads as off', () async {
      final c = await make(show: false);
      expect(c.read(karaokeButtonVisibleProvider), isFalse);
      c
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(karaokeOn: true));
      expect(c.read(karaokeProvider).on, isFalse);
    });
  });

  testWidgets('an episode row puts karaoke in bypass, a song does not', (
    tester,
  ) async {
    final h = await Harness.create(tester, tracks: 2);
    final c = ProviderContainer(overrides: h.overrides);
    addTearDown(c.dispose);
    final sub = c.listen(karaokeBypassProvider, (_, _) {});
    addTearDown(sub.close);
    final rows = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!;
    await tester.runAsync(() async {
      await (h.db.update(h.db.tracks)..where((t) => t.id.equals(rows[1].id)))
          .write(const TracksCompanion(kind: Value(kEpisodeKind)));
      await h.handler.playQueue([rows[0].id], 0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(c.read(karaokeBypassProvider), isFalse);
    await tester.runAsync(() async {
      await h.handler.playQueue([rows[1].id], 0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(c.read(currentTrackProvider).value?.kind, kEpisodeKind);
    expect(c.read(karaokeBypassProvider), isTrue);
    await h.dispose(tester);
  });

  test('the lyrics pill shows only while the base plays and the level is under 100 %', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    await store.writeSettings(store.readSettings().copyWith(karaokeOn: true));
    KaraokeBase? base;
    final c = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        karaokeButtonVisibleProvider.overrideWithValue(true),
        karaokeBaseProvider.overrideWith((ref) async => base),
      ],
    );
    addTearDown(c.dispose);
    Future<int?> pill() async {
      c.invalidate(karaokeBaseProvider);
      await c.read(karaokeBaseProvider.future);
      return c.read(karaokePillPercentProvider);
    }

    expect(await pill(), isNull); // separating / failed: no base
    base = const KaraokeBase('karaoke:k', '/b.wav', true);
    expect(
      await pill(),
      isNull,
    ); // the original still plays: nothing of this level in use
    c.read(karaokeInUseProvider.notifier).set({4});
    expect(await pill(), 20);
    c.read(karaokeInUseProvider.notifier).set({
      10,
    }); // another level plays: no stale 20 %
    expect(await pill(), isNull);
    c.read(karaokeInUseProvider.notifier).set({4});
    c
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(karaokeLevel: 1));
    expect(await pill(), isNull); // 100 %: the original plays
  });

  testWidgets('files in use are pinned and unpinned in balance', (
    tester,
  ) async {
    final h = await Harness.create(tester, tracks: 1);
    final dir = Directory.systemTemp.createTempSync('kar_pin');
    addTearDown(() => dir.deleteSync(recursive: true));
    // Built inside runAsync: their Future.value() chains must live in the real zone.
    late StreamCache cache;
    late SeparationService svc;
    late String basePath;
    await tester.runAsync(() async {
      cache = StreamCache(dir, freeSpace: () async => null);
      svc = SeparationService(
        cache: cache,
        separator: _NoSeparator(),
        modelsRoot: () async => dir,
      );
      await h.store.writeSettings(
        h.store.readSettings().copyWith(karaokeOn: true, karaokeLevel: 0),
      );
      await cache.open();
      final part = File('${dir.path}/x.wav.part')..writeAsBytesSync([1]);
      basePath = (await cache.put('karaoke:base:s1', part)).path;
    });
    final c = ProviderContainer(
      overrides: [
        ...h.overrides,
        streamCacheProvider.overrideWithValue(cache),
        separationServiceProvider.overrideWithValue(svc),
      ],
    );
    addTearDown(c.dispose);
    c.read(karaokeBaseApplierProvider);
    final track = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!
        .first;
    final path = await tester.runAsync(
      () => h.handler.karaokeSource!(track, 's1'),
    );
    expect(path, basePath);
    h.handler.onKaraokeInUse!({basePath});
    expect(cache.isPinned('karaoke:base:s1'), isTrue);
    expect(cache.isPinned('karaoke:voice:s1'), isTrue);
    h.handler.onKaraokeInUse!({basePath}); // told again: still one pin
    h.handler.onKaraokeInUse!({});
    expect(cache.isPinned('karaoke:base:s1'), isFalse);
    expect(cache.isPinned('karaoke:voice:s1'), isFalse);
    await h.dispose(tester);
  });
}

StreamCache _cache() => StreamCache(Directory.systemTemp);
