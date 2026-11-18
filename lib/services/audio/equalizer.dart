import 'dart:math' as math;

/// Layout of an equalizer: centre frequency of each band and the gain limits
/// of the device (Android typically offers 5 bands within ±15 dB).
class EqBands {
  const EqBands({required this.centerHz, required this.minDb, required this.maxDb});

  final List<double> centerHz;
  final double minDb, maxDb;

  int get count => centerHz.length;
}

/// An equalizer on a playback backend. Only Android has one (`AndroidEqualizer`
/// of `just_audio`); elsewhere [AudioBackend.equalizer] is null.
abstract class Equalizer {
  /// The band layout. Completes when the platform reports it, which for
  /// Android is once the first track is loaded.
  Future<EqBands> bands();

  Future<void> setEnabled(bool enabled);

  /// One gain in dB per band, in band order; values outside the device limits
  /// are clamped.
  Future<void> setGains(List<double> gainsDb);
}

enum EqPreset { flat, bass, voice, treble, custom }

/// Reference curves on ten octave bands, in dB.
const _referenceHz = [31.0, 62.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0];

const _curves = <EqPreset, List<double>>{
  EqPreset.flat: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  EqPreset.bass: [6, 5, 4, 2, 1, 0, 0, 0, 0, 0],
  EqPreset.voice: [-2, -2, -1, 0, 2, 3, 3, 2, 0, -1],
  EqPreset.treble: [0, 0, 0, 0, 0, 1, 2, 4, 5, 6],
};

/// The gains of [preset] for bands centred at [centerHz]: the reference curve
/// is interpolated along the logarithm of the frequency and clamped to
/// [minDb]..[maxDb]. [EqPreset.custom] has no curve of its own (flat here):
/// the user's values are stored with the settings.
List<double> presetGains(
  EqPreset preset,
  List<double> centerHz, {
  double minDb = -12,
  double maxDb = 12,
}) {
  final curve = _curves[preset] ?? _curves[EqPreset.flat]!;
  return [
    for (final f in centerHz)
      _interpolate(curve, f).clamp(minDb, maxDb).toDouble(),
  ];
}

double _interpolate(List<double> curve, double hz) {
  if (hz <= _referenceHz.first) return curve.first;
  if (hz >= _referenceHz.last) return curve.last;
  for (var i = 1; i < _referenceHz.length; i++) {
    if (hz <= _referenceHz[i]) {
      final lo = math.log(_referenceHz[i - 1]), hi = math.log(_referenceHz[i]);
      final t = (math.log(hz) - lo) / (hi - lo);
      return curve[i - 1] + (curve[i] - curve[i - 1]) * t;
    }
  }
  return curve.last;
}

/// [gains] clamped into [minDb]..[maxDb] and padded or cut to [count] bands
/// (a saved custom curve may come from a device with another layout).
List<double> fitGains(List<double> gains, int count, double minDb, double maxDb) => [
      for (var i = 0; i < count; i++)
        (i < gains.length ? gains[i] : 0.0).clamp(minDb, maxDb).toDouble(),
    ];
