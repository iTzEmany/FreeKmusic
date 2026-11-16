import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'equalizer.dart';

/// The mpv `af` fragment for a voice [level] (D-603): the centre of the stereo
/// image, without what is below 150 Hz (bass and kick stay), is subtracted from
/// both channels in proportion to `1 - level`. 1.0 and null give '' (no filter).
/// A single-input/single-output graph, as mpv's `lavfi` filter wants.
String voiceFilterString(double? level) {
  if (level == null || level >= 1.0) return '';
  final k = ((1 - level.clamp(0.0, 1.0)) / 2).toStringAsFixed(4);
  final centre = 'pan=stereo|c0=-$k*c0-$k*c1|c1=-$k*c0-$k*c1';
  return 'lavfi=[asplit[o][m];[m]$centre,highpass=f=150[h];[o][h]amix=inputs=2:normalize=0]';
}

/// The desktop [VoiceFilter]: sets mpv's `af` on the players that were made with
/// [audioLoadConfiguration]'s tag (see `JustAudioMediaKit.setVoiceFilter`).
class DesktopVoiceFilter implements VoiceFilter {
  DesktopVoiceFilter() : tag = _nextTag++;

  static int _nextTag = 1;

  /// Identifies this filter's player to `just_audio_media_kit`.
  final int tag;

  /// The value for `AudioPlayer(audioLoadConfiguration: ...)`'s
  /// `DarwinLoadControl.preferredPeakBitRate` of the player this filter drives.
  double get preferredPeakBitRate => JustAudioMediaKit.voiceFilterTag(tag);

  @override
  Future<void> setLevel(double? level) =>
      JustAudioMediaKit.setVoiceFilter(tag, voiceFilterString(level));
}
