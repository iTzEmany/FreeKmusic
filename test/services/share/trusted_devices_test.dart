import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/share_providers.dart';
import 'package:codecore/services/share/trusted_devices.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

TrustedDevice dev(String id, {String name = 'Phone', String fp = 'A1F3-09BC-1122-3344', bool auto = false}) =>
    TrustedDevice(id: id, name: name, fingerprint: fp, pairedAt: 1000, autoAccept: auto);

void main() {
  group('TrustedDevices', () {
    test('add and look up', () {
      final t = TrustedDevices().add(dev('a')).add(dev('b', name: 'Laptop'));
      expect(t.byId('a')!.name, 'Phone');
      expect(t.byId('zzz'), isNull);
      expect(t.all.map((d) => d.name), ['Laptop', 'Phone'], reason: 'by name');
      expect(TrustedDevices().isEmpty, isTrue);
    });

    test('pairing again replaces the entry but keeps «accept automatically»', () {
      final t = TrustedDevices().add(dev('a', auto: true)).add(dev('a', fp: 'FFFF-0000-FFFF-0000'));
      expect(t.all, hasLength(1));
      expect(t.byId('a')!.fingerprint, 'FFFF-0000-FFFF-0000');
      expect(t.byId('a')!.autoAccept, isTrue);
    });

    test('revoking removes only that device', () {
      final t = TrustedDevices().add(dev('a')).add(dev('b')).revoke('a');
      expect(t.byId('a'), isNull);
      expect(t.byId('b'), isNotNull);
      expect(t.revoke('nope').all, hasLength(1));
    });

    test('matches: right fingerprint yes, any other no, same id different fingerprint no', () {
      final t = TrustedDevices().add(dev('a', fp: 'A1F3-09BC-1122-3344'));
      expect(t.matches('a', 'A1F3-09BC-1122-3344'), isTrue);
      expect(t.matches('a', 'a1f3 09bc 1122 3344'), isTrue, reason: 'case and separators do not matter');
      expect(t.matches('a', 'A1F309BC11223344'), isTrue);
      expect(t.matches('a', 'A1F3-09BC-1122-3345'), isFalse, reason: 'a different identity under a known id');
      expect(t.matches('b', 'A1F3-09BC-1122-3344'), isFalse, reason: 'an unknown id');
      expect(t.matches('a', ''), isFalse);
    });

    test('by fingerprint: the owner whatever id it announces', () {
      final t = TrustedDevices().add(dev('a', fp: 'A1F3-09BC-1122-3344'));
      expect(t.byFingerprint('a1f309bc11223344')!.id, 'a');
      expect(t.byFingerprint('0000'), isNull);
      expect(t.byFingerprint('---'), isNull);
    });

    test('accept automatically can be turned on and off for one device', () {
      var t = TrustedDevices().add(dev('a')).add(dev('b'));
      expect(t.byId('a')!.autoAccept, isFalse, reason: 'off by default');
      t = t.setAutoAccept('a', true);
      expect(t.byId('a')!.autoAccept, isTrue);
      expect(t.byId('b')!.autoAccept, isFalse);
      expect(t.setAutoAccept('a', false).byId('a')!.autoAccept, isFalse);
    });

    test('encode and decode keep everything', () {
      final t = TrustedDevices().add(dev('a', auto: true)).add(dev('b', name: 'Ünïcode 📱'));
      final back = TrustedDevices.decode(t.encode());
      expect(back.all.map((d) => d.toJson()), t.all.map((d) => d.toJson()));
    });

    test('damaged or odd data gives an empty list or skips the bad entry, never throws', () {
      expect(TrustedDevices.decode(null).isEmpty, isTrue);
      expect(TrustedDevices.decode('').isEmpty, isTrue);
      expect(TrustedDevices.decode('not json{').isEmpty, isTrue);
      expect(TrustedDevices.decode('{"a": 1}').isEmpty, isTrue);
      final partly = TrustedDevices.decode('[{"id":"a","fingerprint":"AB12"}, {"id":"","fingerprint":"X"}, 5, {"fingerprint":"Z"}, {"id":"c"}]');
      expect(partly.all.map((d) => d.id), ['a']);
      expect(partly.byId('a')!.name, 'a', reason: 'no name: the id stands in');
      expect(partly.byId('a')!.autoAccept, isFalse);
    });
  });

  group('trustedDevicesProvider', () {
    Future<ProviderContainer> container() async {
      final store = await SettingsStore.open();
      return ProviderContainer(overrides: [settingsStoreProvider.overrideWithValue(store)]);
    }

    test('starts from what was saved and saves every change', () async {
      SharedPreferences.setMockInitialValues({});
      var c = await container();
      expect(c.read(trustedDevicesProvider).isEmpty, isTrue);
      c.read(trustedDevicesProvider.notifier).add(dev('a'));
      c.read(trustedDevicesProvider.notifier).setAutoAccept('a', true);
      c.dispose();

      c = await container();
      addTearDown(c.dispose);
      expect(c.read(trustedDevicesProvider).byId('a')!.autoAccept, isTrue, reason: 'it survives a restart');
      c.read(trustedDevicesProvider.notifier).revoke('a');
      c.dispose();

      c = await container();
      addTearDown(c.dispose);
      expect(c.read(trustedDevicesProvider).isEmpty, isTrue, reason: 'the revocation was saved too');
    });

    test('a damaged setting does not stop the app', () async {
      SharedPreferences.setMockInitialValues({'trustedDevices': '<<<garbage'});
      final c = await container();
      addTearDown(c.dispose);
      expect(c.read(trustedDevicesProvider).isEmpty, isTrue);
    });
  });

  test('formatFingerprint groups by four, upper-case, and cuts after N groups', () {
    const fp = 'a1f309bc77d24e10ffee0011';
    expect(formatFingerprint(fp), 'A1F3-09BC-77D2-4E10');
    expect(formatFingerprint(fp, groups: 2), 'A1F3-09BC');
    expect(formatFingerprint('A1:F3:09'), 'A1F3-09', reason: 'a short tail is its own group');
    expect(formatFingerprint(''), '');
  });

  group('mine', () {
    test('data saved before the field existed reads as not mine; the flag round-trips', () {
      final old = TrustedDevices.decode('[{"id":"a","name":"A","fingerprint":"AB12","pairedAt":1,"autoAccept":true}]');
      expect(old.byId('a')!.mine, isFalse);
      final back = TrustedDevices.decode(old.setMine('a', true).encode());
      expect(back.byId('a')!.mine, isTrue);
      expect(back.byId('a')!.autoAccept, isTrue);
    });

    test('pairing again keeps the choice', () {
      final d = TrustedDevices([const TrustedDevice(id: 'a', name: 'A', fingerprint: 'AB12', pairedAt: 1, mine: true)])
          .add(const TrustedDevice(id: 'a', name: 'A', fingerprint: 'CD34', pairedAt: 2));
      expect(d.byId('a')!.mine, isTrue);
    });
  });
}
