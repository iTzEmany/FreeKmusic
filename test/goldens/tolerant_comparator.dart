
import 'package:codecore/core/platform.dart' show debugIsDesktopOverride;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_shots/support/shot_harness.dart';

/// Accepts a golden that differs in at most [tolerance] (a fraction) of its
/// pixels: anti-aliasing moves a few edge pixels between runs.
class TolerantComparator extends LocalFileComparator {
  TolerantComparator(super.testFile, {this.tolerance = 0.005});

  final double tolerance;

  /// Install it for the tests in [testFile]'s folder.
  static void install({double tolerance = 0.005}) {
    final current = goldenFileComparator as LocalFileComparator;
    goldenFileComparator = TolerantComparator(
        Uri.parse('${current.basedir}placeholder_test.dart'),
        tolerance: tolerance);
  }

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
        imageBytes, await getGoldenBytes(golden));
    if (result.passed || result.diffPercent <= tolerance) return true;
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}

/// [withShot] with the platform the size stands for (phone sizes are not desktop).
Future<void> withGoldenShot(
  WidgetTester tester,
  ShotSize size,
  Future<void> Function(Shot s) body, {
  bool radio = false,
}) {
  debugIsDesktopOverride = size == ShotSize.desktop;
  addTearDown(() => debugIsDesktopOverride = null);
  return withShot(tester, size, body, radio: radio);
}
