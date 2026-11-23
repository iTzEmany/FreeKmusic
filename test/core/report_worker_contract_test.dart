import 'dart:io';

import 'package:codecore/core/app_info.dart' show kReleaseRepo;
import 'package:codecore/core/issue_report.dart';
import 'package:flutter_test/flutter_test.dart';

// The Worker (tools/report-worker) and the app must agree on what a report may be.
void main() {
  final js = File('tools/report-worker/src/index.js').readAsStringSync();
  // The regex must match: a renamed constant fails here with its name, not on a null.
  Match find(String re, String what) {
    final m = RegExp(re).firstMatch(js);
    expect(m, isNotNull, reason: 'index.js: $what not found');
    return m!;
  }

  int num(String re, String what) => int.parse(find(re, what).group(1)!);

  test('title and body limits match issue_report.dart', () {
    expect(num(r'title:\s*(\d+)', 'title limit'), kIssueTitleMax);
    expect(num(r'body:\s*(\d+)', 'body limit'), kIssueBodyMax);
  });

  test('the app keeps its request under the Worker limit', () {
    final m = find(r'MAX_REQUEST\s*=\s*(\d+)\s*\*\s*(\d+)', 'MAX_REQUEST');
    final limit = int.parse(m.group(1)!) * int.parse(m.group(2)!);
    expect(kIssueJsonMax, lessThanOrEqualTo(limit));
  });

  test('the version regex accepts what the app sends', () {
    final re = RegExp(find(r'VERSION\s*=\s*/(.+)/;', 'VERSION').group(1)!);
    // The real one, from pubspec.yaml, and the shapes the Worker documents.
    final pubspec = RegExp(r'^version:\s*(\S+)', multiLine: true)
        .firstMatch(File('pubspec.yaml').readAsStringSync())!
        .group(1)!;
    for (final v in [pubspec, '1.2.3', '1.2.3+45', '2.0.0-beta.1']) {
      expect(re.hasMatch(v), isTrue, reason: v);
    }
    expect(re.hasMatch('x' * 41), isFalse); // the Worker caps its length at 40
  });

  test('wrangler.toml points at the release repo', () {
    final toml = File('tools/report-worker/wrangler.toml').readAsStringSync();
    final m = RegExp(r'GITHUB_REPO\s*=\s*"([^"]+)"').firstMatch(toml);
    expect(m, isNotNull, reason: 'wrangler.toml: GITHUB_REPO not found');
    expect(m!.group(1), kReleaseRepo);
  });
}
