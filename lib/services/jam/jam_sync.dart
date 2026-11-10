/// What one output has to do right now to follow the shared position.
class JamSyncAction {
  const JamSyncAction({
    this.play,
    this.seekToMs,
    this.speed,
    this.playInMs,
  });

  /// true = start, false = pause, null = leave as is.
  final bool? play;

  /// Jump to this position (ms) before anything else.
  final int? seekToMs;

  /// New playback speed (1.0 = normal).
  final double? speed;

  /// Start playing in this many ms (the Jam start is still ahead).
  final int? playInMs;

  bool get isNoop =>
      play == null && seekToMs == null && speed == null && playInMs == null;

  static const noop = JamSyncAction();

  @override
  String toString() =>
      'JamSyncAction(play: $play, seek: $seekToMs, speed: $speed, in: $playInMs)';
}

/// Thresholds of the drift controller (see docs/storico/fasi/fase-10-jam-sincronia.md).
class JamSyncTuning {
  const JamSyncTuning({
    this.ignoreMs = 25,
    this.resetMs = 10,
    this.seekMs = 120,
    this.speedDelta = 0.025,
    this.gainMs = 4000,
    this.idleSeekMs = 150,
  });

  /// Below this error nothing is touched.
  final int ignoreMs;

  /// While correcting with speed, normal speed resumes under this error.
  final int resetMs;

  /// Above this error the position is simply set.
  final int seekMs;

  /// Largest speed change used to absorb an error (±2.5 %).
  final double speedDelta;

  /// Proportional gain: the speed offset is `error / gainMs` (so 80 ms ahead
  /// slows playback by 2 %), which avoids the limit cycle of a fixed step.
  final int gainMs;

  /// Tolerance for the paused position.
  final int idleSeekMs;
}

/// Pure decision logic of a synchronised output. No I/O, no clocks: everything
/// is passed in so scenarios can be played back deterministically.
class JamSyncController {
  const JamSyncController([this.tuning = const JamSyncTuning()]);

  final JamSyncTuning tuning;

  /// [positionMs]/[positionAtMs]/[playing] come from the shared state,
  /// [jamNowMs] from the Jam clock. [measuredMs] is the player's position and
  /// [backendPlaying]/[speed] its current state. [latencyMs] is the extra time
  /// this device's output path takes (Bluetooth...): the player is run that
  /// far ahead.
  JamSyncAction decide({
    required bool playing,
    required int positionMs,
    required int positionAtMs,
    required int jamNowMs,
    required int measuredMs,
    required bool backendPlaying,
    double speed = 1.0,
    int latencyMs = 0,
  }) {
    final t = tuning;
    if (!playing) {
      if (backendPlaying) {
        return JamSyncAction(
            play: false,
            seekToMs: (measuredMs - positionMs).abs() > t.idleSeekMs
                ? positionMs
                : null,
            speed: speed != 1.0 ? 1.0 : null);
      }
      if ((measuredMs - positionMs).abs() > t.idleSeekMs) {
        return JamSyncAction(seekToMs: positionMs);
      }
      return JamSyncAction.noop;
    }

    // Playing, but the scheduled start is still ahead: wait in position.
    if (jamNowMs < positionAtMs) {
      final wait = positionAtMs - jamNowMs - latencyMs;
      if (backendPlaying) {
        return JamSyncAction(play: false, seekToMs: positionMs, speed: 1.0);
      }
      final off = (measuredMs - positionMs).abs() > t.idleSeekMs;
      return JamSyncAction(
          seekToMs: off ? positionMs : null,
          playInMs: wait > 0 ? wait : 0,
          play: wait > 0 ? null : true);
    }

    final expected = positionMs + (jamNowMs - positionAtMs) + latencyMs;
    if (!backendPlaying) {
      return JamSyncAction(play: true, seekToMs: expected, speed: 1.0);
    }
    final err = measuredMs - expected; // > 0: this output is ahead
    final abs = err.abs();
    if (abs > t.seekMs) {
      return JamSyncAction(seekToMs: expected, speed: speed != 1.0 ? 1.0 : null);
    }
    if (abs >= t.ignoreMs) {
      final k = (err / t.gainMs).clamp(-t.speedDelta, t.speedDelta).toDouble();
      final want = double.parse((1.0 - k).toStringAsFixed(4));
      // Do not chatter the player for tiny changes of the target speed.
      return (want - speed).abs() < 0.003
          ? JamSyncAction.noop
          : JamSyncAction(speed: want);
    }
    if (speed != 1.0 && abs <= t.resetMs) return const JamSyncAction(speed: 1.0);
    return JamSyncAction.noop;
  }
}
