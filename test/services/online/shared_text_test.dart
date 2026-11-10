import 'package:codecore/services/online/shared_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
