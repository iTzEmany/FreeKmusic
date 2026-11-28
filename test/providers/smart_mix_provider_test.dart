import 'dart:async';
import 'dart:io';

import 'package:codecore/core/network_kind.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/smart_playlist_providers.dart';
import 'package:codecore/providers/seed_resolver_provider.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/ytm_radio_parser.dart';
import 'package:codecore/services/online/ytm_radio_service.dart';
import 'package:codecore/services/shuffle_plus/genre_mix.dart';
import 'package:codecore/services/shuffle_plus/seed_index.dart';
import 'package:codecore/services/shuffle_plus/seed_resolver.dart';
import 'package:codecore/services/shuffle_plus/suggestion_log.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/shuffle_plus/genre_mix_test.dart' show page, track;

RadioPage mixPage(String id) => page(id);

class _Radio implements YtmRadioService {
  int calls = 0;
  Completer<void>? gate;

  @override
  Future<RadioPage> page(String videoId, {String? continuation}) async {
    calls++;
    await gate?.future;
    return mixPage(videoId);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(GenreMixState?, _Radio)> mix(String rules) async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    final dir = Directory.systemTemp.createTempSync('smart_mix_provider');
    addTearDown(() => dir.deleteSync(recursive: true));
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final downloads = DownloadIndex(File(p.join(dir.path, 'downloads.json')));
    for (var i = 1; i <= 6; i++) {
      await downloads.add('dl$i', '/m/$i.mp3');
    }
    final radio = _Radio();
    final container = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(store),
      databaseProvider.overrideWithValue(db),
      smartPlaylistProvider.overrideWith((ref, id) => Stream.value(
          SmartPlaylist(id: id, name: 'S', rules: rules, createdAt: 1))),
      smartTracksProvider.overrideWith((ref, id) => Stream.value([for (var i = 1; i <= 6; i++) track(i)])),
      downloadIndexProvider.overrideWith((ref) async => downloads),
      seedResolverProvider.overrideWith((ref) async => SeedResolver(
            downloads: downloads,
            index: SeedIndex(file: () async => File(p.join(dir.path, 'seeds.json'))),
            searchSongs: (q) async => const [],
          )),
      ytDlpStatusProvider.overrideWith((ref) async => YtDlpStatus('2026.01.01')),
      networkProbeProvider.overrideWithValue(NetworkProbe(android: false)),
      ytmRadioServiceProvider.overrideWithValue(radio),
      suggestionLogProvider.overrideWithValue(SuggestionLog(
        file: () async => File(p.join(dir.path, 'suggestions.json')),
        writeDelay: const Duration(days: 1),
      )),
      shufflePlusProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(smartMixProvider(7), (_, _) {});
    addTearDown(sub.close);
    final end = DateTime.now().add(const Duration(seconds: 20));
    GenreMixState? v;
    while (DateTime.now().isBefore(end)) {
      v = container.read(smartMixProvider(7)).value;
      if (v != null && v.incoming == 0 && v.off == null && (v.suggested.isNotEmpty || radio.calls >= 4)) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return (v, radio);
  }

  test('rules the radio rows respect: the mix fills as on a genre page', () async {
    final (v, _) = await mix('artista:Artist');
    expect(v?.suggested, hasLength(3));
  });

  test('rules the radio rows break: nothing suggested', () async {
    final (v, radio) = await mix('artista:zzz');
    expect(v?.suggested, isEmpty);
    expect(radio.calls, greaterThan(0));
  });
}
