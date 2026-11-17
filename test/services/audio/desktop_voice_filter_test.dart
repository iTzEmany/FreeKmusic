import 'package:codecore/services/audio/desktop_voice_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('level 1, null, NaN and above 1 mean no filter at all', () {
    expect(voiceFilterString(1.0), '');
    expect(voiceFilterString(null), '');
    expect(voiceFilterString(1.5), '');
    expect(voiceFilterString(double.nan), '');
  });

  test('level 0 takes the whole centre, 0.5 half, below 0 is clamped to 0', () {
    String graph(String w) =>
        '@kv:lavfi=[asplit=3[o][m][b];[m]pan=stereo|c0=-0.5*c0-0.5*c1|c1=-0.5*c0-0.5*c1[s];'
        '[b]pan=stereo|c0=0.5*c0+0.5*c1|c1=0.5*c0+0.5*c1,lowpass=f=150,lowpass=f=150[l];'
        '[o][s][l]amix=inputs=3:weights=1 $w $w:normalize=0]';
    expect(voiceFilterString(0), graph('1.0000'));
    expect(voiceFilterString(0.5), graph('0.5000'));
    expect(voiceFilterString(-1), graph('1.0000'));
  });

  test('the live change is an af-command on the amix weights, same numbers as the graph', () {
    expect(voiceFilterCommand(0.25), ['af-command', 'kv', 'weights', '1 0.7500 0.7500', 'amix']);
    expect(voiceFilterString(0.25), contains('weights=1 0.7500 0.7500'));
    expect(voiceFilterCommand(-3)[3], '1 1.0000 1.0000');
  });
}
