import 'equalizer.dart';

enum BackendState { idle, loading, ready, playing, paused, completed, error }

/// How one track gives way to the next: as today (a new load), joined with no
/// pause, or overlapped with a fade.
enum TransitionMode { normal, gapless, crossfade }

class BackendException implements Exception {
  const BackendException(this.message,
      {this.fileMissing = false, this.expired = false});

  final String message;
  final bool fileMissing;

  /// A stream address that was refused (HTTP 403/410): it can be asked again.
  final bool expired;

  @override
  String toString() => 'BackendException: $message';
}

abstract class AudioBackend {
  Stream<Duration> get position;
  Stream<Duration?> get duration;
  Stream<BackendState> get state;

  /// Throws [BackendException] when the file cannot be played.
  Future<void> load(String filePath);

  /// Streams from [uri] (Jam: another device on the LAN). Same errors as [load].
  Future<void> loadUri(Uri uri, {Map<String, String> headers = const {}});

  /// The «now playing» text of a live stream (ICY), null where the stream or
  /// the platform gives none.
  Stream<String?> get streamTitle;
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);

  /// Playback rate (1.0 = normal), used by the Jam to absorb small drifts.
  Future<void> setSpeed(double speed);

  /// The equalizer of this backend, or null where there is none (desktop, the
  /// Jam's player, previews).
  Equalizer? get equalizer;

  /// Current position read on demand (not from the throttled stream).
  Duration get positionNow;
  Future<void> dispose();
}

/// A backend that can hold the next track ready, so the change from one to the
/// other needs no new load: either a seamless join (gapless) or an overlap
/// (crossfade). The queue stays the only authority on the order: the backend
/// plays what it is given and says when it moved on.
abstract class GaplessCapable {
  /// Prepares [path] to follow the current track (null: nothing follows), at
  /// [volume] once it is playing. A new call replaces the previous one.
  /// [overlap] says whether the two tracks may play over each other (a
  /// crossfade) or must simply follow one another.
  Future<void> setNext(String? path, {double volume = 1.0, bool overlap = true});

  /// Fires when playback has moved on to the track given to [setNext].
  Stream<void> get advanced;

  /// Silences the player and drops what follows, but keeps its native side
  /// alive for the next load. Unlike `stop`, which on Android tears the native
  /// player down and builds a new one (with a new audio effect) at the next
  /// load: done at every track change it exhausts the system's audio effects.
  Future<void> park();
}
