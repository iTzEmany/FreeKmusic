import 'package:codecore/services/lyrics/hangul_romanizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('romanizes with liaison and common assimilations', () {
    const table = {
      '안녕하세요': 'annyeonghaseyo',
      '국물': 'gungmul',
      '신라': 'silla',
      '같이': 'gachi',
      '좋아': 'joa',
      '좋다': 'jota',
      '읽어': 'ilgeo',
      '설날': 'seollal',
      '종로': 'jongno',
    };
    table.forEach((k, v) => expect(romanizeHangul(k), v, reason: k));
  });

  test('keeps non-hangul text and handles empty input', () {
    expect(romanizeHangul('사랑해, my love!'), 'saranghae, my love!');
    expect(romanizeHangul(''), '');
  });

  test(
    'final clusters, liaison of a lone consonant, nasals and palatalisation',
    () {
      // The «revised» forms this romanizer gives (documented by the table).
      const table = {
        '몫이': 'moksi',
        '앉아': 'anja',
        '없어': 'eopseo',
        '입니다': 'imnida',
        '국립': 'gungnip',
        '막혀': 'makyeo',
        '놓지': 'nochi',
        '닭이': 'dalgi',
        '힣': 'hit',
      };
      table.forEach((k, v) => expect(romanizeHangul(k), v, reason: k));
    },
  );
}
