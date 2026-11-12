import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart' show trackRepositoryProvider;
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/library_providers.dart' show libraryQueriesProvider;
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/share_hub.dart';
import 'package:codecore/providers/stream_providers.dart' show streamPreparerProvider;
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';
import '../support/fake_stream_preparer.dart';

class _Jam extends JamController {
  @override
  JamUiState build() {
    super.build();
    return const JamUiState();
  }
}

class _Hub extends ShareHubNotifier {
  @override
  ShareHubState build() => const ShareHubState();
}

/// A YouTube item of a remote guest the host plays itself (R-21): no owner to fetch it from.
void main() {
  late FakeBackend jamBackend;
  late FakeStreamPreparer preparer;
  late ProviderContainer c;

  const item = JamItem(
      id: 1, ownerDeviceId: 'g', title: 'T', ext: 'm4a', ref: 'yt:youtube:vid', videoId: 'vid');
  const key = 'youtube:vid';

  JamState state({List<String> outputs = const []}) => JamState(
      version: 1,
      hostDeviceId: '',
      outputDeviceId: '',
      outputDeviceIds: outputs,
      items: const [item],
      currentIndex: 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore(await SharedPreferences.getInstance());
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final backend = FakeBackend();
    final handler = CodecoreAudioHandler(backend, PlayQueue(), TrackRepository(db), onError: (_) {});
    addTearDown(handler.dispose);
    jamBackend = FakeBackend();
    preparer = FakeStreamPreparer(
        TrackRepository(db), Directory.systemTemp.createTempSync('jam_self'));
    c = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(store),
      shareHubProvider.overrideWith(_Hub.new),
      jamProvider.overrideWith(_Jam.new),
      libraryQueriesProvider.overrideWithValue(LibraryQueries(db)),
      trackRepositoryProvider.overrideWithValue(TrackRepository(db)),
      audioHandlerProvider.overrideWithValue(handler),
      streamPreparerProvider.overrideWithValue(preparer),
      jamCacheDirProvider.overrideWith((ref) => Directory.systemTemp.createTemp('jam_self_cache')),
      jamBackendFactoryProvider.overrideWithValue(() => jamBackend),
    ]);
    addTearDown(c.dispose);
    c.read(jamProvider);
  });

  test('a Jam with one output plays from the stream address while the download goes on', () async {
    preparer.urls[key] = (Uri.parse('https://yt.example/a'), {'h': 'v'});
    preparer.gates[key] = Completer<void>(); // the download never ends
    await c.read(jamProvider.notifier).debugBegin(JamRole.host, state());
    await pumpEventQueue();
    expect(jamBackend.loadedUris.map((u) => u.uri), [Uri.parse('https://yt.example/a')]);
    expect(jamBackend.loadedUris.single.headers, {'h': 'v'});
    expect(preparer.asked, contains(key)); // the download goes on in the background
  });

  test('a synchronised Jam waits for the file', () async {
    final gate = preparer.gates[key] = Completer<void>();
    preparer.urls[key] = (Uri.parse('https://yt.example/a'), const {});
    await c.read(jamProvider.notifier).debugBegin(JamRole.host, state(outputs: ['', 'x']));
    await pumpEventQueue();
    expect(jamBackend.loadedUris, isEmpty);
    gate.complete();
    // The load waits on real file I/O (temp cache dir): on a busy CI runner one
    // event-queue turn is not always enough.
    for (var i = 0; i < 50 && jamBackend.loaded.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(jamBackend.loaded, hasLength(1));
    expect(jamBackend.loadedUris, isEmpty);
  });
}
