import 'dart:async';
import 'dart:io';

import 'package:codecore/core/network_kind.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/services/shuffle_plus/radio_gate.dart';
import 'package:flutter/services.dart';
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

class _ActiveJam extends JamController {
  @override
  JamUiState build() => const JamUiState(phase: JamPhase.active, role: JamRole.host);
}

NetworkProbe _meteredProbe() {
  const channel = MethodChannel('codecore/net-genre-mix');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => {'metered': true, 'online': true});
  addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));
  return NetworkProbe(channel: channel, android: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Radio radio;
  late ProviderContainer container;
  late DownloadIndex downloads;

  /// [libraryIds]: radio rows that are already in the library (downloaded).
  Future<void> open({
    bool jam = false,
    String? tool = '2026.01.01',
    NetworkProbe? probe,
    RadioGate? gate,
    Iterable<String> libraryIds = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final store = await SettingsStore.open();
    final dir = Directory.systemTemp.createTempSync('genre_mix_provider');
    addTearDown(() => dir.deleteSync(recursive: true));
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    downloads = DownloadIndex(File(p.join(dir.path, 'downloads.json')));
    for (var i = 1; i <= 6; i++) {
      await downloads.add('dl$i', '/m/$i.mp3');
    }
    for (final id in libraryIds) {
      final path = p.join(dir.path, '$id.mp3');
      File(path).writeAsStringSync('x'); // the index only knows files that exist
      await downloads.add(id, path);
    }
    radio = _Radio();
    container = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(store),
      databaseProvider.overrideWithValue(db),
      genreTracksProvider.overrideWith((ref, genre) => Stream.value([for (var i = 1; i <= 6; i++) track(i)])),
      downloadIndexProvider.overrideWith((ref) async => downloads),
      seedResolverProvider.overrideWith((ref) async => SeedResolver(
            downloads: downloads,
            index: SeedIndex(file: () async => File(p.join(dir.path, 'seeds.json'))),
            searchSongs: (q) async => const [],
          )),
      ytDlpStatusProvider.overrideWith((ref) async => YtDlpStatus(tool)),
      networkProbeProvider.overrideWithValue(probe ?? NetworkProbe(android: false)),
      ytmRadioServiceProvider.overrideWithValue(radio),
      suggestionLogProvider.overrideWithValue(SuggestionLog(
        file: () async => File(p.join(dir.path, 'suggestions.json')),
        writeDelay: const Duration(days: 1),
      )),
      shufflePlusProvider.overrideWith((ref) async => null),
      if (gate != null) radioGateProvider.overrideWithValue(gate),
      if (jam) jamProvider.overrideWith(_ActiveJam.new),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(genreMixProvider('Rock'), (_, _) {});
    addTearDown(sub.close);
  }

  Future<GenreMixState?> until(bool Function(GenreMixState v) done) async {
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(end)) {
      final v = container.read(genreMixProvider('Rock')).value;
      if (v != null && done(v)) return v;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return null;
  }

  Future<GenreMixState?> settled() => until((v) => v.incoming == 0 && v.suggested.isNotEmpty);

  test('a download (downloadIndexProvider invalidated) does not restart the mix', () async {
    await open();
    final first = await settled();
    expect(first, isNotNull);
    expect(first!.suggested, hasLength(3));
    final calls = radio.calls;
    container.invalidate(downloadIndexProvider);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(radio.calls, calls, reason: 'no new requests');
    expect(container.read(genreMixProvider('Rock')).value?.suggested, first.suggested);
  });

  // «Solo su Wi-Fi» is on by default.
  for (final (name, reason, open_) in <(String, GenreMixOff, Future<void> Function())>[
    ('a Jam', GenreMixOff.jam, () => open(jam: true)),
    ('no yt-dlp', GenreMixOff.noTool, () => open(tool: null)),
    ('a metered network with «Solo su Wi-Fi»', GenreMixOff.metered, () => open(probe: _meteredProbe())),
    ('the radio gate tripped by a 429', GenreMixOff.rateLimited, () => open(gate: RadioGate()..trip())),
  ]) {
    test('$name: library only, the reason, no request', () async {
      await open_();
      final v = await until((v) => v.off != null);
      expect(v?.off, reason);
      expect(v?.suggested, isEmpty);
      expect(radio.calls, 0);
    });
  }

  test('the radio asked a moment ago (by Shuffle+): the mix still asks its first page, and marks the gate', () async {
    final gate = RadioGate()..asked();
    await open(gate: gate);
    final v = await settled();
    expect(v?.suggested, isNotEmpty);
    expect(radio.calls, 1, reason: 'one page, the gap holds the next');
  });

  test('songs already in the library are not suggested', () async {
    final owned = [for (var i = 1; i <= 6; i++) for (var j = 0; j < 5; j++) 'dl$i-r$j'];
    await open(libraryIds: owned);
    final v = await settled();
    expect(v!.suggested, hasLength(3));
    expect(v.suggested.where((s) => owned.contains(s.result.id)), isEmpty);
  });

  test('the container closed in the middle of the mix: no more requests', () async {
    await open();
    radio.gate = Completer<void>();
    while (radio.calls == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    container.dispose();
    radio.gate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(radio.calls, 1);
  });
}
