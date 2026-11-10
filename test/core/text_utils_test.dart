import 'package:codecore/core/text_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizeFileName', () {
    test('removes illegal chars', () => expect(sanitizeFileName('a/b:c'), 'abc'));
    test('reserved names', () => expect(sanitizeFileName('CON'), '_CON'));
    test('trailing dots and spaces',
        () => expect(sanitizeFileName('nome. '), 'nome'));
    test('truncates to 120', () {
      expect(sanitizeFileName('a' * 300).length, 120);
    });
    test('keeps emoji', () => expect(sanitizeFileName('song 🎵 ok'), 'song 🎵 ok'));
    test('empty becomes track', () => expect(sanitizeFileName('///'), 'track'));
    test('leading dots', () => expect(sanitizeFileName('..hidden'), 'hidden'));
  });

  group('normalize / albumKey', () {
    test('strips diacritics', () => expect(normalize('  Èlan  Vital '), 'elan vital'));
    test('artist|album', () {
      expect(
        computeAlbumKey(artist: 'Björk', album: 'Homogénic', directory: '/m'),
        'bjork|homogenic',
      );
    });
    test('albumArtist wins', () {
      expect(
        computeAlbumKey(albumArtist: 'VA', artist: 'X', album: 'Hits', directory: '/m'),
        'va|hits',
      );
    });
    test('unknown album groups by directory', () {
      expect(
        computeAlbumKey(artist: 'X', album: 'Unknown Album', directory: '/Music/Rock'),
        'unknown|/music/rock',
      );
      expect(
        computeAlbumKey(artist: 'X', directory: '/A'),
        'unknown|/a',
      );
    });
  });

  group('filterByText', () {
    const rows = [
      ('Café del Mar', 'Ibiza', 'Chill'),
      ('Song', 'ÉLODIE', 'Other'),
      ('Plain', 'Nobody', 'Dëep'),
    ];
    List<String> hits(String q) => [
          for (final r in filterByText(rows, q, (r) => [r.$1, r.$2, r.$3])) r.$1,
        ];
    test('title, artist and album, case and accents ignored', () {
      expect(hits('cafe'), ['Café del Mar']);
      expect(hits('elodie'), ['Song']);
      expect(hits('DEEP'), ['Plain']);
    });
    test('an empty query keeps everything, no match keeps nothing', () {
      expect(hits('  '), hasLength(3));
      expect(hits('zzz'), isEmpty);
    });
  });
}
