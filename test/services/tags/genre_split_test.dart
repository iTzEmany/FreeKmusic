import 'package:codecore/services/tags/tag_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('several tags and both separators give the genres in order, once each', () {
    expect(splitGenres(['Rock; Pop', 'jazz/Blues', 'ROCK', '  ', null, 'Soul\u0000Funk']), ['Rock', 'Pop', 'jazz', 'Blues', 'Soul', 'Funk']);
  });

  test('no genre at all gives an empty list', () {
    expect(splitGenres([null, '', ' ; / ']), isEmpty);
    expect(const TagInfo().genres, isEmpty);
  });

  test('a TagInfo with only the single genre derives the list from it', () {
    const t = TagInfo(genre: 'Rock;Pop');
    expect(t.genres, ['Rock', 'Pop']);
  });

  test('without slash splitting a web genre keeps its slash', () {
    expect(splitGenres(['R&B/Soul'], slash: false), ['R&B/Soul']);
    expect(splitGenres(['Hip-Hop/Rap; Pop'], slash: false), ['Hip-Hop/Rap', 'Pop']);
  });
}
