import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/audio/playback_persistence.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_backend.dart';

void main() {
  test('library-only queues are saved as they are', () {
    final q = savedQueue([5, 6, 7], 1);
    expect(q.ids, [5, 6, 7]);
    expect(q.index, 1);
  });

  test('an online entry in the middle is dropped and the index follows', () {
    final q = savedQueue([5, -1, 6, 7], 2);
    expect(q.ids, [5, 6, 7]);
    expect(q.index, 1); // still pointing to 6
  });

  test('current online entry: the index points to the library track after it', () {
    final q = savedQueue([5, -1, 6, 7], 1);
    expect(q.ids, [5, 6, 7]);
    expect(q.index, 1);
  });

  test('an online entry at the end: index clamps to the last kept track', () {
    final q = savedQueue([5, 6, -1], 2);
    expect(q.ids, [5, 6]);
    expect(q.index, 1);
  });

  test('only online entries save an empty queue', () {
    final q = savedQueue([-1, -2], 0);
    expect(q.ids, isEmpty);
    expect(q.index, 0);
  });

  test('the context is saved with the queue and a new handler resumes it with its name', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore(await SharedPreferences.getInstance());
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    CodecoreAudioHandler open() =>
        CodecoreAudioHandler(FakeBackend(), PlayQueue(), TrackRepository(db), onError: (_) {});
    final ids = [
      for (var i = 0; i < 2; i++)
        await db.into(db.tracks).insert(TracksCompanion.insert(
            path: '/m/$i.mp3', title: 'S$i', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: i)),
    ];
    final first = open();
    addTearDown(first.dispose);
    first.setPlayContext(PlayContextKind.playlist.index, 'Mix');
    await first.restore(ids, 0, Duration.zero);
    await PlaybackPersistence(first, store).flush();

    final second = open(); // the restart
    addTearDown(second.dispose);
    await PlaybackPersistence(second, store).restore();
    final seen = <PlayContext?>[];
    await PlayerController(second, null, onContext: seen.add).resumeLastQueue();
    expect(seen.single?.kind, PlayContextKind.playlist);
    expect(seen.single?.name, 'Mix');

    // What an older version saved has no context.
    SharedPreferences.setMockInitialValues({'lastQueueIds': ['${ids[0]}']});
    final old = SettingsStore(await SharedPreferences.getInstance()).readPlayback();
    expect(old.contextKind, isNull);
  });
}
