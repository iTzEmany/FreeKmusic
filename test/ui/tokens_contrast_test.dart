import 'dart:math' as math;

import 'package:codecore/ui/theme/tokens.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _ratio(Color a, Color b) {
  final (hi, lo) = _lum(a) > _lum(b) ? (_lum(a), _lum(b)) : (_lum(b), _lum(a));
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const c = CcColors.notte;
  for (final (name, bg) in [
    ('surface1', c.surface1),
    ('surface2', c.surface2),
    ('surface3', c.surface3),
  ]) {
    test('night palette: muted text on $name >= 6.8:1 (rounded), text >= 13.4:1', () {
      expect(_ratio(c.textMuted, bg), greaterThanOrEqualTo(6.79));
      expect(_ratio(c.text, bg), greaterThanOrEqualTo(13.4));
    });
  }
}
