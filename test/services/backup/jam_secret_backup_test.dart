import 'package:codecore/data/settings/jam_secret_store.dart';
import 'package:codecore/services/backup/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('settings.json never carries the Jam secrets (block lists, friends, AK)', () async {
    SharedPreferences.setMockInitialValues({
      'theme': 'dark',
      jamBlockedKey: '[]',
      jamSuspendedKey: '[]',
      jamFriendsKey: '[]',
      jamAnnounceKeyKey: 'x',
      'jamAutoAcceptFriends': true,
      'trustedDevices': '[]',
    });
    final json = settingsToJson(await SharedPreferences.getInstance());
    // The friends' list and AK are secrets; the switch is a plain preference.
    expect(json.keys, ['theme', 'jamAutoAcceptFriends']);
  });
}
