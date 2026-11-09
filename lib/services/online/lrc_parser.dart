class LrcLine {
  const LrcLine(this.time, this.text);

  final Duration time;
  final String text;
}

final _stamp = RegExp(r'\[(\d{1,3}):([0-5]?\d)(?:[.:](\d{1,3}))?\]');
final _offsetTag = RegExp(
  r'^\[offset:\s*([-+]?\d+)\s*\]',
  caseSensitive: false,
);

List<LrcLine> parseLrc(String raw) {
  final lines = <LrcLine>[];
  var offsetMs = 0;
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    final off = _offsetTag.firstMatch(trimmed);
    if (off != null) {
      // A huge offset from a shared file must not throw.
      offsetMs = int.tryParse(off.group(1)!) ?? 0;
      continue;
    }
    final stamps = _stamp.allMatches(trimmed).toList();
    if (stamps.isEmpty) continue;
    final text = trimmed.substring(stamps.last.end).trim();
    for (final m in stamps) {
      final min = int.parse(m.group(1)!);
      final sec = int.parse(m.group(2)!);
      final frac = m.group(3);
      var ms = 0;
      if (frac != null) {
        ms = frac.length == 3
            ? int.parse(frac)
            : int.parse(frac.padRight(2, '0')) * 10;
      }
      final total = (min * 60 + sec) * 1000 + ms - offsetMs;
      lines.add(LrcLine(Duration(milliseconds: total < 0 ? 0 : total), text));
    }
  }
  lines.sort((a, b) => a.time.compareTo(b.time));
  return lines;
}

final _leadStamps = RegExp(r'^(?:\[\d{1,3}:[0-5]?\d(?:[.:]\d{1,3})?\]\s*)+');
final _metaTag = RegExp(r'^\[[A-Za-z]+:[^\]]*\]$');

/// Lyrics typed or pasted by hand. They are synced when most of the non-empty
/// lines (metadata tags like `[ar:X]` aside) start with a time stamp and at
/// least two do; the plain version is then every line without its leading
/// stamps. Anything else stays plain, kept whole.
({String? plain, String? synced}) lyricsFromText(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return (plain: null, synced: null);
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => !_metaTag.hasMatch(l));
  final body = lines.where((l) => l.isNotEmpty).toList();
  final timed = body.where(_leadStamps.hasMatch).length;
  if (timed < 2 || timed * 2 <= body.length) return (plain: text, synced: null);
  final plain = lines
      .map((l) => l.replaceFirst(_leadStamps, ''))
      .join('\n')
      .trim();
  return (plain: plain.isEmpty ? null : plain, synced: text);
}

/// Index of the line playing at [position], or -1 before the first one.
int currentLrcIndex(List<LrcLine> lines, Duration position) {
  var lo = 0, hi = lines.length - 1, ans = -1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (lines[mid].time <= position) {
      ans = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return ans;
}
