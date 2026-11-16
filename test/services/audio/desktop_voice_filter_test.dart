import 'package:codecore/services/audio/desktop_voice_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('level 1 and null mean no filter at all', () {
    expect(voiceFilterString(1.0), '');
    expect(voiceFilterString(null), '');
    expect(voiceFilterString(1.5), '');
  });

  test('level 0 takes the whole centre above 150 Hz, 0.5 takes half', () {
    String centre(String k) => 'pan=stereo|c0=-$k*c0-$k*c1|c1=-$k*c0-$k*c1';
    String graph(String k) =>
        'lavfi=[asplit[o][m];[m]${centre(k)},highpass=f=150[h];[o][h]amix=inputs=2:normalize=0]';
    expect(voiceFilterString(0), graph('0.5000'));
    expect(voiceFilterString(0.5), graph('0.2500'));
    expect(voiceFilterString(-1), graph('0.5000'), reason: 'clamped');
  });
}
