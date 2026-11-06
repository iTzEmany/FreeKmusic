import 'package:codecore/core/import_row.dart';
import 'package:codecore/services/import/track_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final lib = LibraryIndex(const [
    LibraryEntryLite(id: 1, title: 'Born On The Bayou', artist: 'Creedence Clearwater Revival', durationMs: 315222),
  ]);

  ImportRow row(int ms) => ImportRow(
      index: 0, title: 'Born On The Bayou', artists: const ['Creedence Clearwater Revival'], durationMs: ms);

  test('same title and artist is owned whatever the length (D-389)', () {
    expect(lib.find(row(231000))?.id, 1);
    expect(lib.find(row(315222 + 5001))?.id, 1);
  });

  test('the 5 s edge is inclusive on the approximate path (artist nested in a longer credit)', () {
    ImportRow credit(int ms) => ImportRow(
        index: 0, title: 'Born On The Bayou', artists: ['Creedence Clearwater Revival', 'Guest'], durationMs: ms);
    expect(lib.find(credit(315222 + 5000))?.id, 1);
    expect(lib.find(credit(315222 - 5000))?.id, 1);
    expect(lib.find(credit(315222 + 5001)), isNull);
  });

  test('live version stays distinct', () {
    final l = LibraryIndex(const [LibraryEntryLite(id: 1, title: 'Song', artist: 'Band', durationMs: 1000)]);
    expect(l.find(const ImportRow(index: 0, title: 'Song (Live)', artists: ['Band'])), isNull);
    expect(l.find(const ImportRow(index: 0, title: 'Song (Live Version)', artists: ['Band'])), isNull);
  });

  test('feat. in a different order matches', () {
    final l = LibraryIndex(const [LibraryEntryLite(id: 1, title: 'Song', artist: 'A feat. B', durationMs: 1000)]);
    expect(l.find(const ImportRow(index: 0, title: 'Song', artists: ['B', 'A'], durationMs: 99000))?.id, 1);
  });

  test('same title, different artist is not owned', () {
    final l = LibraryIndex(const [LibraryEntryLite(id: 1, title: 'Song', artist: 'Band', durationMs: 1000)]);
    expect(l.find(const ImportRow(index: 0, title: 'Song', artists: ['Other'], durationMs: 1000)), isNull);
  });

  test('edition suffixes are ignored', () {
    final l = LibraryIndex(const [LibraryEntryLite(id: 1, title: 'Song', artist: 'Band', durationMs: 1000)]);
    for (final t in [
      'Song (25th Anniversary Edition)',
      'Song - 40th Anniversary',
      'Song - Deluxe Edition',
      'Song [Expanded Edition]',
      'Song (2009 Remaster)',
      'Song (Album Version)',
    ]) {
      expect(l.find(ImportRow(index: 0, title: t, artists: const ['Band'])), isNotNull, reason: t);
    }
  });

  test('other kinds of version stay distinct', () {
    final l = LibraryIndex(const [LibraryEntryLite(id: 1, title: 'Song', artist: 'Band', durationMs: 1000)]);
    for (final t in [
      'Song - Acoustic Version',
      'Song (Instrumental Version)',
      'Song (Radio Version)',
      'Song (Demo Version)',
      'Song - Remix Version',
      "Song (Taylor's Version)",
      'Song (Extended Version)',
      'Song (Piano Version)',
      'Song - Orchestral Version',
      'Song (Remixed Deluxe Edition)',
    ]) {
      expect(l.find(ImportRow(index: 0, title: t, artists: const ['Band'])), isNull, reason: t);
    }
  });

  test('a match within 5 s is found, and so is one with no known length', () {
    expect(lib.find(row(315222 + 4000))?.id, 1);
    expect(lib.find(const ImportRow(index: 0, title: 'Born On The Bayou', artists: ['Creedence Clearwater Revival']))?.id, 1);
  });

  test('subversion and conversion are not edition words', () {
    final l = LibraryIndex(const [LibraryEntryLite(id: 1, title: 'Song', artist: 'Band', durationMs: 1000)]);
    expect(l.find(const ImportRow(index: 0, title: 'Song (Subversion)', artists: ['Band'])), isNull);
    expect(l.find(const ImportRow(index: 0, title: 'Song - Conversion', artists: ['Band'])), isNull);
  });

  test('a nested artist credit with an unknown length is not owned', () {
    final l = LibraryIndex(const [LibraryEntryLite(id: 1, title: 'Smells Like Teen Spirit', artist: 'Nirvana', durationMs: 301000)]);
    expect(l.find(const ImportRow(index: 0, title: 'Smells Like Teen Spirit', artists: ['Nirvana Tribute Band'])), isNull);
    expect(l.find(const ImportRow(index: 0, title: 'Smells Like Teen Spirit', artists: ['Nirvana', 'Guest'])), isNull);
  });

  test('an untagged track is not owned by title alone', () {
    final l = LibraryIndex(const [LibraryEntryLite(id: 1, title: 'Song', artist: null, durationMs: 1000)]);
    expect(l.find(const ImportRow(index: 0, title: 'Song', artists: [])), isNull);
  });

  test('of several tracks with the same key the closest length wins', () {
    final l = LibraryIndex(const [
      LibraryEntryLite(id: 1, title: 'Intro', artist: 'Band', durationMs: 60000),
      LibraryEntryLite(id: 2, title: 'Intro', artist: 'Band', durationMs: 120000),
    ]);
    expect(l.find(const ImportRow(index: 0, title: 'Intro', artists: ['Band'], durationMs: 118000))?.id, 2);
    expect(l.find(const ImportRow(index: 0, title: 'Intro', artists: ['Band'], durationMs: 62000))?.id, 1);
  });

  LibraryIndex one(String title, [String artist = 'Band']) =>
      LibraryIndex([LibraryEntryLite(id: 1, title: title, artist: artist, durationMs: 1000)]);
  ImportRow rw(String title, [String artist = 'Band']) => ImportRow(index: 0, title: title, artists: [artist]);

  test('a group with any non-edition word stays distinct', () {
    final l = one('Song');
    for (final t in [
      'Song (Spanish Edition)',
      "Song (Taylor's Version - Deluxe Edition)",
      'Song (Sped Up Edition)',
      'Song (Nightcore Edition)',
      'Song (Extended Edition)',
      'Song (Piano Version - Anniversary Edition)',
      'Song - Piano Version Anniversary',
    ]) {
      expect(l.find(rw(t)), isNull, reason: t);
    }
    for (final t in ['Song (25th Anniversary Edition)', 'Song (Deluxe Edition)', 'Song [Special Edition]', 'Song - Expanded Edition']) {
      expect(l.find(rw(t)), isNotNull, reason: t);
    }
  });

  test('symbol-only titles do not collide, and an empty title never matches', () {
    expect(one('😀').find(rw('🎉')), isNull);
    expect(one('😀').find(rw('😀')), isNotNull);
    expect(one('...').find(rw('???')), isNull);
    expect(one('').find(rw('  ')), isNull);
  });

  test('symbol-only artists match only the same symbols', () {
    expect(one('Song', '!!!').find(rw('Song', '!!!')), isNotNull);
    expect(one('Song', '!!!').find(rw('Song', '+')), isNull);
  });

  test('a huge unclosed title is cheap', () {
    final sw = Stopwatch()..start();
    one('Song').find(rw('Song (${'a' * 10000}'));
    expect(sw.elapsedMilliseconds, lessThan(1000));
  });

  test('a known close length beats an unknown one', () {
    final l = LibraryIndex(const [
      LibraryEntryLite(id: 1, title: 'Intro', artist: 'Band', durationMs: 0),
      LibraryEntryLite(id: 2, title: 'Intro', artist: 'Band', durationMs: 90000),
    ]);
    expect(l.find(ImportRow(index: 0, title: 'Intro', artists: const ['Band'], durationMs: 100000))?.id, 2);
  });

  test('a longer credit in the library is an approximate match only: 20 s apart or unknown is null', () {
    final l = one('Song', 'Queen & David Bowie');
    expect(l.find(const ImportRow(index: 0, title: 'Song', artists: ['Queen'], durationMs: 21000)), isNull);
    expect(l.find(rw('Song', 'Queen')), isNull);
    expect(l.find(const ImportRow(index: 0, title: 'Song', artists: ['Queen'], durationMs: 3000))?.id, 1);
  });
}
