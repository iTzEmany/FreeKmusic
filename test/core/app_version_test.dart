import 'dart:io';

import 'package:codecore/core/app_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kAppVersion matches the version in pubspec.yaml', () {
    final m = RegExp(r'^version:\s*([0-9.]+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync());
    expect(kAppVersion, m!.group(1));
  });
}
