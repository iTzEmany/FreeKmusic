import 'dart:io';

import 'package:codecore/services/online/shared_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // One row per real fixture (R-210): new language = new fixture + new row.
  for (final (n, title, artist) in const [
    (1, 'Siren', 'The Chainsmokers & Aazar'),
    (2, 'Pink (feat. Yameii Online)', 'Deko'),
    (3, 'Can We Kiss Forever? (feat. Adriana Proenza)', 'Kina'),
  ]) {
    test('Shazam it fixture $n', () {
      final text = File('test/fixtures/shazam/it_$n.txt').readAsStringSync();
      final r = routeSharedText(text) as ShazamShare;
      expect((r.title, r.artist), (title, artist));
      expect(r.shazamUrl, startsWith('https://www.shazam.com/track/'));
    });
  }

  test('a title with « di » keeps it: the split is on the last one', () {
    final r = routeSharedText('Il mare di notte di Tizio https://www.shazam.com/track/1/x') as ShazamShare;
    expect((r.title, r.artist), ('Il mare di notte', 'Tizio'));
  });

  test('a shazam link without the known phrase is a plain share, never guessed from the slug', () {
    final r = routeSharedText('Guarda https://www.shazam.com/track/444241914/siren');
    expect(r, isA<PlainShare>());
  });

  const cases = {
    'Ascolta https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=x ora':
        'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M?si=x',
    'https://www.deezer.com/it/playlist/1234 bella': 'https://www.deezer.com/it/playlist/1234',
    'guarda https://youtu.be/dQw4w9WgXcQ': 'https://youtu.be/dQw4w9WgXcQ',
    'https://spotify.link/AbCdEf123 via Spotify': 'https://spotify.link/AbCdEf123',
    'https://example.com/x https://link.deezer.com/s/abc': 'https://link.deezer.com/s/abc',
  };
  cases.forEach((text, url) {
    test('link in "$text"', () {
      expect((routeSharedText(text) as SharedLink).url, url);
    });
  });

  test('no known link is a plain share', () {
    final r = routeSharedText('una canzone https://example.com/a');
    expect((r as PlainShare).text, 'una canzone https://example.com/a');
  });

  test('subject is used only when the text is empty', () {
    expect((routeSharedText('ciao', subject: 'https://youtu.be/dQw4w9WgXcQ') as PlainShare).text, 'ciao');
    expect(
      (routeSharedText('  ', subject: 'https://youtu.be/dQw4w9WgXcQ') as SharedLink).url,
      'https://youtu.be/dQw4w9WgXcQ',
    );
  });
}
