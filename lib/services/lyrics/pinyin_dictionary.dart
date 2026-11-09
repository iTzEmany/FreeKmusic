import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

/// Pinyin from the CC-CEDICT dictionary (D-476): longest word first, then the
/// single character; anything unknown is left as it is.
class PinyinDictionary {
  PinyinDictionary(this._words);

  final Map<String, String> _words;

  static const _maxWord = 8;

  /// Reads a CC-CEDICT `.txt.gz` in an isolate; the map comes back without a copy.
  static Future<PinyinDictionary> load(String gzPath) async =>
      PinyinDictionary(await Isolate.run(() => _read(gzPath)));

  int get length => _words.length;

  static Future<Map<String, String>> _read(String path) async {
    final map = <String, String>{};
    final lines = File(path)
        .openRead()
        .transform(gzip.decoder)
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      final e = parseCedictLine(line);
      if (e == null) continue;
      // The first reading listed wins.
      map.putIfAbsent(e.$1, () => e.$3);
      map.putIfAbsent(e.$2, () => e.$3);
    }
    return map;
  }

  /// `傳統 传统 [chuan2 tong3] /tradition/` -> (traditional, simplified, pinyin).
  static (String, String, String)? parseCedictLine(String line) {
    if (line.isEmpty || line.startsWith('#')) return null;
    final open = line.indexOf('[');
    final close = line.indexOf(']', open + 1);
    if (open < 0 || close < 0) return null;
    final heads = line.substring(0, open).trim().split(' ');
    if (heads.length != 2) return null;
    return (
      heads[0],
      heads[1],
      numericToMarks(line.substring(open + 1, close)),
    );
  }

  /// `yin2 hang2` -> `yínháng`.
  static String numericToMarks(String numeric) =>
      numeric.split(' ').map(_syllable).join();

  static final _syl = RegExp(r'^([A-Za-z:]+)([1-5])$');
  static const _marks = {
    'a': 'āáǎà',
    'e': 'ēéěè',
    'i': 'īíǐì',
    'o': 'ōóǒò',
    'u': 'ūúǔù',
    'ü': 'ǖǘǚǜ',
    'A': 'ĀÁǍÀ',
    'E': 'ĒÉĚÈ',
    'I': 'ĪÍǏÌ',
    'O': 'ŌÓǑÒ',
    'U': 'ŪÚǓÙ',
    'Ü': 'ǕǗǙǛ',
  };

  static String _syllable(String s) {
    final m = _syl.firstMatch(s);
    if (m == null) return s; // «xx5», «A», punctuation: as listed
    final tone = int.parse(m[2]!);
    final body = m[1]!
        .replaceAll('u:', 'ü')
        .replaceAll('U:', 'Ü')
        .replaceAll('v', 'ü')
        .replaceAll('V', 'Ü');
    if (tone == 5) return body;
    final lower = body.toLowerCase();
    // The tone sits on a/e, else on the o of «ou», else on the last vowel.
    var at = lower.indexOf(RegExp('[ae]'));
    if (at < 0) at = lower.contains('ou') ? lower.indexOf('ou') : -1;
    if (at < 0) at = lower.lastIndexOf(RegExp('[aeiouü]'));
    if (at < 0) return body;
    final marked = _marks[body[at]]![tone - 1];
    return body.replaceRange(at, at + 1, marked);
  }

  static bool _alnum(int c) =>
      (c >= 0x30 && c <= 0x39) ||
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A) ||
      (c >= 0xC0 && c < 0x2000) ||
      (c >= 0x3400 && c <= 0x9FFF);

  /// The line with its Chinese turned into pinyin, words separated by a space.
  String romanize(String line) {
    final r = line.runes.toList();
    final out = StringBuffer();
    var lastPinyin = false;
    var lastAlnum = false;
    var i = 0;
    while (i < r.length) {
      String? hit;
      var len = 0;
      if (r[i] >= 0x2E80) {
        for (
          var n = _maxWord < r.length - i ? _maxWord : r.length - i;
          n >= 1;
          n--
        ) {
          hit = _words[String.fromCharCodes(r, i, i + n)];
          if (hit != null) {
            len = n;
            break;
          }
        }
      }
      if (hit != null) {
        if (lastPinyin || lastAlnum) out.write(' ');
        out.write(hit);
        i += len;
        lastPinyin = true;
        lastAlnum = false;
      } else {
        if (lastPinyin && _alnum(r[i])) out.write(' ');
        out.writeCharCode(r[i]);
        lastAlnum = _alnum(r[i]);
        lastPinyin = false;
        i++;
      }
    }
    return out.toString();
  }
}
