import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/share_hub.dart';
import 'package:codecore/services/share/collection_sync.dart';
import 'package:codecore/services/share/playlist_sync.dart';
import 'package:codecore/services/share/settings_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Hub extends ShareHubNotifier {
  @override
  ShareHubState build() => const ShareHubState();
}

void main() {
  test('applySettingsSync writes only the settings the user picked, through the settings notifier', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(SettingsStore(await SharedPreferences.getInstance())),
      shareHubProvider.overrideWith(_Hub.new),
    ]);
    addTearDown(c.dispose);
    const plan = SyncPlan(
      [],
      CollectionPlan(settings: [
        SettingChange('theme', 'notte', 'oled'),
        SettingChange('accent', 'viola', 'rosso'),
        SettingChange('deviceName', null, 'evil'),
      ]),
    );

    c.read(shareHubProvider.notifier).applySettingsSync(plan, {'theme', 'deviceName'});

    final s = c.read(settingsProvider);
    expect((s.theme, s.accent), ('oled', 'viola'), reason: 'the accent was not picked');
    expect(s.deviceName, isNot('evil'), reason: 'a key out of the list is ignored');
  });
}
