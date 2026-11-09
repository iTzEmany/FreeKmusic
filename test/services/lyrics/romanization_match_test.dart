import 'package:codecore/services/lyrics/romanization_match.dart';
import 'package:codecore/services/online/lrc_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final orig = parseLrc(
    '[by:x]\n[00:01.00]作词 : A\n[00:05.00]こんにちは\n[00:10.00]さようなら\n'
    '[00:15.00]ありがとう',
  );

  test('stamps 70 ms off, credits dropped', () {
    final m = matchRomanization(
      orig,
      '[by:y]\n[00:01.070]作曲 : B\n[00:05.070]konnichiwa\n'
      '[00:10.070]sayonara\n[00:15.070]arigatou',
    );
    expect(m.lines, [null, 'konnichiwa', 'sayonara', 'arigatou']);
    expect(m.total, 3);
    expect(m.available, isTrue);
  });

  test(
    'missing lines: only the near ones match, half or more is available',
    () {
      final m = matchRomanization(
        orig,
        '[00:05.02]konnichiwa\n[00:15.00]arigatou',
      );
      expect(m.lines, [null, 'konnichiwa', null, 'arigatou']);
      expect(m.available, isTrue);
      final few = matchRomanization(orig, '[00:05.02]konnichiwa');
      expect(few.matched, 1);
      expect(few.available, isFalse);
    },
  );

  test('stamps far apart but same line count: by index', () {
    final m = matchRomanization(orig, '[00:30.00]a\n[00:40.00]b\n[00:50.00]c');
    expect(m.lines, [null, 'a', 'b', 'c']);
  });

  test('mm:ss:xx stamps are read', () {
    final m = matchRomanization([
      const LrcLine(Duration(milliseconds: 11950), 'x'),
    ], '[00:12.025]ro\n');
    expect(m.lines, ['ro']);
    expect(parseLrc('[00:11:95]a').single.time.inMilliseconds, 11950);
  });

  test('unsynced: by index only with the same number of lines', () {
    const lrc = '[00:01.00]a\n[00:02.00]b';
    expect(matchRomanizationByIndex(['x', '', 'y'], lrc).lines, [
      'a',
      null,
      'b',
    ]);
    final m = matchRomanizationByIndex(['x', 'y', 'z'], lrc);
    expect(m.matched, 0);
    expect(m.available, isFalse);
  });
}
