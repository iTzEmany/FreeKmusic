import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  ProviderContainer open() {
    final c = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(SettingsStore(prefs))],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  const normal = PlaylistShuffleKey(5);
  const smart = PlaylistShuffleKey(5, smart: true);

  test('a playlist mode survives a new container; a smart one is apart', () async {
    final c = open();
    expect(c.read(listShuffleProvider(normal)), ShuffleMode.off);
    c.read(listShuffleProvider(normal).notifier).set(ShuffleMode.plus);
    c.read(listShuffleProvider(smart).notifier).set(ShuffleMode.shuffle);
    c.read(settingsProvider.notifier).flush(); // the save is debounced
    await Future<void>.delayed(const Duration(milliseconds: 50)); // the store writes key by key
    final c2 = open();
    expect(c2.read(listShuffleProvider(normal)), ShuffleMode.plus);
    expect(c2.read(listShuffleProvider(smart)), ShuffleMode.shuffle);
    expect(c2.read(settingsProvider).playlistShuffles, {'5': 'plus', 'smart:5': 'shuffle'});
  });

  test('the mode is by id: a sort change keeps it, off drops the entry, a new key equals the old', () {
    final c = open();
    c.read(listShuffleProvider(normal).notifier).set(ShuffleMode.shuffle);
    c.read(settingsProvider.notifier).update((s) => s.copyWith(playlistSorts: {'5': 'title:asc'}));
    expect(c.read(listShuffleProvider(const PlaylistShuffleKey(5))), ShuffleMode.shuffle);
    c.read(listShuffleProvider(normal).notifier).set(ShuffleMode.off);
    expect(c.read(settingsProvider).playlistShuffles, isEmpty);
  });

  test('a removed entry (playlist deleted) reads as off', () {
    final c = open();
    c.read(listShuffleProvider(normal).notifier).set(ShuffleMode.plus);
    c.read(settingsProvider.notifier).update((s) => s.copyWith(playlistShuffles: {}));
    expect(c.read(listShuffleProvider(normal)), ShuffleMode.off);
  });

  test('other keys stay in memory and write nothing', () {
    final c = open();
    c.read(listShuffleProvider(listKeyOf(const [1, 2])).notifier).set(ShuffleMode.plus);
    expect(c.read(listShuffleProvider(listKeyOf(const [1, 2]))), ShuffleMode.plus);
    expect(c.read(settingsProvider).playlistShuffles, isEmpty);
  });
}
