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
}
