import '../online/lrc_parser.dart';

/// Per original line: its transliteration or null. [lines] is aligned with the
/// original lines; [total] counts the lines that could carry one (non-empty,
/// not a credit), [matched] those that do.
class RomanizationMatch {
  const RomanizationMatch(this.lines, this.total);

  final List<String?> lines;
  final int total;

  int get matched => lines.where((l) => l != null).length;

  /// D-475: under half of the lines matched means «not available».
  bool get available => total > 0 && matched * 2 >= total;
}

/// Max distance between an original and a transliterated line stamp.
const kRomanizationTolerance = Duration(milliseconds: 1500);

// «作词 : x», «作曲 : x», «By: x»… the credit lines NetEase puts in the text,
// and the same in Latin letters («zuo ci : x») as the romalrc has them.
final _credit = RegExp(
  r'^\s*(?:作词|作詞|作曲|编曲|編曲|编辑|制作人|制作|监制|混音|母带|演唱|歌手|词|曲|'
  r'zu[oò]\s*c[iíì]|zu[oò]\s*q[uǔ]|bi[aā]n\s*q[uǔ]|zhì\s*zu[oò]|zhi\s*zuo|'
  r'lyrics?|lyricist|words?|music|composer|composed|arranger|arranged|'
  r'producer|produced|written|by)'
  r'\s*(?:by)?\s*[:：]',
  caseSensitive: false,
);

bool _eligible(String text) =>
    text.trim().isNotEmpty && !_credit.hasMatch(text);

/// Synced original against a transliterated LRC: the nearest stamp within
/// [kRomanizationTolerance] (each used once); when that leaves lines out and
/// both sides have the same number of lines, by index instead.
RomanizationMatch matchRomanization(List<LrcLine> original, String romanLrc) {
  final rom = parseLrc(romanLrc).where((l) => _eligible(l.text)).toList();
  final idx = [
    for (var i = 0; i < original.length; i++)
      if (_eligible(original[i].text)) i,
  ];
  final out = List<String?>.filled(original.length, null);
  final used = <int>{};
  var hits = 0;
  for (final i in idx) {
    int? best;
    // Strictly nearer wins (the first of equal stamps); the limit is inclusive.
    var bestGap = kRomanizationTolerance + const Duration(milliseconds: 1);
    for (var j = 0; j < rom.length; j++) {
      if (used.contains(j)) continue;
      final gap = (rom[j].time - original[i].time).abs();
      if (gap < bestGap) {
        best = j;
        bestGap = gap;
      }
    }
    if (best != null) {
      used.add(best);
      out[i] = rom[best].text.trim();
      hits++;
    }
  }
  if (hits < idx.length && idx.length == rom.length) {
    for (var k = 0; k < idx.length; k++) {
      out[idx[k]] = rom[k].text.trim();
    }
  }
  return RomanizationMatch(out, idx.length);
}

/// Unsynced original (one entry per line) against a transliterated LRC: by
/// index, only when both have the same number of lines.
RomanizationMatch matchRomanizationByIndex(
  List<String> original,
  String romanLrc,
) {
  final rom = parseLrc(romanLrc).where((l) => _eligible(l.text)).toList();
  final idx = [
    for (var i = 0; i < original.length; i++)
      if (_eligible(original[i])) i,
  ];
  final out = List<String?>.filled(original.length, null);
  if (idx.length == rom.length) {
    for (var k = 0; k < idx.length; k++) {
      out[idx[k]] = rom[k].text.trim();
    }
  }
  return RomanizationMatch(out, idx.length);
}

/// Transliteration typed by hand (plain text, no stamps) against the lines
/// shown. The editor writes one line per shown line (blank where there is no
/// transliteration): with that many lines they pair by index, a blank one
/// meaning none. Otherwise by index among the non-empty lines of both sides.
/// Credits are not skipped: the user wrote a line for them too.
RomanizationMatch matchManualRomanization(List<String> original, String text) {
  final written = text.split(RegExp(r'\r?\n'));
  final idx = [
    for (var i = 0; i < original.length; i++)
      if (original[i].trim().isNotEmpty) i,
  ];
  final out = List<String?>.filled(original.length, null);
  if (written.length == original.length) {
    for (final i in idx) {
      final l = written[i].trim();
      if (l.isNotEmpty) out[i] = l;
    }
    return RomanizationMatch(out, idx.length);
  }
  final typed = [
    for (final l in written)
      if (l.trim().isNotEmpty) l.trim(),
  ];
  if (idx.length == typed.length) {
    for (var k = 0; k < idx.length; k++) {
      out[idx[k]] = typed[k];
    }
  }
  return RomanizationMatch(out, idx.length);
}
