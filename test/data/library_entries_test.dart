import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_entries.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:flutter_test/flutter_test.dart';

AlbumSummary album(String t, {int? played, int added = 0}) => AlbumSummary(
      albumKey: t,
      title: t,
      artist: 'X',
      variousArtists: false,
      trackCount: 3,
      durationMs: 1,
      year: null,
      coverKey: null,
      lastPlayedAt: played,
      addedAt: added,
    );

PlaylistSummary list(int id, String name, {int? played, int added = 0}) =>
    PlaylistSummary(Playlist(id: id, name: name, createdAt: 0, updatedAt: 0), 2, null,
        played, added);

ArtistSummary artist(String n, {int? played, int added = 0}) => ArtistSummary(
    key: n.toLowerCase(),
    name: n,
    trackCount: 4,
    albumCount: 1,
    lastPlayedAt: played,
    addedAt: added);

void main() {
  final playlists = [list(1, 'Notte', played: 50), list(2, 'In macchina')];
  final albums = [album('Zeta', played: 90, added: 5), album('Alfa', added: 30)];
  final artists = [artist('Mina', played: 70, added: 1)];

  List<String?> titles(List<LibraryEntry> e) => [for (final x in e) x.title];

  test('alphabetical mixes every kind', () {
    final e = buildLibraryEntries(
        playlists: playlists,
        albums: albums,
        artists: artists,
        sort: LibrarySort.alpha);
    expect(titles(e), ['Alfa', 'In macchina', 'Mina', 'Notte', 'Zeta']);
  });

  test('alphabetical: digits and symbols first, accents fold', () {
    final e = buildLibraryEntries(
        playlists: [list(1, 'Zeta'), list(2, '#1'), list(3, '😀'), list(4, 'Àlfa')],
        albums: [],
        artists: [],
        sort: LibrarySort.alpha);
    expect(titles(e), ['#1', '😀', 'Àlfa', 'Zeta']);
  });

  test('recent: played first by latest play, then the rest alphabetically',
      () {
    final e = buildLibraryEntries(
        playlists: playlists, albums: albums, artists: artists);
    expect(titles(e), ['Zeta', 'Mina', 'Notte', 'Alfa', 'In macchina']);
  });

  test('added: latest added first', () {
    final e = buildLibraryEntries(
        playlists: playlists,
        albums: albums,
        artists: artists,
        sort: LibrarySort.added);
    expect(e.first.title, 'Alfa');
    expect(titles(e).sublist(1, 3), ['Zeta', 'Mina']);
  });

  test('a kind filter keeps only that kind', () {
    final e = buildLibraryEntries(
        playlists: playlists,
        albums: albums,
        artists: artists,
        kind: LibraryKind.artist);
    expect(titles(e), ['Mina']);
    expect(e.single.kind, LibraryKind.artist);
  });

  group('sort criteria', () {
    AlbumSummary alb(String t, String? artist, int? year, int plays, int dur, int n) =>
        AlbumSummary(
            albumKey: t,
            title: t,
            artist: artist,
            variousArtists: false,
            trackCount: n,
            durationMs: dur,
            year: year,
            coverKey: null,
            playCount: plays);
    final al = [
      alb('B', 'Édith', 1990, 5, 300, 3),
      alb('A', 'Zed', 2010, 9, 100, 12),
      alb('C', 'abba', null, 9, 200, 7),
      alb('D', null, 1990, 0, 200, 1),
    ];
    List<String?> by(LibrarySort s, {bool? asc, LibraryKind? kind = LibraryKind.album}) =>
        titles(buildLibraryEntries(
            playlists: [], albums: al, artists: [], sort: s, ascending: asc, kind: kind));

    test('artist: accents folded, no artist last in both directions', () {
      expect(by(LibrarySort.artist), ['C', 'B', 'A', 'D']);
      expect(by(LibrarySort.artist, asc: false), ['A', 'B', 'C', 'D']);
    });
    test('year: ties fall back to the title, no year last', () {
      expect(by(LibrarySort.year), ['B', 'D', 'A', 'C']);
      expect(by(LibrarySort.year, asc: false), ['A', 'B', 'D', 'C']);
    });
    test('plays start descending, ties alphabetical', () {
      expect(by(LibrarySort.plays), ['A', 'C', 'B', 'D']);
      expect(by(LibrarySort.plays, asc: true), ['D', 'B', 'A', 'C']);
    });
    test('duration and track count', () {
      expect(by(LibrarySort.duration), ['A', 'C', 'D', 'B']);
      expect(by(LibrarySort.duration, asc: false), ['B', 'C', 'D', 'A']);
      expect(by(LibrarySort.trackCount), ['D', 'B', 'C', 'A']);
      expect(by(LibrarySort.trackCount, asc: false), ['A', 'C', 'B', 'D']);
    });
    test('alpha reversed and recent ascending', () {
      expect(by(LibrarySort.alpha, asc: false), ['D', 'C', 'B', 'A']);
      final e = buildLibraryEntries(
          playlists: playlists, albums: [], artists: [], sort: LibrarySort.recent, ascending: true);
      expect(titles(e), ['Notte', 'In macchina']);
    });
    test('various artists, unknown artist and no added date go last', () {
      final e = buildLibraryEntries(
        playlists: [],
        albums: [
          AlbumSummary(albumKey: 'v', title: 'V', artist: 'Aaa', variousArtists: true, trackCount: 1, durationMs: 1, year: null, coverKey: null, addedAt: 5),
          alb('Z', 'Zed', 1, 1, 1, 1),
          AlbumSummary(albumKey: 'n', title: 'N', artist: 'Bbb', variousArtists: false, trackCount: 1, durationMs: 1, year: null, coverKey: null, addedAt: 0),
        ],
        artists: [],
        sort: LibrarySort.artist,
      );
      expect(titles(e), ['N', 'Z', 'V']);
      final byAdded = buildLibraryEntries(
          playlists: [], albums: [e[0].album!, e[2].album!], artists: [], sort: LibrarySort.added);
      expect(titles(byAdded).last, 'N');
      final art = buildLibraryEntries(
        playlists: [],
        albums: [],
        artists: [
          const ArtistSummary(key: '', name: null, trackCount: 1, albumCount: 1),
          const ArtistSummary(key: 'm', name: 'Mina', trackCount: 1, albumCount: 1),
        ],
        sort: LibrarySort.artist,
        ascending: false,
      );
      expect(art.last.id, '');
    });
    test('track count is not offered for the artists tab', () {
      expect(LibrarySort.forKind(LibraryKind.artist), isNot(contains(LibrarySort.trackCount)));
      expect(LibrarySort.forKind(LibraryKind.album), contains(LibrarySort.trackCount));
    });
  });
}
