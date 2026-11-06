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
      'Song - Deluxe Version',
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
    ]) {
      expect(l.find(ImportRow(index: 0, title: t, artists: const ['Band'])), isNull, reason: t);
    }
  });

  test('a match within 5 s is found, and so is one with no known length', () {
    expect(lib.find(row(315222 + 4000))?.id, 1);
    expect(lib.find(const ImportRow(index: 0, title: 'Born On The Bayou', artists: ['Creedence Clearwater Revival']))?.id, 1);
  });
}
