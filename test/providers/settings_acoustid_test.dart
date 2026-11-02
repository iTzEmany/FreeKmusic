import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('turning AcoustID back on makes the recognition pass run again', () async {
    SharedPreferences.setMockInitialValues({'acoustId': false});
    final store = SettingsStore(await SharedPreferences.getInstance());
    await store.writeRecogPassDone(2);
    final c = ProviderContainer(overrides: [settingsStoreProvider.overrideWithValue(store)]);
    addTearDown(c.dispose);
    final n = c.read(settingsProvider.notifier);
    n.update((s) => s.copyWith(creditsDetails: !s.creditsDetails));
    expect(store.recogPassDone, 2, reason: 'another setting changed');
    n.update((s) => s.copyWith(acoustId: true));
    await Future<void>.delayed(Duration.zero);
    expect(store.recogPassDone, 0);
  });
}
