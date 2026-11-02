import 'package:codecore/services/recognition/cover_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Titles (and artists) as in Test.zip, plus the other cover shapes of D-303.
  const covers = <(String, String?, String)>[
    ('Believer (Romy Wave Cover) [Not So Good Remix]', 'Imagine Dragons', 'Believer'),
    ('Believer (Romy Wave Cover)', '7clouds Rock', 'Believer'),
    ('Believer Romy Wave Cover Not So Good Remix', 'Imagine Dragons', 'Believer Romy Wave'),
    ('Here (Lucian Remix)', 'Alessia Cara', 'Here'),
    ('Distortion World (From Pokémon Platinum) (Arrangement)', null, 'Distortion World (From Pokémon Platinum)'),
    ('The Trapper & The Trader by Jonah Senzel', 'Inscryption', 'The Trapper & The Trader'),
    ('OST Preview - The Trapper & The Trader by Jonah Senzel', 'Inscryption', 'OST Preview - The Trapper & The Trader'),
    ('Skyfall (Piano Version)', 'Adele', 'Skyfall'),
    ('Heathens [Orchestral Version]', 'Twenty One Pilots', 'Heathens'),
    ('Happier (Piano Cover)', 'Marshmello', 'Happier'),
    ('Believer - Piano Cover', 'Romy Wave', 'Believer'),
    ('Song | Cover', 'X', 'Song'),
  ];
  const normal = <(String, String?)>[
    ('Cover Me', 'Bruce Springsteen'),
    ('Discover', 'Marc Almond'),
    ('Remixed', 'Remixed'),
    ('Stand By Me', 'Ben E. King'),
    ('Close By', 'Dolly Parton'),
    ('Believer', 'Imagine Dragons'),
    ('MONTERO (Call Me By Your Name) (Lyrics)', 'Lil Nas X'),
    ('Passing By', 'Cranberries'),
    ('Piano Man', 'Billy Joel'),
    ('Covered in Rain', 'John Frusciante'),
    ('Song Written by Me', 'Someone'),
    ('Oshi no Ko Opening by CHANMINA', 'CHANMINA'),
    ('Under Cover of Darkness', 'The Strokes'),
    ('Take Cover', 'Daughter'),
    ('Run for Cover', 'Cher'),
    ('Dive for Cover', 'Someone'),
    ('Breaking Cover', 'Someone'),
    ('Sad Arrangement', 'Someone'),
    ('Girl on the Cover', 'Someone'),
  ];

  for (final (title, artist, original) in covers) {
    test('cover: $title', () {
      final h = coverHint(title, artist);
      expect([h.cover, h.original], [true, original]);
    });
  }
  for (final (title, artist) in normal) {
    test('not a cover: $title', () => expect(coverHint(title, artist).cover, isFalse));
  }

  test('a huge title with unclosed brackets is answered fast', () {
    final sw = Stopwatch()..start();
    coverHint('(' * 20000, null);
    expect(sw.elapsedMilliseconds, lessThan(100));
  });
}
