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
    await PlayerController(second, null).resumeLastQueue();
    expect(playContextOf(second)?.kind, PlayContextKind.playlist);
    expect(playContextOf(second)?.name, 'Mix');

    // What an older version saved has no context.
    SharedPreferences.setMockInitialValues({'lastQueueIds': ['${ids[0]}']});
    final old = SettingsStore(await SharedPreferences.getInstance()).readPlayback();
    expect(old.contextKind, isNull);
    final third = open();
    addTearDown(third.dispose);
    await PlaybackPersistence(third, SettingsStore(await SharedPreferences.getInstance())).restore();
    expect(third.queueIds, [ids[0]]);
    expect(playContextOf(third), isNull);

    // A kind this version does not know is dropped, the queue is restored all the same.
    for (final kind in [-1, PlayContextKind.values.length, 9999]) {
      SharedPreferences.setMockInitialValues({
        'lastQueueIds': ['${ids[0]}'],
        'lastContextKind': kind,
        'lastContextName': 'x',
      });
      final h = open();
      addTearDown(h.dispose);
      await PlaybackPersistence(h, SettingsStore(await SharedPreferences.getInstance())).restore();
      expect(h.queueIds, [ids[0]]);
      expect(playContextOf(h), isNull);
    }
  });

  // Meant to stay green after 108.3: a missing `lastQueueUser` key means 0
  // tracks in the user block, so today's saves keep restoring as they are.
  test('a save without lastQueueUser restores the same queue and current track', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final ids = [
      for (var i = 0; i < 3; i++)
        await db.into(db.tracks).insert(TracksCompanion.insert(
            path: '/m/$i.mp3', title: 'S$i', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: i)),
    ];
    SharedPreferences.setMockInitialValues({
      'lastQueueIds': [for (final id in [ids[2], ids[0], ids[1]]) '$id'],
      'lastIndex': 1,
      'lastPositionMs': 0,
    });
    final h = CodecoreAudioHandler(FakeBackend(), PlayQueue(), TrackRepository(db), onError: (_) {});
    addTearDown(h.dispose);
    await PlaybackPersistence(h, SettingsStore(await SharedPreferences.getInstance())).restore();
    expect(h.queueIds, [ids[2], ids[0], ids[1]]);
    expect(h.currentTrack?.id, ids[0]);
  });

  test('lastQueueUser is saved and restored: the entries after the current are the block', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final ids = [
      for (var i = 0; i < 4; i++)
        await db.into(db.tracks).insert(TracksCompanion.insert(
            path: '/m/$i.mp3', title: 'S$i', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: i)),
    ];
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore(await SharedPreferences.getInstance());
    CodecoreAudioHandler open() {
      final h = CodecoreAudioHandler(FakeBackend(), PlayQueue(), TrackRepository(db), onError: (_) {});
      addTearDown(h.dispose);
      return h;
    }

    final a = open();
    await a.playQueue(ids, 0);
    a.addToQueue(ids[3]);
    a.addToQueue(ids[2]);
    await PlaybackPersistence(a, store).flush();
    expect(store.readPlayback().userAhead, 2);

    final b = open();
    await PlaybackPersistence(b, store).restore();
    expect(b.queueIds, a.queueIds);
    expect(b.userAhead, 2);
  });

  test('an online current takes itself out of the saved block count', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final ids = [
      for (var i = 0; i < 4; i++)
        await db.into(db.tracks).insert(TracksCompanion.insert(
            path: '/m/$i.mp3', title: 'S$i', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: i)),
    ];
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore(await SharedPreferences.getInstance());
    CodecoreAudioHandler open(PlayQueue q) {
      final h = CodecoreAudioHandler(FakeBackend(), q, TrackRepository(db), onError: (_) {});
      addTearDown(h.dispose);
      return h;
    }

    // [A, O (online, current), U (block), B, C]: the block is only U.
    final q = PlayQueue()..setItems([ids[0], -1, ids[1], ids[2], ids[3]], startIndex: 1, userAhead: 1);
    await PlaybackPersistence(open(q), store).flush();
    expect(store.readPlayback().userAhead, 0);

    final b = open(PlayQueue());
    await PlaybackPersistence(b, store).restore();
    expect(b.userAhead, 0);
  });
}
