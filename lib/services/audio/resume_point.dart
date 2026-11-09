/// «Riprendi da qui»: only long tracks (audiobooks, DJ sets, recordings) are
/// worth remembering the position of.
const kResumeThreshold = Duration(minutes: 20);

/// Playing less than this from the start, or this close to the end, is not a
/// place to come back to.
const kResumeEdge = Duration(seconds: 30);

/// Resume a little before the saved point, to catch the sentence again.
const kResumeRewind = Duration(seconds: 5);

/// While playing, the position is saved at most this often.
const kResumeSaveEvery = Duration(seconds: 15);

/// A podcast episode is always worth remembering the place of, whatever its
/// length: only the first seconds are not.
const kEpisodeEdge = Duration(seconds: 10);

/// From this part of its length on, an episode counts as heard.
const kEpisodeHeardAt = 0.95;

/// An episode at [position] of [durationMs] has been listened to (practically)
/// to the end.
bool episodeHeard(Duration position, int durationMs) =>
    durationMs > 0 && position.inMilliseconds >= durationMs * kEpisodeHeardAt;

/// The position to store for a track of [durationMs] at [position]; null means
/// «no bookmark» (short track, still at the start, or practically finished).
/// For a podcast [episode] there is no length threshold, and the end is the
/// moment it counts as heard.
int? resumePointFor(Duration position, int durationMs, {bool episode = false}) {
  if (durationMs <= 0) return null;
  if (episode) {
    if (position < kEpisodeEdge || episodeHeard(position, durationMs)) return null;
    return position.inMilliseconds;
  }
  final duration = Duration(milliseconds: durationMs);
  if (duration < kResumeThreshold) return null;
  if (position < kResumeEdge || position > duration - kResumeEdge) return null;
  return position.inMilliseconds;
}

/// Where to start a track with a saved point: a few seconds earlier.
Duration? resumeStartFor(int? savedMs) {
  if (savedMs == null || savedMs <= 0) return null;
  final start = Duration(milliseconds: savedMs) - kResumeRewind;
  return start < Duration.zero ? Duration.zero : start;
}

/// [position] is at or past the end of a track of [durationMs]: a stale one (an
/// unknown length, <= 0, is never past).
bool isPastEnd(Duration position, int durationMs) =>
    durationMs > 0 && position.inMilliseconds >= durationMs;

/// A position this close to where a seek asked to go tells the seek arrived.
const kSeekConfirm = Duration(seconds: 30);
