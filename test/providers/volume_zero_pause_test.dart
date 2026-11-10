import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/sleep_timer_provider.dart';
import 'package:codecore/providers/volume_zero_pause_provider.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/audio/preview_player.dart';
import 'package:codecore/services/audio/remote_transport.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';

class _Remote implements RemoteTransport {
  @override
  RemoteStatus get status => const RemoteStatus(
        title: 'Jam',
        artist: '',
        album: '',
        duration: Duration(minutes: 3),
        position: Duration.zero,
        playing: true,
      );
  @override
  Stream<RemoteStatus> get changes => const Stream.empty();
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> next() async {}
  @override
  Future<void> previous() async {}
  @override
  Future<void> seek(Duration position) async {}
}

void main() {
  late CodecoreAudioHandler handler;
  late ProviderContainer c;
  late List<int> ids;
  late AppDatabase db;

  Future<void> settle() => pumpEventQueue();
  bool flag() => c.read(volumeZeroPauseProvider);
  void setVol(double v) => c.read(volumeProvider.notifier).set(v);
  void toggle(bool on) => c
      .read(settingsProvider.notifier)
      .update((s) => s.copyWith(pauseOnZeroVolume: on));

  setUp(() async {
    SharedPreferences.setMockInitialValues({'pauseOnZeroVolume': true});
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    ids = [
      for (var i = 0; i < 2; i++)
        await db.into(db.tracks).insert(TracksCompanion.insert(
              path: '/m/$i.mp3',
              title: 't$i',
              albumKey: 'k$i',
              format: 'mp3',
              sizeBytes: 1,
              mtimeMs: 1,
              addedAt: 1,
              artist: const Value('a'),
            )),
    ];
    handler = CodecoreAudioHandler(
        FakeBackend(), PlayQueue(), TrackRepository(db),
        onError: (_) {});
    addTearDown(handler.dispose);
    c = ProviderContainer(overrides: [
      audioHandlerProvider.overrideWithValue(handler),
      settingsStoreProvider.overrideWithValue(await SettingsStore.open()),
      playerControllerProvider.overrideWithValue(PlayerController(handler, null)),
    ]);
    addTearDown(c.dispose);
    c.read(volumeProvider);
    c.read(volumeZeroPauseProvider);
    await handler.playQueue(ids, 0);
    await settle();
  });

  test('zero while playing pauses', () async {
    setVol(0);
    await settle();
    expect(handler.isPlaying, isFalse);
    expect(flag(), isTrue);
  });

  test('raising it again resumes', () async {
    setVol(0);
    await settle();
    setVol(0.5);
    await settle();
    expect(handler.isPlaying, isTrue);
    expect(flag(), isFalse);
  });

  test('a pause by the user at zero does not resume', () async {
    setVol(0);
    await settle();
    await handler.play(); // the user plays...
    await settle();
    await handler.pause(); // ...and pauses again
    await settle();
    setVol(0.5);
    await settle();
    expect(handler.isPlaying, isFalse);
  });

  test('switch off does nothing', () async {
    toggle(false);
    setVol(0);
    await settle();
    expect(handler.isPlaying, isTrue);
    expect(flag(), isFalse);
  });

  test('switch off midway drops the flag and does not resume', () async {
    setVol(0);
    await settle();
    toggle(false);
    setVol(0.5);
    await settle();
    expect(flag(), isFalse);
    expect(handler.isPlaying, isFalse);
  });

  test('already paused at zero sets no flag', () async {
    await handler.pause();
    await settle();
    setVol(0);
    await settle();
    expect(flag(), isFalse);
    setVol(0.5);
    await settle();
    expect(handler.isPlaying, isFalse);
  });

  test('with a Jam attached it does nothing', () async {
    handler.attachRemote(_Remote());
    setVol(0);
    await settle();
    expect(handler.isPlaying, isTrue);
    expect(flag(), isFalse);
  });

  test('the user pressing Play while at zero clears the flag', () async {
    setVol(0);
    await settle();
    await handler.play();
    await settle();
    expect(flag(), isFalse);
    await handler.pause();
    await settle();
    setVol(0.5);
    await settle();
    expect(handler.isPlaying, isFalse);
  });

  test('another track while at zero clears the flag', () async {
    setVol(0);
    await settle();
    await handler.playQueue(ids, 1);
    await settle();
    expect(flag(), isFalse);
  });

  test('mute twice resumes', () async {
    c.read(volumeProvider.notifier).toggleMute();
    await settle();
    expect(handler.isPlaying, isFalse);
    c.read(volumeProvider.notifier).toggleMute();
    await settle();
    expect(handler.isPlaying, isTrue);
  });

  test('the sleep-timer fade to zero does not pause and leaves no flag',
      () async {
    await handler.setVolume(0);
    await settle();
    expect(handler.isPlaying, isTrue);
    // What the timer does at its end.
    await handler.pause();
    await handler.setVolume(1);
    await settle();
    expect(flag(), isFalse);
    expect(handler.isPlaying, isFalse);
    expect(c.read(sleepTimerProvider).active, isFalse);
  });
  test('a preview (its own backend, volume 0 at start) does not act', () async {
    final preview = PreviewPlayer(FakeBackend.new,
        fade: Duration.zero, step: const Duration(milliseconds: 1));
    final row = await db.select(db.tracks).get().then((r) => r.first);
    await preview.start(row);
    await settle();
    expect(handler.isPlaying, isTrue);
    expect(flag(), isFalse);
    await preview.stop();
  });
}
