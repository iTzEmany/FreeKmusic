import 'package:codecore/services/online/lrc_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('two or more timed lines are synced, the plain text drops the stamps', () {
    final r = lyricsFromText('[00:01.00]Hello\n[00:05.50] World ');
    expect(r.synced, '[00:01.00]Hello\n[00:05.50] World');
    expect(r.plain, 'Hello\nWorld');
  });
  test('untimed or single-stamp text is plain; blank has nothing', () {
    expect(lyricsFromText('just words\nmore').synced, isNull);
    expect(lyricsFromText('[00:01.00]only one').synced, isNull);
    expect(lyricsFromText(' \n ').plain, isNull);
  });
  test('stamps in the middle of a line do not make it synced; the text stays whole', () {
    const t = 'Meet at [10:30] and again at [10:30] ok\nsecond line';
    expect(lyricsFromText(t), (plain: t, synced: null));
  });
  test('tags, untimed lines and stamps without hundredths in a synced text', () {
    final r = lyricsFromText('[ar:X]\n[offset:+500]\n[Chorus]\n[01:23]one\n[01:30]two\nloose\n[01:40]three');
    expect(r.synced, isNotNull);
    expect(r.plain, '[Chorus]\none\ntwo\nloose\nthree');
  });
  test('mostly untimed lines stay plain', () {
    expect(lyricsFromText('[00:01.00]a\n[00:02.00]b\nc\nd\ne').synced, isNull);
  });
  test('timed lines with no text are synced; the plain text may be empty', () {
    final r = lyricsFromText('[00:01.00]\n[00:02.00]');
    expect((r.synced, r.plain), ('[00:01.00]\n[00:02.00]', null));
  });
  test('an offset tag with a plus sign moves the lines', () {
    expect(parseLrc('[offset:+500]\n[00:01.00]a').single.time, const Duration(milliseconds: 500));
  });
}
