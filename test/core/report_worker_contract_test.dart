import 'dart:io';

import 'package:codecore/core/app_info.dart' show kReleaseRepo;
import 'package:codecore/core/issue_report.dart';
import 'package:flutter_test/flutter_test.dart';

// The Worker (tools/report-worker) and the app must agree on what a report may be.
void main() {
  final js = File('tools/report-worker/src/index.js').readAsStringSync();
  int num(String re) => int.parse(RegExp(re).firstMatch(js)!.group(1)!);

  test('title and body limits match issue_report.dart', () {
    expect(num(r'title: (\d+)'), kIssueTitleMax);
    expect(num(r'body: (\d+)'), kIssueBodyMax);
  });

  test('the app keeps its request under the Worker limit', () {
    expect(js, contains('MAX_REQUEST = 32 * 1024'));
    expect(kIssueJsonMax, lessThanOrEqualTo(32 * 1024));
  });

  test('the version regex accepts what the app sends', () {
    final re = RegExp(RegExp(r'VERSION = /(.+)/;').firstMatch(js)!.group(1)!);
    for (final v in ['1.2.3', '1.2.3+45', '2.0.0-beta.1']) {
      expect(re.hasMatch(v), isTrue, reason: v);
    }
  });

  test('wrangler.toml points at the release repo', () {
    final toml = File('tools/report-worker/wrangler.toml').readAsStringSync();
    expect(RegExp(r'GITHUB_REPO = "([^"]+)"').firstMatch(toml)!.group(1), kReleaseRepo);
  });
}
