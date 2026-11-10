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

  group('filterByText', () {
    List<String> hits(List<String> titles, String q) =>
        filterByText(titles, q, (s) => [s]);
    test('NFD text, NFC query and the reverse', () {
      expect(hits(['Cafe\u0301 del Mar'], 'cafe del'), hasLength(1));
      expect(hits(['Café'], 'cafe\u0301'), hasLength(1));
      expect(hits(['CAFÉ'], 'café'), hasLength(1));
      expect(hits(['Café'], 'CAFE'), hasLength(1));
    });
    test('Vietnamese letters', () {
      expect(hits(['Việt Nam'], 'viet'), hasLength(1));
      expect(hits(['Hương'], 'huong'), hasLength(1));
      expect(hits(['Sơn Tùng'], 'son tung'), hasLength(1));
    });
    test('a query never matches across two fields', () {
      expect(filterByText([('Foo', 'Bar')], 'foo bar', (r) => [r.$1, r.$2]), isEmpty);
    });
    test('haystacks made off the UI isolate give the same answer', () async {
      final items = ['Café del Mar', 'Zzz'];
      await primeHaystacks(items, (s) => [s]);
      expect(filterByText(items, 'CAFE', (s) => [s]), ['Café del Mar']);
    });
  });

  group('album keys stay as they were (not search folding)', () {
    String key(String album) => computeAlbumKey(artist: 'A', album: album, directory: '/m');
    test('NFD and Vietnamese names keep their old key', () {
      // Old normalize: no NFD marks skipped, no Vietnamese letters folded.
      expect(key('Cafe\u0301'), 'a|cafe\u0301');
      expect(key('Việt'), 'a|việt');
      expect(key('Hương'), 'a|hương');
      expect(key('Café'), 'a|cafe');
    });
  });
}
