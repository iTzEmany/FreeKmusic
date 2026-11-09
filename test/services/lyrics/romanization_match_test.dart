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

  group('matchManualRomanization', () {
    test('45 lines keep their order (no stamp sorting)', () {
      final original = [for (var i = 0; i < 45; i++) 'line $i あ'];
      final typed = [for (var i = 0; i < 45; i++) 'rom $i'].join('\n');
      final m = matchManualRomanization(original, typed);
      expect(m.lines, [for (var i = 0; i < 45; i++) 'rom $i']);
      expect(m.available, isTrue);
    });

    test(
      'a credit line gets its line too; blank lines are skipped on both sides',
      () {
        final m = matchManualRomanization([
          '作词 : A',
          '',
          'こんにちは',
        ], 'sakushi : A\n\nkonnichiwa\n');
        expect(m.lines, ['sakushi : A', null, 'konnichiwa']);
        expect(m.total, 2);
      },
    );

    test('one written line per shown line: by index, blank means none', () {
      final n = matchManualRomanization(['あ', 'い', '', 'う'], '\nii\n\nu');
      expect(n.lines, [null, 'ii', null, 'u']);
      expect((n.total, n.matched), (3, 2));
    });

    test('a different number of lines matches nothing', () {
      final m = matchManualRomanization(['あ', 'い'], 'a');
      expect(m.available, isFalse);
    });
  });

  group('matchRomanization details', () {
    List<LrcLine> at(List<int> ms) => [
      for (final t in ms) LrcLine(Duration(milliseconds: t), 'あ$t'),
    ];

    test('lines with the same stamp are paired in order', () {
      final m = matchRomanization(
        parseLrc('[00:10.00]一\n[00:10.00]二\n[00:20.00]三'),
        '[00:10.00]yi\n[00:10.00]er\n[00:20.00]san',
      );
      expect(m.lines, ['yi', 'er', 'san']);
    });

    test('the tolerance is 1.5 s: 1.4 s matches, 1.6 s does not', () {
      // Different numbers of lines, so the by-index fallback cannot help.
      final near = matchRomanization(at([10000]), '[00:11.40]a\n[00:50.00]b');
      expect(near.lines, ['a']);
      final far = matchRomanization(at([10000]), '[00:11.60]a\n[00:50.00]b');
      expect(far.lines, [null]);
      final edge = matchRomanization(at([10000]), '[00:11.50]a\n[00:50.00]b');
      expect(edge.lines, ['a'], reason: 'the limit is inclusive');
    });

    test('a transliterated line is used for one original line only', () {
      final m = matchRomanization(
        at([10000, 10500]),
        '[00:10.20]only\n[00:50.00]far\n[01:00.00]farther',
      );
      expect(m.matched, 1);
    });

    test('exactly half of the lines is available, less is not', () {
      final half = matchRomanization(
        at([1000, 2000, 3000, 4000]),
        '[00:01.00]a\n[00:02.00]b\n[00:40.00]x\n[00:50.00]y\n[01:00.00]z',
      );
      expect((half.matched, half.total, half.available), (2, 4, true));
      final less = matchRomanization(
        at([1000, 2000, 3000, 4000]),
        '[00:01.00]a\n[00:40.00]x\n[00:50.00]y\n[01:00.00]z\n[01:10.00]w',
      );
      expect((less.matched, less.available), (1, false));
    });

    test('no line that can carry a transliteration is not available', () {
      final blank = matchRomanization([
        const LrcLine(Duration(seconds: 1), ''),
        const LrcLine(Duration(seconds: 2), '作词 : A'),
      ], '[00:01.00]x');
      expect((blank.total, blank.available), (0, false));
      expect(matchRomanizationByIndex([], '').available, isFalse);
    });

    test(
      'Latin credit lines of the romalrc are dropped too, so counts agree',
      () {
        final m = matchRomanizationByIndex([
          '作词 : A',
          'こんにちは',
          'さようなら',
        ], '[00:00.50]zuo ci : A\n[00:01.00]konnichiwa\n[00:05.00]sayonara');
        expect(m.lines, [null, 'konnichiwa', 'sayonara']);
        for (final credit in ['zuo qu : B', 'Lyrics by: C', 'Composed by: D']) {
          final r = matchRomanizationByIndex([
            'あ',
          ], '[00:00.50]$credit\n[00:01.00]a');
          expect(r.lines, ['a'], reason: credit);
        }
      },
    );
  });
}
