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

// «作词 : x», «作曲 : x», «By: x»… the credit lines NetEase puts in the text.
final _credit = RegExp(
  r'^\s*(?:作词|作詞|作曲|编曲|編曲|编辑|制作人|制作|监制|混音|母带|演唱|歌手|词|曲|'
  r'lyrics?|words?|music|composer|arranger|producer|written|by)'
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
    var bestGap = kRomanizationTolerance;
    for (var j = 0; j < rom.length; j++) {
      if (used.contains(j)) continue;
      final gap = (rom[j].time - original[i].time).abs();
      if (gap <= bestGap) {
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
