import 'package:codecore/services/lyrics/script_detect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detectScript picks the dominant script', () {
    expect(detectScript('こんにちは 世界'), LyricsScript.japanese);
    expect(detectScript('안녕하세요 hello'), LyricsScript.korean);
    expect(detectScript('你好世界'), LyricsScript.chinese);
    expect(detectScript('hello world'), isNull);
    expect(detectScript(''), isNull);
  });

  test('hasCjk is true only with kana, hangul or hanzi', () {
    expect(hasCjk('abc 사랑'), isTrue);
    expect(hasCjk('愛'), isTrue);
    expect(hasCjk('ア'), isTrue);
    expect(hasCjk('abc, 123'), isFalse);
  });

  test(
    'the middle dot and the long mark alone do not make Chinese Japanese',
    () {
      expect(detectScript('约翰・列侬 你好'), LyricsScript.chinese);
      expect(detectScript('ー 你好'), LyricsScript.chinese);
      expect(hasCjk('・ー'), isFalse);
      expect(detectScript('ラーメン'), LyricsScript.japanese);
    },
  );

  test(
    'every kana, hangul and hanzi range is recognised, one row per range',
    () {
      for (final (char, script) in [
        ('\u3041', LyricsScript.japanese), // hiragana first
        ('\u3096', LyricsScript.japanese), // hiragana last
        ('\u30A1', LyricsScript.japanese), // katakana first
        ('\u30FA', LyricsScript.japanese), // katakana last
        ('\u31F0', LyricsScript.japanese), // katakana extensions
        ('\uFF66', LyricsScript.japanese), // half-width katakana first
        ('\uFF9F', LyricsScript.japanese), // half-width katakana last
        ('\uAC00', LyricsScript.korean), // syllables
        ('\u1100', LyricsScript.korean), // jamo
        ('\u3131', LyricsScript.korean), // compatibility jamo
        ('\u4E00', LyricsScript.chinese), // CJK ideographs
        ('\u3400', LyricsScript.chinese), // extension A
        ('\uF900', LyricsScript.chinese), // compatibility ideographs
      ]) {
        expect(
          detectScript(char),
          script,
          reason: char.runes.first.toRadixString(16),
        );
      }
      expect(detectScript('\u30FB'), isNull);
      expect(detectScript('\uFF65'), isNull);
    },
  );

  test('hangul and hanzi in equal number: Korean; one more hanzi: Chinese', () {
    expect(detectScript('가 你'), LyricsScript.korean);
    expect(detectScript('가 你好'), LyricsScript.chinese);
  });
}
