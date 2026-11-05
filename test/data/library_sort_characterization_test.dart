import 'package:codecore/data/repositories/library_entries.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:flutter_test/flutter_test.dart';

// Characterization of phase 87: the order each LibrarySort gives today, with
// ties and accents.
ArtistSummary _artist(String n, {int? played, int added = 0}) => ArtistSummary(
    key: n,
    name: n,
    trackCount: 4,
    albumCount: 1,
    lastPlayedAt: played,
    addedAt: added);

List<String?> _titles(LibrarySort sort, List<ArtistSummary> artists) => [
      for (final e in buildLibraryEntries(
          playlists: [], albums: [], artists: artists, sort: sort))
        e.title,
    ];

void main() {
  final artists = [
    _artist('Zucchero', played: 10, added: 7),
    _artist('Eagles', played: 30, added: 7),
    _artist('Édith', played: 30, added: 7),
    _artist('Edith B', added: 7),
    _artist('Abba', added: 9),
  ];

  test('alpha: accents fold, distinct keys, fully ordered', () {
    expect(_titles(LibrarySort.alpha, artists),
        ['Abba', 'Eagles', 'Édith', 'Edith B', 'Zucchero']);
  });

  test('recent: played first by latest play, ties and never-played alphabetical', () {
    expect(_titles(LibrarySort.recent, artists),
        ['Eagles', 'Édith', 'Zucchero', 'Abba', 'Edith B']);
  });

  test('added: latest first, same date alphabetical with accents folded', () {
    expect(_titles(LibrarySort.added, artists),
        ['Abba', 'Eagles', 'Édith', 'Edith B', 'Zucchero']);
  });
}
