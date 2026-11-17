import 'dart:io';

import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'equalizer.dart';

/// The levels that mean «filter on»: 0..1 (clamped); null, NaN and 1.0 are off.
double? _active(double? level) =>
    level == null || level.isNaN || level >= 1.0 ? null : (level < 0 ? 0.0 : level);

/// The weight of the centre branches at [level]: 1 at level 0, 0 at level 1.
String _weights(double level) {
  final a = (1 - level).toStringAsFixed(4);
  return '1 $a $a';
}

/// The mpv `af` for a voice [level] (D-603), labelled `@kv`: the centre of the
/// stereo image is subtracted from both channels (pan `s`), and its part below
/// 150 Hz (4th-order low-pass, so the phase cancels the rest) is added back
/// (pan `l`), so bass and kick stay. The weights of `amix` scale both branches
/// by `1 - level`; [voiceFilterCommand] changes them without rebuilding the
/// graph. 1.0, null and NaN give '' (no filter). One input and one output, as
/// mpv's `lavfi` wants.
String voiceFilterString(double? level) {
  final l = _active(level);
  if (l == null) return '';
  return '@kv:lavfi=[asplit=3[o][m][b];'
      '[m]pan=stereo|c0=-0.5*c0-0.5*c1|c1=-0.5*c0-0.5*c1[s];'
      '[b]pan=stereo|c0=0.5*c0+0.5*c1|c1=0.5*c0+0.5*c1,lowpass=f=150,lowpass=f=150[l];'
      '[o][s][l]amix=inputs=3:weights=${_weights(l)}:normalize=0]';
}

/// The mpv command that moves a running [voiceFilterString] graph to [level]
/// (0..1) without rebuilding it (a rebuild can make the audio drop out).
List<String> voiceFilterCommand(double level) =>
    ['af-command', 'kv', 'weights', _weights(_active(level) ?? 1.0), 'amix'];

/// The desktop [VoiceFilter]: sets mpv's `af` on the players that were made with
/// [preferredPeakBitRate] (see `JustAudioMediaKit.setVoiceFilter`).
///
/// Create it, and put [preferredPeakBitRate] in the player's
/// `DarwinLoadControl`, ONLY where [supported]: macOS and iOS really apply
/// `preferredPeakBitRate` (AVPlayer), and Windows' libmpv has no `pan`/`amix`
/// (F-6), where a filter that cannot be built stops playback.
class DesktopVoiceFilter implements VoiceFilter {
  DesktopVoiceFilter() : tag = _nextTag++ {
    assert(supported, 'DesktopVoiceFilter exists on Linux only');
  }

  /// Linux only (F-6).
  static bool get supported => Platform.isLinux;

  static int _nextTag = 1;

  /// Identifies this filter's player to `just_audio_media_kit`.
  final int tag;

  bool _on = false;

  /// The value for `AudioPlayer(audioLoadConfiguration: ...)`'s
  /// `DarwinLoadControl.preferredPeakBitRate` of the player this filter drives.
  double get preferredPeakBitRate => JustAudioMediaKit.voiceFilterTag(tag);

  @override
  Future<void> setLevel(double? level) {
    final l = _active(level);
    final wasOn = _on;
    _on = l != null;
    return JustAudioMediaKit.setVoiceFilter(
      tag,
      voiceFilterString(l),
      // On to on: only the weights change. Off, or on after off: the graph is
      // removed or built once.
      command: wasOn && l != null ? voiceFilterCommand(l) : null,
    );
  }
}
