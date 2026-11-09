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
}
