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
}
