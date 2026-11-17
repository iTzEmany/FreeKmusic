import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_kinds.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/karaoke_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/services/karaoke/karaoke_controller.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/app_harness.dart';
import '../../support/fake_voice_filter.dart';

class _Bypass extends Notifier<bool> {
  @override
  bool build() => false;
  // ignore: use_setters_to_change_properties
  void set(bool v) => state = v;
}

final _bypass = NotifierProvider<_Bypass, bool>(_Bypass.new);

void main() {
  test('level is saved and read back; default 20 %, off', () async {
    SharedPreferences.setMockInitialValues({});
    var store = await SettingsStore.open();
    expect(store.readSettings().karaokeOn, isFalse);
    expect(store.readSettings().karaokeLevel, 0.2);
    await store.writeSettings(
      store.readSettings().copyWith(karaokeOn: true, karaokeLevel: 0.65),
    );
    store = await SettingsStore.open();
    expect(store.readSettings().karaokeOn, isTrue);
    expect(store.readSettings().karaokeLevel, 0.65);
  });

  test('the controller sends the level once and null when off', () async {
    final f = FakeVoiceFilter();
    final c = KaraokeController(f);
    await c.apply(on: true, level: 0.3, bypass: false);
    await c.apply(on: true, level: 0.3, bypass: false);
    await c.apply(on: true, level: 0.5, bypass: false);
    await c.apply(on: false, level: 0.5, bypass: false);
    expect(f.calls, [0.3, 0.5, null]);
  });

  test('on stays on between tracks, bypass on episode/radio keeps the level',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    final f = FakeVoiceFilter();
    final c = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(store),
      voiceFilterProvider.overrideWithValue(f),
      karaokeBypassProvider.overrideWith((ref) => ref.watch(_bypass)),
    ]);
    addTearDown(c.dispose);
    c.listen(karaokeApplierProvider, (_, _) {}); // the app root watches it
    expect(f.calls, [null]);
    c.read(settingsProvider.notifier).update(
      (s) => s.copyWith(karaokeOn: true, karaokeLevel: 0.3),
    );
    await Future<void>.delayed(Duration.zero);
    expect(f.calls.last, 0.3);
    // Two music tracks in a row: nothing changes, the filter stays on.
    final n = f.calls.length;
    c.read(_bypass.notifier).set(false);
    expect(f.calls.length, n);
    // An episode or a radio: bypass, the saved level is untouched.
    c.read(_bypass.notifier).set(true);
    await Future<void>.delayed(Duration.zero);
    expect(f.calls.last, isNull);
    expect(c.read(karaokeProvider).on, isTrue);
    expect(c.read(karaokeProvider).level, 0.3);
    // Music again: back to the saved level.
    c.read(_bypass.notifier).set(false);
    await Future<void>.delayed(Duration.zero);
    expect(f.calls.last, 0.3);
  });

  testWidgets('an episode row puts the filter in bypass, a song does not',
      (tester) async {
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
}
