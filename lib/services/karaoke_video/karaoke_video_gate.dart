import '../../data/db/app_database.dart' show Track;

/// What the audio handler asks of the karaoke video before playing (D-647). A null answer means
/// no wait (every normal track); the handler applies the time limits, so a video never holds the audio for long.
abstract interface class KaraokeVideoGate {
  /// Completes when the video of [t] has its first frame (or has failed), or null if [t] has no video.
  /// [start] is where the audio starts (a saved place).
  Future<void>? beforePlay(Track t, Duration start);

  /// Completes when the video is at [pos] after a seek of the audio, or null if there is no video.
  Future<void>? afterSeek(Duration pos);
}
