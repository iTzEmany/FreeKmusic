import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/lyrics/pinyin_dictionary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late PinyinDictionary dict;
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('cedict');
    const text = '''# CC-CEDICT
#! version=1
銀行 银行 [yin2 hang2] /bank/
行 行 [xing2] /to walk/
音樂 音乐 [yin1 yue4] /music/
音 音 [yin1] /sound/
我 我 [wo3] /I/
愛 爱 [ai4] /love/
你 你 [ni3] /you/
女 女 [nv3] /woman/
綠 绿 [lu:4] /green/
六 六 [liu4] /six/
行 行 [hang2] /row/
狗 狗 [gou3] /dog/
一帆風順 一帆风顺 [yi1 fan1 feng1 shun4] /smooth sailing/
的 的 [de5] /of/
''';
    File('${dir.path}/c.txt.gz')
        .writeAsBytesSync(gzip.encode(utf8.encode(text)));
    dict = await PinyinDictionary.load('${dir.path}/c.txt.gz');
  });

  tearDownAll(() => dir.delete(recursive: true));

  test('reads words in both scripts, skips comments', () {
    expect(dict.length, 18);
  });

  for (final (input, expected) in [
    ('银行', 'yínháng'),
    ('銀行', 'yínháng'),
    ('音乐', 'yīnyuè'),
    ('我爱你', 'wǒ ài nǐ'),
    ('女', 'nǚ'),
    ('绿', 'lǜ'),
    ('六', 'liù'),
    ('的', 'de'),
    ('行', 'xíng'), // the first reading listed wins
    ('狗', 'gǒu'), // the tone mark goes on the o of «ou»
    ('一帆风顺', 'yīfānfēngshùn'), // a word of more than 3 characters
    ('我 love 你', 'wǒ love nǐ'),
    ('hello 我', 'hello wǒ'),
    ('我x', 'wǒ x'),
    ('我龘你', 'wǒ 龘 nǐ'),
  ]) {
    test('romanize $input', () => expect(dict.romanize(input), expected));
  }
}
