import 'package:codecore/services/online/external_collection.dart';
import 'package:codecore/services/online/external_links.dart';
import 'package:flutter_test/flutter_test.dart';

ExternalLink l(ExternalService s, ExternalLinkKind k, String id) => ExternalLink(s, k, id);

void main() {
  const d = ExternalService.deezer, s = ExternalService.spotify;
  const pl = ExternalLinkKind.playlist,
      al = ExternalLinkKind.album,
      tr = ExternalLinkKind.track,
      ar = ExternalLinkKind.artist;

  test('Deezer and Spotify links are taken apart', () {
    final table = {
      'https://www.deezer.com/playlist/123': l(d, pl, '123'),
      'https://deezer.com/en/album/456/': l(d, al, '456'),
      'https://www.deezer.com/fr/track/7?utm=x': l(d, tr, '7'),
      'https://www.deezer.com/pt-br/artist/8': l(d, ar, '8'),
      'https://open.spotify.com/playlist/37i9dQZF1DX': l(s, pl, '37i9dQZF1DX'),
      'https://open.spotify.com/intl-it/album/4aawyAB9?si=a': l(s, al, '4aawyAB9'),
      ' http://open.spotify.com/track/abc ': l(s, tr, 'abc'),
      'https://open.spotify.com/artist/xyz': l(s, ar, 'xyz'),
    };
    table.forEach((url, want) => expect(parseExternalLink(url), want, reason: url));
  });

  test('anything else is not a link', () {
    for (final u in [
      'spotify wrapped',
      'https://deezer.com',
      'https://www.deezer.com/en/',
      'https://open.spotify.com/user/someone/playlist/abc',
      'https://open.spotify.com/user/someone',
      'spotify:playlist:abc',
      'https://evil.com/open.spotify.com/playlist/abc',
      'https://open.spotify.com.evil.com/playlist/abc',
      'https://www.deezer.com/playlist/abc',
    ]) {
      expect(parseExternalLink(u), isNull, reason: u);
    }
  });

  test('short links', () {
    expect(isShortLink('https://link.deezer.com/s/32abc'), isTrue);
    expect(isShortLink('https://deezer.page.link/xyz'), isTrue);
    expect(isShortLink('https://spotify.link/abc'), isTrue);
    expect(isShortLink('https://spotify.link/'), isFalse);
    expect(isShortLink('https://spotify.link.evil.com/abc'), isFalse);
  });

  test('a track becomes an import row', () {
    const t = ExternalTrack(
        title: 'T', artists: ['A', 'B'], key: 'k', durationMs: 5, isrc: 'X1');
    final r = t.toImportRow(3);
    expect([r.index, r.title, r.durationMs, r.isrc], [3, 'T', 5, 'X1']);
    expect(r.artists, ['A', 'B']);
  });
}
