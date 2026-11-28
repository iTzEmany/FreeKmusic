import 'package:codecore/services/online/karaoke_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isKaraokeTitle: the word karaoke in any case, nothing else', () {
    expect(isKaraokeTitle('Song (Karaoke Version)'), isTrue);
    expect(isKaraokeTitle('SONG KARAOKE'), isTrue);
    expect(isKaraokeTitle('Song - Karaoke Live'), isTrue); // extra exclusions live in karaokeResults
    expect(isKaraokeTitle('Song'), isFalse);
    expect(isKaraokeTitle(''), isFalse);
  });
}
