import 'package:codecore/core/issue_report.dart';
import 'package:flutter_test/flutter_test.dart';

const _info = TechInfo(
  appVersion: '1.2.0',
  buildNumber: '6053',
  platform: 'android',
  osVersion: '14 (API 34)',
  deviceModel: 'Xiaomi Mi A3',
  flavor: 'completa',
  transition: 'gapless',
  shufflePlus: true,
  language: 'it',
);

void main() {
  test('the body starts with the kind, so the service-created issue says it too', () {
    for (final (k, label) in [(IssueKind.bug, 'Bug'), (IssueKind.idea, 'Idea')]) {
      final d = buildIssue(repo: 'o/r', kind: k, title: 't', description: 'desc');
      expect(d.body, startsWith('Tipo: $label\n\ndesc'));
    }
  });

  test('URL carries encoded title, body and the label of the kind', () {
    final d = buildIssue(
      repo: 'o/r',
      kind: IssueKind.idea,
      title: ' Ciao & più ',
      description: 'riga 1\nriga #2',
    );
    expect(
      d.url,
      startsWith(
        'https://github.com/o/r/issues/new?title=Ciao%20%26%20pi%C3%B9&body=',
      ),
    );
    expect(d.url, contains('riga%201%0Ariga%20%232'));
    expect(d.url, endsWith('&labels=enhancement'));
    expect(
      buildIssue(
        repo: 'o/r',
        kind: IssueKind.bug,
        title: 't',
        description: 'd',
      ).url,
      endsWith('&labels=bug'),
    );
  });

  test('technical info is part of the body only when given', () {
    final withInfo = buildIssue(
      repo: 'o/r',
      kind: IssueKind.bug,
      title: 't',
      description: 'd',
      info: _info,
    );
    expect(withInfo.body, contains('1.2.0 (build 6053, completa)'));
    expect(withInfo.body, contains('Casuale+: sì'));
    final without = buildIssue(
      repo: 'o/r',
      kind: IssueKind.bug,
      title: 't',
      description: 'd',
    );
    expect(without.body, 'Tipo: Bug\n\nd');
  });

  test('log lines are sanitized: only W/E, no user name, no IP, no token', () {
    const log =
        '2026-01-01T10:00:00 [I] ok\n'
        '2026-01-01T10:00:01 [W] fail /home/mario/Music/a.mp3 from 192.168.1.20\n'
        '2026-01-01T10:00:02 [E] bad http://x/?token=abc123\n'
        'stack line that is not a log entry\n';
    final lines = recentProblemLines(log, home: '/home/mario');
    expect(lines, hasLength(2));
    final all = lines.join();
    expect(all, isNot(contains('mario')));
    expect(all, isNot(contains('192.168')));
    expect(all, isNot(contains('abc123')));
  });

  test('keeps only the last 20 lines and caps each line', () {
    final log = [
      for (var i = 0; i < 30; i++) '2026-01-01T10:00:00 [W] n$i ${'x' * 400}',
    ].join('\n');
    final lines = recentProblemLines(log, home: '');
    expect(lines, hasLength(20));
    expect(lines.first, contains('n10'));
    expect(lines.first.length, lessThan(260));
  });

  test('a long log is shortened first and the body says so; URL stays under the cap', () {
    final big = _info.withLog([
      for (var i = 0; i < 20; i++) 'riga $i ${'é' * 200}',
    ]);
    final d = buildIssue(
      repo: 'o/r',
      kind: IssueKind.bug,
      title: 't',
      description: 'descrizione',
      info: big,
    );
    expect(d.url.length, lessThanOrEqualTo(kMaxIssueUrl));
    expect(d.logTruncated, isTrue);
    expect(d.body, contains('Log accorciato'));
    expect(d.body, contains('riga 19'));
  });

  test('an enormous description is cut as a last resort', () {
    final d = buildIssue(
      repo: 'o/r',
      kind: IssueKind.bug,
      title: 't',
      description: 'ab ' * 5000,
      info: _info.withLog(['[W] x']),
    );
    expect(d.url.length, lessThanOrEqualTo(kMaxIssueUrl));
    expect(d.body, contains('Testo accorciato'));
  });

  test('fits: a huge log is shortened to the report service limits', () {
    final big = TechInfo(
      appVersion: '1',
      buildNumber: '1',
      platform: 'linux',
      osVersion: '1',
      deviceModel: 'x',
      flavor: 'lite',
      transition: 'n',
      shufflePlus: false,
      language: 'it',
      logLines: List.filled(500, 'è' * 200),
    );
    final d = buildIssue(
      repo: 'o/r',
      kind: IssueKind.bug,
      title: 't',
      description: 'd',
      info: big,
      fits: (t, b) => fitsReportService(t, b, '1.0.0'),
    );
    expect(d.logTruncated, isTrue);
    expect(fitsReportService(d.title, d.body, '1.0.0'), isTrue);
    expect(d.body, contains('Log accorciato'));
  });

  test('a title over 120 is cut and the description survives', () {
    final d = buildIssue(
      repo: 'o/r',
      kind: IssueKind.bug,
      title: 'x' * 300,
      description: 'una descrizione che deve restare intera',
      info: _info.withLog(['[W] x']),
      fits: (t, b) => fitsReportService(t, b, '1.0.0'),
    );
    expect(d.title.length, kIssueTitleMax);
    expect(d.body, contains('una descrizione che deve restare intera'));
    expect(d.body, contains('[W] x'));
    expect(fitsReportService(d.title, d.body, '1.0.0'), isTrue);
  });

  test('fitsReportService: exact limits and a body that is long for a URL but fine here', () {
    expect(fitsReportService('t' * 120, 'b', '1'), isTrue);
    expect(fitsReportService('t' * 121, 'b', '1'), isFalse);
    expect(fitsReportService('t', 'b' * 20000, '1'), isTrue);
    expect(fitsReportService('t', 'b' * 19000, '1'), isTrue);
    expect(fitsReportService('t', 'b' * 20001, '1'), isFalse);
    final d = buildIssue(
      repo: 'o/r',
      kind: IssueKind.bug,
      title: 't',
      description: 'd' * 12000,
      fits: (t, b) => fitsReportService(t, b, '1.0.0'),
    );
    expect(d.body.length, 12000 + 'Tipo: Bug\n\n'.length, reason: 'not cut: the service takes it whole');
    expect(d.logTruncated, isFalse);
  });

  test('a multibyte body is reduced even below 20000 characters', () {
    final d = buildIssue(
      repo: 'o/r',
      kind: IssueKind.bug,
      title: 't',
      description: 'è' * 15000,
      fits: (t, b) => fitsReportService(t, b, '1.0.0'),
    );
    expect(d.body.length, lessThan(15000));
    expect(fitsReportService(d.title, d.body, '1.0.0'), isTrue);
  });
}
