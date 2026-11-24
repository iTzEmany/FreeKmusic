import 'dart:io';

import 'package:codecore/core/app_info.dart';
import 'package:codecore/services/online/update_checker.dart' show compareVersions;
import 'package:codecore/services/update/release_notes.dart' show parseReleaseNotes;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kAppVersion matches the version in pubspec.yaml', () {
    final m = RegExp(r'^version:\s*([0-9.]+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync());
    expect(kAppVersion, m!.group(1));
  });

  // The bump PR must carry the notes: the tag is never rewritten (D-538) and the `notes` job fails without them.
  test('a version above 1.7.0 has non-empty release-notes/<version>.md', () {
    if (compareVersions(kAppVersion, '1.7.0') <= 0) return; // 1.7.0 and earlier shipped before D-711
    final f = File('release-notes/$kAppVersion.md');
    expect(f.existsSync(), isTrue, reason: 'write ${f.path} in the PR that bumps the version');
    expect(parseReleaseNotes(f.readAsStringSync()).isEmpty, isFalse);
  });
}
