import 'package:codecore/services/online/query_cleaner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const table = [
    ['01 - Car Radio (Official Video)', 'twenty one pilots', 'Car Radio', 'twenty one pilots'],
    ['Queen – Bohemian Rhapsody (Official Video Remastered)', '', 'Bohemian Rhapsody', 'Queen'],
    ['Jay-Z - Empire State of Mind', '', 'Empire State of Mind', 'Jay-Z'],
    ['Don’t Stop Believin’', 'Journey', "Don't Stop Believin'", 'Journey'],
    ['song.mp3', 'Artist - Topic', 'song', 'Artist'],
    // extra cases
    ['Spider-Man Theme', 'Unknown', 'Spider-Man Theme', 'Unknown'],
    ['Adele - Hello [Official Audio]', 'Adele VEVO', 'Hello', 'Adele'],
    ['Imagine Dragons - Believer (Lyric Video)', 'Sconosciuto', 'Believer', 'Imagine Dragons'],
    ['12. Hotel California', 'Eagles', 'Hotel California', 'Eagles'],
    ['Song - Live', 'Band', 'Song - Live', 'Band'],
    // noisy YouTube file names (R-178)
    ['Adele - Skyfall (Lyrics) [sZrTJesvJeo]', '7clouds Rock', 'Skyfall', 'Adele'],
    [
      'Inscryption - OST Preview - _The Trapper & The Trader_ by Jonah Senzel',
      '',
      'The Trapper & The Trader',
      'Jonah Senzel'
    ],
    ['Coronation Day - Pokémon Black & Pokémon White (OST) [8OAOTK]', '', 'Pokémon Black & Pokémon White', 'Coronation Day'],
    ['Luma - Super Mario Galaxy [nr-cpmEb7KM]', '', 'Super Mario Galaxy', 'Luma'],
    ['🔥 Trap City - Song 🔥', '', 'Song', 'Trap City'],
    ['[Copyright Free] Song Name', 'Chill', 'Song Name', 'Chill'],
    ['【Nightcore】 Song Name', 'Chill', 'Song Name', 'Chill'],
    ['Chill Song - No.19', 'Lofi', 'Chill Song', 'Lofi'],
    ['No. 19 - Chill Song', 'Lofi', 'Chill Song', 'Lofi'],
    ['Chill Song (No. 19)', 'Lofi', 'Chill Song', 'Lofi'],
    ['Symphony No. 5', 'Beethoven', 'Symphony No. 5', 'Beethoven'],
    ['Stand by Me', 'Ben E. King', 'Stand by Me', 'Ben E. King'],
    ['Song [Remix]', 'Band', 'Song [Remix]', 'Band'],
    ['"Song Name" by Real Artist', 'Chill Channel', 'Song Name', 'Chill Channel'],
  ];

  for (final r in table) {
    test('${r[0]} / ${r[1]}', () {
      final c = cleanSearchQuery(r[0], r[1]);
      expect(c.title, r[2]);
      expect(c.artist, r[3]);
    });
  }

  test('«Symphony No. 5 - I. Allegro» keeps its number in the tagged query', () {
    final c = cleanSearchQuery('Symphony No. 5 - I. Allegro', 'Beethoven');
    expect(c.tagged!.title, 'Symphony No. 5 - I. Allegro');
  });

  test('extractPrimaryArtist', () {
    expect(extractPrimaryArtist('A & B'), 'A');
    expect(extractPrimaryArtist('A feat. B'), 'A');
    expect(extractPrimaryArtist('A ft B'), 'A');
    expect(extractPrimaryArtist('Solo'), 'Solo');
    expect(extractPrimaryArtist(', X'), ', X');
  });

  test('coreTitle', () {
    expect(coreTitle('Car Radio (Live)'), 'Car Radio');
    expect(coreTitle('Song (feat. X)'), 'Song (feat. X)');
    expect(coreTitle('Heathens (MTV Unplugged) [Live]'), 'Heathens');
  });

  group('what a file name adds to a title', () {
    test('a copy number like (2) is dropped', () {
      final c = cleanSearchQuery('Dire Straits - Fade To Black (2)', '');
      expect([c.title, c.artist], ['Fade To Black', 'Dire Straits']);
    });

    test('a «Remastered 2011» tail goes away whole, not leaving «- 2011»', () {
      for (final t in ['Imagine - Remastered 2010', 'Imagine - 2010 Remaster', 'Imagine - Remaster', 'Imagine - Remastered Version']) {
        expect(cleanSearchQuery(t, 'John Lennon').title, 'Imagine', reason: t);
      }
      expect(cleanSearchQuery('Forever Young - Slow Version', 'Bob Dylan').title, 'Forever Young - Slow Version',
          reason: 'a version that names the song stays');
    });

    test('«Label and Artist - Artist Title» takes the artist the title repeats', () {
      final c = cleanSearchQuery('Fueled By Ramen and twenty one pilots - twenty one pilots Stressed Out', '');
      expect([c.title, c.artist], ['Stressed Out', 'twenty one pilots']);
    });

    test('«A and B - Title» without a repeated side is left as it is', () {
      final c = cleanSearchQuery('Simon and Garfunkel - The Sound of Silence', '');
      expect([c.title, c.artist], ['The Sound of Silence', 'Simon and Garfunkel']);
    });
  });

  group('uploader as artist', () {
    test('«Real Artist - Title» under an uploader reads as such, keeping the tagged query', () {
      final c = cleanSearchQuery('Adele - Skyfall', '7clouds Rock');
      expect([c.title, c.artist], ['Skyfall', 'Adele']);
      expect([c.tagged!.title, c.tagged!.artist], ['Adele - Skyfall', '7clouds Rock']);
    });

    test('a version tail (not a version in brackets), the artist in the title, or a generic artist is not split this way', () {
      expect(cleanSearchQuery('Bohemian Rhapsody - Live', 'Queen').tagged, isNull);
      expect(cleanSearchQuery('Imagine Dragons - Believer (Romy Wave Cover)', 'Trap City').artist,
          'Imagine Dragons');
      final q = cleanSearchQuery('Queen - Bohemian Rhapsody', 'Queen');
      expect([q.title, q.artist, q.tagged], ['Bohemian Rhapsody', 'Queen', null]);
      expect(cleanSearchQuery('Adele - Skyfall', 'Adele VEVO').tagged, isNull);
    });
  });

  test('splitArtists keeps names and original separators', () {
    final r = splitArtists('A, B feat. C');
    expect(r.map((e) => e.name), ['A', 'B', 'C']);
    expect(r.map((e) => e.sep), [', ', ' feat. ', '']);
    expect(splitArtists(' , ').isEmpty, true);
  });

  test('splitArtists: the last name has no separator even after a trailing one', () {
    final r = splitArtists('A &');
    expect(r.map((e) => e.name), ['A']);
    expect(r.single.sep, '');
  });
}
