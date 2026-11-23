import 'dart:convert';

import 'log_export.dart';

enum IssueKind { bug, idea }

/// The facts attached to a report; all of them are shown to the user first.
class TechInfo {
  const TechInfo({
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.osVersion,
    required this.deviceModel,
    required this.flavor,
    required this.transition,
    required this.shufflePlus,
    required this.language,
    this.logLines = const [],
  });

  final String appVersion, buildNumber, platform, osVersion, deviceModel;
  final String flavor, transition, language;
  final bool shufflePlus;

  /// Already sanitized.
  final List<String> logLines;

  TechInfo withLog(List<String> lines) => TechInfo(
    appVersion: appVersion,
    buildNumber: buildNumber,
    platform: platform,
    osVersion: osVersion,
    deviceModel: deviceModel,
    flavor: flavor,
    transition: transition,
    shufflePlus: shufflePlus,
    language: language,
    logLines: lines,
  );

  /// The block without the log lines.
  String get summary =>
      '- Versione: $appVersion (build $buildNumber, $flavor)\n'
      '- Sistema: $platform $osVersion\n'
      '- Dispositivo: $deviceModel\n'
      '- Transizioni: $transition, Casuale+: ${shufflePlus ? 'sì' : 'no'}, Lingua: $language';

  /// Exactly what the preview shows and the body carries.
  String render({int? maxLogLines}) {
    final lines = maxLogLines == null || maxLogLines >= logLines.length
        ? logLines
        : logLines.sublist(logLines.length - maxLogLines);
    if (lines.isEmpty) return summary;
    return '$summary\n\nUltimi avvisi ed errori del log:\n```\n${lines.join('\n')}\n```';
  }
}

class IssueDraft {
  const IssueDraft({
    required this.title,
    required this.body,
    required this.url,
    required this.logTruncated,
  });

  final String title, body, url;

  /// Some log lines (or all) were left out to keep the address short.
  final bool logTruncated;

  /// For «Copia testo».
  String get plainText => '$title\n\n$body';
}

const kMaxIssueUrl = 7000;
const kIssueLogMaxLines = 20;
const _maxLogLineChars = 220;
final _logLine = RegExp(r'^\S+ \[(?:W|E)\] ');

/// The last warning / error lines of a log, redacted like «Esporta log».
List<String> recentProblemLines(
  String log, {
  required String home,
  String? deviceName,
  int max = kIssueLogMaxLines,
}) {
  final picked = [
    for (final l in log.split('\n'))
      if (_logLine.hasMatch(l)) l,
  ];
  final last = picked.length > max
      ? picked.sublist(picked.length - max)
      : picked;
  return [
    for (final l in last)
      () {
        final s = redactLog(l, home: home, deviceName: deviceName);
        return s.length > _maxLogLineChars
            ? '${s.substring(0, _maxLogLineChars)}…'
            : s;
      }(),
  ];
}

String _enc(String s) => Uri.encodeQueryComponent(s).replaceAll('+', '%20');

String _url(String repo, String title, String body, IssueKind kind) =>
    'https://github.com/$repo/issues/new?title=${_enc(title)}'
    '&body=${_enc(body)}&labels=${kind == IssueKind.bug ? 'bug' : 'enhancement'}';

/// What the anonymous-report service accepts (tools/report-worker): title and
/// body lengths, and the JSON request under 32 KB (a margin is kept).
const kIssueTitleMax = 120;
const kIssueBodyMax = 20000;
const kIssueJsonMax = 30000;

/// For [buildIssue]`.fits`: the body and title go in a request the service takes.
bool fitsReportService(String title, String body, String version) =>
    title.length <= kIssueTitleMax &&
    body.length <= kIssueBodyMax &&
    utf8.encode(jsonEncode({'title': title, 'body': body, 'version': version})).length <= kIssueJsonMax;

/// Builds the pre-filled «new issue» page. When the address would be too long
/// (or [fits] says no) the log goes first (oldest lines, then all), then the description.
IssueDraft buildIssue({
  required String repo,
  required IssueKind kind,
  required String title,
  required String description,
  TechInfo? info,
  int maxUrl = kMaxIssueUrl,
  bool Function(String title, String body)? fits,
}) {
  final t = title.trim();
  bool ok(String body) => fits != null ? fits(t, body) : _url(repo, t, body, kind).length <= maxUrl;
  var desc = description.trim();
  String compose(int? logLines, String note) {
    final parts = [desc];
    if (info != null) parts.add('---\n${info.render(maxLogLines: logLines)}');
    if (note.isNotEmpty) parts.add(note);
    return parts.join('\n\n');
  }

  final total = info?.logLines.length ?? 0;
  for (var n = total; n >= 0; n--) {
    final note = n < total
        ? '_Log accorciato per stare in un indirizzo: ${n == 0 ? 'nessuna riga' : 'ultime $n righe su $total'}._'
        : '';
    final body = compose(n, note);
    final url = _url(repo, t, body, kind);
    if (ok(body)) {
      return IssueDraft(
        title: t,
        body: body,
        url: url,
        logTruncated: n < total,
      );
    }
  }
  // Even without log: shorten the description.
  const note = '_Testo accorciato per stare in un indirizzo._';
  while (desc.length > 50) {
    desc = '${desc.substring(0, (desc.length * 0.8).floor())}…';
    final body = compose(0, note);
    final url = _url(repo, t, body, kind);
    if (ok(body)) {
      return IssueDraft(
        title: t,
        body: body,
        url: url,
        logTruncated: total > 0,
      );
    }
  }
  final body = compose(0, note);
  return IssueDraft(
    title: t,
    body: body,
    url: _url(repo, t, body, kind),
    logTruncated: true,
  );
}
