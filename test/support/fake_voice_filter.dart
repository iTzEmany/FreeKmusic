import 'package:codecore/services/audio/equalizer.dart';

/// Records every level sent to the voice filter (null = off).
class FakeVoiceFilter implements VoiceFilter {
  final List<double?> calls = [];

  @override
  Future<void> setLevel(double? level) async => calls.add(level);
}
