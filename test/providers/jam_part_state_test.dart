import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart'
    show trackRepositoryProvider;
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/library_providers.dart'
    show libraryQueriesProvider;
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/share_hub.dart';
import 'package:codecore/providers/youtube_providers.dart'
    show downloadIndexProvider;
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/jam/jam_host.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';

final _host = JamHost(deviceId: 'me', deviceName: 'PC');

class _Hub extends ShareHubNotifier {
  @override
  ShareHubState build() => const ShareHubState();
  @override
  JamHost? get jamHost => _host;
  @override
  String? get deviceId => 'me';
}

class _Jam extends JamController {
  @override
  JamUiState build() {
    super.build();
    return const JamUiState();
  }
}

void main() {
  // The draw is unseeded: repeat, so that a missing memory cannot pass by luck.
  for (var n = 0; n < 8; n++) {
    test(
      'a played track the host trimmed before the first suggestion is not suggested later ($n)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final store = SettingsStore(await SharedPreferences.getInstance());
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final handler = CodecoreAudioHandler(
          FakeBackend(),
          PlayQueue(),
          TrackRepository(db),
          onError: (_) {},
        );
        addTearDown(handler.dispose);
        final ids = [
          for (final t in ['Alpha', 'Beta', 'Gamma'])
            await db
                .into(db.tracks)
                .insert(
                  TracksCompanion.insert(
                    path: '/m/$t.mp3',
                    title: t,
                    albumKey: 'k',
                    format: 'mp3',
                    sizeBytes: 1,
                    mtimeMs: 1,
                    addedAt: 1,
                  ),
                ),
        ];
        final c = ProviderContainer(
          overrides: [
            settingsStoreProvider.overrideWithValue(store),
            shareHubProvider.overrideWith(_Hub.new),
            jamProvider.overrideWith(_Jam.new),
            libraryQueriesProvider.overrideWithValue(LibraryQueries(db)),
            trackRepositoryProvider.overrideWithValue(TrackRepository(db)),
            audioHandlerProvider.overrideWithValue(handler),
            downloadIndexProvider.overrideWith(
              (ref) async => DownloadIndex(File('/nonexistent/dl.json')),
            ),
            jamCacheDirProvider.overrideWith(
              (ref) => Directory.systemTemp.createTemp('jam_part_state'),
            ),
            jamBackendFactoryProvider.overrideWithValue(FakeBackend.new),
          ],
        );
        addTearDown(c.dispose);
        JamItem mine(int n, String title) => JamItem(
          id: n,
          ownerDeviceId: 'me',
          title: title,
          ext: 'mp3',
          ref: '${ids[n - 1]}',
        );
        c.read(jamProvider);
        final jam = c.read(jamProvider.notifier);
        {
          _host.clearSession();
          _host.open();
          // Started apart (no suggestions yet), then shown the together states by hand.
          final base = _host.state!;
          await jam.debugBegin(JamRole.host, base);
          final together = base.copyWith(
            mode: JamMode.together,
            currentIndex: 0,
          );
          // Alpha plays with Beta after it: no suggestion is due. The host then trims Alpha.
          jam.debugState(
            together.copyWith(
              version: 2,
              items: [mine(1, 'Alpha'), mine(2, 'Beta')],
            ),
          );
          await pumpEventQueue();
          expect(_host.state!.items, isEmpty);
          final trimmed = together.copyWith(
            version: 3,
            items: [mine(2, 'Beta')],
          );
          jam.debugState(trimmed);
          await jam.debugFeeder!.update(
            trimmed,
          ); // joins the run the state started
          expect(_host.state!.items.map((i) => i.title), ['Gamma']);
          await jam.debugFinish();
        }
      },
    );
  }
}
