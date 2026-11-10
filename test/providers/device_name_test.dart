import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/share_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String> _name({String? custom, String system = '', String model = ''}) async {
  SharedPreferences.setMockInitialValues({'deviceName': ?custom});
  final store = SettingsStore(await SharedPreferences.getInstance());
  final c = ProviderContainer(overrides: [
    settingsStoreProvider.overrideWithValue(store),
    systemDeviceNameProvider.overrideWithValue(system),
    systemDeviceModelProvider.overrideWithValue(model),
  ]);
  addTearDown(c.dispose);
  return c.read(deviceNameProvider);
}

void main() {
  test('a chosen name wins over the system one', () async {
    expect(await _name(custom: 'Salotto', system: 'Pixel', model: 'M2010'), 'Salotto');
  });

  test('a generic saved name (old version) falls back like the system one', () async {
    expect(await _name(custom: 'Telefono', system: 'Telefono', model: 'Mi A3'), 'Mi A3');
    expect(await _name(custom: 'Telefone', system: 'Pixel', model: 'M2010'), 'Pixel');
  });

  test('a real system name is kept', () async {
    expect(await _name(system: 'Mario', model: 'Mi A3'), 'Mario');
  });

  test('a generic system name gives the phone model', () async {
    for (final g in ['Telefono', 'phone', 'Smartphone', 'localhost', '']) {
      expect(await _name(system: g, model: 'Mi A3'), 'Mi A3', reason: g);
    }
  });

  test('generic and no model: FreeKmusic', () async {
    expect(await _name(system: 'Telefono'), 'FreeKmusic');
  });
}
