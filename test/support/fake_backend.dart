import 'dart:async';

import 'package:codecore/services/audio/audio_backend.dart';
import 'package:codecore/services/audio/equalizer.dart';

class FakeBackend implements AudioBackend, GaplessCapable {
  final stateC = StreamController<BackendState>.broadcast();
  final posC = StreamController<Duration>.broadcast();
  final durC = StreamController<Duration?>.broadcast();
  final titleC = StreamController<String?>.broadcast();
  final loaded = <String>[];
  final failing = <String>{};

  /// Paths whose load fails like a load replaced by a newer one.
  /// Paths that fail with an unplayable error carrying this message.
  final failMessages = <String, String>{};
  bool playing = false;

  /// Like just_audio: a player that was playing goes on playing a file loaded
  /// after it, until it is told to pause.
  bool playingSurvivesLoad = false;

  @override
  Stream<BackendState> get state => stateC.stream;
  @override
  Stream<Duration> get position => posC.stream;
  @override
  Stream<Duration?> get duration => durC.stream;
  @override
  Stream<String?> get streamTitle => titleC.stream;

  /// What was prepared to follow the current track (null: nothing).
  String? nextPath;
  double nextVolume = 1.0;
  bool nextOverlap = true;
  final nextCalls = <String?>[];
  final advancedC = StreamController<void>.broadcast();

  @override
  Stream<void> get advanced => advancedC.stream;

  @override
  Future<void> setNext(String? path,
      {double volume = 1.0, bool overlap = true}) async {
    nextCalls.add(path);
    nextPath = path;
    nextVolume = volume;
    nextOverlap = overlap;
  }

  /// The backend moves on to the prepared track by itself.
  void advance() {
    nextPath = null;
    advancedC.add(null);
  }

  @override
  Future<void> load(String filePath) async {
    if (failing.contains(filePath)) throw const BackendException('missing', fileMissing: true);
    final m = failMessages[filePath];
    if (m != null) throw BackendException(m);
    nextPath = null;
    loaded.add(filePath);
    if (forgetSpeedOnLoad) speed = 1.0;
    stateC.add(playing && playingSurvivesLoad
        ? BackendState.playing
        : BackendState.paused);
  }

  /// Addresses that answer «expired» once (an HTTP 403), then work.
  final expiring = <String>{};
  final loadedUris = <({Uri uri, Map<String, String> headers})>[];

  @override
  Future<void> loadUri(Uri uri, {Map<String, String> headers = const {}}) async {
    if (expiring.remove(uri.toString())) {
      throw const BackendException('403', expired: true);
    }
    if (failing.contains(uri.toString())) {
      throw const BackendException('unreachable');
    }
    nextPath = null;
    loadedUris.add((uri: uri, headers: headers));
    stateC.add(BackendState.paused);
  }

  @override
  Future<void> play() async {
    playing = true;
    stateC.add(BackendState.playing);
  }

  @override
  Future<void> pause() async {
    playing = false;
    stateC.add(BackendState.paused);
  }

  @override
  Future<void> park() async {
    parkCalls++;
    playing = false;
    stateC.add(BackendState.paused);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    playing = false;
    stateC.add(BackendState.idle);
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    positionValue = position;
  }
  final volumes = <double>[];
  bool disposed = false;
  int stopCalls = 0;
  int parkCalls = 0;

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  double speed = 1.0;

  /// Like a native player that drops its rate when a new file is loaded.
  bool forgetSpeedOnLoad = false;
  final speedCalls = <double>[];
  Duration positionValue = Duration.zero;
  final seeks = <Duration>[];

  @override
  Future<void> setSpeed(double s) async {
    speedCalls.add(s);
    speed = s;
  }

  /// A fake equalizer can be put here by tests that need one.
  @override
  Equalizer? equalizer;

  @override
  Duration get positionNow => positionValue;
  @override
  Future<void> dispose() async => disposed = true;
}
