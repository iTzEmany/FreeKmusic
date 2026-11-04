import 'dart:async';
import 'dart:io';

import 'package:codecore/core/network_kind.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/library_providers.dart';
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

  @override
  Future<RadioPage> page(String videoId, {String? continuation}) async {
    calls++;
    return mixPage(videoId);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

void main() {
  test('a download (downloadIndexProvider invalidated) does not restart the mix', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    final dir = Directory.systemTemp.createTempSync('genre_mix_provider');
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
      genreTracksProvider.overrideWith((ref, genre) => Stream.value([for (var i = 1; i <= 6; i++) track(i)])),
      downloadIndexProvider.overrideWith((ref) async => downloads),
      seedResolverProvider.overrideWith((ref) async => SeedResolver(
            downloads: downloads,
            index: SeedIndex(file: () async => File(p.join(dir.path, 'seeds.json'))),
            searchSongs: (q) async => const [],
          )),
      ytDlpStatusProvider.overrideWith((ref) async => const YtDlpStatus('2026.01.01')),
      networkProbeProvider.overrideWithValue(NetworkProbe(android: false)),
      ytmRadioServiceProvider.overrideWithValue(radio),
      suggestionLogProvider.overrideWithValue(SuggestionLog(
        file: () async => File(p.join(dir.path, 'suggestions.json')),
        writeDelay: const Duration(days: 1),
      )),
      shufflePlusProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(genreMixProvider('Rock'), (_, _) {});
    addTearDown(sub.close);
    Future<GenreMixState?> settled() async {
      final end = DateTime.now().add(const Duration(seconds: 20));
      while (DateTime.now().isBefore(end)) {
        final v = container.read(genreMixProvider('Rock')).value;
        if (v != null && v.incoming == 0 && v.suggested.isNotEmpty) return v;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return null;
    }

    final first = await settled();
    expect(first, isNotNull);
    expect(first!.suggested, hasLength(3));
    final calls = radio.calls;
    container.invalidate(downloadIndexProvider);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(radio.calls, calls, reason: 'no new requests');
    expect(container.read(genreMixProvider('Rock')).value?.suggested, first.suggested);
  });
}
