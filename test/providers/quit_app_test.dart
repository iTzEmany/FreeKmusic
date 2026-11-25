import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/app_restart_provider.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/tray_providers.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/audio/playback_persistence.dart';
import 'package:codecore/services/window/tray_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/window/window_fakes.dart';
import '../support/fake_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the one exit closes the tray icon and saves the queue before leaving', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore(await SharedPreferences.getInstance());
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final h = CodecoreAudioHandler(FakeBackend(), PlayQueue(), TrackRepository(db), onError: (_) {});
    addTearDown(h.dispose);
    final id = await db.into(db.tracks).insert(TracksCompanion.insert(
        path: '/m/0.mp3', title: 'S0', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 0));
    await h.restore([id], 0, Duration.zero);
    final adapter = FakeTrayAdapter();
    final tray = TrayService(
      host: FakeWindowHost(),
      adapter: adapter,
      labels: {for (final c in TrayCommand.values) c: c.name},
      closeToTray: () => true,
      playPause: () async {},
      next: () async {},
      quit: () async {},
    );
    final c = ProviderContainer(overrides: [
      trayServiceProvider.overrideWithValue(tray),
      playbackPersistenceProvider.overrideWithValue(PlaybackPersistence(h, store)),
    ]);
    addTearDown(c.dispose);
    expect(store.readPlayback().queueIds, isEmpty);

    // The test binding refuses a real exit: reaching it is the proof the rest ran first.
    await expectLater(c.read(quitAppProvider)(), throwsA(isA<FlutterError>()));

    expect(adapter.disposed, isTrue);
    expect(store.readPlayback().queueIds, [id]);
  });
}
