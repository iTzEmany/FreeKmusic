import 'package:codecore/services/tags/safe_tag_writer.dart';
import 'package:codecore/services/tags/tag_reader.dart';
import 'package:codecore/services/tags/tag_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a multi-artist track passes verification with the first artist as album artist', () {
    const all = 'Tinariwen, Matt Sweeney, Alain Johannes';
    const before = TagInfo(title: 'Old', durationMs: 1000);
    // The reader gives back the whole artist string and no album artist.
    const after = TagInfo(title: 'Imidiwan', artist: all, album: 'Elwan', durationMs: 1000);
    const c = TagChanges(title: 'Imidiwan', artist: all, album: 'Elwan', albumArtist: 'Tinariwen');
    expect(tagMismatch(before, after, c, format: 'flac'), isNull);
  });

  test('an album artist that is not among the artists still fails', () {
    const after = TagInfo(title: 'T', artist: 'A, B', durationMs: 1000);
    const c = TagChanges(title: 'T', albumArtist: 'Z');
    expect(tagMismatch(const TagInfo(title: 'T', durationMs: 1000), after, c), isNotNull);
  });

  test('the artist must match whole: a real name with & passes, a part of it fails', () {
    const before = TagInfo(title: 'T', durationMs: 1000);
    const after = TagInfo(title: 'T', artist: 'Simon & Garfunkel', durationMs: 1000);
    expect(tagMismatch(before, after, const TagChanges(artist: 'Simon & Garfunkel')), isNull);
    expect(tagMismatch(before, after, const TagChanges(artist: 'Simon')), isNotNull);
  });

  test('«A & B» with album artist A passes; artist A alone read back as «A & B» fails', () {
    const before = TagInfo(title: 'T', durationMs: 1000);
    const after = TagInfo(title: 'T', artist: 'A & B', durationMs: 1000);
    expect(tagMismatch(before, after, const TagChanges(artist: 'A & B', albumArtist: 'A')), isNull);
    expect(tagMismatch(before, after, const TagChanges(artist: 'A')), isNotNull);
  });
}
