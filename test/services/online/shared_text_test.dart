import 'dart:io';

import 'package:codecore/data/db/app_database.dart' show Track;
import 'package:codecore/services/online/shared_text.dart';
import 'package:codecore/services/share/external_share_text.dart';
import 'package:codecore/services/share/share_fragment.dart';
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

  for (final text in const [
    'Siren di   https://www.shazam.com/track/1/x', // blank artist
    ' di Deko https://www.shazam.com/track/1/x', // blank title
    'Siren di Deko http://www.shazam.com/track/1/x', // only https is a proven link
  ]) {
    test('"$text" is a plain share', () => expect(routeSharedText(text), isA<PlainShare>()));
  }

  test('extra spaces around « di » are trimmed away', () {
    final r = routeSharedText('Siren  di  Deko https://www.shazam.com/track/1/x') as ShazamShare;
    expect((r.title, r.artist), ('Siren', 'Deko'));
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

  group('share page link (D-702)', () {
    final frag = encodeShareFragment(const SharedFragment(SharedKind.playlist, 'Mix', [SharedRow.id('dQw4w9WgXcQ'), SharedRow.id('abcdefghijk')]));
    final link = 'https://itzemany.github.io/FreeKmusic/#$frag';

    test('alone and inside a text it gives the title and the ids', () {
      for (final text in [link, 'Guarda questa playlist\n$link\nciao']) {
        final r = routeSharedText(text) as SharedCollection;
        expect(r.fragment.title, 'Mix');
        expect(r.fragment.rows, [const SharedRow.id('dQw4w9WgXcQ'), const SharedRow.id('abcdefghijk')]);
      }
    });

    test('a corrupt fragment is an invalid link, not a crash', () {
      expect(routeSharedText('https://itzemany.github.io/FreeKmusic/#xx!!'), isA<InvalidShareLink>());
      expect(routeSharedText('https://itzemany.github.io/FreeKmusic/#'), isA<InvalidShareLink>());
    });

    test('another host or path is not ours', () {
      expect(routeSharedText('https://example.com/FreeKmusic/#$frag'), isA<PlainShare>());
      expect(routeSharedText('https://itzemany.github.io/Other/#$frag'), isA<PlainShare>());
    });

    test('punctuation around the link does not hide it', () {
      for (final text in ['Ascolta $link. Bello', '($link)', '<<$link>>', '"$link"', '$link!', "'$link',"]) {
        expect(routeSharedText(text), isA<SharedCollection>(), reason: text);
      }
    });

    test('a ?query before the # and any case of scheme and host are accepted', () {
      for (final l in [
        'https://itzemany.github.io/FreeKmusic/?utm=1#$frag',
        'HTTPS://ITZEMANY.GITHUB.IO/FreeKmusic/index.html#$frag',
      ]) {
        expect(routeSharedText(l), isA<SharedCollection>(), reason: l);
      }
    });

    test('our address without a readable fragment is an invalid link, not a search', () {
      for (final l in [
        'https://itzemany.github.io/FreeKmusic',
        'https://itzemany.github.io/FreeKmusic/',
        'https://itzemany.github.io/FreeKmusic/?x=1#zz!',
      ]) {
        expect(routeSharedText(l), isA<InvalidShareLink>(), reason: l);
      }
    });

    test('look-alike addresses are not ours', () {
      for (final l in [
        'https://itzemany.github.io.evil.com/FreeKmusic/#$frag',
        'https://evil.com/?u=https://itzemany.github.io/FreeKmusic/#$frag',
        'https://itzemanyXgithub.io/FreeKmusic/#$frag',
        'http://itzemany.github.io/FreeKmusic/#$frag',
        'https://itzemany.github.io:8080/FreeKmusic/#$frag',
        'https://user@itzemany.github.io/FreeKmusic/#$frag',
        'https://itzemany.github.io/FreeKmusicOther/#$frag',
      ]) {
        expect(routeSharedText(l), isA<PlainShare>(), reason: l);
      }
    });

    test('what the app shares comes back, even with a YouTube link in the title', () {
      final t = Track(
        saved: false, coverSource: 0, id: 1,
        path: 'stream:youtube:abcdefgh0_1',
        title: 'Song', artist: 'Band', albumKey: 'k', durationMs: 1000,
        format: 'mp3', sizeBytes: 1, mtimeMs: 1, hasCover: false, isFavorite: false,
        enrichStatus: 0, userEdited: false, missing: false, ignored: false,
        kind: 2, addedAt: 1, playCount: 0,
      );
      final text = buildShareText(SharedKind.playlist, 'Mix https://youtu.be/dQw4w9WgXcQ', [t]);
      final r = routeSharedText(text) as SharedCollection;
      expect(r.fragment.rows, [const SharedRow.id('abcdefgh0_1')]);
    });
  });
}
