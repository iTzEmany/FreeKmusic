/// Oldest yt-dlp that understands `--js-runtimes` (see R19 in the risks file).
const kMinYtDlpVersion = '2025.11.12';

/// `AAAA.MM.GG` with an optional build number (`2026.08.19.232055`).
class YtDlpVersion implements Comparable<YtDlpVersion> {
  const YtDlpVersion(this.year, this.month, this.day, [this.build = 0]);

  final int year, month, day, build;

  @override
  int compareTo(YtDlpVersion o) {
    for (final (a, b) in [
      (year, o.year),
      (month, o.month),
      (day, o.day),
      (build, o.build),
    ]) {
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }

  @override
  String toString() => '$year.'
      '${month.toString().padLeft(2, '0')}.${day.toString().padLeft(2, '0')}'
      '${build == 0 ? '' : '.$build'}';
}

final _versionPattern = RegExp(r'^(\d{4})\.(\d{2})\.(\d{2})(?:\.(\d+))?$');

/// Parses the first line of `yt-dlp --version`; null when it is not a version.
YtDlpVersion? parseYtDlpVersion(String out) {
  final line = out.trim().split(RegExp(r'\r?\n')).first.trim();
  final m = _versionPattern.firstMatch(line);
  if (m == null) return null;
  return YtDlpVersion(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!),
      int.parse(m[4] ?? '0'));
}

/// yt-dlp is fixed by YouTube changes: past this age (from the date in its
/// version) the app downloads a fresh copy by itself.
const kYtDlpMaxAge = Duration(days: 90);

/// No yt-dlp at all, or one older than [kYtDlpMaxAge]. An unreadable version
/// is left alone.
bool ytDlpNeedsDownload(String? raw, DateTime now) {
  if (raw == null) return true;
  final v = parseYtDlpVersion(raw);
  return v != null &&
      now.difference(DateTime(v.year, v.month, v.day)) > kYtDlpMaxAge;
}

/// True only when [raw] is a valid version older than [kMinYtDlpVersion]; an
/// unknown output is never reported as outdated.
bool isYtDlpOutdated(String? raw) {
  final v = raw == null ? null : parseYtDlpVersion(raw);
  return v != null && v.compareTo(parseYtDlpVersion(kMinYtDlpVersion)!) < 0;
}
