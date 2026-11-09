/// Dominant script of a lyric text, used to pick the transliteration source.
enum LyricsScript { japanese, korean, chinese }

// Only real hiragana/katakana: the middle dot U+30FB and the long mark U+30FC
// also appear in Chinese («约翰・列侬»). Half-width katakana count too.
bool _isKana(int c) =>
    (c >= 0x3041 && c <= 0x3096) ||
    (c >= 0x30A1 && c <= 0x30FA) ||
    (c >= 0x31F0 && c <= 0x31FF) ||
    (c >= 0xFF66 && c <= 0xFF9F);

bool _isHangul(int c) =>
    (c >= 0xAC00 && c <= 0xD7A3) ||
    (c >= 0x1100 && c <= 0x11FF) ||
    (c >= 0x3130 && c <= 0x318F);

bool _isHanzi(int c) =>
    (c >= 0x4E00 && c <= 0x9FFF) ||
    (c >= 0x3400 && c <= 0x4DBF) ||
    (c >= 0xF900 && c <= 0xFAFF);

/// True when [text] has at least one kana, hangul or hanzi character.
bool hasCjk(String text) =>
    text.runes.any((c) => _isKana(c) || _isHangul(c) || _isHanzi(c));

/// Dominant script of [text], or null without CJK characters.
///
/// Any kana means Japanese (kanji alone are ambiguous, kana are not); else
/// hangul wins when there are at least as many hangul as hanzi; else hanzi
/// mean Chinese.
LyricsScript? detectScript(String text) {
  var kana = 0, hangul = 0, hanzi = 0;
  for (final c in text.runes) {
    if (_isKana(c)) {
      kana++;
    } else if (_isHangul(c)) {
      hangul++;
    } else if (_isHanzi(c)) {
      hanzi++;
    }
  }
  if (kana > 0) {
    return LyricsScript.japanese;
  }
  if (hangul > 0 && hangul >= hanzi) {
    return LyricsScript.korean;
  }
  return hanzi > 0 ? LyricsScript.chinese : null;
}
