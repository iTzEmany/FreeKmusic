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
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';

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

void main() {
  late ProviderContainer c;
  late JamController jam;

  JamState people(List<JamParticipant> p) =>
      JamState(version: 1, hostDeviceId: 'h', outputDeviceId: 'h', participants: p);
  const host = JamParticipant(id: 'h', name: 'PC');
  const peer = JamParticipant(id: 'peer', name: 'Mi A3');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore(await SharedPreferences.getInstance());
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final handler = CodecoreAudioHandler(FakeBackend(), PlayQueue(), TrackRepository(db), onError: (_) {});
    addTearDown(handler.dispose);
    c = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(store),
      shareHubProvider.overrideWith(_Hub.new),
      jamProvider.overrideWith(_Jam.new),
      libraryQueriesProvider.overrideWithValue(LibraryQueries(db)),
      trackRepositoryProvider.overrideWithValue(TrackRepository(db)),
      audioHandlerProvider.overrideWithValue(handler),
      jamCacheDirProvider.overrideWith((ref) => Directory.systemTemp.createTemp('jam_seen')),
      jamBackendFactoryProvider.overrideWithValue(FakeBackend.new),
    ]);
    addTearDown(c.dispose);
    jam = c.read(jamProvider.notifier);
  });

  test('un ospite che entra ed esce senza che la UI legga nulla ha comunque il nome', () async {
    await jam.debugBegin(JamRole.host, people([host]));
    jam.debugState(people([host, peer, const JamParticipant(id: 'anon', name: '')]));
    jam.debugState(people([host]));
    expect(jam.seenName('peer'), 'Mi A3');
    expect(jam.seenName('anon'), isNull);
  });

  test('una nuova Jam parte senza i nomi della precedente', () async {
    await jam.debugBegin(JamRole.host, people([host, peer]));
    await jam.debugFinish();
    await jam.debugBegin(JamRole.host, people([host]));
    expect(jam.seenName('peer'), isNull);
  });
}
