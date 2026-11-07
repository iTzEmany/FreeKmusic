import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/smart_search.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = 100 * 86400000;

Track track(
  int id,
  String title, {
  String? artist,
  String? album,
  String? genre,
  int? year,
  bool fav = false,
  int added = 0,
  int? played,
  int plays = 0,
}) =>
    Track(coverSource: 0, 
      id: id,
      path: '/$id',
      title: title,
      artist: artist,
      album: album,
      genre: genre,
      year: year,
      albumKey: 'k',
      format: 'mp3',
      sizeBytes: 1,
      mtimeMs: 1,
      addedAt: added,
      lastPlayedAt: played,
      durationMs: 1000,
      playCount: plays,
      isFavorite: fav,
      missing: false,
      ignored: false,
      kind: 0,
      enrichStatus: 0,
      hasCover: false,
      userEdited: false,
    );

List<String> find(List<Track> tracks, String text,
    {Map<int, List<String>> tags = const {}, bool fav = false, bool recent = false}) {
  final r = smartSearch(SearchIndex(tracks, tags), text,
      favorites: fav, recent: recent, nowMs: _now);
  return [for (final t in r) t.title];
}

void main() {
  final lib = [
    track(1, 'Bohemian Rhapsody', artist: 'Queen', album: 'A Night at the Opera', genre: 'Rock', year: 1975),
    track(2, 'Je t’aime', artist: 'Mina', album: 'Éclat', genre: 'Pop', year: 1990),
    track(3, 'Thriller', artist: 'Michael Jackson', album: 'Thriller', genre: 'Pop', year: 1982),
    track(4, 'Queen of Hearts', artist: 'Juice Newton', album: 'Juice', genre: 'Country', year: 1981),
    track(5, 'Radio Ga Ga', artist: 'Queen', album: 'The Works', genre: 'Rock', year: 1984),
  ];

  test('equal scores and titles keep one order whatever the index order', () {
    final a = track(7, 'Same', artist: 'Dylan'), b = track(3, 'Same', artist: 'Dylan');
    List<int> ids(List<Track> t) => [
          for (final x in smartSearch(SearchIndex(t, const {}), 'dylan', nowMs: _now)) x.id,
        ];
    expect(ids([a, b]), [3, 7]);
    expect(ids([b, a]), [3, 7]);
  });

  test('one word matches title, artist, album, genre and year', () {
    expect(find(lib, 'opera'), ['Bohemian Rhapsody']);
    expect(find(lib, 'country'), ['Queen of Hearts']);
    expect(find(lib, '1990'), ['Je t’aime']);
    expect(find(lib, 'jackson'), ['Thriller']);
  });

  test('every word must match, in any order and across fields', () {
    expect(find(lib, 'queen rock 1984'), ['Radio Ga Ga']);
    expect(find(lib, 'rhapsody queen'), ['Bohemian Rhapsody']);
    expect(find(lib, 'queen bohemian'), ['Bohemian Rhapsody']);
    expect(find(lib, 'queen jackson'), isEmpty);
  });

  test('accents and case are ignored', () {
    expect(find(lib, 'ECLAT'), ['Je t’aime']);
    expect(find(lib, 'éclat'), ['Je t’aime']);
  });

  test('a year in the text filters by that year, not by any number', () {
    expect(find(lib, 'pop 1982'), ['Thriller']);
    expect(find(lib, '198'), isEmpty, reason: 'only a whole year matches the year field');
  });

  test('a genre name in the text filters by genre', () {
    expect(find(lib, 'rock 1975'), ['Bohemian Rhapsody']);
    expect(find(lib, 'pop'), unorderedEquals(['Je t’aime', 'Thriller']));
  });

  test('user tags are searched too', () {
    expect(find(lib, 'palestra', tags: {
      2: ['Palestra'],
      3: ['Relax'],
    }), ['Je t’aime']);
  });

  test('ranking: exact title, title start, artist, album, title inside, genre', () {
    final l = [
      track(1, 'Rock Lobster'),
      track(2, 'A rock', artist: 'X'),
      track(3, 'rock', artist: 'Y'),
      track(4, 'Z', genre: 'Rock'),
      track(5, 'Q', album: 'Rock'),
      track(6, 'W', artist: 'Rock'),
    ];
    expect(find(l, 'rock'), ['rock', 'Rock Lobster', 'W', 'Q', 'A rock', 'Z']);
  });

  test('ties go to the most played, then to the title', () {
    final l = [
      track(1, 'B', artist: 'Queen', plays: 1),
      track(2, 'A', artist: 'Queen', plays: 1),
      track(3, 'C', artist: 'Queen', plays: 9),
    ];
    expect(find(l, 'queen'), ['C', 'A', 'B']);
  });

  test('blank text lists nothing, unless a quick filter is on', () {
    expect(find(lib, '  '), isEmpty);
    expect(find([track(1, 'A', fav: true), track(2, 'B')], '', fav: true), ['A']);
  });

  test('«Preferiti» limits a text search to favourites', () {
    final l = [
      track(1, 'Hit one', artist: 'Queen', fav: true),
      track(2, 'Hit two', artist: 'Queen'),
    ];
    expect(find(l, 'queen', fav: true), ['Hit one']);
  });

  test('«Recenti» keeps what was played or added in the last 30 days, newest first', () {
    const day = 86400000;
    final l = [
      track(1, 'Old', added: _now - 90 * day),
      track(2, 'New', added: _now - 5 * day),
      track(3, 'Replayed', added: _now - 90 * day, played: _now - 1 * day),
      track(4, 'Stale play', added: _now - 90 * day, played: _now - 40 * day),
    ];
    expect(find(l, '', recent: true), ['Replayed', 'New']);
    expect(find(l, 'new', recent: true), ['New']);
    expect(find(l, 'old', recent: true), isEmpty);
  });
}
