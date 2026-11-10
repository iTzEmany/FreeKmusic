import 'dart:async';

import 'package:codecore/core/platform.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/equalizer_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/sleep_timer_provider.dart';
import 'package:codecore/providers/volume_zero_pause_provider.dart';
import 'package:codecore/services/audio/audio_backend.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/audio/preview_player.dart';
import 'package:codecore/services/audio/remote_transport.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';

class _Backend extends FakeBackend {
  Completer<void>? gate; // holds load() while set
  bool throwOnPause = false;
  bool throwOnPlay = false;
  @override
  Future<void> load(String filePath) async {
    final g = gate;
    if (g != null) {
      stateC.add(BackendState.loading);
      await g.future;
    }
    return super.load(filePath);
  }

  @override
  Future<void> pause() async {
    if (throwOnPause) throw StateError('pause boom');
    return super.pause();
  }

  @override
  Future<void> play() async {
    if (throwOnPlay) throw StateError('play boom');
    return super.play();
  }
}

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
  TestWidgetsFlutterBinding.ensureInitialized();
  late CodecoreAudioHandler handler;
  late _Backend backend;
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
      for (var i = 0; i < 3; i++)
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
    backend = _Backend();
    handler = CodecoreAudioHandler(
        backend, PlayQueue(), TrackRepository(db),
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

  test('stop at zero clears the flag: raising stays paused', () async {
    setVol(0);
    await settle();
    await handler.stop();
    await settle();
    expect(flag(), isFalse);
    setVol(0.5);
    await settle();
    expect(handler.isPlaying, isFalse);
  });

  test('a metadata refresh of the same track keeps the flag', () async {
    setVol(0);
    await settle();
    final m = handler.mediaItem.value!;
    handler.mediaItem.add(m.copyWith(duration: const Duration(minutes: 9)));
    await settle();
    expect(flag(), isTrue);
    setVol(0.5);
    await settle();
    expect(handler.isPlaying, isTrue);
  });

  test('switch turned on at runtime works', () async {
    toggle(false);
    await settle();
    toggle(true);
    await settle();
    setVol(0);
    await settle();
    expect(handler.isPlaying, isFalse);
  });

  test('a tiny positive volume does not pause', () async {
    setVol(0.05);
    await settle();
    expect(handler.isPlaying, isTrue);
  });

  test('NaN neither pauses nor resumes', () async {
    setVol(double.nan);
    await settle();
    expect(handler.isPlaying, isTrue);
    setVol(0);
    await settle();
    setVol(double.nan);
    await settle();
    expect(handler.isPlaying, isFalse);
    expect(flag(), isTrue);
  });

  test('an output change while paused by it does not resume', () async {
    setVol(0);
    await settle();
    c.read(outputRouteProvider.notifier).set(OutputRoute.headphones);
    await settle();
    expect(flag(), isFalse);
    setVol(0.5);
    await settle();
    expect(handler.isPlaying, isFalse);
  });

  test('the sleep timer ending while at zero drops the flag', () async {
    final n = c.read(sleepTimerProvider.notifier);
    n.startAtTrackEnd();
    setVol(0);
    await settle();
    expect(flag(), isTrue);
    n.cancel(); // the timer's end resets its state the same way
    await settle();
    expect(flag(), isFalse);
    setVol(0.5);
    await settle();
    expect(handler.isPlaying, isFalse);
  });

  test('zero while a track is loading keeps it from starting', () async {
    backend.gate = Completer<void>();
    final f = handler.playQueue(ids, 1);
    await settle();
    setVol(0);
    await settle();
    backend.gate!.complete();
    await f;
    await settle();
    expect(handler.isPlaying, isFalse);
    expect(flag(), isTrue);
    setVol(0.5);
    await settle();
    expect(handler.isPlaying, isTrue);
  });

  test('zero at the moment a track completes does not start the next',
      () async {
    backend.stateC.add(BackendState.completed);
    setVol(0);
    await settle();
    expect(handler.isPlaying, isFalse);
  });

  test('mute, unmute, mute quickly ends paused with the flag', () async {
    final v = c.read(volumeProvider.notifier);
    v.toggleMute();
    v.toggleMute();
    v.toggleMute();
    await settle();
    expect(handler.isPlaying, isFalse);
    expect(flag(), isTrue);
    v.toggleMute();
    await settle();
    expect(handler.isPlaying, isTrue);
  });

  test('a failing pause leaves no flag and no uncaught error', () async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      backend.throwOnPause = true;
      setVol(0);
      await settle();
    }, (e, s) => errors.add(e));
    expect(errors, isEmpty);
    expect(flag(), isFalse);
  });

  test('a failing resume raises no uncaught error', () async {
    setVol(0);
    await settle();
    final errors = <Object>[];
    await runZonedGuarded(() async {
      backend.throwOnPlay = true;
      setVol(0.5);
      await settle();
    }, (e, s) => errors.add(e));
    expect(errors, isEmpty);
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

  group('Android', () {
    const ch = MethodChannel('codecore/volume');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<String> calls;

    Future<void> native(double v) => messenger.handlePlatformMessage(
          ch.name,
          ch.codec.encodeMethodCall(MethodCall('changed', v)),
          (_) {},
        );

    Future<ProviderContainer> make({required bool on}) async {
      debugIsAndroidOverride = true;
      addTearDown(() => debugIsAndroidOverride = null);
      calls = [];
      messenger.setMockMethodCallHandler(ch, (m) async {
        calls.add(m.method);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(ch, null));
      SharedPreferences.setMockInitialValues({'pauseOnZeroVolume': on});
      final k = ProviderContainer(overrides: [
        audioHandlerProvider.overrideWithValue(handler),
        settingsStoreProvider.overrideWithValue(await SettingsStore.open()),
        playerControllerProvider
            .overrideWithValue(PlayerController(handler, null)),
      ]);
      addTearDown(k.dispose);
      k.read(settingsProvider);
      k.read(volumeZeroPauseProvider);
      await settle();
      return k;
    }

    test('starts at launch, pauses and resumes on the system volume',
        () async {
      final k = await make(on: true);
      expect(calls, ['start']);
      await native(0);
      await settle();
      expect(handler.isPlaying, isFalse);
      expect(k.read(volumeZeroPauseProvider), isTrue);
      await native(0.4);
      await settle();
      expect(handler.isPlaying, isTrue);
    });

    test('follows the switch at runtime and stops once on dispose', () async {
      final k = await make(on: false);
      expect(calls, isEmpty);
      k
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(pauseOnZeroVolume: true));
      await settle();
      expect(calls, ['start']);
      k.dispose();
      await settle();
      expect(calls, ['start', 'stop']);
    });

    test('switched off then disposed stops only once', () async {
      final k = await make(on: true);
      k
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(pauseOnZeroVolume: false));
      await settle();
      k.dispose();
      await settle();
      expect(calls, ['start', 'stop']);
    });
  });
}
