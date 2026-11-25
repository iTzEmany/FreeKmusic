// ignore_for_file: depend_on_referenced_packages (the platform interface of just_audio, already a transitive package)
import 'dart:async';
import 'dart:io';

import 'package:codecore/services/audio/audio_backend.dart';
import 'package:codecore/services/audio/just_audio_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A native player that takes a moment to start (the first one of a session does) and then loads at once.
class _Platform extends JustAudioPlatform with MockPlatformInterfaceMixin {
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return _Player(request.id);
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async => DisposePlayerResponse();

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(DisposeAllPlayersRequest request) async =>
      DisposeAllPlayersResponse();
}

class _Player extends AudioPlayerPlatform {
  _Player(super.id);

  final _events = StreamController<PlaybackEventMessage>.broadcast();
  final _data = StreamController<PlayerDataMessage>.broadcast();

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;
  @override
  Stream<PlayerDataMessage> get playerDataMessageStream => _data.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    _events.add(PlaybackEventMessage(
      processingState: ProcessingStateMessage.ready,
      updateTime: DateTime.now(),
      updatePosition: Duration.zero,
      bufferedPosition: Duration.zero,
      duration: const Duration(seconds: 100),
      icyMetadata: null,
      currentIndex: 0,
      androidAudioSessionId: null,
    ));
    return LoadResponse(duration: const Duration(seconds: 100));
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();
  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async => SetVolumeResponse();
  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async => SetSpeedResponse();
  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async => SetPitchResponse();
  @override
  Future<SetSkipSilenceResponse> setSkipSilence(SetSkipSilenceRequest request) async => SetSkipSilenceResponse();
  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async => SetLoopModeResponse();
  @override
  Future<SetShuffleModeResponse> setShuffleMode(SetShuffleModeRequest request) async => SetShuffleModeResponse();
  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async => DisposeResponse();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the newest of two quick first loads is not left «interrupted»', () async {
    JustAudioPlatform.instance = _Platform();
    final dir = await Directory.systemTemp.createTemp('jab');
    addTearDown(() => dir.delete(recursive: true));
    final files = [for (var i = 0; i < 3; i++) (File('${dir.path}/$i.mp3')..writeAsBytesSync([0])).path];
    final backend = JustAudioBackend();
    final first = expectLater(
      backend.load(files[0]),
      throwsA(isA<BackendException>().having((e) => e.interrupted, 'interrupted', true)),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await backend.load(files[1]); // the newest: must load
    await first;
    await backend.load(files[2]); // and the player keeps working
    await backend.dispose();
  });
}
