import '../audio/equalizer.dart';

/// Pushes the karaoke state to the playback backend's [VoiceFilter] (D-584).
///
/// [apply] gets the saved state plus whether the current item is an episode or
/// a radio: there the filter is bypassed (`setLevel(null)`) while the saved
/// level stays untouched, and it comes back on the next music track.
class KaraokeController {
  KaraokeController(this._filter);

  final VoiceFilter _filter;
  // Last value sent; the first apply always sends (the engine's state is unknown).
  bool _sent = false;
  double? _last;

  Future<void> apply({
    required bool on,
    required double level,
    required bool bypass,
  }) async {
    final target = on && !bypass ? level.clamp(0.0, 1.0) : null;
    if (_sent && target == _last) return;
    _sent = true;
    _last = target;
    await _filter.setLevel(target); // the backends log their own errors
  }
}
