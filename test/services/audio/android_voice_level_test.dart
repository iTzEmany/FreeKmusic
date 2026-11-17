// ignore_for_file: depend_on_referenced_packages
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

/// Records the `setVoiceLevel` calls that reach each platform player id.
class _FakeJustAudio extends JustAudioPlatform {
  final ids = <String>[];
  final levels = <String, List<Object?>>{};

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    ids.add(request.id);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      MethodChannel('com.ryanheise.just_audio.methods.${request.id}'),
      (call) async {
        if (call.method == 'setVoiceLevel') {
          (levels[request.id] ??= []).add((call.arguments as Map)['level']);
        }
        return null;
      },
    );
    return _FakePlayer(request.id);
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async =>
      DisposePlayerResponse();
}

class _FakePlayer extends AudioPlayerPlatform {
  _FakePlayer(super.id);

  final _events = StreamController<PlaybackEventMessage>();

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;
  @override
  Stream<PlayerDataMessage> get playerDataMessageStream => const Stream.empty();

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    const d = Duration(seconds: 30);
    _events.add(PlaybackEventMessage(
      processingState: ProcessingStateMessage.ready,
      updatePosition: Duration.zero,
      updateTime: DateTime.now(),
      bufferedPosition: Duration.zero,
      duration: d,
      icyMetadata: null,
      currentIndex: 0,
      androidAudioSessionId: null,
    ));
    return LoadResponse(duration: d);
  }
  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async => SetVolumeResponse();
  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async => SetSpeedResponse();
  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();
  @override
  Future<SetShuffleModeResponse> setShuffleMode(SetShuffleModeRequest request) async =>
      SetShuffleModeResponse();
  @override
  Future<SetSkipSilenceResponse> setSkipSilence(SetSkipSilenceRequest request) async =>
      SetSkipSilenceResponse();
  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async => DisposeResponse();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeJustAudio platform;

  setUp(() {
    platform = _FakeJustAudio();
    JustAudioPlatform.instance = platform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_session'),
      (call) async => null,
    );
  });

  test('the voice level is sent to a new native player after stop() and a new load', () async {
    final player = AudioPlayer();
    await player.setAndroidVoiceLevel(0.25); // idle: nothing to talk to yet
    expect(platform.levels, isEmpty);

    await player.setUrl('https://example.com/a.mp3');
    expect(platform.levels[platform.ids.last], [0.25]);
    final first = platform.ids.last;

    await player.stop();
    await player.setUrl('https://example.com/b.mp3');
    expect(platform.ids.last, isNot(first));
    expect(platform.levels[platform.ids.last], [0.25]);
    await player.dispose();
  });

  test('a NaN level counts as no level (bypass)', () async {
    final player = AudioPlayer();
    await player.setUrl('https://example.com/a.mp3');
    await player.setAndroidVoiceLevel(double.nan);
    expect(platform.levels[platform.ids.last], [null]);
    await player.dispose();
  });
}
